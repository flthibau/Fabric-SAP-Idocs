# Create all Partner APIs - Simple and Fast
# Based on the working "shipments" API configuration

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CREATE ALL PARTNER APIs" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

# Define all APIs to create
$apis = @(
    @{
        Id = "orders-api"
        Name = "Orders API"
        Path = "orders"
        Query = "query { gold_orders_daily_summary(first: 100) { items { order_date total_orders total_lines total_revenue avg_order_value } } }"
    },
    @{
        Id = "warehouse-api"
        Name = "Warehouse Productivity API"
        Path = "warehouse"
        Query = "query { gold_warehouse_productivity_daily(first: 100) { items { warehouse_id productivity_date total_shipments avg_processing_time } } }"
    },
    @{
        Id = "sla-api"
        Name = "SLA Performance API"
        Path = "sla"
        Query = "query { gold_sla_performance(first: 100) { items { carrier_id ontime_shipments late_shipments total_shipments ontime_percentage } } }"
    },
    @{
        Id = "revenue-api"
        Name = "Revenue API"
        Path = "revenue"
        Query = "query { gold_revenue_recognition_realtime(first: 100) { items { event_date total_revenue recognized_revenue pending_revenue } } }"
    }
)

foreach ($api in $apis) {
    Write-Host "`nCreating $($api.Name)..." -ForegroundColor Yellow
    
    # Create API
    $apiBody = @{
        properties = @{
            displayName = $api.Name
            path = $api.Path
            protocols = @("https")
            subscriptionRequired = $false
        }
    } | ConvertTo-Json -Depth 10

    $createUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)?api-version=2021-08-01"

    try {
        Invoke-RestMethod -Method Put -Uri $createUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $apiBody | Out-Null
        
        Write-Host "  ✓ API created" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    Start-Sleep -Seconds 2

    # Create POST operation
    $opBody = @{
        properties = @{
            displayName = "Query"
            method = "POST"
            urlTemplate = "/"
        }
    } | ConvertTo-Json -Depth 10

    $opUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)/operations/query?api-version=2021-08-01"

    try {
        Invoke-RestMethod -Method Put -Uri $opUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $opBody | Out-Null
        
        Write-Host "  ✓ Operation created" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    Start-Sleep -Seconds 2

    # Create simple policy
    $policy = "<policies><inbound><set-backend-service backend-id=`"fabric-graphql-backend`" /><set-header name=`"Content-Type`" exists-action=`"override`"><value>application/json</value></set-header></inbound><backend><forward-request /></backend><outbound></outbound><on-error></on-error></policies>"

    $policyBody = @{
        properties = @{
            value = $policy
            format = "rawxml"
        }
    } | ConvertTo-Json -Depth 10

    $policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)/operations/query/policies/policy?api-version=2021-08-01"

    try {
        Invoke-RestMethod -Method Put -Uri $policyUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $policyBody | Out-Null
        
        Write-Host "  ✓ Policy created" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Add to Partner APIs product
    Start-Sleep -Seconds 2
    try {
        az apim product api add --resource-group rg-3pl-partner-api --service-name apim-3pl-flt --product-id partner-apis --api-id $api.Id 2>$null | Out-Null
        Write-Host "  ✓ Added to product" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ Could not add to product" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  ALL APIs CREATED!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "APIs disponibles:" -ForegroundColor Cyan
Write-Host "  POST https://apim-3pl-flt.azure-api.net/shipments" -ForegroundColor White
Write-Host "  POST https://apim-3pl-flt.azure-api.net/orders" -ForegroundColor White
Write-Host "  POST https://apim-3pl-flt.azure-api.net/warehouse" -ForegroundColor White
Write-Host "  POST https://apim-3pl-flt.azure-api.net/sla" -ForegroundColor White
Write-Host "  POST https://apim-3pl-flt.azure-api.net/revenue" -ForegroundColor White

Write-Host "`nToutes utilisent POST avec body GraphQL query" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan
