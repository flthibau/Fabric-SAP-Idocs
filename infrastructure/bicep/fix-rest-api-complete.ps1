# Fix REST API with complete working configuration
# Based on successful GraphQL API configuration

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FIX REST API - COMPLETE CONFIGURATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
Write-Host "Authenticating..." -ForegroundColor Yellow
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

Write-Host "Authenticated!`n" -ForegroundColor Green

# Update operation policy with complete transformation
Write-Host "Updating get-shipments policy with complete transformation..." -ForegroundColor Yellow

$completePolicy = @'
<policies>
    <inbound>
        <set-backend-service backend-id="fabric-graphql-backend" />
        <set-body>{"query":"query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id customer_id origin_location destination_location current_status estimated_delivery_date actual_delivery_date } } }"}</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <set-method>POST</set-method>
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <set-body>@{
            var response = context.Response.Body.As<JObject>(preserveContent: true);
            if (response["data"] != null && response["data"]["gold_shipments_in_transits"] != null) {
                var items = response["data"]["gold_shipments_in_transits"]["items"];
                return items.ToString();
            }
            return "[]";
        }</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </outbound>
    <on-error>
        <set-body>@{
            return new JObject(
                new JProperty("error", context.LastError.Message),
                new JProperty("source", context.LastError.Source)
            ).ToString();
        }</set-body>
    </on-error>
</policies>
'@

$policyBody = @{
    properties = @{
        value = $completePolicy
        format = "rawxml"
    }
} | ConvertTo-Json -Depth 10

$policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api/operations/get-shipments/policies/policy?api-version=2021-08-01"

try {
    Invoke-RestMethod -Method Put -Uri $policyUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $policyBody | Out-Null
    
    Write-Host "Policy updated successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR updating policy: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nWaiting 10 seconds for propagation..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Test with Service Principal
Write-Host "`nTesting REST API with FedEx Service Principal..." -ForegroundColor Cyan

az login --service-principal `
    -u "94a9edcc-7a22-4d89-b001-799e8414711a" `
    -p "YOUR_FEDEX_SECRET_HERE" `
    --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4" | Out-Null

$testTokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$testToken = $testTokenJson.accessToken

Write-Host "Token acquired" -ForegroundColor Gray
Write-Host "Calling: GET https://apim-3pl-flt.azure-api.net/rest/shipments`n" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest `
        -Uri "https://apim-3pl-flt.azure-api.net/rest/shipments" `
        -Method Get `
        -Headers @{"Authorization" = "Bearer $testToken"} `
        -ErrorAction Stop
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ SUCCESS!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nHTTP Status: $($response.StatusCode)" -ForegroundColor Yellow
    Write-Host "Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Gray
    Write-Host "`nResponse Body:" -ForegroundColor Cyan
    
    # Parse and display nicely
    $json = $response.Content | ConvertFrom-Json
    if ($json -is [array]) {
        Write-Host "Shipments returned: $($json.Count)" -ForegroundColor Yellow
        Write-Host "`nFirst 3 shipments:" -ForegroundColor Gray
        $json | Select-Object -First 3 | ForEach-Object {
            Write-Host "  - $($_.shipment_number) | Carrier: $($_.carrier_id)" -ForegroundColor White
        }
    } else {
        Write-Host $response.Content
    }
    
} catch {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ❌ ERROR" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "`nHTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Response.ReasonPhrase)" -ForegroundColor Yellow
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        if ($responseBody) {
            Write-Host "`nResponse Body:" -ForegroundColor Yellow
            Write-Host $responseBody
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "`nNEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. If this works, test in Azure Portal (refresh page first)" -ForegroundColor Gray
Write-Host "2. If Azure Portal gives 403, use the Service Principal credentials" -ForegroundColor Gray
Write-Host "3. Once working, create additional REST operations" -ForegroundColor Gray
Write-Host "`n========================================`n" -ForegroundColor Cyan
