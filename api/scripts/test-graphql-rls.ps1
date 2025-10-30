#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test OneLake RLS filtering via GraphQL API with 3 Service Principals

.DESCRIPTION
    This script authenticates as each partner Service Principal and tests
    that OneLake RLS correctly filters data in GraphQL API responses.
    
    Tests:
    1. FedEx Carrier - Should only see CARRIER-FEDEX-GROUP shipments
    2. Warehouse Partner - Should only see PARTNER_WH003 warehouse data
    3. ACME Customer - Should only see CUSTOMER data across all tables

.PARAMETER GraphQLEndpoint
    The GraphQL API endpoint URL (default: from environment or hardcoded)

.EXAMPLE
    .\test-graphql-rls.ps1
    
.EXAMPLE
    .\test-graphql-rls.ps1 -GraphQLEndpoint "https://your-endpoint.graphql.fabric.microsoft.com/..."

.NOTES
    Author: GitHub Copilot
    Date: October 29, 2025
    Requires: partner-apps-credentials.json with Service Principal credentials
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

# Color scheme
$script:Colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Header = 'Magenta'
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-TestHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-ColorOutput "========================================================================" -Color $Colors.Header
    Write-ColorOutput "  $Title" -Color $Colors.Header
    Write-ColorOutput "========================================================================" -Color $Colors.Header
    Write-Host ""
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Passed) { $Colors.Success } else { $Colors.Error }
    
    Write-ColorOutput "$status - $TestName" -Color $color
    if ($Details) {
        Write-ColorOutput "       $Details" -Color 'Gray'
    }
}

function Get-ServicePrincipalToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$Scope = "https://api.fabric.microsoft.com/.default"
    )
    
    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = $Scope
        grant_type    = "client_credentials"
    }
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        return $response.access_token
    }
    catch {
        Write-ColorOutput "❌ Failed to get token" -Color $Colors.Error
        Write-ColorOutput "   Error: $($_.Exception.Message)" -Color $Colors.Error
        Write-ColorOutput "   Scope: $Scope" -Color $Colors.Warning
        return $null
    }
}

function Invoke-GraphQLQuery {
    param(
        [string]$Endpoint,
        [string]$Token,
        [string]$Query
    )
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        query = $Query
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -Body $body
        return $response
    }
    catch {
        Write-ColorOutput "   ⚠️  GraphQL Error: $($_.Exception.Message)" -Color $Colors.Warning
        if ($_.ErrorDetails.Message) {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-ColorOutput "   Details: $($errorDetails.errors[0].message)" -Color $Colors.Warning
        }
        return $null
    }
}

