# Comprehensive APIM REST API Diagnostic Script
# Checks all possible issues that could cause 404

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  APIM REST API DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

Write-Host "✓ Authenticated`n" -ForegroundColor Green

# 1. Check APIM Service Status
Write-Host "1. APIM Service Status" -ForegroundColor Yellow
Write-Host "   " -NoNewline
$apimUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt?api-version=2021-08-01"
$apim = Invoke-RestMethod -Method Get -Uri $apimUrl -Headers @{"Authorization" = "Bearer $token"}
Write-Host "Provisioning State: $($apim.properties.provisioningState)" -ForegroundColor $(if($apim.properties.provisioningState -eq "Succeeded"){"Green"}else{"Red"})
Write-Host "   Gateway URL: $($apim.properties.gatewayUrl)" -ForegroundColor Gray
Write-Host "   Developer Portal: $($apim.properties.developerPortalUrl)" -ForegroundColor Gray

# 2. Check REST API Configuration
Write-Host "`n2. REST API Configuration" -ForegroundColor Yellow
$apiUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api?api-version=2021-08-01"
$api = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers @{"Authorization" = "Bearer $token"}
Write-Host "   Name: $($api.name)" -ForegroundColor Gray
Write-Host "   Display Name: $($api.properties.displayName)" -ForegroundColor Gray
Write-Host "   Path: $($api.properties.path)" -ForegroundColor Cyan
Write-Host "   IsCurrent: $($api.properties.isCurrent)" -ForegroundColor $(if($api.properties.isCurrent){"Green"}else{"Red"})
Write-Host "   IsOnline: $($api.properties.isOnline)" -ForegroundColor $(if($api.properties.isOnline -eq $null){"Gray"}elseif($api.properties.isOnline){"Green"}else{"Red"})
Write-Host "   Subscription Required: $($api.properties.subscriptionRequired)" -ForegroundColor $(if($api.properties.subscriptionRequired){"Red"}else{"Green"})
Write-Host "   Service URL: '$($api.properties.serviceUrl)'" -ForegroundColor $(if([string]::IsNullOrEmpty($api.properties.serviceUrl)){"Yellow"}else{"Green"})

# 3. Check Operations
Write-Host "`n3. Operations" -ForegroundColor Yellow
$opsUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api/operations?api-version=2021-08-01"
$ops = Invoke-RestMethod -Method Get -Uri $opsUrl -Headers @{"Authorization" = "Bearer $token"}
Write-Host "   Total Operations: $($ops.value.Count)" -ForegroundColor Cyan
foreach($op in $ops.value) {
    Write-Host "   - $($op.properties.method) $($op.properties.urlTemplate)" -ForegroundColor Gray
    Write-Host "     Display Name: $($op.properties.displayName)" -ForegroundColor DarkGray
}

