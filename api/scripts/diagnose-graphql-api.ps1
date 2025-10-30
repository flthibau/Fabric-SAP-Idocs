#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnose GraphQL API configuration and list available tables

.DESCRIPTION
    Tests GraphQL endpoint connectivity and introspects the schema
    to see what tables are actually exposed.
#>

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  GRAPHQL API DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$endpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"

Write-Host "Endpoint: $endpoint`n" -ForegroundColor White

# Get user token
Write-Host "Getting access token..." -ForegroundColor Cyan
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv

if (-not $token) {
    Write-Host "❌ Failed to get token. Make sure you're logged in with 'az login'" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Token acquired`n" -ForegroundColor Green

# GraphQL introspection query
$introspectionQuery = @"
{
  __schema {
    queryType {
      fields {
        name
        description
      }
    }
  }
}
"@

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$body = @{
    query = $introspectionQuery
} | ConvertTo-Json

Write-Host "Running schema introspection..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body -ErrorAction Stop
    
    if ($response.errors) {
        Write-Host "❌ GraphQL Errors:" -ForegroundColor Red
        $response.errors | ForEach-Object {
            Write-Host "   $($_.message)" -ForegroundColor Red
        }
        exit 1
    }
    
    Write-Host "✅ API is accessible`n" -ForegroundColor Green
    
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "  EXPOSED TABLES" -ForegroundColor Cyan
    Write-Host "========================================================================`n" -ForegroundColor Cyan
    
    $tables = $response.data.__schema.queryType.fields | Sort-Object name
    
    if ($tables.Count -eq 0) {
        Write-Host "⚠️  No tables exposed in GraphQL API!" -ForegroundColor Yellow
        Write-Host "`nYou need to add data sources in Fabric Portal:" -ForegroundColor White
        Write-Host "  1. Go to GraphQL API settings" -ForegroundColor Gray
        Write-Host "  2. Add Lakehouse as data source" -ForegroundColor Gray
        Write-Host "  3. Select Gold tables to expose`n" -ForegroundColor Gray
    }
    else {
        Write-Host "Found $($tables.Count) queryable tables:" -ForegroundColor Green
        Write-Host ""
        
        $goldTables = @()
        $silverTables = @()
        $otherTables = @()
        
        foreach ($table in $tables) {
            if ($table.name -like "gold_*") {
                $goldTables += $table.name
            }
            elseif ($table.name -like "idoc_*_silver*") {
                $silverTables += $table.name
            }
            else {
                $otherTables += $table.name
            }
        }
        
        if ($goldTables.Count -gt 0) {
            Write-Host "✅ GOLD TABLES ($($goldTables.Count)):" -ForegroundColor Green
            $goldTables | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor White
            }
            Write-Host ""
        }
        
        if ($silverTables.Count -gt 0) {
            Write-Host "📊 SILVER TABLES ($($silverTables.Count)):" -ForegroundColor Cyan
            $silverTables | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor White
            }
            Write-Host ""
        }
        
        if ($otherTables.Count -gt 0) {
            Write-Host "📋 OTHER TABLES ($($otherTables.Count)):" -ForegroundColor Gray
            $otherTables | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor White
            }
            Write-Host ""
        }
        
        # Check for required Gold tables
        Write-Host "========================================================================" -ForegroundColor Cyan
        Write-Host "  REQUIRED GOLD TABLES CHECK" -ForegroundColor Cyan
        Write-Host "========================================================================`n" -ForegroundColor Cyan
        
        $requiredTables = @(
            "gold_orders_daily_summaries",
            "gold_shipments_in_transits",
            "gold_warehouse_productivity_dailies",
            "gold_revenue_recognition_realtimes",
            "gold_sla_performances"
        )
        
        $allPresent = $true
        foreach ($required in $requiredTables) {
            $exists = $tables.name -contains $required
            $status = if ($exists) { "✅" } else { "❌"; $allPresent = $false }
            $color = if ($exists) { "Green" } else { "Red" }
            Write-Host "$status $required" -ForegroundColor $color
        }
        
        if ($allPresent) {
            Write-Host "`n✅ All required Gold tables are exposed!" -ForegroundColor Green
            Write-Host "`nYou can now run RLS tests with:" -ForegroundColor Cyan
            Write-Host "   .\test-graphql-rls-azcli.ps1`n" -ForegroundColor White
        }
        else {
            Write-Host "`n⚠️  Some Gold tables are missing!" -ForegroundColor Yellow
            Write-Host "`nSteps to add them:" -ForegroundColor Cyan
            Write-Host "  1. Open Fabric Portal → Workspace → GraphQL API" -ForegroundColor White
            Write-Host "  2. Click '...' → Settings" -ForegroundColor White
            Write-Host "  3. Go to 'Exposed data sources'" -ForegroundColor White
            Write-Host "  4. Add 'Lakehouse3PLAnalytics' if not already added" -ForegroundColor White
            Write-Host "  5. Select the missing Gold tables" -ForegroundColor White
            Write-Host "  6. Save and wait 1-2 minutes for propagation`n" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "❌ Failed to connect to GraphQL API" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode) {
        Write-Host "Status Code: $statusCode`n" -ForegroundColor Red
        
        if ($statusCode -eq 401) {
            Write-Host "⚠️  401 Unauthorized - Check:" -ForegroundColor Yellow
            Write-Host "   - Token scope is correct" -ForegroundColor White
            Write-Host "   - Service Principal has API Execute permissions" -ForegroundColor White
            Write-Host "   - Workspace access granted`n" -ForegroundColor White
        }
        elseif ($statusCode -eq 404) {
            Write-Host "⚠️  404 Not Found - Check:" -ForegroundColor Yellow
            Write-Host "   - GraphQL API endpoint URL is correct" -ForegroundColor White
            Write-Host "   - API exists in workspace`n" -ForegroundColor White
        }
    }
}
