<#
.SYNOPSIS
    Deploy Azure API Management for 3PL Partner API

.DESCRIPTION
    Automates the deployment of Azure APIM instance with:
    - Developer SKU APIM instance
    - GraphQL passthrough API
    - REST transformation policies
    - OAuth 2.0 configuration
    - Rate limiting policies
    - Partner app registrations in Azure AD

.PARAMETER ResourceGroup
    Name of the Azure Resource Group

.PARAMETER Location
    Azure region (default: westeurope)

.PARAMETER ApimName
    Name for the APIM instance (must be globally unique)

.PARAMETER FabricGraphQLEndpoint
    URL of the Fabric GraphQL endpoint

.PARAMETER TenantId
    Azure AD Tenant ID

.EXAMPLE
    .\deploy-apim.ps1 `
        -ResourceGroup "rg-3pl-partner-api" `
        -Location "westeurope" `
        -ApimName "apim-3pl-flt" `
        -FabricGraphQLEndpoint "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql" `
        -TenantId "38de1b20-8309-40ba-9584-5d9fcb7203b4"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westeurope",
    
    [Parameter(Mandatory=$true)]
    [string]$ApimName,
    
    [Parameter(Mandatory=$true)]
    [string]$FabricGraphQLEndpoint,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId
)

$ErrorActionPreference = "Stop"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  AZURE APIM DEPLOYMENT FOR 3PL PARTNER API" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# Configuration
$PublisherEmail = "admin@3pl-logistics.com"
$PublisherName = "3PL Logistics Operations"
$Sku = "Developer"
$ApiPath = "api/v1"
$GraphQLPath = "graphql"

Write-Host "`n📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  APIM Name: $ApimName" -ForegroundColor White
Write-Host "  SKU: $Sku" -ForegroundColor White
Write-Host "  Fabric GraphQL: $FabricGraphQLEndpoint" -ForegroundColor White

# Step 1: Check if logged in
Write-Host "`n🔐 Step 1: Checking Azure login..." -ForegroundColor Cyan
try {
    $context = az account show 2>$null | ConvertFrom-Json
    Write-Host "  ✓ Logged in as: $($context.user.name)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Not logged in. Running az login..." -ForegroundColor Yellow
    az login --tenant $TenantId
}

# Step 2: Create Resource Group
Write-Host "`n🏗️ Step 2: Creating Resource Group..." -ForegroundColor Cyan
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "  ✓ Resource group already exists" -ForegroundColor Green
} else {
    az group create --name $ResourceGroup --location $Location
    Write-Host "  ✓ Resource group created" -ForegroundColor Green
}

# Step 3: Deploy APIM Instance
Write-Host "`n🚀 Step 3: Deploying APIM Instance..." -ForegroundColor Cyan
Write-Host "  ⏳ This may take 30-45 minutes..." -ForegroundColor Yellow

$apimExists = az apim show --name $ApimName --resource-group $ResourceGroup 2>$null
if ($apimExists) {
    Write-Host "  ✓ APIM instance already exists" -ForegroundColor Green
} else {
    az apim create `
        --name $ApimName `
        --resource-group $ResourceGroup `
        --location $Location `
        --publisher-email $PublisherEmail `
        --publisher-name $PublisherName `
        --sku-name $Sku `
        --no-wait
    
    Write-Host "  APIM deployment initiated (running in background)" -ForegroundColor Green
    Write-Host "  Check deployment status:" -ForegroundColor Yellow
    Write-Host "     az apim show --name $ApimName --resource-group $ResourceGroup --query provisioningState" -ForegroundColor Gray
}

# Step 4: Wait for APIM to be ready (if just created)
if (-not $apimExists) {
    Write-Host "`nStep 4: Waiting for APIM provisioning..." -ForegroundColor Cyan
    Write-Host "  This will check every 2 minutes..." -ForegroundColor Yellow
    
    $maxAttempts = 30
    $attempt = 0
    $provisioningState = "Creating"
    
    while ($provisioningState -ne "Succeeded" -and $attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 120
        $attempt++
        
        $apimStatus = az apim show --name $ApimName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        $provisioningState = $apimStatus.provisioningState
        
        Write-Host "  Attempt $attempt/$maxAttempts - State: $provisioningState" -ForegroundColor Gray
    }
    
    if ($provisioningState -eq "Succeeded") {
        Write-Host "  APIM provisioning completed" -ForegroundColor Green
    } else {
        Write-Host "  APIM provisioning still in progress. Continue manually." -ForegroundColor Yellow
        Write-Host "  Run this script again once APIM is ready." -ForegroundColor Yellow
        exit 0
    }
}