function Test-CarrierFedExRLS {
    param(
        [string]$Token,
        [string]$Endpoint
    )
    
    Write-TestHeader "TEST 1: FEDEX CARRIER (CARRIER-FEDEX-GROUP)"
    
    Write-ColorOutput "Testing gold_shipments_in_transit..." -Color $Colors.Info
    
    # Query shipments
    $query = @"
query {
  gold_shipments_in_transits(first: 100) {
    items {
      carrier_id
      carrier_name
      shipment_number
      delay_status
    }
  }
}
"@
    
    $result = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $query
    
    if ($result -and $result.data -and $result.data.gold_shipments_in_transits) {
        $shipments = $result.data.gold_shipments_in_transits.items
        $totalShipments = $shipments.Count
        $uniqueCarriers = $shipments | Select-Object -ExpandProperty carrier_id -Unique
        
        Write-ColorOutput "   Total shipments returned: $totalShipments" -Color 'White'
        Write-ColorOutput "   Unique carriers: $($uniqueCarriers -join ', ')" -Color 'White'
        
        # Test: Should ONLY see CARRIER-FEDEX-GROUP
        $onlyFedEx = $uniqueCarriers.Count -eq 1 -and $uniqueCarriers[0] -eq 'CARRIER-FEDEX-GROUP'
        $noOtherCarriers = -not ($shipments | Where-Object { $_.carrier_id -ne 'CARRIER-FEDEX-GROUP' })
        
        Write-TestResult -TestName "Only CARRIER-FEDEX-GROUP data visible" -Passed $onlyFedEx -Details "Found carriers: $($uniqueCarriers -join ', ')"
        Write-TestResult -TestName "No data leakage from other carriers" -Passed $noOtherCarriers
        
        if ($totalShipments -eq 0) {
            Write-TestResult -TestName "Data exists for FedEx" -Passed $false -Details "No shipments found - check data generation"
        } else {
            Write-TestResult -TestName "Data exists for FedEx" -Passed $true -Details "$totalShipments shipments found"
        }
    } else {
        Write-TestResult -TestName "GraphQL query execution" -Passed $false -Details "No data returned or query failed"
    }
    
    # Test SLA Performance
    Write-Host ""
    Write-ColorOutput "Testing gold_sla_performance..." -Color $Colors.Info
    
    $slaQuery = @"
query {
  gold_sla_performances(first: 50) {
    items {
      carrier_id
      order_number
      sla_compliance
      processing_days
    }
  }
}
"@
    
    $slaResult = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $slaQuery
    
    if ($slaResult -and $slaResult.data -and $slaResult.data.gold_sla_performances) {
        $slaRecords = $slaResult.data.gold_sla_performances.items
        $totalSLA = $slaRecords.Count
        $slaCarriers = $slaRecords | Select-Object -ExpandProperty carrier_id -Unique | Where-Object { $_ }
        
        Write-ColorOutput "   Total SLA records: $totalSLA" -Color 'White'
        Write-ColorOutput "   Unique carriers in SLA: $($slaCarriers -join ', ')" -Color 'White'
        
        $onlyFedExSLA = ($slaCarriers.Count -eq 0) -or (($slaCarriers.Count -eq 1) -and ($slaCarriers[0] -eq 'CARRIER-FEDEX-GROUP'))
        Write-TestResult -TestName "SLA data filtered correctly" -Passed $onlyFedExSLA -Details "Carriers: $($slaCarriers -join ', ')"
    }
}

function Test-WarehousePartnerRLS {
    param(
        [string]$Token,
        [string]$Endpoint
    )
    
    Write-TestHeader "TEST 2: WAREHOUSE PARTNER (PARTNER_WH003)"
    
    Write-ColorOutput "Testing gold_warehouse_productivity_daily..." -Color $Colors.Info
    
    $query = @"
query {
  gold_warehouse_productivity_dailies(first: 100) {
    items {
      warehouse_partner_id
      warehouse_partner_name
      warehouse_id
      movement_day
      total_movements
      performance_status
    }
  }
}
"@
    
    $result = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $query
    
    if ($result -and $result.data -and $result.data.gold_warehouse_productivity_dailies) {
        $records = $result.data.gold_warehouse_productivity_dailies.items
        $totalRecords = $records.Count
        $uniquePartners = $records | Select-Object -ExpandProperty warehouse_partner_id -Unique | Where-Object { $_ }
        
        Write-ColorOutput "   Total warehouse records: $totalRecords" -Color 'White'
        Write-ColorOutput "   Unique warehouse partners: $($uniquePartners -join ', ')" -Color 'White'
        
        # Test: Should ONLY see PARTNER_WH003
        $onlyPARTNER_WH003 = $uniquePartners.Count -eq 1 -and $uniquePartners[0] -eq 'PARTNER_WH003'
        $noOtherPartners = -not ($records | Where-Object { $_.warehouse_partner_id -ne 'PARTNER_WH003' -and $_.warehouse_partner_id })
        
        Write-TestResult -TestName "Only PARTNER_WH003 data visible" -Passed $onlyPARTNER_WH003 -Details "Found partners: $($uniquePartners -join ', ')"
        Write-TestResult -TestName "No data leakage from other warehouses" -Passed $noOtherPartners
        
        if ($totalRecords -eq 0) {
            Write-TestResult -TestName "Data exists for PARTNER_WH003" -Passed $false -Details "No records found - check data generation"
        } else {
            Write-TestResult -TestName "Data exists for PARTNER_WH003" -Passed $true -Details "$totalRecords records found"
        }
    } else {
        Write-TestResult -TestName "GraphQL query execution" -Passed $false -Details "No data returned or query failed"
    }
}

