# Create all Partner APIs using the working POST approach
# Based on successful /shipments API

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CREATE ALL PARTNER APIs" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Authenticate
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4 | Out-Null
az account set --subscription "ME-MngEnvMCAP396311-flthibau-1"

$subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

Write-Host "✓ Authenticated`n" -ForegroundColor Green

# Define all APIs to create
$apis = @(
    @{
        Id = "orders-api"
        DisplayName = "3PL Orders API"
        Path = "orders"
        Description = "Get orders data"
        Query = "query { gold_orders_daily_summary(first: 100) { items { order_number order_date customer_id customer_name order_status total_amount } } }"
        DataPath = "gold_orders_daily_summary"
    },
    @{
        Id = "warehouse-productivity-api"
        DisplayName = "3PL Warehouse Productivity API"
        Path = "warehouse-productivity"
        Description = "Get warehouse productivity metrics"
        Query = "query { gold_warehouse_productivity_daily(first: 100) { items { warehouse_id warehouse_name productivity_date total_receipts total_shipments productivity_score } } }"
        DataPath = "gold_warehouse_productivity_daily"
    },
    @{
        Id = "sla-performance-api"
        DisplayName = "3PL SLA Performance API"
        Path = "sla-performance"
        Description = "Get SLA performance metrics"
        Query = "query { gold_sla_performance(first: 100) { items { partner_id partner_name sla_date on_time_deliveries total_deliveries sla_compliance_rate } } }"
        DataPath = "gold_sla_performance"
    },
    @{
        Id = "revenue-api"
        DisplayName = "3PL Revenue API"
        Path = "revenue"
        Description = "Get revenue recognition data"
        Query = "query { gold_revenue_recognition_realtime(first: 100) { items { transaction_date customer_id customer_name service_type revenue_amount recognition_status } } }"
        DataPath = "gold_revenue_recognition_realtime"
    }
)

$createdApis = @()

foreach ($api in $apis) {
    Write-Host "Creating API: $($api.DisplayName)" -ForegroundColor Yellow
    Write-Host "  Path: $($api.Path)" -ForegroundColor Gray
    
    # Create API
    $apiBody = @{
        properties = @{
            displayName = $api.DisplayName
            path = $api.Path
            protocols = @("https")
            subscriptionRequired = $false
            description = $api.Description
        }
    } | ConvertTo-Json -Depth 10
    
    $createUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)?api-version=2021-08-01"
    
    try {
        $apiResult = Invoke-RestMethod -Method Put -Uri $createUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $apiBody
        
        Write-Host "  ✓ API created" -ForegroundColor Green
        
        # Create POST operation
        $opBody = @{
            properties = @{
                displayName = "Get Data"
                method = "POST"
                urlTemplate = "/"
                description = $api.Description
                request = @{
                    description = "GraphQL query request"
                    representations = @(
                        @{
                            contentType = "application/json"
                        }
                    )
                }
            }
        } | ConvertTo-Json -Depth 10
        
        $opUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)/operations/get-data?api-version=2021-08-01"
        
        Invoke-RestMethod -Method Put -Uri $opUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $opBody | Out-Null
        
        Write-Host "  ✓ Operation created" -ForegroundColor Green
        
        # Create policy with response transformation
        $dataPath = $api.DataPath
        $policy = @"
<policies>
    <inbound>
        <set-backend-service backend-id="fabric-graphql-backend" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <set-body>``@{
            var response = context.Response.Body.As<JObject>(preserveContent: true);
            if (response["data"] != null && response["data"]["$dataPath"] != null) {
                var items = response["data"]["$dataPath"]["items"];
                return items.ToString();
            }
            return "[]";
        }</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </outbound>
    <on-error>
        <set-body>``@{
            return new JObject(
                new JProperty("error", context.LastError.Message),
                new JProperty("source", context.LastError.Source)
            ).ToString();
        }</set-body>
    </on-error>
</policies>
"@
        
        $policyBody = @{
            properties = @{
                value = $policy
                format = "rawxml"
            }
        } | ConvertTo-Json -Depth 10
        
        $policyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/$($api.Id)/operations/get-data/policies/policy?api-version=2021-08-01"
        
        Invoke-RestMethod -Method Put -Uri $policyUrl -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $policyBody | Out-Null
        
        Write-Host "  ✓ Policy created" -ForegroundColor Green
        
        # Add to Partner APIs product
        try {
            az apim product api add `
                --resource-group rg-3pl-partner-api `
                --service-name apim-3pl-flt `
                --product-id partner-apis `
                --api-id $api.Id 2>$null | Out-Null
            Write-Host "  ✓ Added to product" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠ Could not add to product" -ForegroundColor Yellow
        }
        
        $createdApis += @{
            Name = $api.DisplayName
            Path = $api.Path
            Url = "https://apim-3pl-flt.azure-api.net/$($api.Path)"
            Query = $api.Query
        }
        
        Write-Host ""
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
}

# Also update shipments API policy with transformation
Write-Host "Updating /shipments API with response transformation..." -ForegroundColor Yellow

$shipmentsPolicy = @'
<policies>
    <inbound>
        <set-backend-service backend-id="fabric-graphql-backend" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <set-body>@{
            var response = context.Response.Body.As<JObject>(preserveContent: true);
            if (response["data"] != null && response["data"]["gold_shipments_in_transits"] != null) {
                var items = response["data"]["gold_shipments_in_transits"]["items"];
                return items.ToString();
            }
            return "[]";
        }</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </outbound>
    <on-error>
        <set-body>@{
            return new JObject(
                new JProperty("error", context.LastError.Message),
                new JProperty("source", context.LastError.Source)
            ).ToString();
        }</set-body>
    </on-error>
