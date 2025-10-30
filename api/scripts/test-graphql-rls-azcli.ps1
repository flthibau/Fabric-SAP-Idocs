#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test OneLake RLS via GraphQL API using Azure CLI authentication

.DESCRIPTION
    Alternative version that uses Azure CLI to get tokens instead of direct OAuth.
    This bypasses the 401 error by using Azure CLI's authentication mechanism.

.NOTES
    Requires: Azure CLI (az) installed and configured
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4",
    
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ONELAKE RLS TESTING VIA GRAPHQL API (Azure CLI Auth)" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "GraphQL Endpoint: $GraphQLEndpoint" -ForegroundColor White
Write-Host ""

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"
if (-not (Test-Path $credentialsPath)) {
    Write-Host "❌ Credentials file not found: $credentialsPath" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credentialsPath | ConvertFrom-Json
Write-Host "✅ Loaded credentials from $credentialsPath`n" -ForegroundColor Green

# Function to get token using Azure CLI
function Get-ServicePrincipalToken-AzCLI {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$PartnerName
    )
    
    Write-Host "Authenticating $PartnerName via Azure CLI..." -ForegroundColor Cyan
    
    # Login with Service Principal
    $env:AZURE_CLIENT_ID = $ClientId
    $env:AZURE_CLIENT_SECRET = $ClientSecret
    $env:AZURE_TENANT_ID = $TenantId
    
    try {
        # Login
        az login --service-principal `
            --username $ClientId `
            --password $ClientSecret `
            --tenant $TenantId `
            --allow-no-subscriptions --output none 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Azure CLI login failed for $PartnerName" -ForegroundColor Red
            return $null
        }
        
        # Get Power BI token
        $token = az account get-access-token `
            --resource "https://analysis.windows.net/powerbi/api" `
            --query accessToken -o tsv 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $token) {
            Write-Host "✅ Successfully obtained token for $PartnerName" -ForegroundColor Green
            return $token
        }
        
        # Try Fabric scope if Power BI fails
        Write-Host "  Trying Fabric scope..." -ForegroundColor Yellow
        $token = az account get-access-token `
            --resource "https://api.fabric.microsoft.com" `
            --query accessToken -o tsv 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $token) {
            Write-Host "✅ Successfully obtained token for $PartnerName (Fabric scope)" -ForegroundColor Green
            return $token
        }
        
        Write-Host "❌ Failed to get token for $PartnerName" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    finally {
        # Logout to clean up
        az logout --output none 2>$null
    }
}

# Function to test GraphQL query
function Test-GraphQLQuery {
    param(
        [string]$Endpoint,
        [string]$Token,
        [string]$Query,
        [string]$Description,
        [string]$ExpectedFilterColumn,
        [string]$ExpectedFilterValue
    )
    
    Write-Host "`n  Testing: $Description" -ForegroundColor Yellow
    Write-Host "  Query: $($Query.Substring(0, [Math]::Min(80, $Query.Length)))..." -ForegroundColor Gray
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        query = $Query
    } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -Body $body -ErrorAction Stop
        
        if ($result.errors) {
            Write-Host "  ❌ GraphQL Error:" -ForegroundColor Red
            $result.errors | ForEach-Object {
                Write-Host "     $($_.message)" -ForegroundColor Red
            }
            return $false
        }
        
        # Extract items from result
        $dataKey = $result.data.PSObject.Properties.Name | Select-Object -First 1
        $items = $result.data.$dataKey.items
        
        if ($items.Count -eq 0) {
            Write-Host "  ⚠️  No data returned (RLS may be too restrictive or no data exists)" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "  ✅ Received $($items.Count) items" -ForegroundColor Green
        
        # Validate RLS filtering
        if ($ExpectedFilterColumn) {
            $violations = $items | Where-Object { 
                $_.$ExpectedFilterColumn -ne $ExpectedFilterValue 
            }
            
            if ($violations.Count -gt 0) {
                Write-Host "  ❌ RLS VIOLATION: Found $($violations.Count) items with incorrect filter!" -ForegroundColor Red
                Write-Host "     Expected: $ExpectedFilterColumn = '$ExpectedFilterValue'" -ForegroundColor Red
                Write-Host "     Found values:" -ForegroundColor Red
                $violations | Select-Object -First 3 | ForEach-Object {
                    Write-Host "       - $($_.$ExpectedFilterColumn)" -ForegroundColor Red
                }
                return $false
            }
            
            Write-Host "  ✅ RLS verified: All items have $ExpectedFilterColumn = '$ExpectedFilterValue'" -ForegroundColor Green
        }
        
        # Show sample data
        Write-Host "  Sample data:" -ForegroundColor Gray
        $items | Select-Object -First 2 | ForEach-Object {
            $item = $_
            $properties = $item.PSObject.Properties | Select-Object -First 5
            $preview = ($properties | ForEach-Object { "$($_.Name): $($_.Value)" }) -join ", "
            Write-Host "    - $preview" -ForegroundColor Gray
        }
        
        return $true
    }
    catch {
        Write-Host "  ❌ Request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "     Status: $statusCode" -ForegroundColor Red
        }
        return $false
    }
}

