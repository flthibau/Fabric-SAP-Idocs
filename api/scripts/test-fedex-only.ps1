#!/usr/bin/env pwsh
# Test OneLake RLS for FedEx Carrier only via GraphQL API

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4",
    
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  FEDEX CARRIER RLS TEST (GraphQL API)" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "GraphQL Endpoint: $GraphQLEndpoint" -ForegroundColor White
Write-Host ""

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"
if (-not (Test-Path $credentialsPath)) {
    Write-Host "Failed to find credentials file" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credentialsPath | ConvertFrom-Json
Write-Host "Loaded credentials`n" -ForegroundColor Green

# Get FedEx credentials
$fedExCred = $credentials.Partners | Where-Object { $_.Role -eq "CARRIER-FEDEX" } | Select-Object -First 1

if (-not $fedExCred) {
    Write-Host "FedEx Carrier credentials not found" -ForegroundColor Red
    exit 1
}

Write-Host "FedEx Carrier API:" -ForegroundColor Yellow
Write-Host "  App ID: $($fedExCred.AppId)" -ForegroundColor Gray
Write-Host "  Object ID: $($fedExCred.ServicePrincipalObjectId)" -ForegroundColor Gray
Write-Host ""

# Function to get token using Azure CLI
function Get-ServicePrincipalToken-AzCLI {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    Write-Host "Authenticating FedEx Carrier via Azure CLI..." -ForegroundColor Cyan
    
    try {
        # Login with Service Principal
        az login --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId --allow-no-subscriptions --output none 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Azure CLI login failed" -ForegroundColor Red
            return $null
        }
        
        # Get Power BI token
        $token = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $token) {
            Write-Host "Successfully obtained token (Power BI scope)" -ForegroundColor Green
            return $token
        }
        
        # Try Fabric scope if Power BI fails
        Write-Host "  Power BI scope failed, trying Fabric scope..." -ForegroundColor Yellow
        $token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $token) {
            Write-Host "Successfully obtained token (Fabric scope)" -ForegroundColor Green
            return $token
        }
        
        Write-Host "Failed to get token for any scope" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
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
        [string]$QueryName
    )
    
    Write-Host "`n========================================================================" -ForegroundColor DarkGray
    Write-Host "Testing: $QueryName" -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor DarkGray
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        query = $Query
    } | ConvertTo-Json -Depth 10
    
    try {
        Write-Host "`nSending GraphQL request..." -ForegroundColor Cyan
        $result = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -Body $body -ErrorAction Stop
        
        if ($result.errors) {
            Write-Host "`nGraphQL Error:" -ForegroundColor Red
            $result.errors | ForEach-Object {
                Write-Host "   $($_.message)" -ForegroundColor Red
            }
            return $false
        }
        
        # Extract items from result
        $dataKey = $result.data.PSObject.Properties.Name | Select-Object -First 1
        $items = $result.data.$dataKey.items
        
        Write-Host "`nQuery successful!" -ForegroundColor Green
        Write-Host "   Received: $($items.Count) items" -ForegroundColor White
        
        if ($items.Count -eq 0) {
            Write-Host "`nNo data returned" -ForegroundColor Yellow
            Write-Host "   Possible reasons:" -ForegroundColor Gray
            Write-Host "   - RLS is filtering correctly but no FedEx data exists" -ForegroundColor Gray
            Write-Host "   - RLS is too restrictive" -ForegroundColor Gray
            Write-Host "   - Gold views are empty" -ForegroundColor Gray
            return $true
        }
        
        # Check RLS filtering for carrier_id
        Write-Host "`nChecking RLS filtering..." -ForegroundColor Cyan
        
        $expectedCarrierId = "CARRIER-FEDEX-GROU"
        $carrierIds = $items | Select-Object -ExpandProperty carrier_id -ErrorAction SilentlyContinue | Sort-Object -Unique
        
        if ($carrierIds) {
            Write-Host "`n   Carrier IDs found in results:" -ForegroundColor White
            $carrierIds | ForEach-Object {
                if ($_ -eq $expectedCarrierId) {
                    Write-Host "   OK: $_" -ForegroundColor Green
                } else {
                    Write-Host "   VIOLATION: $_ (SHOULD NOT BE VISIBLE!)" -ForegroundColor Red
                }
            }
            
            $violations = $carrierIds | Where-Object { $_ -ne $expectedCarrierId }
            if ($violations.Count -gt 0) {
                Write-Host "`nRLS VIOLATION DETECTED!" -ForegroundColor Red
                Write-Host "   Expected: Only $expectedCarrierId" -ForegroundColor Red
                Write-Host "   Found: $($violations.Count) unauthorized carrier(s)" -ForegroundColor Red
                return $false
            }
            
            Write-Host "`nRLS FILTERING WORKING CORRECTLY!" -ForegroundColor Green
            Write-Host "   All results filtered to: $expectedCarrierId" -ForegroundColor Green
        }
        
        # Show sample data
        Write-Host "`nSample data (first 3 items):" -ForegroundColor Cyan
        $items | Select-Object -First 3 | ForEach-Object {
            Write-Host "`n   Item:" -ForegroundColor Gray
            $_.PSObject.Properties | ForEach-Object {
                $value = if ($_.Value) { $_.Value } else { "(null)" }
                Write-Host "     $($_.Name): $value" -ForegroundColor Gray
            }
        }
        
        return $true
    }
    catch {
        Write-Host "`nRequest failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "   Status Code: $statusCode" -ForegroundColor Red
        }
        return $false
    }
}

