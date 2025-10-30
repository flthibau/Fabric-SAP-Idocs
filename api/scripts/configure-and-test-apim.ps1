# ============================================================
# APIM Configuration and End-to-End Testing Script
# ============================================================

param(
    [string]$ResourceGroup = "rg-3pl-partner-api",
    [string]$ApimName = "apim-3pl-flt",
    [string]$FabricGraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql",
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
)

$ErrorActionPreference = "Continue"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  APIM CONFIGURATION AND END-TO-END TESTING" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  APIM Name: $ApimName"
Write-Host "  Fabric GraphQL: $FabricGraphQLEndpoint"

# ============================================================
# STEP 1: Get APIM Details
# ============================================================

Write-Host "`nStep 1: Getting APIM details..." -ForegroundColor Cyan
$apimInfo = az apim show --name $ApimName --resource-group $ResourceGroup | ConvertFrom-Json
$gatewayUrl = $apimInfo.gatewayUrl

Write-Host "  Gateway URL: $gatewayUrl" -ForegroundColor Green

# ============================================================
# STEP 2: Create Backend for Fabric GraphQL
# ============================================================

Write-Host "`nStep 2: Creating Fabric GraphQL backend..." -ForegroundColor Cyan

$backendId = "fabric-graphql-backend"

# Check if backend exists
$backendExists = az apim backend show `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --backend-id $backendId `
    2>$null

