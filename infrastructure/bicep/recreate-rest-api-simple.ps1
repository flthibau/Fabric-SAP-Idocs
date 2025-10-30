# Recreate REST API with simplest possible configuration
# This script deletes and recreates the REST API to troubleshoot 404 issues

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RECREATE REST API - SIMPLE VERSION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
Write-Host "Authenticating..." -ForegroundColor Yellow
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

# Delete existing REST API
Write-Host "`nDeleting existing REST API..." -ForegroundColor Yellow
$deleteUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api?api-version=2021-08-01"

try {
    Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers @{
        "Authorization" = "Bearer $token"
    } | Out-Null
    Write-Host "Deleted!" -ForegroundColor Green
    Start-Sleep -Seconds 5
} catch {
    Write-Host "Could not delete (maybe doesn't exist): $($_.Exception.Message)" -ForegroundColor Gray
}

# Create API with SIMPLEST configuration
Write-Host "`nCreating new REST API with simple config..." -ForegroundColor Yellow

$apiBody = @{
    properties = @{
        displayName = "3PL Partner REST API"
        path = "rest"  # Changed from "api/v1" to simple "rest"
        protocols = @("https")
        subscriptionRequired = $false
    }
} | ConvertTo-Json -Depth 10

$createUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api?api-version=2021-08-01"

try {
    $api = Invoke-RestMethod -Method Put -Uri $createUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $apiBody
    
    Write-Host "API Created!" -ForegroundColor Green
    Write-Host "  Name: $($api.properties.displayName)" -ForegroundColor Gray
    Write-Host "  Path: $($api.properties.path)" -ForegroundColor Gray
    
} catch {
    Write-Host "ERROR creating API: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

# Create ONE simple operation
Write-Host "`nCreating simple GET /shipments operation..." -ForegroundColor Yellow

$opBody = @{
    properties = @{
        displayName = "Get Shipments"
        method = "GET"
        urlTemplate = "/shipments"
        description = "Get shipments from Fabric GraphQL"
    }
} | ConvertTo-Json -Depth 10

$opUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api/operations/get-shipments?api-version=2021-08-01"

try {
    $operation = Invoke-RestMethod -Method Put -Uri $opUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $opBody
    
    Write-Host "Operation Created!" -ForegroundColor Green
    Write-Host "  Method: $($operation.properties.method)" -ForegroundColor Gray
    Write-Host "  URL: $($operation.properties.urlTemplate)" -ForegroundColor Gray
    
} catch {
    Write-Host "ERROR creating operation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

# Create SIMPLE policy for the operation
Write-Host "`nCreating operation policy..." -ForegroundColor Yellow

$policy = @'
<policies>
    <inbound>
        <set-backend-service backend-id="fabric-graphql-backend" />
        <set-body>{"query":"query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id } } }"}</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <set-method>POST</set-method>
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
    </outbound>
    <on-error>
    </on-error>
</policies>
'@

$policyBody = @{
    properties = @{
        value = $policy
        format = "rawxml"
    }
} | ConvertTo-Json -Depth 10

$policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api/operations/get-shipments/policies/policy?api-version=2021-08-01"

try {
    Invoke-RestMethod -Method Put -Uri $policyUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $policyBody | Out-Null
    
    Write-Host "Policy Created!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR creating policy: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  REST API RECREATED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nNew configuration:" -ForegroundColor Cyan
Write-Host "  API Path: rest" -ForegroundColor Yellow
Write-Host "  Full URL: https://apim-3pl-flt.azure-api.net/rest/shipments" -ForegroundColor Yellow
Write-Host "  Method: GET" -ForegroundColor Yellow

Write-Host "`nWaiting 10 seconds for propagation..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Test the new endpoint
Write-Host "`nTesting new endpoint..." -ForegroundColor Cyan

az login --service-principal `
    -u "94a9edcc-7a22-4d89-b001-799e8414711a" `
    -p "YOUR_FEDEX_SECRET_HERE" `
    --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4" | Out-Null

$testTokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$testToken = $testTokenJson.accessToken

try {
    $response = Invoke-WebRequest `
        -Uri "https://apim-3pl-flt.azure-api.net/rest/shipments" `
        -Method Get `
        -Headers @{"Authorization" = "Bearer $testToken"} `
        -ErrorAction Stop
    
    Write-Host "`n✅ SUCCESS! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "`nResponse:" -ForegroundColor Yellow
    Write-Host $response.Content
    
} catch {
    Write-Host "`n❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
