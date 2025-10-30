param(
    [Parameter(Mandatory=$false)]
    [string]$Token
)

# Get token from clipboard if not provided
if (-not $Token) {
    Write-Host "Getting token from clipboard..." -ForegroundColor Yellow
    $Token = Get-Clipboard
    if (-not $Token) {
        Write-Host "ERROR: No token in clipboard. Run .\get-token.ps1 first!" -ForegroundColor Red
        exit 1
    }
}

$url = "https://apim-3pl-flt.azure-api.net/graphql"
$query = @"
query {
  gold_shipments_in_transits(first: 50) {
    items {
      shipment_number
      carrier_id
      customer_id
      customer_name
      origin
      destination
      ship_date
      estimated_delivery_date
      actual_delivery_date
      partner_access_scope
    }
  }
}
"@

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING GRAPHQL API" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "URL: $url" -ForegroundColor Gray
Write-Host "Token: $($Token.Substring(0,20))..." -ForegroundColor Gray
Write-Host "Query length: $($query.Length) characters`n" -ForegroundColor Gray

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

$body = @{
    query = $query
} | ConvertTo-Json -Depth 10

Write-Host "Sending request..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod `
        -Uri $url `
        -Method Post `
        -Headers $headers `
        -Body $body `
        -ContentType "application/json" `
        -Verbose `
        -TimeoutSec 30
    
    Write-Host "`n✅ SUCCESS!" -ForegroundColor Green
    
    if ($response.errors) {
        Write-Host "`nGraphQL Errors:" -ForegroundColor Red
        $response.errors | ConvertTo-Json -Depth 10 | Write-Host
    }
    
    if ($response.data) {
        $items = $response.data.gold_shipments_in_transits.items
        Write-Host "`nRetrieved $($items.Count) shipments" -ForegroundColor Green
        
        Write-Host "`nFirst 3 shipments:" -ForegroundColor Cyan
        $items | Select-Object -First 3 | Format-Table -AutoSize
        
        Write-Host "`nFull Response:" -ForegroundColor Cyan
        $response | ConvertTo-Json -Depth 10 | Write-Host
    }
    
} catch {
    Write-Host "`n❌ POWERSHELL ALSO FAILED!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nDetails:" -ForegroundColor Yellow
    $_ | Format-List -Force | Write-Host
    
    if ($_.Exception.Response) {
        Write-Host "`nResponse Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $streamReader.ReadToEnd()
        Write-Host "Response Body: $errorBody" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
