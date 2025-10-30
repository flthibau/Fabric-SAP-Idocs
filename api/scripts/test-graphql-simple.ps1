<#
.SYNOPSIS
    Test Fabric GraphQL API with simple queries
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

$ErrorActionPreference = "Stop"

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  TEST API GRAPHQL FABRIC - REQUETES SIMPLES" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

Write-Host "`nEndpoint:" -ForegroundColor Yellow
Write-Host "  $GraphQLEndpoint" -ForegroundColor White

# Get token
Write-Host "`nObtaining Azure AD token..." -ForegroundColor Cyan

try {
    $tokenResponse = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv
    
    if ([string]::IsNullOrEmpty($tokenResponse)) {
        Write-Host "  Failed to get token. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Token obtained" -ForegroundColor Green
    
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $tokenResponse"
    "Content-Type" = "application/json"
}

# Test tables
$testTables = @(
    "idoc_orders_silver",
    "idoc_shipments_silver",
    "idoc_warehouse_silver",
    "idoc_invoices_silver"
)

$successCount = 0
$failureCount = 0

Write-Host "`nTesting tables..." -ForegroundColor Cyan

foreach ($tableName in $testTables) {
    Write-Host "`n  Table: $tableName" -ForegroundColor Yellow
    
    # Fabric GraphQL uses plural form for queries
    $pluralName = $tableName + "s"
    $queryText = "query { $pluralName { items { __typename } } }"
    
    $query = @{
        query = $queryText
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $GraphQLEndpoint -Method Post -Headers $headers -Body $query
        
        if ($response.errors) {
            Write-Host "    ERROR: $($response.errors[0].message)" -ForegroundColor Red
            $failureCount++
        } elseif ($response.data) {
            $itemCount = 0
            $dataProperty = $response.data.$pluralName
            if ($dataProperty.items) {
                $itemCount = ($dataProperty.items | Measure-Object).Count
            }
            Write-Host "    OK - Retrieved $itemCount items" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "    WARNING: No data or errors" -ForegroundColor Yellow
            $failureCount++
        }
        
    } catch {
        Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failureCount++
    }
}

# Summary
Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host "  TEST SUMMARY" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Green

Write-Host "`nResults:" -ForegroundColor Cyan
Write-Host "  Success: $successCount/$($testTables.Count)" -ForegroundColor White
Write-Host "  Failed: $failureCount/$($testTables.Count)" -ForegroundColor White

if ($successCount -eq $testTables.Count) {
    Write-Host "`n  ALL TABLES ACCESSIBLE!" -ForegroundColor Green
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "  1. Configure Row-Level Security (RLS)" -ForegroundColor Yellow
    Write-Host "     Fabric Portal -> Lakehouse -> SQL Analytics Endpoint -> Security" -ForegroundColor Gray
    Write-Host "`n  2. Deploy APIM" -ForegroundColor Yellow
    Write-Host "     .\deploy-apim.ps1 -ResourceGroup 'rg-3pl' -ApimName 'apim-3pl-flt' ..." -ForegroundColor Gray
} elseif ($successCount -gt 0) {
    Write-Host "`n  PARTIAL SUCCESS" -ForegroundColor Yellow
    Write-Host "  Some tables are accessible, check errors above" -ForegroundColor Yellow
} else {
    Write-Host "`n  NO TABLES ACCESSIBLE" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify tables were selected when creating the GraphQL API" -ForegroundColor Gray
    Write-Host "  2. Check that tables exist in lh_3pl_logistics_gold Lakehouse" -ForegroundColor Gray
    Write-Host "  3. Verify you have read permissions on the Lakehouse" -ForegroundColor Gray
}

Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host ""