function Test-CustomerAcmeRLS {
    param(
        [string]$Token,
        [string]$Endpoint
    )
    
    Write-TestHeader "TEST 3: ACME CUSTOMER (CUSTOMER)"
    
    # Test 1: Orders
    Write-ColorOutput "Testing gold_orders_daily_summary..." -Color $Colors.Info
    
    $ordersQuery = @"
query {
  gold_orders_daily_summaries(first: 100) {
    items {
      partner_access_scope
      customer_id
      customer_name
      order_day
      total_orders
      total_revenue
    }
  }
}
"@
    
    $ordersResult = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $ordersQuery
    
    if ($ordersResult -and $ordersResult.data -and $ordersResult.data.gold_orders_daily_summaries) {
        $orders = $ordersResult.data.gold_orders_daily_summaries.items
        $totalOrders = $orders.Count
        $scopes = $orders | Select-Object -ExpandProperty partner_access_scope -Unique
        
        Write-ColorOutput "   Total order records: $totalOrders" -Color 'White'
        Write-ColorOutput "   Access scopes: $($scopes -join ', ')" -Color 'White'
        
        $onlyCustomer = $scopes.Count -eq 1 -and $scopes[0] -eq 'CUSTOMER'
        Write-TestResult -TestName "Orders filtered to CUSTOMER scope only" -Passed $onlyCustomer -Details "Scopes: $($scopes -join ', ')"
        
        if ($totalOrders -gt 0) {
            Write-TestResult -TestName "Order data exists" -Passed $true -Details "$totalOrders records"
        } else {
            Write-TestResult -TestName "Order data exists" -Passed $false -Details "No data found"
        }
    }
    
    # Test 2: Shipments
    Write-Host ""
    Write-ColorOutput "Testing gold_shipments_in_transit..." -Color $Colors.Info
    
    $shipmentsQuery = @"
query {
  gold_shipments_in_transits(first: 100) {
    items {
      partner_access_scope
      customer_id
      customer_name
      carrier_id
      shipment_number
    }
  }
}
"@
    
    $shipmentsResult = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $shipmentsQuery
    
    if ($shipmentsResult -and $shipmentsResult.data -and $shipmentsResult.data.gold_shipments_in_transits) {
        $shipments = $shipmentsResult.data.gold_shipments_in_transits.items
        $totalShipments = $shipments.Count
        $scopes = $shipments | Select-Object -ExpandProperty partner_access_scope -Unique | Where-Object { $_ }
        
        Write-ColorOutput "   Total shipment records: $totalShipments" -Color 'White'
        Write-ColorOutput "   Access scopes: $($scopes -join ', ')" -Color 'White'
        
        $onlyCustomer = ($scopes.Count -eq 0) -or (($scopes.Count -eq 1) -and ($scopes[0] -eq 'CUSTOMER'))
        Write-TestResult -TestName "Shipments filtered to CUSTOMER scope only" -Passed $onlyCustomer -Details "Scopes: $($scopes -join ', ')"
    }
    
    # Test 3: Revenue
    Write-Host ""
    Write-ColorOutput "Testing gold_revenue_recognition_realtime..." -Color $Colors.Info
    
    $revenueQuery = @"
query {
  gold_revenue_recognition_realtimes(first: 100) {
    items {
      partner_access_scope
      customer_id
      customer_name
      total_revenue
      total_due
    }
  }
}
"@
    
    $revenueResult = Invoke-GraphQLQuery -Endpoint $Endpoint -Token $Token -Query $revenueQuery
    
    if ($revenueResult -and $revenueResult.data -and $revenueResult.data.gold_revenue_recognition_realtimes) {
        $revenue = $revenueResult.data.gold_revenue_recognition_realtimes.items
        $totalRevenue = $revenue.Count
        $scopes = $revenue | Select-Object -ExpandProperty partner_access_scope -Unique
        
        Write-ColorOutput "   Total revenue records: $totalRevenue" -Color 'White'
        Write-ColorOutput "   Access scopes: $($scopes -join ', ')" -Color 'White'
        
        $onlyCustomer = $scopes.Count -eq 1 -and $scopes[0] -eq 'CUSTOMER'
        Write-TestResult -TestName "Revenue filtered to CUSTOMER scope only" -Passed $onlyCustomer -Details "Scopes: $($scopes -join ', ')"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-ColorOutput "========================================================================" -Color $Colors.Header
Write-ColorOutput "  ONELAKE RLS TESTING VIA GRAPHQL API" -Color $Colors.Header
Write-ColorOutput "========================================================================" -Color $Colors.Header
Write-Host ""
Write-ColorOutput "GraphQL Endpoint: $GraphQLEndpoint" -Color $Colors.Info
Write-Host ""

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"

if (-not (Test-Path $credentialsPath)) {
    Write-ColorOutput "❌ Credentials file not found: $credentialsPath" -Color $Colors.Error
    Write-ColorOutput "   Run create-partner-apps.ps1 first to create Service Principals" -Color $Colors.Warning
    exit 1
}

try {
    $credentials = Get-Content $credentialsPath | ConvertFrom-Json
    Write-ColorOutput "✅ Loaded credentials from $credentialsPath" -Color $Colors.Success
}
catch {
    Write-ColorOutput "❌ Failed to load credentials: $($_.Exception.Message)" -Color $Colors.Error
    exit 1
}

$tenantId = $credentials.TenantId

# ============================================================================
# TEST 1: FEDEX CARRIER
# ============================================================================

$fedex = $credentials.Partners | Where-Object { $_.Role -eq 'CARRIER-FEDEX' }

if ($fedex) {
    Write-ColorOutput "`n🔑 Authenticating as FedEx Carrier..." -Color $Colors.Info
    $fedexToken = Get-ServicePrincipalToken -TenantId $tenantId -ClientId $fedex.AppId -ClientSecret $fedex.ClientSecret
    
    if ($fedexToken) {
        Write-ColorOutput "✅ Token acquired for FedEx Carrier" -Color $Colors.Success
        Test-CarrierFedExRLS -Token $fedexToken -Endpoint $GraphQLEndpoint
    }
} else {
    Write-ColorOutput "⚠️  FedEx Carrier credentials not found" -Color $Colors.Warning
}

# ============================================================================
# TEST 2: WAREHOUSE PARTNER
# ============================================================================

$warehouse = $credentials.Partners | Where-Object { $_.Role -eq 'WAREHOUSE-EAST' }

if ($warehouse) {
    Write-ColorOutput "`n🔑 Authenticating as Warehouse Partner..." -Color $Colors.Info
    $warehouseToken = Get-ServicePrincipalToken -TenantId $tenantId -ClientId $warehouse.AppId -ClientSecret $warehouse.ClientSecret
    
    if ($warehouseToken) {
        Write-ColorOutput "✅ Token acquired for Warehouse Partner" -Color $Colors.Success
        Test-WarehousePartnerRLS -Token $warehouseToken -Endpoint $GraphQLEndpoint
    }
} else {
    Write-ColorOutput "⚠️  Warehouse Partner credentials not found" -Color $Colors.Warning
}

# ============================================================================
# TEST 3: ACME CUSTOMER
# ============================================================================

$customer = $credentials.Partners | Where-Object { $_.Role -eq 'CUSTOMER-ACME' }

if ($customer) {
    Write-ColorOutput "`n🔑 Authenticating as ACME Customer..." -Color $Colors.Info
    $customerToken = Get-ServicePrincipalToken -TenantId $tenantId -ClientId $customer.AppId -ClientSecret $customer.ClientSecret
    
    if ($customerToken) {
        Write-ColorOutput "✅ Token acquired for ACME Customer" -Color $Colors.Success
        Test-CustomerAcmeRLS -Token $customerToken -Endpoint $GraphQLEndpoint
    }
} else {
    Write-ColorOutput "⚠️  ACME Customer credentials not found" -Color $Colors.Warning
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-ColorOutput "========================================================================" -Color $Colors.Header
Write-ColorOutput "  RLS TESTING COMPLETE" -Color $Colors.Header
Write-ColorOutput "========================================================================" -Color $Colors.Header
Write-Host ""
Write-ColorOutput "Next Steps:" -Color $Colors.Info
Write-ColorOutput "  1. Review test results above" -Color 'White'
Write-ColorOutput "  2. If failures: Check OneLake RLS configuration in Fabric Portal" -Color 'White'
Write-ColorOutput "  3. If no data: Regenerate data and re-run Gold views notebook" -Color 'White'
Write-ColorOutput "  4. If passes: Proceed to deploy APIM" -Color 'White'
Write-Host ""
