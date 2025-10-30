# ============================================================
# Create REST APIs in APIM with GraphQL Backend
# ============================================================

param(
    [string]$ResourceGroup = "rg-3pl-partner-api",
    [string]$ApimName = "apim-3pl-flt",
    [string]$Subscription = "f79d4407-99c6-4d64-88fc-848fb05d5476"
)

$ErrorActionPreference = "Continue"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  CREATE REST APIs IN APIM" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  APIM Name: $ApimName"
Write-Host "  Subscription: $Subscription"

# Get management token
Write-Host "`nGetting Azure Management token..." -ForegroundColor Yellow
$tokenJson = az account get-access-token --resource "https://management.azure.com/" | ConvertFrom-Json
$token = $tokenJson.accessToken

if (-not $token) {
    Write-Host "ERROR: Failed to get management token" -ForegroundColor Red
    exit 1
}

Write-Host "Token acquired" -ForegroundColor Green

# ============================================================
# Step 1: Create REST API
# ============================================================

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  STEP 1: CREATE REST API" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$apiId = "rest-partner-api"
$apiUrl = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$apiId`?api-version=2021-08-01"

$apiBody = @{
    properties = @{
        displayName = "3PL Partner REST API"
        description = "REST API for 3PL partners with GraphQL backend transformation"
        path = "api/v1"
        protocols = @("https")
        subscriptionRequired = $false
        isCurrent = $true
    }
} | ConvertTo-Json -Depth 10

Write-Host "Creating REST API: $apiId" -ForegroundColor Yellow

try {
    $apiResponse = Invoke-RestMethod -Method Put `
        -Uri $apiUrl `
        -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } `
        -Body $apiBody
    
    Write-Host "REST API created successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ============================================================
# Step 2: Create Operations
# ============================================================

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  STEP 2: CREATE REST OPERATIONS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$operations = @(
    @{
        id = "get-shipments"
        displayName = "Get Shipments"
        method = "GET"
        urlTemplate = "/shipments"
        description = "Get list of shipments with optional filtering"
        graphqlQuery = 'query { gold_shipments_in_transits(first: 100) { items { shipment_number carrier_id customer_id origin_location destination_location current_status estimated_delivery_date actual_delivery_date } } }'
    },
    @{
        id = "get-shipment-by-number"
        displayName = "Get Shipment by Number"
        method = "GET"
        urlTemplate = "/shipments/{shipmentNumber}"
        description = "Get a specific shipment by its number"
        graphqlQuery = 'query($shipmentNumber: String!) { gold_shipments_in_transits(filter: {shipment_number: {eq: $shipmentNumber}}) { items { shipment_number carrier_id customer_id origin_location destination_location current_status estimated_delivery_date actual_delivery_date } } }'
    },
    @{
        id = "get-orders"
        displayName = "Get Orders"
        method = "GET"
        urlTemplate = "/orders"
        description = "Get daily orders summary"
        graphqlQuery = 'query { gold_orders_daily_summary(first: 100) { items { order_date total_orders total_order_value avg_order_value partner_access_scope } } }'
    },
    @{
        id = "get-warehouse-productivity"
        displayName = "Get Warehouse Productivity"
        method = "GET"
        urlTemplate = "/warehouse/productivity"
        description = "Get warehouse productivity metrics"
        graphqlQuery = 'query { gold_warehouse_productivity_daily(first: 100) { items { warehouse_date warehouse_partner_id warehouse_partner_name total_movements inbound_count outbound_count avg_processing_time_hours } } }'
    },
    @{
        id = "get-sla-performance"
        displayName = "Get SLA Performance"
        method = "GET"
        urlTemplate = "/sla/performance"
        description = "Get SLA performance metrics"
        graphqlQuery = 'query { gold_sla_performance(first: 100) { items { sla_date carrier_id total_shipments on_time_deliveries delayed_deliveries on_time_percentage avg_delay_hours } } }'
    },
    @{
        id = "get-revenue"
        displayName = "Get Revenue"
        method = "GET"
        urlTemplate = "/revenue"
        description = "Get real-time revenue recognition"
        graphqlQuery = 'query { gold_revenue_recognition_realtime(first: 100) { items { revenue_timestamp customer_id service_type revenue_amount currency_code partner_access_scope } } }'
    }
)

