# ============================================================
# Update APIM Policy to Pure Passthrough (No Managed Identity)
# ============================================================

param(
    [string]$ResourceGroup = "rg-3pl-partner-api",
    [string]$ApimName = "apim-3pl-flt",
    [string]$ApiId = "graphql-partner-api"
)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  UPDATE APIM POLICY TO PURE PASSTHROUGH" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  APIM Name: $ApimName"
Write-Host "  API ID: $ApiId"

# Get subscription ID
$subscription = az account show --query id -o tsv

if (-not $subscription) {
    Write-Host "`nERROR: Not logged in to Azure" -ForegroundColor Red
    exit 1
}

Write-Host "`nSubscription: $subscription" -ForegroundColor Green

# Define the passthrough policy (NO managed identity authentication)
$policyXml = @"
<policies>
    <inbound>
        <base />
        <!-- Set the backend to Fabric GraphQL -->
        <set-backend-service backend-id="fabric-graphql-backend" />
        
        <!-- Ensure Content-Type is application/json -->
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        
        <!-- PASSTHROUGH: Authorization header from client is forwarded as-is -->
        <!-- This allows Fabric to see the original Service Principal identity -->
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

# Save policy to file
$policyFile = "$env:TEMP\apim-passthrough-policy.xml"
$policyXml | Out-File -FilePath $policyFile -Encoding UTF8 -NoNewline

Write-Host "`nPolicy saved to: $policyFile" -ForegroundColor Gray

# Get access token for Azure Management API
Write-Host "`nGetting Azure Management API token..." -ForegroundColor Yellow
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

if (-not $token) {
    Write-Host "ERROR: Failed to get management token" -ForegroundColor Red
    exit 1
}

Write-Host "Token acquired" -ForegroundColor Green

# Build API URL
$apiUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId/policies/policy?api-version=2021-08-01"

Write-Host "`nAPI URL: $apiUrl" -ForegroundColor Gray

# Prepare request body
$requestBody = @{
    properties = @{
        format = "rawxml"
        value = $policyXml
    }
} | ConvertTo-Json -Depth 10

# Update policy via REST API
Write-Host "`nUpdating API policy..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Method Put `
        -Uri $apiUrl `
        -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } `
        -Body $requestBody
    
    Write-Host "`nSUCCESS! Policy updated" -ForegroundColor Green
    Write-Host "Policy ID: $($response.id)" -ForegroundColor Gray
    
} catch {
    Write-Host "`nERROR: Failed to update policy" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  POLICY CONFIGURATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nPassthrough Behavior:" -ForegroundColor Yellow
Write-Host "  1. Client sends request with: Authorization: Bearer <SP_TOKEN>" -ForegroundColor White
Write-Host "  2. APIM forwards the request to Fabric GraphQL backend" -ForegroundColor White
Write-Host "  3. Authorization header is passed through unchanged" -ForegroundColor White
Write-Host "  4. Fabric sees the original Service Principal identity" -ForegroundColor White
Write-Host "  5. Fabric applies RLS based on the SP identity" -ForegroundColor White

Write-Host "`nAuthentication Flow:" -ForegroundColor Yellow
Write-Host "  Client -> APIM: Bearer token of Service Principal (FedEx/Warehouse/ACME)"
Write-Host "  APIM -> Fabric: Same Bearer token (passthrough)"
Write-Host "  Fabric: Applies RLS based on Service Principal identity"

Write-Host "`nNo Managed Identity needed for APIM!" -ForegroundColor Green
Write-Host "The Service Principal tokens are passed through directly." -ForegroundColor Green

Write-Host "`n============================================================`n" -ForegroundColor Cyan
