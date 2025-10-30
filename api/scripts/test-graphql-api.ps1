<#
.SYNOPSIS
    Test Fabric GraphQL API with introspection query
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

$ErrorActionPreference = "Stop"

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  TEST API GRAPHQL FABRIC" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

Write-Host "`nEndpoint:" -ForegroundColor Yellow
Write-Host "  $GraphQLEndpoint" -ForegroundColor White

# Step 1: Get Azure AD token
Write-Host "`nStep 1: Obtaining Azure AD token..." -ForegroundColor Cyan

try {
    $tokenResponse = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv
    
    if ([string]::IsNullOrEmpty($tokenResponse)) {
        Write-Host "  Failed to get token. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Token obtained successfully" -ForegroundColor Green
    
} catch {
    Write-Host "  Error getting token: $_" -ForegroundColor Red
    Write-Host "  Try running: az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4" -ForegroundColor Yellow
    exit 1
}

# Step 2: Prepare introspection query
Write-Host "`nStep 2: Preparing introspection query..." -ForegroundColor Cyan

$introspectionQueryText = 'query IntrospectionQuery { __schema { queryType { name } types { name kind description fields { name type { name kind ofType { name kind } } } } } }'

$introspectionQuery = @{
    query = $introspectionQueryText
} | ConvertTo-Json -Depth 10

Write-Host "  Query prepared" -ForegroundColor Green

# Step 3: Execute GraphQL query
Write-Host "`nStep 3: Executing introspection query..." -ForegroundColor Cyan

try {
    $headers = @{
        "Authorization" = "Bearer $tokenResponse"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod -Uri $GraphQLEndpoint -Method Post -Headers $headers -Body $introspectionQuery
    
    Write-Host "  Query executed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "  Error executing query:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "  HTTP Status: $statusCode" -ForegroundColor Red
    }
    
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify the API was created successfully in Fabric Portal" -ForegroundColor Gray
    Write-Host "  2. Check that you have access to the workspace" -ForegroundColor Gray
    Write-Host "  3. Ensure the endpoint URL is correct" -ForegroundColor Gray
    Write-Host "  4. Try re-authenticating: az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4" -ForegroundColor Gray
    
    exit 1
}

# Step 4: Analyze response
Write-Host "`nStep 4: Analyzing schema..." -ForegroundColor Cyan

if ($response.errors) {
    Write-Host "  GraphQL errors returned:" -ForegroundColor Red
    $response.errors | ForEach-Object {
        Write-Host "    $($_.message)" -ForegroundColor Red
    }
    exit 1
}

if (-not $response.data) {
    Write-Host "  No data returned from introspection query" -ForegroundColor Red
    exit 1
}

$schema = $response.data.__schema
$types = $schema.types | Where-Object { $_.kind -eq "OBJECT" -and $_.name -notlike "__*" }

Write-Host "  Schema retrieved successfully" -ForegroundColor Green
Write-Host "  Query Type: $($schema.queryType.name)" -ForegroundColor White
Write-Host "  Total Types: $($types.Count)" -ForegroundColor White

# Step 5: Check for expected tables
Write-Host "`nStep 5: Checking for expected tables..." -ForegroundColor Cyan

$expectedTables = @(
    "idoc_orders_silver",
    "idoc_shipments_silver",
    "idoc_warehouse_silver",
    "idoc_invoices_silver"
)

$foundTables = @()
$missingTables = @()

foreach ($expectedTable in $expectedTables) {
    $found = $types | Where-Object { $_.name -eq $expectedTable }
    
    if ($found) {
        $foundTables += $expectedTable
        $fieldCount = ($found.fields | Measure-Object).Count
        Write-Host "  $expectedTable ($fieldCount fields)" -ForegroundColor Green
    } else {
        $missingTables += $expectedTable
        Write-Host "  $expectedTable (NOT FOUND)" -ForegroundColor Red
    }
}

# Step 6: Display table schemas
Write-Host "`nStep 6: Table Schemas:" -ForegroundColor Cyan

foreach ($tableName in $foundTables) {
    $table = $types | Where-Object { $_.name -eq $tableName }
    
    Write-Host "`n  Table: $tableName" -ForegroundColor Yellow
    if ($table.description) {
        Write-Host "  Description: $($table.description)" -ForegroundColor Gray
    }
    Write-Host "  Fields:" -ForegroundColor White
    
    $table.fields | Select-Object -First 10 | ForEach-Object {
        $fieldType = if ($_.type.ofType) { $_.type.ofType.name } else { $_.type.name }
        Write-Host "    $($_.name): $fieldType" -ForegroundColor Gray
    }
    
    if (($table.fields | Measure-Object).Count -gt 10) {
        $remaining = ($table.fields | Measure-Object).Count - 10
        Write-Host "    ... and $remaining more fields" -ForegroundColor DarkGray
    }
}

# Summary
Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host "  TEST SUMMARY" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Green

Write-Host "`nResults:" -ForegroundColor Cyan
Write-Host "  Tables Found: $($foundTables.Count)/$($expectedTables.Count)" -ForegroundColor White
Write-Host "  API Status: " -NoNewline
if ($foundTables.Count -eq $expectedTables.Count) {
    Write-Host "ALL TABLES EXPOSED" -ForegroundColor Green
} elseif ($foundTables.Count -gt 0) {
    Write-Host "PARTIAL" -ForegroundColor Yellow
} else {
    Write-Host "NO TABLES FOUND" -ForegroundColor Red
}

if ($missingTables.Count -gt 0) {
    Write-Host "`nMissing Tables:" -ForegroundColor Yellow
    $missingTables | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
    
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify tables were selected when creating the GraphQL API" -ForegroundColor Gray
    Write-Host "  2. Check that tables exist in lh_3pl_logistics_gold Lakehouse" -ForegroundColor Gray
    Write-Host "  3. Refresh the API in Fabric Portal (Settings -> Refresh Schema)" -ForegroundColor Gray
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan

if ($foundTables.Count -eq $expectedTables.Count) {
    Write-Host "  API is working correctly!" -ForegroundColor Green
    Write-Host "`n  1. Configure Row-Level Security (RLS)" -ForegroundColor Yellow
    Write-Host "     Fabric Portal -> Lakehouse -> SQL Analytics Endpoint -> Security" -ForegroundColor Gray
    Write-Host "`n  2. Deploy APIM" -ForegroundColor Yellow
    Write-Host "     .\deploy-apim.ps1 -ResourceGroup 'rg-3pl' -ApimName 'apim-3pl-flt' ..." -ForegroundColor Gray
    Write-Host "`n  3. Create partner app registrations" -ForegroundColor Yellow
    Write-Host "     .\create-partner-apps.ps1" -ForegroundColor Gray
} else {
    Write-Host "  Fix missing tables in Fabric Portal" -ForegroundColor Yellow
    Write-Host "  Then run this test again" -ForegroundColor Gray
}

Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host ""
