# Environment Setup Guide

This guide walks you through setting up your complete environment for the Microsoft Fabric SAP IDoc Workshop.

## 📋 Overview

You'll configure:
1. Azure resources (Event Hub, Resource Group, optional APIM)
2. Microsoft Fabric workspace and resources
3. Local development environment
4. Workshop repository and dependencies

**Estimated Time**: 90 minutes

---

## Part 1: Azure Resources Setup (30 minutes)

### Step 1.1: Create Resource Group

All Azure resources will be organized in a single Resource Group.

```powershell
# Set variables
$resourceGroup = "rg-fabric-sap-workshop"
$location = "eastus"  # Change to your preferred region

# Login to Azure (if not already logged in)
az login

# Set subscription (if you have multiple)
az account list --output table
az account set --subscription "Your-Subscription-Name"

# Create resource group
az group create `
  --name $resourceGroup `
  --location $location

# Verify creation
az group show --name $resourceGroup
```

**Expected Output:**
```json
{
  "id": "/subscriptions/.../resourceGroups/rg-fabric-sap-workshop",
  "location": "eastus",
  "name": "rg-fabric-sap-workshop",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

---

### Step 1.2: Create Event Hub Namespace

Event Hubs will receive SAP IDoc messages from the simulator.

```powershell
# Set variables
$eventhubNamespace = "eh-idoc-workshop-$(Get-Random -Maximum 9999)"
$eventHubName = "idoc-events"

# Create Event Hub Namespace (Standard tier)
az eventhubs namespace create `
  --resource-group $resourceGroup `
  --name $eventhubNamespace `
  --location $location `
  --sku Standard `
  --capacity 1

# Wait for namespace to be ready
Start-Sleep -Seconds 30

# Create Event Hub instance
az eventhubs eventhub create `
  --resource-group $resourceGroup `
  --namespace-name $eventhubNamespace `
  --name $eventHubName `
  --partition-count 4 `
  --message-retention 7

# Get connection string
$connectionString = az eventhubs namespace authorization-rule keys list `
  --resource-group $resourceGroup `
  --namespace-name $eventhubNamespace `
  --name RootManageSharedAccessKey `
  --query primaryConnectionString `
  --output tsv

Write-Host "✅ Event Hub Created!" -ForegroundColor Green
Write-Host "Namespace: $eventhubNamespace"
Write-Host "Event Hub: $eventHubName"
Write-Host "Connection String: $connectionString"

# Save connection string for later
$connectionString | Out-File -FilePath "eventhub-connection.txt"
```

**Important**: Keep the connection string safe! You'll need it for the IDoc simulator.

---

### Step 1.3: Configure Event Hub for Fabric

Enable Entra ID authentication for Fabric Eventstream connection.

```powershell
# Get your user principal ID
$userPrincipalId = az ad signed-in-user show --query id -o tsv

# Assign Azure Event Hubs Data Receiver role to yourself
az role assignment create `
  --role "Azure Event Hubs Data Receiver" `
  --assignee $userPrincipalId `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$resourceGroup/providers/Microsoft.EventHub/namespaces/$eventhubNamespace"

# Assign Data Sender role (for simulator)
az role assignment create `
  --role "Azure Event Hubs Data Sender" `
  --assignee $userPrincipalId `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$resourceGroup/providers/Microsoft.EventHub/namespaces/$eventhubNamespace"

Write-Host "✅ Event Hub permissions configured!" -ForegroundColor Green
```

---

### Step 1.4: (Optional) Deploy Azure API Management

**Note**: This step is optional and only needed for Module 6 (API Development). You can skip this for now and return later.

```powershell
# OPTIONAL - Skip if not doing Module 6 immediately

$apimName = "apim-3pl-workshop-$(Get-Random -Maximum 9999)"
$publisherEmail = "your-email@example.com"  # Change this
$publisherName = "Your Name"                 # Change this

# Deploy APIM (Consumption tier - cheapest)
az apim create `
  --resource-group $resourceGroup `
  --name $apimName `
  --publisher-email $publisherEmail `
  --publisher-name $publisherName `
  --sku-name Consumption `
  --location $location

# Note: APIM deployment takes 30-40 minutes
# You can continue with other steps while it deploys
```

**Estimated Cost**: 
- Consumption tier: ~$3-5/month (pay-per-use)
- Standard tier: ~$700/month (not recommended for workshop)

