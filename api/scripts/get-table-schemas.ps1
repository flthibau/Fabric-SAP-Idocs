#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Get detailed schema for Gold tables
#>

$endpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"

Write-Host "`nGetting access token..." -ForegroundColor Cyan
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv

if (-not $token) {
    Write-Host "❌ Failed to get token" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$tables = @(
    "gold_shipments_in_transit",
    "gold_sla_performance",
    "gold_warehouse_productivity_daily",
    "gold_orders_daily_summary",
    "gold_revenue_recognition_realtime"
)

foreach ($table in $tables) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $table" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    
    $query = @"
{
  __type(name: "$table") {
    fields {
      name
      type {
        name
        kind
      }
    }
  }
}
"@

    $body = @{ query = $query } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body -ContentType "application/json"
        
        if ($response.data.__type) {
            Write-Host "`nAvailable fields:" -ForegroundColor Green
            $response.data.__type.fields | ForEach-Object {
                Write-Host "  - $($_.name)" -ForegroundColor White
            }
        } else {
            Write-Host "❌ Table not found in schema" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error: $_" -ForegroundColor Red
    }
}

Write-Host "`n"
