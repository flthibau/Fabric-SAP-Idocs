#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple test to discover actual column names by querying tables
#>

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  DISCOVER ACTUAL COLUMN NAMES" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$endpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"

# Get token with correct scope
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv

if (-not $token) {
    Write-Host "❌ Failed to get token" -ForegroundColor Red
    exit 1
}

# Test query - request ALL fields with *minimal* query to see what's available
$testQueries = @{
    "gold_orders_daily_summaries" = @"
{
  gold_orders_daily_summaries(first: 1) {
    items {
      order_day
      partner_access_scope
      total_orders
    }
  }
}
"@
    "gold_shipments_in_transits" = @"
{
  gold_shipments_in_transits(first: 1) {
    items {
      carrier_id
      partner_access_scope
    }
  }
}
"@
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

foreach ($tableName in $testQueries.Keys) {
    Write-Host "Testing: $tableName" -ForegroundColor Cyan
    
    $body = @{
        query = $testQueries[$tableName]
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body -ErrorAction Stop
        
        if ($response.errors) {
            Write-Host "  ❌ GraphQL Errors:" -ForegroundColor Red
            $response.errors | ForEach-Object {
                Write-Host "     $($_.message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  ✅ SUCCESS - Table exists and RLS columns work!" -ForegroundColor Green
            $data = $response.data.$tableName.items
            if ($data.Count -gt 0) {
                Write-Host "  Sample data:" -ForegroundColor Gray
                $data[0].PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "  (No data returned - RLS may be filtering everything)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  ❌ Request failed: $($_.Exception.Message)" -ForegroundColor Red
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            Write-Host "     Status: $statusCode" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}