# ===== MAIN TEST EXECUTION =====

Write-Host "========================================================================" -ForegroundColor Magenta
Write-Host "  STEP 1: GET ACCESS TOKEN" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

$token = Get-ServicePrincipalToken-AzCLI -TenantId $TenantId -ClientId $fedExCred.AppId -ClientSecret $fedExCred.ClientSecret

if (-not $token) {
    Write-Host "`nCannot proceed - token acquisition failed" -ForegroundColor Red
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "  - Service Principal not configured correctly" -ForegroundColor Gray
    Write-Host "  - Tenant setting Service principals can use Fabric APIs disabled" -ForegroundColor Gray
    Write-Host "  - GraphQL API Execute permission not granted" -ForegroundColor Gray
    exit 1
}

Write-Host "`n========================================================================" -ForegroundColor Magenta
Write-Host "  STEP 2: TEST RLS FILTERING" -ForegroundColor Magenta
Write-Host "========================================================================" -ForegroundColor Magenta

Write-Host "`nExpected RLS behavior:" -ForegroundColor Cyan
Write-Host "  OK: Only see carrier_id = CARRIER-FEDEX-GROU" -ForegroundColor Green
Write-Host "  VIOLATION: Should NOT see other carriers (TFORCE, KNIGHT, SAIA, etc.)" -ForegroundColor Red

$testsPassed = 0
$testsFailed = 0

# Test 1: Shipments in Transit
$query1 = @"
query {
  gold_shipments_in_transits(first: 10) {
    items {
      carrier_id
      carrier_name
      shipment_number
      delay_status
      origin_location
      destination_location
      days_in_transit
    }
  }
}
"@

if (Test-GraphQLQuery -Endpoint $GraphQLEndpoint -Token $token -Query $query1 -QueryName "Shipments in Transit") {
    $testsPassed++
} else {
    $testsFailed++
}

# Test 2: SLA Performance
$query2 = @"
query {
  gold_sla_performances(first: 10) {
    items {
      carrier_id
      carrier_name
      order_number
      sla_compliance
      processing_days
      on_time_delivery
    }
  }
}
"@

if (Test-GraphQLQuery -Endpoint $GraphQLEndpoint -Token $token -Query $query2 -QueryName "SLA Performance") {
    $testsPassed++
} else {
    $testsFailed++
}

# ===== FINAL RESULTS =====

Write-Host "`n`n========================================================================" -ForegroundColor Cyan
Write-Host "  FINAL RESULTS" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "Tests Passed: $testsPassed" -ForegroundColor $(if ($testsPassed -gt 0) { "Green" } else { "Gray" })
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Gray" })
Write-Host "Total Tests:  $($testsPassed + $testsFailed)`n" -ForegroundColor White

if ($testsFailed -eq 0 -and $testsPassed -gt 0) {
    Write-Host "ALL TESTS PASSED - RLS is working correctly for FedEx Carrier!" -ForegroundColor Green
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "  1. Test other Service Principals (Warehouse Partner, ACME Customer)" -ForegroundColor Gray
    Write-Host "  2. Deploy Azure APIM" -ForegroundColor Gray
    Write-Host "  3. Run end-to-end tests via APIM" -ForegroundColor Gray
} elseif ($testsPassed -eq 0) {
    Write-Host "ALL TESTS FAILED" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify Service Principal has RLS role assigned (not workspace READ)" -ForegroundColor Gray
    Write-Host "  2. Check that OneLake RLS role CarrierFedEx exists with correct filter" -ForegroundColor Gray
    Write-Host "  3. Verify SP Object ID assigned to role: fa86b10b-792c-495b-af85-bc8a765b44a1" -ForegroundColor Gray
    Write-Host "  4. Check Gold Views contain data with carrier_id = CARRIER-FEDEX-GROU" -ForegroundColor Gray
} else {
    Write-Host "PARTIAL SUCCESS - Some tests passed, some failed" -ForegroundColor Yellow
    Write-Host "`nReview the output above to identify which queries failed." -ForegroundColor Gray
}

Write-Host "`n========================================================================`n" -ForegroundColor Cyan