---

## Part 2: Microsoft Fabric Setup (45 minutes)

### Step 2.1: Create Fabric Workspace

1. **Navigate to Fabric Portal**
   - Open: https://app.fabric.microsoft.com
   - Sign in with your Azure AD account

2. **Activate Fabric Trial** (if needed)
   - Click your profile icon (top right)
   - Click "Start trial"
   - Follow the prompts
   - Trial is free for 60 days

3. **Create New Workspace**
   - Click "Workspaces" in left navigation
   - Click "+ New workspace"
   - Enter name: `SAP-IDoc-Workshop`
   - Description: `Workshop for SAP IDoc real-time data product`
   - Click "Advanced" to expand options

4. **Configure Workspace Settings**
   - **License mode**: Trial (or Premium if you have capacity)
   - **Default storage format**: Small dataset format
   - Click "Apply"

5. **Verify Workspace Creation**
   - You should see the empty workspace
   - Note the workspace ID from URL

**Workspace URL Format:**
```
https://app.fabric.microsoft.com/groups/{workspace-id}/
```

Save the workspace ID for later use.

---

### Step 2.2: Create Eventhouse (Real-Time Intelligence)

1. **In your workspace**, click "+ New item"

2. **Select "Eventhouse"** (under Real-Time Intelligence)

3. **Configure Eventhouse**
   - Name: `kql-3pl-logistics`
   - Click "Create"
   - Wait for provisioning (1-2 minutes)

4. **Create KQL Database**
   - Eventhouse will prompt to create a database
   - Database name: `sapidoc` (lowercase, no hyphens)
   - Click "Create"

5. **Verify Database Creation**
   - You should see the database in the Eventhouse
   - Click on it to open the query editor

---

### Step 2.3: Create Fabric Eventstream

1. **In your workspace**, click "+ New item"

2. **Select "Eventstream"** (under Real-Time Intelligence)

3. **Configure Eventstream**
   - Name: `idoc-ingestion-stream`
   - Click "Create"

4. **Configure Source: Azure Event Hubs**
   - Click "+ Add source" → "Azure Event Hubs"
   - **Connection type**: "Cloud connection"
   - **Subscription**: Select your Azure subscription
   - **Resource group**: `rg-fabric-sap-workshop`
   - **Event Hub namespace**: Your namespace from Step 1.2
   - **Event Hub**: `idoc-events`
   - **Consumer group**: `$Default`
   - Click "Next"
   - Review and "Add"

5. **Configure Destination: KQL Database**
   - Click "+ Add destination" → "KQL Database"
   - **Workspace**: Current workspace
   - **KQL Database**: `sapidoc`
   - **Destination table**: Create new → `idoc_raw`
   - **Input data format**: JSON
   - Click "Next"
   - Review and "Add"

6. **Start Eventstream**
   - Click "Publish" to activate the stream
   - Verify status shows "Running"

**Tip**: The Eventstream visualization shows data flow. You'll see it populate once the simulator sends messages.

---

### Step 2.4: Create Lakehouse

1. **In your workspace**, click "+ New item"

2. **Select "Lakehouse"** (under Data Engineering)

3. **Configure Lakehouse**
   - Name: `lakehouse_3pl`
   - Click "Create"
   - Wait for provisioning (30 seconds)

4. **Verify Lakehouse Structure**
   - You should see three sections:
     - **Tables** (Delta Lake tables)
     - **Files** (unstructured data)
     - **Shortcuts** (external data references)

5. **Create Folder Structure**
   - In "Files" section, create folders:
     - `bronze/` - Raw IDoc data
     - `silver/` - Cleaned and normalized
     - `gold/` - Business aggregations

**Note**: We'll populate the Lakehouse with data in Module 4.

---

### Step 2.5: Create Warehouse (Optional)

The Warehouse provides SQL endpoint for OneLake Security (RLS) configuration.

1. **In your workspace**, click "+ New item"

2. **Select "Warehouse"** (under Data Warehouse)

3. **Configure Warehouse**
   - Name: `warehouse_3pl`
   - Click "Create"

4. **Verify Creation**
   - Warehouse should open with SQL query editor
   - Note: Tables will be created via Lakehouse mirroring

---

## Part 3: Local Development Environment (15 minutes)

### Step 3.1: Clone Repository