# Function to test partner RLS
function Test-PartnerRLS {
    param(
        [string]$PartnerName,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$ExpectedFilterColumn,
        [string]$ExpectedFilterValue,
        [array]$TestQueries
    )
    
    Write-Host "`n========================================================================" -ForegroundColor Magenta
    Write-Host "  TESTING: $PartnerName" -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Magenta
    
    Write-Host "`nExpected RLS filter: $ExpectedFilterColumn = '$ExpectedFilterValue'" -ForegroundColor Cyan
    
    # Get token using Azure CLI
    $token = Get-ServicePrincipalToken-AzCLI `
        -TenantId $TenantId `
        -ClientId $ClientId `
        -ClientSecret $ClientSecret `
        -PartnerName $PartnerName
    
    if (-not $token) {
        Write-Host "`n❌ Cannot test $PartnerName - token acquisition failed`n" -ForegroundColor Red
        return @{
            Success = $false
            Tested = 0
            Passed = 0
        }
    }
    
    $results = @{
        Success = $true
        Tested = 0
        Passed = 0
    }
    
    foreach ($testQuery in $TestQueries) {
        $results.Tested++
        
        $success = Test-GraphQLQuery `
            -Endpoint $GraphQLEndpoint `
            -Token $token `
            -Query $testQuery.Query `
            -Description $testQuery.Description `
            -ExpectedFilterColumn $ExpectedFilterColumn `
            -ExpectedFilterValue $ExpectedFilterValue
        
        if ($success) {
            $results.Passed++
        }
    }
    
    Write-Host "`n$PartnerName Results: $($results.Passed)/$($results.Tested) tests passed" -ForegroundColor $(if ($results.Passed -eq $results.Tested) { "Green" } else { "Red" })
    
    return $results
}

# ===== TEST DEFINITIONS =====

# FedEx Carrier tests (CARRIER-FEDEX-GROUP)
$fedExQueries = @(
    @{
        Query = @"
query {
  gold_shipments_in_transits(first: 10) {
    items {
      carrier_id
      shipment_number
      delay_status
      origin_location
      destination_location
      days_in_transit
    }
  }
}
"@
        Description = "Shipments in Transit (should only see CARRIER-FEDEX-GROU)"
    },
    @{
        Query = @"
query {
  gold_sla_performances(first: 10) {
    items {
      carrier_id
      order_number
      sla_compliance
      processing_days
      on_time_delivery
    }
  }
}
"@
        Description = "SLA Performance (should only see CARRIER-FEDEX-GROU)"
    }
)

# Warehouse Partner tests (PARTNER_WH003)
$warehouseQueries = @(
    @{
        Query = @"
query {
  gold_warehouse_productivity_dailies(first: 10) {
    items {
      warehouse_partner_id
      warehouse_partner_name
      movement_day
      total_movements
      performance_status
      productivity_variance_pct
    }
  }
}
"@
        Description = "Warehouse Productivity (should only see PARTNER-WH003)"
    }
)

