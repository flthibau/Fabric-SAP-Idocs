# Test REST API endpoints
param(
    [string]$ApimGatewayUrl = "https://apim-3pl-flt.azure-api.net",
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  TEST REST API ENDPOINTS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Load credentials
$credFile = "C:\Users\flthibau\Desktop\Fabric+SAP+Idocs\api\scripts\partner-apps-credentials.json"
$credentials = Get-Content $credFile | ConvertFrom-Json
$fedExCred = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" }

Write-Host "`nAuthenticating with FedEx Service Principal..." -ForegroundColor Yellow
az login --service-principal `
    --username $fedExCred.AppId `
    --password $fedExCred.ClientSecret `
    --tenant $TenantId `
    --allow-no-subscriptions | Out-Null

$tokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$token = $tokenJson.accessToken

Write-Host "Token acquired" -ForegroundColor Green

$headers = @{
    "Authorization" = "Bearer $token"
}

# Test endpoints
$endpoints = @(
    @{ name = "Shipments"; url = "/api/v1/shipments" },
    @{ name = "Orders"; url = "/api/v1/orders" },
    @{ name = "Warehouse Productivity"; url = "/api/v1/warehouse/productivity" },
    @{ name = "SLA Performance"; url = "/api/v1/sla/performance" },
    @{ name = "Revenue"; url = "/api/v1/revenue" }
)

foreach ($endpoint in $endpoints) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  TEST: $($endpoint.name)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    $url = "$ApimGatewayUrl$($endpoint.url)"
    Write-Host "`nURL: $url" -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Method Get -Uri $url -Headers $headers
        
        Write-Host "Status: $($response.StatusCode) OK" -ForegroundColor Green
        Write-Host "Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor Gray
        
        $jsonResponse = $response.Content | ConvertFrom-Json
        
        if ($jsonResponse -is [Array]) {
            Write-Host "Returned: $($jsonResponse.Count) items" -ForegroundColor Cyan
            
            if ($jsonResponse.Count -gt 0) {
                Write-Host "`nFirst item:" -ForegroundColor Yellow
                $jsonResponse[0] | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor White
            }
        } else {
            Write-Host "`nResponse:" -ForegroundColor Yellow
            $jsonResponse | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor White
        }
        
    } catch {
        Write-Host "Status: $($_.Exception.Response.StatusCode.value__) ERROR" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.ErrorDetails.Message) {
            Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor DarkRed
        }
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  TEST COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