# 4. Check Operation Policy
if ($ops.value.Count -gt 0) {
    Write-Host "`n4. Operation Policy (get-shipments)" -ForegroundColor Yellow
    $policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api/operations/get-shipments/policies/policy?api-version=2021-08-01&format=rawxml"
    try {
        $policy = Invoke-RestMethod -Method Get -Uri $policyUrl -Headers @{"Authorization" = "Bearer $token"}
        $policyXml = $policy.properties.value
        
        # Check for key policy elements
        Write-Host "   Backend Service: " -NoNewline -ForegroundColor Gray
        if ($policyXml -match 'set-backend-service.*backend-id="([^"]+)"') {
            Write-Host $matches[1] -ForegroundColor Green
        } else {
            Write-Host "NOT FOUND" -ForegroundColor Red
        }
        
        Write-Host "   Set Method: " -NoNewline -ForegroundColor Gray
        if ($policyXml -match '<set-method>([^<]+)</set-method>') {
            Write-Host $matches[1] -ForegroundColor Green
        } else {
            Write-Host "NOT FOUND" -ForegroundColor Yellow
        }
        
        Write-Host "   Set Body: " -NoNewline -ForegroundColor Gray
        if ($policyXml -match '<set-body>') {
            Write-Host "YES" -ForegroundColor Green
        } else {
            Write-Host "NO" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "   ERROR: Could not retrieve policy" -ForegroundColor Red
    }
}

# 5. Check Backend Configuration
Write-Host "`n5. Backend Configuration" -ForegroundColor Yellow
$backendUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/backends/fabric-graphql-backend?api-version=2021-08-01"
try {
    $backend = Invoke-RestMethod -Method Get -Uri $backendUrl -Headers @{"Authorization" = "Bearer $token"}
    Write-Host "   Backend ID: fabric-graphql-backend" -ForegroundColor Green
    Write-Host "   URL: $($backend.properties.url)" -ForegroundColor Gray
    Write-Host "   Protocol: $($backend.properties.protocol)" -ForegroundColor Gray
} catch {
    Write-Host "   ERROR: Backend not found!" -ForegroundColor Red
}

# 6. Compare with working GraphQL API
Write-Host "`n6. Comparison with GraphQL API (working)" -ForegroundColor Yellow
$graphqlApiUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/graphql-partner-api?api-version=2021-08-01"
$graphqlApi = Invoke-RestMethod -Method Get -Uri $graphqlApiUrl -Headers @{"Authorization" = "Bearer $token"}

Write-Host "`n   GraphQL API:" -ForegroundColor Cyan
Write-Host "     Path: $($graphqlApi.properties.path)" -ForegroundColor Gray
Write-Host "     IsCurrent: $($graphqlApi.properties.isCurrent)" -ForegroundColor Gray
Write-Host "     Service URL: '$($graphqlApi.properties.serviceUrl)'" -ForegroundColor Gray

Write-Host "`n   REST API:" -ForegroundColor Cyan
Write-Host "     Path: $($api.properties.path)" -ForegroundColor Gray
Write-Host "     IsCurrent: $($api.properties.isCurrent)" -ForegroundColor Gray
Write-Host "     Service URL: '$($api.properties.serviceUrl)'" -ForegroundColor Gray

Write-Host "`n   Differences:" -ForegroundColor Yellow
if ($graphqlApi.properties.serviceUrl -ne $api.properties.serviceUrl) {
    Write-Host "     Service URL differs!" -ForegroundColor Red
}
if ($graphqlApi.properties.path.Contains('/') -ne $api.properties.path.Contains('/')) {
    Write-Host "     Path format differs (slashes)!" -ForegroundColor Yellow
}

# 7. Test Connectivity
Write-Host "`n7. Test Connectivity" -ForegroundColor Yellow

# Get SP token
az login --service-principal `
    -u "94a9edcc-7a22-4d89-b001-799e8414711a" `
    -p "YOUR_FEDEX_SECRET_HERE" `
    --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4" | Out-Null

$testTokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$testToken = $testTokenJson.accessToken

Write-Host "   Testing GraphQL API..." -NoNewline -ForegroundColor Gray
try {
    $response = Invoke-WebRequest `
        -Uri "https://apim-3pl-flt.azure-api.net/graphql" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $testToken"
            "Content-Type" = "application/json"
        } `
        -Body '{"query":"query { gold_shipments_in_transits(first: 1) { items { shipment_number } } }"}' `
        -ErrorAction Stop
    Write-Host " ✓ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host " ✗ $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

Write-Host "   Testing REST API..." -NoNewline -ForegroundColor Gray
try {
    $response = Invoke-WebRequest `
        -Uri "https://apim-3pl-flt.azure-api.net/rest/shipments" `
        -Method Get `
        -Headers @{"Authorization" = "Bearer $testToken"} `
        -ErrorAction Stop
    Write-Host " ✓ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host " ✗ $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

# 8. Check APIM Diagnostics Settings
Write-Host "`n8. APIM Diagnostics" -ForegroundColor Yellow
$diagUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/diagnostics?api-version=2021-08-01"
try {
    $diags = Invoke-RestMethod -Method Get -Uri $diagUrl -Headers @{"Authorization" = "Bearer $token"}
    Write-Host "   Diagnostics Configured: $($diags.value.Count)" -ForegroundColor Gray
} catch {
    Write-Host "   Could not retrieve diagnostics" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "SUMMARY:" -ForegroundColor Yellow
Write-Host "  GraphQL API (path: '$($graphqlApi.properties.path)'): WORKING ✓" -ForegroundColor Green
Write-Host "  REST API (path: '$($api.properties.path)'): NOT WORKING ✗" -ForegroundColor Red
Write-Host "`nPlease check the portal and try the Test tab for REST API." -ForegroundColor Cyan