```bash
# Navigate to your development folder
cd ~/Documents  # Windows
# OR
cd ~/projects  # Mac/Linux

# Clone the repository
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git

# Navigate to repository
cd Fabric-SAP-Idocs

# Verify structure
ls -la
```

**Expected Folders:**
```
.
├── api/
├── demo-app/
├── fabric/
├── simulator/
├── workshop/     ← You are here!
├── README.md
└── ...
```

---

### Step 3.2: Configure IDoc Simulator

1. **Navigate to simulator directory**
   ```bash
   cd simulator
   ```

2. **Create Python virtual environment**
   ```bash
   # Create venv
   python -m venv venv

   # Activate (Windows PowerShell)
   .\venv\Scripts\Activate.ps1

   # Activate (Mac/Linux)
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Configure Event Hub connection**
   ```bash
   # Copy example configuration
   cp .env.example .env

   # Edit .env file
   # Add your Event Hub connection string from Step 1.2
   ```

   **.env file content:**
   ```bash
   # Azure Event Hub Configuration
   EVENT_HUB_CONNECTION_STRING=Endpoint=sb://eh-idoc-workshop-XXXX.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY_HERE
   EVENT_HUB_NAME=idoc-events

   # Simulator Configuration
   IDOC_GENERATION_RATE=100  # messages per minute
   IDOC_TYPES=ORDERS,SHPMNT,DESADV,WHSCON,INVOIC
   ```

5. **Test simulator (dry run)**
   ```bash
   python main.py --dry-run --count 5
   ```

   **Expected Output:**
   ```
   Generated 5 IDoc messages (dry run)
   - ORDERS: 2
   - SHPMNT: 2
   - DESADV: 1
   ```

---

### Step 3.3: Configure PowerShell Scripts

1. **Navigate to api/scripts directory**
   ```powershell
   cd ../api/scripts
   ```

2. **Review available scripts**
   ```powershell
   Get-ChildItem *.ps1 | Select-Object Name
   ```

   **Key scripts:**
   - `create-partner-apps.ps1` - Create Service Principals
   - `grant-sp-workspace-access.ps1` - Grant Fabric access
   - `configure-and-test-apim.ps1` - Setup APIM
   - `test-graphql-rls.ps1` - Test RLS filtering

3. **Update configuration file**
   ```powershell
   # Copy example
   Copy-Item partner-apps-credentials.example.json partner-apps-credentials.json

   # Edit with your values
   notepad partner-apps-credentials.json
   ```

   **Update these values:**
   ```json
   {
     "tenantId": "your-tenant-id",
     "workspaceId": "your-workspace-id-from-step-2.1",
     "fabricApi": "https://api.fabric.microsoft.com/v1"
   }
   ```

---

## Part 4: Verification and Testing (10 minutes)

### Step 4.1: Test Event Hub Connectivity

```powershell
# Navigate to simulator
cd ../../simulator

# Activate venv
.\venv\Scripts\Activate.ps1

# Send test message
python main.py --count 1

# Expected output:
# ✅ Sent 1 IDoc messages to Event Hub
# Rate: ~10 msg/sec
```

---

### Step 4.2: Verify Eventstream Ingestion

1. **Open Fabric Portal**
   - Navigate to your workspace
   - Open `idoc-ingestion-stream`

2. **Check Data Flow**
   - You should see data flowing from source to destination
   - Click on "Data preview" to see messages

3. **Verify KQL Table**
   - Open `sapidoc` KQL database
   - Run query:
     ```kql
     idoc_raw
     | take 10
     ```
   - You should see your test message

---

### Step 4.3: Verify Lakehouse Access

1. **Open Fabric Portal**
   - Navigate to your workspace
   - Open `lakehouse_3pl`

2. **Check Folders**
   - Verify `bronze/`, `silver/`, `gold/` folders exist
   - Currently empty - will populate in Module 4

---

### Step 4.4: Environment Summary

Run this verification script:

```powershell
# Save as: verify-environment.ps1

Write-Host "🔍 Verifying Workshop Environment..." -ForegroundColor Cyan

# Azure Resources
Write-Host "`n--- Azure Resources ---" -ForegroundColor Yellow
az group show --name rg-fabric-sap-workshop --query "{Name:name, State:properties.provisioningState}" -o table

az eventhubs namespace list --resource-group rg-fabric-sap-workshop --query "[].{Name:name, State:provisioningState}" -o table