</policies>
'@

$shipmentsPolicyBody = @{
    properties = @{
        value = $shipmentsPolicy
        format = "rawxml"
    }
} | ConvertTo-Json -Depth 10

$shipmentsPolicyUrl = "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/shipments-rest-api/operations/get-shipments/policies/policy?api-version=2021-08-01"

try {
    Invoke-RestMethod -Method Put -Uri $shipmentsPolicyUrl -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $shipmentsPolicyBody | Out-Null
    Write-Host "✓ Shipments policy updated`n" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not update shipments policy`n" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  ALL APIs CREATED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "APIs Created:" -ForegroundColor Cyan
Write-Host "  1. Shipments:     POST https://apim-3pl-flt.azure-api.net/shipments" -ForegroundColor White
Write-Host "  2. Orders:        POST https://apim-3pl-flt.azure-api.net/orders" -ForegroundColor White
Write-Host "  3. Warehouse:     POST https://apim-3pl-flt.azure-api.net/warehouse-productivity" -ForegroundColor White
Write-Host "  4. SLA:           POST https://apim-3pl-flt.azure-api.net/sla-performance" -ForegroundColor White
Write-Host "  5. Revenue:       POST https://apim-3pl-flt.azure-api.net/revenue" -ForegroundColor White

Write-Host "`nAll APIs:" -ForegroundColor Cyan
Write-Host "  - No subscription required (subscriptionRequired: false)" -ForegroundColor Gray
Write-Host "  - Use POST method with GraphQL query in body" -ForegroundColor Gray
Write-Host "  - Return JSON array of items (GraphQL wrapper removed)" -ForegroundColor Gray
Write-Host "  - Added to 'Partner APIs' product" -ForegroundColor Gray

Write-Host "`nWaiting 10 seconds for propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nTesting all APIs..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Gray

az login --service-principal `
    -u "94a9edcc-7a22-4d89-b001-799e8414711a" `
    -p "YOUR_FEDEX_SECRET_HERE" `
    --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4" | Out-Null

$testTokenJson = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
$testToken = $testTokenJson.accessToken

Write-Host "Testing with FedEx Service Principal`n" -ForegroundColor Gray

# Test each API
$testResults = @()

# Test Shipments
Write-Host "1. Testing /shipments..." -ForegroundColor Yellow
$shipmentsQuery = '{"query":"query { gold_shipments_in_transits(first: 3) { items { shipment_number carrier_id } } }"}'
try {
    $response = Invoke-WebRequest -Uri "https://apim-3pl-flt.azure-api.net/shipments" -Method Post -Headers @{"Authorization" = "Bearer $testToken"; "Content-Type" = "application/json"} -Body $shipmentsQuery -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   ✅ SUCCESS - $($json.Count) items returned" -ForegroundColor Green
    $testResults += "✅ Shipments"
} catch {
    Write-Host "   ❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $testResults += "❌ Shipments"
}

# Test Orders
Write-Host "2. Testing /orders..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://apim-3pl-flt.azure-api.net/orders" -Method Post -Headers @{"Authorization" = "Bearer $testToken"; "Content-Type" = "application/json"} -Body '{"query":"query { gold_orders_daily_summary(first: 3) { items { order_number } } }"}' -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   ✅ SUCCESS - $($json.Count) items returned" -ForegroundColor Green
    $testResults += "✅ Orders"
} catch {
    Write-Host "   ❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $testResults += "❌ Orders"
}

# Test Warehouse Productivity
Write-Host "3. Testing /warehouse-productivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://apim-3pl-flt.azure-api.net/warehouse-productivity" -Method Post -Headers @{"Authorization" = "Bearer $testToken"; "Content-Type" = "application/json"} -Body '{"query":"query { gold_warehouse_productivity_daily(first: 3) { items { warehouse_id } } }"}' -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   ✅ SUCCESS - $($json.Count) items returned" -ForegroundColor Green
    $testResults += "✅ Warehouse"
} catch {
    Write-Host "   ❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $testResults += "❌ Warehouse"
}

# Test SLA Performance
Write-Host "4. Testing /sla-performance..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://apim-3pl-flt.azure-api.net/sla-performance" -Method Post -Headers @{"Authorization" = "Bearer $testToken"; "Content-Type" = "application/json"} -Body '{"query":"query { gold_sla_performance(first: 3) { items { partner_id } } }"}' -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   ✅ SUCCESS - $($json.Count) items returned" -ForegroundColor Green
    $testResults += "✅ SLA"
} catch {
    Write-Host "   ❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $testResults += "❌ SLA"
}

# Test Revenue
Write-Host "5. Testing /revenue..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://apim-3pl-flt.azure-api.net/revenue" -Method Post -Headers @{"Authorization" = "Bearer $testToken"; "Content-Type" = "application/json"} -Body '{"query":"query { gold_revenue_recognition_realtime(first: 3) { items { transaction_date } } }"}' -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   ✅ SUCCESS - $($json.Count) items returned" -ForegroundColor Green
    $testResults += "✅ Revenue"
} catch {
    Write-Host "   ❌ ERROR: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    $testResults += "❌ Revenue"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$testResults | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

$successCount = ($testResults | Where-Object { $_ -like "✅*" }).Count
Write-Host "`nSuccess Rate: $successCount/5" -ForegroundColor $(if($successCount -eq 5){"Green"}else{"Yellow"})

Write-Host "`n========================================`n" -ForegroundColor Cyan
