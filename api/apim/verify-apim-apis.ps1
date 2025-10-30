# Verify APIM APIs Configuration
# This script validates all Partner APIs in APIM

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  APIM PARTNER APIS VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$resourceGroup = "rg-3pl-partner-api"
$apimName = "apim-3pl-flt"

# Check if logged in
Write-Host "Checking Azure login..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "? Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "? Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "? Subscription: $($account.name)`n" -ForegroundColor Green

# Get all APIs
Write-Host "Fetching APIs from APIM..." -ForegroundColor Yellow
$apis = az apim api list `
    --resource-group $resourceGroup `
    --service-name $apimName `
    --query "[].{Name:name, Display:displayName, Path:path, ServiceUrl:serviceUrl}" `
    | ConvertFrom-Json

if (-not $apis) {
    Write-Host "? Failed to fetch APIs" -ForegroundColor Red
    exit 1
}

Write-Host "? Found $($apis.Count) APIs`n" -ForegroundColor Green

# Expected APIs
$expectedApis = @(
    @{Name="graphql-partner-api"; Display="3PL Partner GraphQL API"; Path="graphql"},
    @{Name="shipments-rest-api"; Display="3PL Shipments REST API"; Path="shipments"},
    @{Name="orders-api"; Display="3PL Orders REST API"; Path="orders"},
    @{Name="warehouse-productivity-api"; Display="3PL Warehouse Productivity REST API"; Path="warehouse-productivity"},
    @{Name="sla-performance-api"; Display="3PL SLA Performance REST API"; Path="sla-performance"},
    @{Name="revenue-api"; Display="3PL Revenue REST API"; Path="revenue"}
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  API VALIDATION RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$allValid = $true

foreach ($expected in $expectedApis) {
    $api = $apis | Where-Object { $_.Name -eq $expected.Name }
    
    if (-not $api) {
        Write-Host "? MISSING: $($expected.Name)" -ForegroundColor Red
        $allValid = $false
        continue
    }
    
    # Validate Display Name
    if ($api.Display -ne $expected.Display) {
        Write-Host "WARN:  $($expected.Name)" -ForegroundColor Yellow
        Write-Host "       Display Name mismatch:" -ForegroundColor Gray
        Write-Host "       Expected: $($expected.Display)" -ForegroundColor Gray
        Write-Host "       Actual:   $($api.Display)" -ForegroundColor Gray
        $allValid = $false
    }
    
    # Validate Path
    elseif ($api.Path -ne $expected.Path) {
        Write-Host "WARN:  $($expected.Name)" -ForegroundColor Yellow
        Write-Host "       Path mismatch:" -ForegroundColor Gray
        Write-Host "       Expected: $($expected.Path)" -ForegroundColor Gray
        Write-Host "       Actual:   $($api.Path)" -ForegroundColor Gray
        $allValid = $false
    }
    
    # Validate ServiceUrl exists
    elseif ([string]::IsNullOrEmpty($api.ServiceUrl)) {
        Write-Host "WARN:  $($expected.Name)" -ForegroundColor Yellow
        Write-Host "       ServiceUrl is missing" -ForegroundColor Gray
        $allValid = $false
    }
    
    else {
        Write-Host "OK:    $($expected.Display)" -ForegroundColor Green
        Write-Host "       Path: /$($api.Path)" -ForegroundColor Gray
    }
}

Write-Host ""

# Check for unexpected APIs
$unexpectedApis = $apis | Where-Object { 
    $apiName = $_.Name
    -not ($expectedApis | Where-Object { $_.Name -eq $apiName })
}

if ($unexpectedApis) {
    Write-Host "UNEXPECTED APIs FOUND:" -ForegroundColor Yellow
    foreach ($api in $unexpectedApis) {
        Write-Host "  WARN: $($api.Name) - $($api.Display)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
if ($allValid -and -not $unexpectedApis) {
    Write-Host "  SUCCESS: ALL APIS VALID" -ForegroundColor Green
} else {
    Write-Host "  WARNING: VALIDATION ISSUES" -ForegroundColor Yellow
}
Write-Host "========================================`n" -ForegroundColor Cyan

# Display API Summary Table
Write-Host "API SUMMARY:" -ForegroundColor Cyan
$apis | Select-Object `
    @{Name="Display Name"; Expression={$_.Display}}, `
    @{Name="Path"; Expression={"/$($_.Path)"}}, `
    @{Name="Has ServiceUrl"; Expression={if($_.ServiceUrl){"Yes"}else{"No"}}} `
    | Format-Table -AutoSize

Write-Host "Total APIs: $($apis.Count)" -ForegroundColor Gray
Write-Host "Expected APIs: $($expectedApis.Count)" -ForegroundColor Gray
Write-Host ""

if ($allValid -and -not $unexpectedApis) {
    exit 0
} else {
    exit 1
}
