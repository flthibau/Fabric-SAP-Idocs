# Recreate REST API by copying EXACTLY the working GraphQL API configuration
# Only change: path and operation details

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RECREATE REST API (copy GraphQL config)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

# Get GraphQL API configuration as reference
Write-Host "Getting GraphQL API configuration (working baseline)..." -ForegroundColor Yellow
$graphqlUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/graphql-partner-api?api-version=2021-08-01"
$graphqlApi = Invoke-RestMethod -Method Get -Uri $graphqlUrl -Headers @{"Authorization" = "Bearer $token"}

Write-Host "GraphQL API Config:" -ForegroundColor Gray
Write-Host "  Path: $($graphqlApi.properties.path)" -ForegroundColor DarkGray
Write-Host "  Subscription Required: $($graphqlApi.properties.subscriptionRequired)" -ForegroundColor DarkGray
Write-Host "  Protocols: $($graphqlApi.properties.protocols -join ', ')" -ForegroundColor DarkGray
Write-Host "  Service URL: '$($graphqlApi.properties.serviceUrl)'" -ForegroundColor DarkGray

# Delete existing REST API
Write-Host "`nDeleting existing REST API..." -ForegroundColor Yellow
$deleteUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/rest-partner-api?api-version=2021-08-01"
try {
    Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers @{"Authorization" = "Bearer $token"} | Out-Null
    Write-Host "Deleted!" -ForegroundColor Green
    Start-Sleep -Seconds 5
} catch {
    Write-Host "Could not delete: $($_.Exception.Message)" -ForegroundColor Gray
}

# Create new REST API with EXACT same config as GraphQL
Write-Host "`nCreating REST API with GraphQL's exact configuration..." -ForegroundColor Yellow

# Copy GraphQL configuration but change path to "shipments"
$apiBody = @{
    properties = @{
        displayName = "3PL Shipments REST API"
        path = "shipments"  # Simple path like GraphQL uses "graphql"
        protocols = $graphqlApi.properties.protocols
        subscriptionRequired = $graphqlApi.properties.subscriptionRequired
        serviceUrl = $graphqlApi.properties.serviceUrl  # Same as GraphQL (probably null)
    }
} | ConvertTo-Json -Depth 10

$createUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/shipments-rest-api?api-version=2021-08-01"

try {
    $api = Invoke-RestMethod -Method Put -Uri $createUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $apiBody
    
    Write-Host "API Created!" -ForegroundColor Green
    Write-Host "  Name: $($api.properties.displayName)" -ForegroundColor Gray
    Write-Host "  Path: $($api.properties.path)" -ForegroundColor Gray
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

# Create ONE operation - use POST like GraphQL does (not GET)
Write-Host "`nCreating POST operation (like GraphQL)..." -ForegroundColor Yellow

$opBody = @{
    properties = @{
        displayName = "Get Shipments"
        method = "POST"  # Same as GraphQL
        urlTemplate = "/"  # Same as GraphQL (root)
        description = "Get shipments from Fabric GraphQL"
        request = @{
            description = "GraphQL request"
            representations = @(
                @{
                    contentType = "application/json"
                }
            )
        }
    }
} | ConvertTo-Json -Depth 10

$opUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/shipments-rest-api/operations/get-shipments?api-version=2021-08-01"

try {
    $operation = Invoke-RestMethod -Method Put -Uri $opUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $opBody
    
    Write-Host "Operation Created!" -ForegroundColor Green
    Write-Host "  Method: $($operation.properties.method)" -ForegroundColor Gray
    Write-Host "  URL: $($operation.properties.urlTemplate)" -ForegroundColor Gray
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

# Create EXACT same policy as GraphQL (but with shipments query)
Write-Host "`nCreating operation policy (same structure as GraphQL)..." -ForegroundColor Yellow

$policy = @'
<policies>
    <inbound>
        <set-backend-service backend-id="fabric-graphql-backend" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
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

$policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/shipments-rest-api/operations/get-shipments/policies/policy?api-version=2021-08-01"

try {
    Invoke-RestMethod -Method Put -Uri $policyUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $policyBody | Out-Null
    
    Write-Host "Policy Created!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Add to Partner APIs product
Write-Host "`nAdding API to 'Partner APIs' product..." -ForegroundColor Yellow
try {
    az apim product api add `
        --resource-group rg-3pl-partner-api `
        --service-name apim-3pl-flt `
        --product-id partner-apis `
        --api-id shipments-rest-api 2>$null | Out-Null
    Write-Host "Added to product!" -ForegroundColor Green
} catch {
    Write-Host "Could not add to product (may not exist)" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  REST API CREATED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nNew API configuration:" -ForegroundColor Cyan
Write-Host "  API Path: shipments" -ForegroundColor Yellow
Write-Host "  Operation: POST /" -ForegroundColor Yellow
Write-Host "  Full URL: https://apim-3pl-flt.azure-api.net/shipments" -ForegroundColor Yellow
Write-Host "  Method: POST (like GraphQL)" -ForegroundColor Yellow

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

$graphqlQuery = '{"query":"query { gold_shipments_in_transits(first: 5) { items { shipment_number carrier_id } } }"}'

try {
    $response = Invoke-WebRequest `
        -Uri "https://apim-3pl-flt.azure-api.net/shipments" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $testToken"
            "Content-Type" = "application/json"
        } `
        -Body $graphqlQuery `
        -ErrorAction Stop
    
    Write-Host "`n✅ SUCCESS! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "`nResponse:" -ForegroundColor Yellow
    $json = $response.Content | ConvertFrom-Json
    Write-Host "Shipments returned: $($json.data.gold_shipments_in_transits.items.Count)" -ForegroundColor Cyan
    $json.data.gold_shipments_in_transits.items | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.shipment_number) | $($_.carrier_id)" -ForegroundColor White
    }
    
} catch {
    Write-Host "`n❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
