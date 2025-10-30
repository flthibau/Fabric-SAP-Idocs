#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Introspect Gold table schemas in GraphQL API

.DESCRIPTION
    Retrieves the exact field names for all Gold tables
#>

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  GOLD TABLES SCHEMA INTROSPECTION" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$endpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"

# Get token
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv

$tables = @(
    "gold_orders_daily_summary",
    "gold_shipments_in_transit",
    "gold_warehouse_productivity_daily",
    "gold_revenue_recognition_realtime",
    "gold_sla_performance"
)

foreach ($table in $tables) {
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "  $table" -ForegroundColor Magenta
    Write-Host "========================================================================`n" -ForegroundColor Magenta
    
    $query = @"
{
  __type(name: "$table") {
    name
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
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    $body = @{ query = $query } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body -ErrorAction Stop
        
        if ($response.data.__type) {
            $fields = $response.data.__type.fields | Sort-Object name
            
            Write-Host "Fields ($($fields.Count)):" -ForegroundColor Cyan
            foreach ($field in $fields) {
                $typeName = if ($field.type.name) { $field.type.name } else { $field.type.kind }
                Write-Host "  - $($field.name) : $typeName" -ForegroundColor White
            }
            Write-Host ""
        }
        else {
            Write-Host "⚠️  Table not found or no fields" -ForegroundColor Yellow
            Write-Host ""
        }
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
}