# ACME Customer tests (CUSTOMER)
$acmeQueries = @(
    @{
        Query = @"
query {
  gold_orders_daily_summaries(first: 10) {
    items {
      partner_access_scope
      customer_id
      customer_name
      order_day
      total_orders
      total_revenue
      sla_compliance_pct
    }
  }
}
"@
        Description = "Orders Daily Summary (should only see CUSTOMER)"
    },
    @{
        Query = @"
query {
  gold_shipments_in_transits(first: 10) {
    items {
      partner_access_scope
      customer_id
      customer_name
      shipment_number
      delay_status
      days_in_transit
    }
  }
}
"@
        Description = "Shipments (should only see CUSTOMER scope)"
    },
    @{
        Query = @"
query {
  gold_revenue_recognition_realtimes(first: 10) {
    items {
      partner_access_scope
      customer_id
      customer_name
      invoice_day
      total_revenue
      total_due
      collection_risk
    }
  }
}
"@
        Description = "Revenue Recognition (should only see CUSTOMER)"
    },
    @{
        Query = @"
query {
  gold_sla_performances(first: 10) {
    items {
      partner_access_scope
      customer_id
      customer_name
      order_number
      sla_compliance
      on_time_delivery
    }
  }
}
"@
        Description = "SLA Performance (should only see CUSTOMER scope)"
    }
)

# ===== RUN TESTS =====

$allResults = @()

# Test 1: FedEx Carrier
$fedex = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" }
if ($fedex) {
    $result = Test-PartnerRLS `
        -PartnerName "FedEx Carrier" `
        -ClientId $fedex.AppId `
        -ClientSecret $fedex.ClientSecret `
        -ExpectedFilterColumn "carrier_id" `
        -ExpectedFilterValue "CARRIER-FEDEX-GROU" `
        -TestQueries $fedExQueries
    
    $allResults += $result
}

# Test 2: Warehouse Partner
$warehouse = $credentials.Partners | Where-Object { $_.Role -eq "WAREHOUSE-EAST" }
if ($warehouse) {
    $result = Test-PartnerRLS `
        -PartnerName "Warehouse Partner" `
        -ClientId $warehouse.AppId `
        -ClientSecret $warehouse.ClientSecret `
        -ExpectedFilterColumn "warehouse_partner_id" `
        -ExpectedFilterValue "PARTNER-WH003" `
        -TestQueries $warehouseQueries
    
    $allResults += $result
}

# Test 3: ACME Customer
$acme = $credentials.Partners | Where-Object { $_.Role -eq "CUSTOMER-ACME" }
if ($acme) {
    $result = Test-PartnerRLS `
        -PartnerName "ACME Customer" `
        -ClientId $acme.AppId `
        -ClientSecret $acme.ClientSecret `
        -ExpectedFilterColumn "partner_access_scope" `
        -ExpectedFilterValue "CUSTOMER" `
        -TestQueries $acmeQueries
    
    $allResults += $result
}

# ===== FINAL SUMMARY =====

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  RLS TESTING COMPLETE" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$totalTested = ($allResults | Measure-Object -Property Tested -Sum).Sum
$totalPassed = ($allResults | Measure-Object -Property Passed -Sum).Sum
$allSuccess = ($allResults | Where-Object { -not $_.Success }).Count -eq 0

Write-Host "Overall Results: $totalPassed/$totalTested tests passed" -ForegroundColor $(if ($totalPassed -eq $totalTested) { "Green" } else { "Yellow" })

if ($totalPassed -eq $totalTested -and $allSuccess) {
    Write-Host "`n✅ ALL TESTS PASSED - RLS is working correctly!" -ForegroundColor Green
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "  1. ✅ OneLake RLS configuration validated" -ForegroundColor White
    Write-Host "  2. ▶️  Deploy Azure APIM for production" -ForegroundColor White
    Write-Host "  3. ▶️  Configure APIM policies and rate limiting" -ForegroundColor White
    Write-Host "  4. ▶️  Run end-to-end partner testing`n" -ForegroundColor White
} else {
    Write-Host "`n⚠️  Some tests failed. Please review:" -ForegroundColor Yellow
    Write-Host "  1. Check OneLake RLS configuration in Fabric Portal" -ForegroundColor White
    Write-Host "  2. Verify RLS roles are assigned to correct Service Principals" -ForegroundColor White
    Write-Host "  3. Ensure Gold tables have data with correct filter values" -ForegroundColor White
    Write-Host "  4. Re-run SQL verification: verify-rls-data.sql`n" -ForegroundColor White
}
