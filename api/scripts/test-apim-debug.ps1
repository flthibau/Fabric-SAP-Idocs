# Test APIM avec détails de debug
param(
    [string]$ApimGatewayUrl = "https://apim-3pl-flt.azure-api.net"
)

# Load credentials
$credFile = "C:\Users\flthibau\Desktop\Fabric+SAP+Idocs\api\scripts\partner-apps-credentials.json"
$credentials = Get-Content $credFile | ConvertFrom-Json
$fedExCred = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" }

Write-Host "`nAuthenticating..." -ForegroundColor Cyan
az login --service-principal `
    --username $fedExCred.AppId `
    --password $fedExCred.ClientSecret `
    --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4" `
    --allow-no-subscriptions | Out-Null

$tokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$token = $tokenJson.accessToken

Write-Host "Token acquired" -ForegroundColor Green

# Test avec Invoke-WebRequest pour voir les détails
$apimGraphQLUrl = "$ApimGatewayUrl/graphql"

$graphqlQuery = @{
    query = "query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id } } }"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "`nCalling APIM: $apimGraphQLUrl" -ForegroundColor Cyan
Write-Host "Query: $graphqlQuery" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Method Post `
        -Uri $apimGraphQLUrl `
        -Headers $headers `
        -Body $graphqlQuery
    
    Write-Host "`nHTTP Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor Gray
    Write-Host "Content-Length: $($response.RawContentLength)" -ForegroundColor Gray
    Write-Host "`nResponse Body:" -ForegroundColor Yellow
    Write-Host $response.Content -ForegroundColor White
    
    # Parse JSON
    $jsonResponse = $response.Content | ConvertFrom-Json
    Write-Host "`nParsed Response:" -ForegroundColor Cyan
    $jsonResponse | ConvertTo-Json -Depth 10
    
} catch {
    Write-Host "`nERROR:" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host "`nError Details:" -ForegroundColor Red
        Write-Host $_.ErrorDetails.Message -ForegroundColor DarkRed
    }
}