# Fabric Workspace (manual check)
Write-Host "`n--- Fabric Workspace ---" -ForegroundColor Yellow
Write-Host "✓ Manually verify in Fabric Portal:"
Write-Host "  - Workspace: SAP-IDoc-Workshop"
Write-Host "  - Eventhouse: kql-3pl-logistics"
Write-Host "  - Eventstream: idoc-ingestion-stream"
Write-Host "  - Lakehouse: lakehouse_3pl"

# Local Setup
Write-Host "`n--- Local Environment ---" -ForegroundColor Yellow
if (Test-Path "../simulator/venv") {
    Write-Host "✅ Python venv created" -ForegroundColor Green
} else {
    Write-Host "❌ Python venv missing" -ForegroundColor Red
}

if (Test-Path "../simulator/.env") {
    Write-Host "✅ Simulator .env configured" -ForegroundColor Green
} else {
    Write-Host "❌ Simulator .env missing" -ForegroundColor Red
}

Write-Host "`n✅ Environment check complete!" -ForegroundColor Cyan
```

---

## 🎯 Environment Setup Checklist

Mark off each item as you complete it:

### Azure Resources
- [ ] Resource Group created (`rg-fabric-sap-workshop`)
- [ ] Event Hub Namespace created
- [ ] Event Hub `idoc-events` created
- [ ] Event Hub connection string saved
- [ ] Entra ID permissions configured
- [ ] (Optional) APIM deployed

### Microsoft Fabric
- [ ] Fabric trial activated (or capacity assigned)
- [ ] Workspace created (`SAP-IDoc-Workshop`)
- [ ] Workspace ID saved
- [ ] Eventhouse created (`kql-3pl-logistics`)
- [ ] KQL Database created (`sapidoc`)
- [ ] Eventstream created (`idoc-ingestion-stream`)
- [ ] Eventstream connected (Event Hub → KQL)
- [ ] Eventstream published and running
- [ ] Lakehouse created (`lakehouse_3pl`)
- [ ] Lakehouse folder structure created
- [ ] (Optional) Warehouse created

### Local Development
- [ ] Repository cloned
- [ ] Python venv created in simulator/
- [ ] Python dependencies installed
- [ ] simulator/.env configured
- [ ] Test message sent successfully
- [ ] PowerShell scripts reviewed
- [ ] Configuration files updated

### Verification
- [ ] Test IDoc sent to Event Hub
- [ ] Message appears in Eventstream preview
- [ ] Message ingested to KQL table
- [ ] Can query `idoc_raw` table
- [ ] All Fabric resources accessible

---

## 🚀 Next Steps

**Congratulations!** Your environment is ready for the workshop modules.

➡️ Start learning: [Module 1 - Architecture Overview](../labs/module1-architecture.md)

---

## 🆘 Troubleshooting

### Issue: Event Hub Creation Failed

**Error**: "Namespace name not available"

**Solution:**
```powershell
# Use a more unique name
$eventhubNamespace = "eh-idoc-$(Get-Random -Minimum 10000 -Maximum 99999)"
```

---

### Issue: Fabric Trial Not Available

**Error**: "Trial not available in your region/tenant"

**Solution:**
1. Check if your admin has disabled Fabric trials
2. Ask for access to a Fabric capacity instead
3. Try a different browser/incognito mode

---

### Issue: Eventstream Won't Connect

**Error**: "Failed to connect to Event Hub"

**Solution:**
1. Verify Event Hub namespace and name are correct
2. Check you have "Azure Event Hubs Data Receiver" role
3. Try recreating the Eventstream connection
4. Check firewall rules in Event Hub namespace

---

### Issue: Python Dependencies Install Fails

**Error**: Various pip install errors

**Solution:**
```bash
# Upgrade pip first
python -m pip install --upgrade pip setuptools wheel

# Install with no-cache
pip install --no-cache-dir -r requirements.txt

# For SSL errors
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt
```

---

## 📞 Getting Help

If you're stuck during setup:

1. **Review error messages** carefully
2. **Check Azure Portal** → Activity Log for resource deployment issues
3. **Verify permissions** in Azure AD and Fabric
4. **Ask for help**:
   - GitHub Issues: [Report setup issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
   - Include error messages and steps attempted

---

**Environment Setup Complete! Ready to Learn! 🎉**

**Last Updated**: November 2024  
**Version**: 1.0