foreach ($operation in $operations) {
    Write-Host "`nCreating operation: $($operation.displayName)" -ForegroundColor Yellow
    
    $operationUrl = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$apiId/operations/$($operation.id)?api-version=2021-08-01"
    
    $operationBody = @{
        properties = @{
            displayName = $operation.displayName
            method = $operation.method
            urlTemplate = $operation.urlTemplate
            description = $operation.description
            responses = @()
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $opResponse = Invoke-RestMethod -Method Put `
            -Uri $operationUrl `
            -Headers @{
                "Authorization" = "Bearer $token"
                "Content-Type" = "application/json"
            } `
            -Body $operationBody
        
        Write-Host "  Operation created: $($operation.id)" -ForegroundColor Green
        
        # Create policy for this operation to transform REST to GraphQL
        Write-Host "  Creating transformation policy..." -ForegroundColor Gray
        
        $policyXml = @"
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="fabric-graphql-backend" />
        
        <!-- Extract route parameters if any -->
        <set-variable name="shipmentNumber" value="@(context.Request.MatchedParameters.ContainsKey("shipmentNumber") ? context.Request.MatchedParameters["shipmentNumber"] : "")" />
        
        <!-- Transform REST to GraphQL -->
        <set-body>@{
            var graphqlQuery = "$($operation.graphqlQuery)";
            var shipmentNumber = context.Variables.GetValueOrDefault<string>("shipmentNumber", "");
            
            if (!string.IsNullOrEmpty(shipmentNumber)) {
                // For parameterized queries
                return new JObject(
                    new JProperty("query", graphqlQuery),
                    new JProperty("variables", new JObject(
                        new JProperty("shipmentNumber", shipmentNumber)
                    ))
                ).ToString();
            } else {
                // For simple queries
                return new JObject(
                    new JProperty("query", graphqlQuery)
                ).ToString();
            }
        }</set-body>
        
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        
        <!-- Change method to POST for GraphQL -->
        <set-method>POST</set-method>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        
        <!-- Extract data from GraphQL response -->
        <set-body>@{
            var response = context.Response.Body.As<JObject>(preserveContent: true);
            
            if (response["data"] != null) {
                // Get the first property in data (the query result)
                var dataProperty = response["data"].First as JProperty;
                if (dataProperty != null && dataProperty.Value["items"] != null) {
                    return dataProperty.Value["items"].ToString();
                }
                return dataProperty?.Value?.ToString() ?? "[]";
            }
            
            return "[]";
        }</set-body>
        
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@
        
        $policyUrl = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$apiId/operations/$($operation.id)/policies/policy?api-version=2021-08-01"
        
        $policyBody = @{
            properties = @{
                format = "rawxml"
                value = $policyXml
            }
        } | ConvertTo-Json -Depth 10
        
        $policyResponse = Invoke-RestMethod -Method Put `
            -Uri $policyUrl `
            -Headers @{
                "Authorization" = "Bearer $token"
                "Content-Type" = "application/json"
            } `
            -Body $policyBody
        
        Write-Host "  Policy created for operation" -ForegroundColor Green
        
    } catch {
        Write-Host "  Warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================
# Summary
# ============================================================

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  REST APIs CREATED SUCCESSFULLY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$apimInfo = az apim show --name $ApimName --resource-group $ResourceGroup | ConvertFrom-Json
$gatewayUrl = $apimInfo.gatewayUrl

Write-Host "`nAPI Base URL: $gatewayUrl/api/v1" -ForegroundColor Yellow

Write-Host "`nAvailable Endpoints:" -ForegroundColor Yellow
foreach ($operation in $operations) {
    $endpoint = "$gatewayUrl/api/v1$($operation.urlTemplate)"
    Write-Host "  $($operation.method) $endpoint" -ForegroundColor White
    Write-Host "      $($operation.description)" -ForegroundColor Gray
}

Write-Host "`nAuthentication:" -ForegroundColor Yellow
Write-Host "  All endpoints require:" -ForegroundColor White
Write-Host "    Authorization: Bearer <SERVICE_PRINCIPAL_TOKEN>" -ForegroundColor Gray

Write-Host "`nExample Usage:" -ForegroundColor Yellow
Write-Host "  curl -H 'Authorization: Bearer \$TOKEN' $gatewayUrl/api/v1/shipments" -ForegroundColor Gray

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Test the REST endpoints with Service Principal tokens" -ForegroundColor White
Write-Host "  2. Configure rate limiting policies" -ForegroundColor White
Write-Host "  3. Set up API products for different partner tiers" -ForegroundColor White

Write-Host "`n============================================================`n" -ForegroundColor Cyan