# Step 5: Get APIM Gateway URL
Write-Host "`n🌐 Step 5: Getting APIM Gateway URL..." -ForegroundColor Cyan
$apimDetails = az apim show --name $ApimName --resource-group $ResourceGroup | ConvertFrom-Json
$gatewayUrl = $apimDetails.gatewayUrl
Write-Host "  Gateway URL: $gatewayUrl" -ForegroundColor White

# Step 6: Create Backend for Fabric GraphQL
Write-Host "`n🔗 Step 6: Creating Backend for Fabric GraphQL..." -ForegroundColor Cyan
az apim backend create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --backend-id "fabric-graphql-backend" `
    --url $FabricGraphQLEndpoint `
    --protocol "http" `
    --description "Fabric GraphQL Endpoint for 3PL Data Product"

Write-Host "  ✓ Backend created" -ForegroundColor Green

# Step 7: Create GraphQL Passthrough API
Write-Host "`n📡 Step 7: Creating GraphQL API..." -ForegroundColor Cyan

# Create API definition JSON
$apiDefinition = @{
    properties = @{
        displayName = "3PL Partner GraphQL API"
        path = $GraphQLPath
        protocols = @("https")
        serviceUrl = $FabricGraphQLEndpoint
        description = "GraphQL API for 3PL logistics partners (carriers, warehouses, customers)"
        subscriptionRequired = $true
        isCurrent = $true
    }
} | ConvertTo-Json -Depth 10

$apiDefinitionPath = "temp_graphql_api_def.json"
$apiDefinition | Out-File -FilePath $apiDefinitionPath -Encoding UTF8

az apim api create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "graphql-partner-api" `
    --path $GraphQLPath `
    --display-name "3PL Partner GraphQL API" `
    --protocols "https" `
    --service-url $FabricGraphQLEndpoint `
    --subscription-required true

Remove-Item $apiDefinitionPath -Force

Write-Host "  ✓ GraphQL API created" -ForegroundColor Green

# Step 8: Create REST API
Write-Host "`n📡 Step 8: Creating REST API..." -ForegroundColor Cyan

az apim api create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --path $ApiPath `
    --display-name "3PL Partner REST API" `
    --protocols "https" `
    --service-url $FabricGraphQLEndpoint `
    --subscription-required true

Write-Host "  ✓ REST API created" -ForegroundColor Green

# Step 9: Create Operations for REST API
Write-Host "`n🔧 Step 9: Creating REST API Operations..." -ForegroundColor Cyan

# Shipments
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-shipments" `
    --display-name "Get Shipments" `
    --method "GET" `
    --url-template "/shipments"

az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-shipment-by-number" `
    --display-name "Get Shipment by Number" `
    --method "GET" `
    --url-template "/shipments/{shipmentNumber}"

# Orders
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-orders" `
    --display-name "Get Orders" `
    --method "GET" `
    --url-template "/orders"

# Warehouse
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-warehouse-movements" `
    --display-name "Get Warehouse Movements" `
    --method "GET" `
    --url-template "/warehouse/movements"

# Invoices
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-invoices" `
    --display-name "Get Invoices" `
    --method "GET" `
    --url-template "/invoices"

# KPIs
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "rest-partner-api" `
    --operation-id "get-kpis" `
    --display-name "Get KPIs" `
    --method "GET" `
    --url-template "/kpis/{metric}"