if ($backendExists) {
    Write-Host "  Backend already exists, updating..." -ForegroundColor Yellow
    az apim backend update `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --backend-id $backendId `
        --url $FabricGraphQLEndpoint `
        --protocol http
} else {
    Write-Host "  Creating new backend..." -ForegroundColor Yellow
    az apim backend create `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --backend-id $backendId `
        --url $FabricGraphQLEndpoint `
        --protocol http `
        --description "Microsoft Fabric GraphQL API Backend"
}

Write-Host "  Backend created/updated: $backendId" -ForegroundColor Green

# ============================================================
# STEP 3: Create GraphQL Passthrough API
# ============================================================

Write-Host "`nStep 3: Creating GraphQL passthrough API..." -ForegroundColor Cyan

$apiId = "graphql-partner-api"

# Check if API exists
$apiExists = az apim api show `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $apiId `
    2>$null

if ($apiExists) {
    Write-Host "  API already exists, updating..." -ForegroundColor Yellow
} else {
    Write-Host "  Creating new API..." -ForegroundColor Yellow
    
    # Create the API
    az apim api create `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --api-id $apiId `
        --path "graphql" `
        --display-name "3PL Partner GraphQL API" `
        --protocols https `
        --subscription-required false `
        --service-url $FabricGraphQLEndpoint
    
    Write-Host "  API created: $apiId" -ForegroundColor Green
    
    # Add POST operation for GraphQL queries
    Write-Host "  Adding POST operation..." -ForegroundColor Yellow
    az apim api operation create `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --api-id $apiId `
        --url-template "/" `
        --method "POST" `
        --display-name "GraphQL Query" `
        --description "Execute GraphQL queries"
}

Write-Host "  GraphQL API configured" -ForegroundColor Green

# ============================================================
# STEP 4: Configure API Policy (Passthrough with Auth)
# ============================================================

Write-Host "`nStep 4: Configuring API policy..." -ForegroundColor Cyan

$policyXml = @"
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="$backendId" />
        <authentication-managed-identity resource="https://analysis.windows.net/powerbi/api" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@

# Save policy to temp file
$policyFile = "$env:TEMP\apim-policy.xml"
$policyXml | Out-File -FilePath $policyFile -Encoding UTF8

Write-Host "  Applying policy to API..." -ForegroundColor Yellow
az apim api policy create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $apiId `
    --xml-content $policyXml

Write-Host "  Policy applied" -ForegroundColor Green

# ============================================================
# STEP 5: Grant APIM Managed Identity Access to Fabric
# ============================================================

Write-Host "`nStep 5: Checking APIM Managed Identity..." -ForegroundColor Cyan

# Enable system-assigned managed identity if not already enabled
Write-Host "  Enabling system-assigned managed identity..." -ForegroundColor Yellow
az apim update `
    --resource-group $ResourceGroup `
    --name $ApimName `
    --set identity.type=SystemAssigned

$apimIdentity = az apim show `
    --resource-group $ResourceGroup `
    --name $ApimName `
    --query identity.principalId -o tsv

Write-Host "  APIM Managed Identity Principal ID: $apimIdentity" -ForegroundColor Green

Write-Host "`n  MANUAL STEP REQUIRED:" -ForegroundColor Yellow
Write-Host "  1. Go to Fabric Portal -> Workspace -> Manage access" -ForegroundColor White
Write-Host "  2. Add the APIM Managed Identity: $ApimName" -ForegroundColor White
Write-Host "  3. Grant 'Viewer' role" -ForegroundColor White
Write-Host "  4. Go to GraphQL API -> Manage permissions" -ForegroundColor White
Write-Host "  5. Add the APIM Managed Identity with 'Execute' permission" -ForegroundColor White

# ============================================================
# STEP 6: Test End-to-End
# ============================================================

Write-Host "`nStep 6: Testing end-to-end access..." -ForegroundColor Cyan

# Load credentials
$credFile = "C:\Users\flthibau\Desktop\Fabric+SAP+Idocs\api\scripts\partner-apps-credentials.json"
if (-not (Test-Path $credFile)) {
    Write-Host "  ERROR: Credentials file not found: $credFile" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credFile | ConvertFrom-Json
$fedExCred = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" }

if (-not $fedExCred) {
    Write-Host "  ERROR: FedEx credentials not found" -ForegroundColor Red
    exit 1
}

Write-Host "  Using FedEx Carrier credentials:" -ForegroundColor Yellow
Write-Host "    App ID: $($fedExCred.AppId)"
Write-Host "    Object ID: $($fedExCred.ServicePrincipalObjectId)"

# Get access token
Write-Host "`n  Getting access token..." -ForegroundColor Yellow
az login --service-principal `
    --username $fedExCred.AppId `
    --password $fedExCred.ClientSecret `
    --tenant $TenantId `
    --allow-no-subscriptions | Out-Null

$tokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$token = $tokenJson.accessToken

if (-not $token) {
    Write-Host "  ERROR: Failed to get access token" -ForegroundColor Red
    exit 1
}

Write-Host "  Token acquired successfully" -ForegroundColor Green

# Test GraphQL query via APIM
Write-Host "`n  Testing GraphQL query via APIM..." -ForegroundColor Yellow

$apimGraphQLUrl = "$gatewayUrl/graphql"

$graphqlQuery = @{
    query = @"
query {
    gold_shipments_in_transits(first: 5) {
        items {
            shipment_number
            carrier_id
            origin_location
            destination_location
            current_status
        }
    }
}
"@
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Method Post -Uri $apimGraphQLUrl -Headers $headers -Body $graphqlQuery
    
    Write-Host "`n  SUCCESS! GraphQL query via APIM returned data:" -ForegroundColor Green
    Write-Host "  ================================================" -ForegroundColor Cyan
    
    if ($response.data.gold_shipments_in_transits.items) {
        $items = $response.data.gold_shipments_in_transits.items
        Write-Host "  Received $($items.Count) shipments" -ForegroundColor Green
        
        $items | ForEach-Object {
            Write-Host "`n  Shipment: $($_.shipment_number)" -ForegroundColor Yellow
            Write-Host "    Carrier: $($_.carrier_id)" -ForegroundColor White
            Write-Host "    Origin: $($_.origin_location)" -ForegroundColor White
            Write-Host "    Destination: $($_.destination_location)" -ForegroundColor White
            Write-Host "    Status: $($_.current_status)" -ForegroundColor White
        }
    } else {
        Write-Host "  No items returned (may be filtered by RLS)" -ForegroundColor Yellow
    }
    
    Write-Host "`n  ================================================" -ForegroundColor Cyan
    Write-Host "  END-TO-END TEST PASSED!" -ForegroundColor Green
    
} catch {
    Write-Host "`n  ERROR: GraphQL query failed" -ForegroundColor Red
    Write-Host "  Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

# ============================================================
# Summary
# ============================================================

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nAPIM Endpoints:" -ForegroundColor Yellow
Write-Host "  Gateway: $gatewayUrl"
Write-Host "  GraphQL API: $gatewayUrl/graphql"
Write-Host "  Developer Portal: $($apimInfo.developerPortalUrl)"

Write-Host "`nBackend:" -ForegroundColor Yellow
Write-Host "  ID: $backendId"
Write-Host "  URL: $FabricGraphQLEndpoint"

Write-Host "`nAPI:" -ForegroundColor Yellow
Write-Host "  ID: $apiId"
Write-Host "  Path: /graphql"
Write-Host "  Subscription Required: No"

Write-Host "`nManaged Identity:" -ForegroundColor Yellow
Write-Host "  Principal ID: $apimIdentity"
Write-Host "  Status: Enabled"

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Grant APIM Managed Identity access to Fabric (see manual steps above)"
Write-Host "  2. Configure RLS roles for Service Principals"
Write-Host "  3. Create additional REST APIs if needed"
Write-Host "  4. Configure rate limiting and other policies"

Write-Host "`n============================================================`n" -ForegroundColor Cyan
