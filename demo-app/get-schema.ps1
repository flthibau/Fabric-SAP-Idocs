param(
    [Parameter(Mandatory=$false)]
    [string]$Token
)

# Get token from clipboard if not provided
if (-not $Token) {
    Write-Host "Getting token from clipboard..." -ForegroundColor Yellow
    $Token = Get-Clipboard
}

$url = "https://apim-3pl-flt.azure-api.net/graphql"

# GraphQL Introspection Query
$query = @"
query {
  __type(name: "gold_shipments_in_transit") {
    name
    fields {
      name
      type {
        name
        kind
        ofType {
          name
          kind
        }
      }
    }
  }
}
"@

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  GRAPHQL SCHEMA INTROSPECTION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

$body = @{ query = $query }
$bodyJson = $body | ConvertTo-Json -Depth 10 -Compress

try {
    $response = Invoke-RestMethod `
        -Uri $url `
        -Method Post `
        -Headers $headers `
        -Body $bodyJson `
        -ContentType "application/json"
    
    if ($response.errors) {
        Write-Host "GraphQL Errors:" -ForegroundColor Red
        $response.errors | ConvertTo-Json -Depth 10 | Write-Host
    }
    
    if ($response.data.__type) {
        Write-Host "✅ Type: $($response.data.__type.name)`n" -ForegroundColor Green
        Write-Host "Available Fields:" -ForegroundColor Cyan
        $response.data.__type.fields | ForEach-Object {
            $typeName = if ($_.type.ofType) { $_.type.ofType.name } else { $_.type.name }
            Write-Host "  - $($_.name) : $typeName" -ForegroundColor White
        }
        
        Write-Host "`n`nFormatted for GraphQL query:" -ForegroundColor Yellow
        $fields = $response.data.__type.fields | Select-Object -ExpandProperty name
        Write-Host "query {" -ForegroundColor Gray
        Write-Host "  gold_shipments_in_transits(first: 50) {" -ForegroundColor Gray
        Write-Host "    items {" -ForegroundColor Gray
        $fields | ForEach-Object { Write-Host "      $_" -ForegroundColor Green }
        Write-Host "    }" -ForegroundColor Gray
        Write-Host "  }" -ForegroundColor Gray
        Write-Host "}" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
