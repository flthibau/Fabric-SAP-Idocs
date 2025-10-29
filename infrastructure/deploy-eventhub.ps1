# Deploy Azure Event Hub for SAP IDoc Simulator
# This script creates all necessary Azure resources for the IDoc streaming solution

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-idoc-fabric-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubNamespace = "eh-idoc-fabric-dev-$(Get-Random -Maximum 9999)",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubName = "idoc-events",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "f79d4407-99c6-4d64-88fc-848fb05d5476"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Event Hub Deployment for SAP IDoc" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription
Write-Host "Setting active subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to set subscription" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Subscription set: $SubscriptionId" -ForegroundColor Green
Write-Host ""

# Create Resource Group
Write-Host "Creating resource group: $ResourceGroup in $Location..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "✓ Resource group already exists: $ResourceGroup" -ForegroundColor Green
}
else {
    az group create --name $ResourceGroup --location $Location --output table
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to create resource group" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Resource group created: $ResourceGroup" -ForegroundColor Green
}
Write-Host ""

# Create Event Hubs Namespace
Write-Host "Creating Event Hubs namespace: $EventHubNamespace..." -ForegroundColor Yellow
Write-Host "  - SKU: Standard" -ForegroundColor Gray
Write-Host "  - Capacity: 2 Throughput Units" -ForegroundColor Gray
Write-Host "  - Location: $Location" -ForegroundColor Gray

az eventhubs namespace create --name $EventHubNamespace --resource-group $ResourceGroup --location $Location --sku Standard --capacity 2 --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create Event Hubs namespace" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Event Hubs namespace created: $EventHubNamespace" -ForegroundColor Green
Write-Host ""

# Create Event Hub
Write-Host "Creating Event Hub: $EventHubName..." -ForegroundColor Yellow
Write-Host "  - Partitions: 4" -ForegroundColor Gray
Write-Host "  - Retention: 7 days (168 hours)" -ForegroundColor Gray

az eventhubs eventhub create --name $EventHubName --namespace-name $EventHubNamespace --resource-group $ResourceGroup --partition-count 4 --message-retention 7 --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create Event Hub" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Event Hub created: $EventHubName" -ForegroundColor Green
Write-Host ""

# Create Shared Access Policy for Simulator (Send only)
Write-Host "Creating Shared Access Policy: simulator-send..." -ForegroundColor Yellow
az eventhubs eventhub authorization-rule create --name "simulator-send" --eventhub-name $EventHubName --namespace-name $EventHubNamespace --resource-group $ResourceGroup --rights Send --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create shared access policy" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Shared Access Policy created: simulator-send (Send rights)" -ForegroundColor Green
Write-Host ""

# Create Shared Access Policy for Fabric (Listen only)
Write-Host "Creating Shared Access Policy: fabric-listen..." -ForegroundColor Yellow
az eventhubs eventhub authorization-rule create --name "fabric-listen" --eventhub-name $EventHubName --namespace-name $EventHubNamespace --resource-group $ResourceGroup --rights Listen --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Failed to create fabric-listen policy (may already exist)" -ForegroundColor Yellow
}
Write-Host "✓ Shared Access Policy created: fabric-listen (Listen rights)" -ForegroundColor Green
Write-Host ""

# Get Connection Strings
Write-Host "Retrieving connection strings..." -ForegroundColor Yellow

$sendConnectionString = az eventhubs eventhub authorization-rule keys list --name "simulator-send" --eventhub-name $EventHubName --namespace-name $EventHubNamespace --resource-group $ResourceGroup --query primaryConnectionString --output tsv

$listenConnectionString = az eventhubs eventhub authorization-rule keys list --name "fabric-listen" --eventhub-name $EventHubName --namespace-name $EventHubNamespace --resource-group $ResourceGroup --query primaryConnectionString --output tsv

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Resource Group: " -NoNewline -ForegroundColor Yellow
Write-Host $ResourceGroup -ForegroundColor White

Write-Host "Event Hub Namespace: " -NoNewline -ForegroundColor Yellow
Write-Host $EventHubNamespace -ForegroundColor White

Write-Host "Event Hub Name: " -NoNewline -ForegroundColor Yellow
Write-Host $EventHubName -ForegroundColor White

Write-Host "Location: " -NoNewline -ForegroundColor Yellow
Write-Host $Location -ForegroundColor White

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connection Strings" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Simulator (Send):" -ForegroundColor Yellow
Write-Host $sendConnectionString -ForegroundColor Gray
Write-Host ""

Write-Host "Fabric (Listen):" -ForegroundColor Yellow
Write-Host $listenConnectionString -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Copy the Simulator connection string to your .env file:" -ForegroundColor White
Write-Host "   cd simulator" -ForegroundColor Gray
Write-Host "   copy .env.example .env" -ForegroundColor Gray
Write-Host "   # Edit .env and paste the Simulator connection string" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Install Python dependencies:" -ForegroundColor White
Write-Host "   python -m venv venv" -ForegroundColor Gray
Write-Host "   .\venv\Scripts\Activate.ps1" -ForegroundColor Gray
Write-Host "   pip install -r requirements.txt" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Run the simulator:" -ForegroundColor White
Write-Host "   python main.py" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Configure Fabric Eventstream with the Listen connection string" -ForegroundColor White
Write-Host ""

# Save connection strings to file
$outputFile = "eventhub-connection-strings.txt"
$outputContent = @"
Azure Event Hub Deployment - Connection Strings
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Resource Group: $ResourceGroup
Event Hub Namespace: $EventHubNamespace
Event Hub Name: $EventHubName
Location: $Location

SIMULATOR CONNECTION STRING (Send only):
$sendConnectionString

FABRIC CONNECTION STRING (Listen only):
$listenConnectionString

"@

$outputContent | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Connection strings saved to: $outputFile" -ForegroundColor Green
Write-Host ""

# Create .env file template in simulator folder
$envFile = "..\..\simulator\.env"
if (-not (Test-Path $envFile)) {
    $envContent = @"
# Azure Event Hub Configuration
EVENT_HUB_CONNECTION_STRING=$sendConnectionString
EVENT_HUB_NAME=$EventHubName

# SAP Configuration
SAP_SYSTEM_ID=S4HPRD
SAP_CLIENT=100
SAP_SENDER=3PLSYSTEM

# Simulator Settings
MESSAGE_RATE=10
BATCH_SIZE=100
RUN_DURATION_SECONDS=3600

# Master Data Configuration
WAREHOUSE_COUNT=5
CUSTOMER_COUNT=100
CARRIER_COUNT=20

# Logging
LOG_LEVEL=INFO
"@
    
    $envContent | Out-File -FilePath $envFile -Encoding UTF8
    Write-Host ".env file created in simulator folder!" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Deployment completed successfully! 🎉" -ForegroundColor Green
