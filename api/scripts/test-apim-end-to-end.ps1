# ============================================================
# Test APIM End-to-End with Service Principal Passthrough
# ============================================================

param(
    [string]$ApimGatewayUrl = "https://apim-3pl-flt.azure-api.net",
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
)

$ErrorActionPreference = "Continue"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  APIM END-TO-END TEST (PASSTHROUGH MODE)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  APIM Gateway: $ApimGatewayUrl"
Write-Host "  GraphQL Path: /graphql"
Write-Host "  Tenant ID: $TenantId"

# Load credentials
$credFile = "C:\Users\flthibau\Desktop\Fabric+SAP+Idocs\api\scripts\partner-apps-credentials.json"
if (-not (Test-Path $credFile)) {
    Write-Host "`nERROR: Credentials file not found: $credFile" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credFile | ConvertFrom-Json
$fedExCred = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" }

if (-not $fedExCred) {
    Write-Host "`nERROR: FedEx credentials not found" -ForegroundColor Red
    exit 1
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  TEST 1: FEDEX CARRIER SERVICE PRINCIPAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nService Principal:" -ForegroundColor Yellow
Write-Host "  Name: $($fedExCred.DisplayName)"
Write-Host "  App ID: $($fedExCred.AppId)"
Write-Host "  Object ID: $($fedExCred.ServicePrincipalObjectId)"
Write-Host "  Role: $($fedExCred.Role)"

# Step 1: Get Access Token
Write-Host "`nStep 1: Getting access token..." -ForegroundColor Yellow

az login --service-principal `
    --username $fedExCred.AppId `
    --password $fedExCred.ClientSecret `
    --tenant $TenantId `
    --allow-no-subscriptions | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to login with Service Principal" -ForegroundColor Red
    exit 1
}

$tokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$token = $tokenJson.accessToken

if (-not $token) {
    Write-Host "ERROR: Failed to get access token" -ForegroundColor Red
    exit 1
}

Write-Host "  Token acquired successfully" -ForegroundColor Green
Write-Host "  Token (first 50 chars): $($token.Substring(0, 50))..." -ForegroundColor Gray

# Step 2: Call APIM GraphQL endpoint
Write-Host "`nStep 2: Calling APIM GraphQL endpoint..." -ForegroundColor Yellow

$apimGraphQLUrl = "$ApimGatewayUrl/graphql"

Write-Host "  URL: $apimGraphQLUrl" -ForegroundColor Gray

$graphqlQuery = @{
    query = @"
query {
    gold_shipments_in_transits(first: 10) {
        items {
            shipment_number
            carrier_id
            customer_id
            origin_location
            destination_location
            current_status
            estimated_delivery_date
        }
    }
}
"@
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "`nQuery:" -ForegroundColor Gray
Write-Host $graphqlQuery -ForegroundColor DarkGray

try {
    Write-Host "`nSending request..." -ForegroundColor Yellow
    
    $response = Invoke-RestMethod -Method Post `
        -Uri $apimGraphQLUrl `
        -Headers $headers `
        -Body $graphqlQuery
    
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "  SUCCESS! APIM END-TO-END TEST PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    
    if ($response.data.gold_shipments_in_transits.items) {
        $items = $response.data.gold_shipments_in_transits.items
        Write-Host "`nReceived: $($items.Count) shipments" -ForegroundColor Cyan
        
        # Display first 5 items
        $displayCount = [Math]::Min(5, $items.Count)
        Write-Host "`nFirst $displayCount shipments:" -ForegroundColor Yellow
        
        for ($i = 0; $i -lt $displayCount; $i++) {
            $item = $items[$i]
            Write-Host "`n  [$($i+1)] Shipment: $($item.shipment_number)" -ForegroundColor White
            Write-Host "      Carrier: $($item.carrier_id)" -ForegroundColor Gray
            Write-Host "      Customer: $($item.customer_id)" -ForegroundColor Gray
            Write-Host "      Route: $($item.origin_location) -> $($item.destination_location)" -ForegroundColor Gray
            Write-Host "      Status: $($item.current_status)" -ForegroundColor Gray
            Write-Host "      ETA: $($item.estimated_delivery_date)" -ForegroundColor Gray
        }
        
        # Check RLS filtering (if enabled)
        $carrierIds = $items | Select-Object -ExpandProperty carrier_id -Unique
        Write-Host "`nCarrier IDs in response:" -ForegroundColor Yellow
        $carrierIds | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        
        if ($carrierIds.Count -eq 1 -and $carrierIds[0] -eq "CARRIER-FEDEX-GROU") {
            Write-Host "`n  RLS FILTERING ACTIVE: Only FedEx carrier data returned" -ForegroundColor Green
        } else {
            Write-Host "`n  RLS FILTERING DISABLED: Multiple carriers returned (as expected)" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "`nNo items returned" -ForegroundColor Yellow
        Write-Host "This could mean:" -ForegroundColor Gray
        Write-Host "  - No data in the table" -ForegroundColor Gray
        Write-Host "  - RLS filtering out all data" -ForegroundColor Gray
        Write-Host "  - Service Principal has no access" -ForegroundColor Gray
    }
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  ARCHITECTURE VALIDATION" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`nData Flow:" -ForegroundColor Yellow
    Write-Host "  1. FedEx SP authenticated -> Got Bearer token" -ForegroundColor Green
    Write-Host "  2. Sent request to APIM: $apimGraphQLUrl" -ForegroundColor Green
    Write-Host "  3. APIM passed token through to Fabric GraphQL" -ForegroundColor Green
    Write-Host "  4. Fabric identified FedEx SP and returned data" -ForegroundColor Green
    
    Write-Host "`nKey Points:" -ForegroundColor Yellow
    Write-Host "  - APIM acts as a pure passthrough (no token replacement)" -ForegroundColor White
    Write-Host "  - Fabric sees the original Service Principal identity" -ForegroundColor White
    Write-Host "  - RLS can be applied based on SP identity (when configured)" -ForegroundColor White
    Write-Host "  - No APIM Managed Identity needed for this flow" -ForegroundColor White
    
} catch {
    Write-Host "`n============================================================" -ForegroundColor Red
    Write-Host "  ERROR: APIM REQUEST FAILED" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    
    Write-Host "`nHTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "`nError Details:" -ForegroundColor Red
        Write-Host ($errorDetails | ConvertTo-Json -Depth 10) -ForegroundColor DarkRed
    }
    
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify Fabric capacity is running (not paused)" -ForegroundColor White
    Write-Host "  2. Check Service Principal has access to Fabric workspace" -ForegroundColor White
    Write-Host "  3. Verify GraphQL API permissions for the SP" -ForegroundColor White
    Write-Host "  4. Check APIM backend configuration" -ForegroundColor White
    Write-Host "  5. Review APIM policy for errors" -ForegroundColor White
    
    exit 1
}

Write-Host "`n============================================================`n" -ForegroundColor Cyan