Write-Host "  ✓ REST operations created" -ForegroundColor Green

# Step 10: Apply Policies
Write-Host "`n📜 Step 10: Applying APIM Policies..." -ForegroundColor Cyan
Write-Host "  ⚠ Policies must be applied manually via Azure Portal for now" -ForegroundColor Yellow
Write-Host "  Policy files location: api/apim/policies/" -ForegroundColor Gray

# Step 11: Create Products (API tiers)
Write-Host "`n📦 Step 11: Creating API Products..." -ForegroundColor Cyan

# Standard tier (default for partners)
az apim product create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-standard" `
    --product-name "Partner Standard" `
    --description "Standard tier for 3PL partners (60 req/min)" `
    --subscription-required true `
    --approval-required true `
    --subscriptions-limit 100 `
    --state "published"

# Premium tier
az apim product create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-premium" `
    --product-name "Partner Premium" `
    --description "Premium tier for high-volume partners (300 req/min)" `
    --subscription-required true `
    --approval-required true `
    --subscriptions-limit 20 `
    --state "published"

Write-Host "  ✓ Products created" -ForegroundColor Green

# Step 12: Add APIs to Products
Write-Host "`n🔗 Step 12: Linking APIs to Products..." -ForegroundColor Cyan

az apim product api add `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-standard" `
    --api-id "graphql-partner-api"

az apim product api add `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-standard" `
    --api-id "rest-partner-api"

az apim product api add `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-premium" `
    --api-id "graphql-partner-api"

az apim product api add `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --product-id "partner-premium" `
    --api-id "rest-partner-api"

Write-Host "  ✓ APIs linked to products" -ForegroundColor Green

# Summary
Write-Host "`n================================================================================" -ForegroundColor Green
Write-Host "  APIM DEPLOYMENT COMPLETED" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green

Write-Host "`n📊 Deployment Summary:" -ForegroundColor Cyan
Write-Host "  APIM Name: $ApimName" -ForegroundColor White
Write-Host "  Gateway URL: $gatewayUrl" -ForegroundColor White
Write-Host "  GraphQL Endpoint: $gatewayUrl/$GraphQLPath" -ForegroundColor White
Write-Host "  REST Endpoint: $gatewayUrl/$ApiPath" -ForegroundColor White

Write-Host "`n📡 APIs Created:" -ForegroundColor Cyan
Write-Host "  • GraphQL Partner API (passthrough)" -ForegroundColor Green
Write-Host "  • REST Partner API (transformation)" -ForegroundColor Green

Write-Host "`n📦 Products Created:" -ForegroundColor Cyan
Write-Host "  • Partner Standard (60 req/min)" -ForegroundColor Green
Write-Host "  • Partner Premium (300 req/min)" -ForegroundColor Green

Write-Host "`n🔧 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Apply policies manually in Azure Portal:" -ForegroundColor Yellow
Write-Host "     - OAuth validation (api/apim/policies/oauth-validation.xml)" -ForegroundColor Gray
Write-Host "     - Rate limiting (api/apim/policies/rate-limiting.xml)" -ForegroundColor Gray
Write-Host "     - GraphQL to REST transform (api/apim/policies/graphql-to-rest.xml)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Create partner subscriptions:" -ForegroundColor Yellow
Write-Host "     az apim product subscription create ..." -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Configure OAuth 2.0 in Azure AD:" -ForegroundColor Yellow
Write-Host "     Run: .\create-partner-apps.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Test the API:" -ForegroundColor Yellow
Write-Host "     Import Postman collection: api/graphql/postman/partner-api-collection.json" -ForegroundColor Gray

Write-Host "`n🌐 Azure Portal Links:" -ForegroundColor Cyan
Write-Host "  APIM: https://portal.azure.com/#resource/subscriptions/.../resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName" -ForegroundColor White
Write-Host "  Developer Portal: https://$ApimName.developer.azure-api.net" -ForegroundColor White

Write-Host "`n================================================================================" -ForegroundColor Green
