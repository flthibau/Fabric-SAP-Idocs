# Azure Event Hub Setup Guide

This guide provides step-by-step instructions for creating and configuring Azure Event Hub for the SAP IDoc simulator.

## Prerequisites

- Azure Subscription
- Azure CLI installed (optional, for CLI method)
- Owner or Contributor role on the subscription

## Method 1: Azure Portal (Recommended for First-Time Setup)

### Step 1: Create Event Hubs Namespace

1. **Sign in to Azure Portal**
   - Navigate to https://portal.azure.com

2. **Create Resource**
   - Click "+ Create a resource"
   - Search for "Event Hubs"
   - Click "Create"

3. **Configure Namespace**
   ```
   Subscription: [Your subscription]
   Resource Group: [Create new] "rg-idoc-fabric-dev"
   Namespace name: "eh-idoc-fabric-dev-001" (must be globally unique)
   Location: [Choose region closest to you, e.g., "East US"]
   Pricing tier: "Standard" (recommended)
   Throughput units: 2 (for dev/test) or 5-10 (for production)
   
   Enable Auto-Inflate: Yes (optional, for automatic scaling)
   Maximum throughput units: 10 (if auto-inflate enabled)
   ```

4. **Review + Create**
   - Click "Review + create"
   - Click "Create"
   - Wait 2-3 minutes for deployment

### Step 2: Create Event Hub

1. **Navigate to Namespace**
   - Go to "Event Hubs Namespaces"
   - Click on your namespace (e.g., "eh-idoc-fabric-dev-001")

2. **Create Event Hub**
   - Click "+ Event Hub" at the top
   
3. **Configure Event Hub**
   ```
   Name: "idoc-events"
   Partition count: 4 (for dev/test) or 8-32 (for production)
   Message retention: 7 days (maximum for Standard tier)
   
   Capture: Disabled (we'll use Fabric Eventstream instead)
   ```

4. **Create**
   - Click "Create"

### Step 3: Create Shared Access Policy

1. **Navigate to Event Hub**
   - Click on "idoc-events" (your Event Hub)

2. **Shared Access Policies**
   - Click "Shared access policies" in left menu
   - Click "+ Add"

3. **Create Policy for Simulator (Send)**
   ```
   Policy name: "simulator-send"
   Permissions: ☑ Send
   ```
   - Click "Create"

4. **Create Policy for Fabric (Listen)**
   ```
   Policy name: "fabric-listen"
   Permissions: ☑ Listen
   ```
   - Click "Create"

### Step 4: Get Connection String

1. **Open Simulator Policy**
   - Click on "simulator-send" policy
   
2. **Copy Connection String**
   - Copy "Connection string–primary key"
   - It looks like:
   ```
   Endpoint=sb://eh-idoc-fabric-dev-001.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=xxxxxxxxxxxxxxxxxxxxx;EntityPath=idoc-events
   ```

3. **Save for Configuration**
   - Keep this for your `.env` file

### Step 5: Configure Simulator

1. **Update .env File**
   ```ini
   EVENT_HUB_CONNECTION_STRING=Endpoint=sb://eh-idoc-fabric-dev-001.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=YOUR_KEY_HERE;EntityPath=idoc-events
   EVENT_HUB_NAME=idoc-events
   ```

2. **Test Connection**
   ```powershell
   cd simulator
   python main.py
   ```

---

## Method 2: Azure CLI (For Automation)

### Step 1: Login to Azure

```bash
az login
az account set --subscription "Your Subscription Name"
```

### Step 2: Create Resource Group

```bash
az group create \
  --name rg-idoc-fabric-dev \
  --location eastus
```

### Step 3: Create Event Hubs Namespace

```bash
az eventhubs namespace create \
  --name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --location eastus \
  --sku Standard \
  --capacity 2
```

### Step 4: Create Event Hub

```bash
az eventhubs eventhub create \
  --name idoc-events \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --partition-count 4 \
  --message-retention 7
```

### Step 5: Create Authorization Rules

**Send policy (for simulator):**
```bash
az eventhubs eventhub authorization-rule create \
  --name simulator-send \
  --eventhub-name idoc-events \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --rights Send
```

**Listen policy (for Fabric):**
```bash
az eventhubs eventhub authorization-rule create \
  --name fabric-listen \
  --eventhub-name idoc-events \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --rights Listen
```

### Step 6: Get Connection String

```bash
az eventhubs eventhub authorization-rule keys list \
  --name simulator-send \
  --eventhub-name idoc-events \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --query primaryConnectionString \
  --output tsv
```

Copy the output and use it in your `.env` file.

---

## Method 3: PowerShell (Windows)

### Step 1: Install Azure PowerShell Module

```powershell
Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
```

### Step 2: Login and Set Subscription

```powershell
Connect-AzAccount
Set-AzContext -Subscription "Your Subscription Name"
```

### Step 3: Create Resource Group

```powershell
New-AzResourceGroup `
  -Name "rg-idoc-fabric-dev" `
  -Location "EastUS"
```

### Step 4: Create Event Hubs Namespace

```powershell
New-AzEventHubNamespace `
  -ResourceGroupName "rg-idoc-fabric-dev" `
  -Name "eh-idoc-fabric-dev-001" `
  -Location "EastUS" `
  -SkuName "Standard" `
  -SkuCapacity 2
```

### Step 5: Create Event Hub

```powershell
New-AzEventHub `
  -ResourceGroupName "rg-idoc-fabric-dev" `
  -NamespaceName "eh-idoc-fabric-dev-001" `
  -Name "idoc-events" `
  -PartitionCount 4 `
  -MessageRetentionInDays 7
```

### Step 6: Create Authorization Rules

**Send policy:**
```powershell
New-AzEventHubAuthorizationRule `
  -ResourceGroupName "rg-idoc-fabric-dev" `
  -NamespaceName "eh-idoc-fabric-dev-001" `
  -EventHubName "idoc-events" `
  -Name "simulator-send" `
  -Rights @("Send")
```

**Listen policy:**
```powershell
New-AzEventHubAuthorizationRule `
  -ResourceGroupName "rg-idoc-fabric-dev" `
  -NamespaceName "eh-idoc-fabric-dev-001" `
  -EventHubName "idoc-events" `
  -Name "fabric-listen" `
  -Rights @("Listen")
```

### Step 7: Get Connection String

```powershell
$keys = Get-AzEventHubKey `
  -ResourceGroupName "rg-idoc-fabric-dev" `
  -NamespaceName "eh-idoc-fabric-dev-001" `
  -EventHubName "idoc-events" `
  -AuthorizationRuleName "simulator-send"

$keys.PrimaryConnectionString
```

---

## Configuration Reference

### Namespace Pricing Tiers

| Tier | Throughput Units | Max Message Size | Best For |
|------|------------------|------------------|----------|
| **Basic** | 1-20 | 256 KB | Development only |
| **Standard** | 1-20 (auto-inflate to 40) | 1 MB | Development & Production |
| **Premium** | 1-16 Processing Units | 1 MB | Production (high throughput) |
| **Dedicated** | 1-10 Capacity Units | 1 MB | Enterprise production |

**Recommendation**: Use **Standard** tier with 2-5 throughput units for this project.

### Partition Count Guidelines

| Scenario | Partition Count | Reason |
|----------|----------------|--------|
| Development/Testing | 2-4 | Lower cost, adequate for testing |
| Production (Low) | 8-16 | Good parallelism, moderate cost |
| Production (High) | 16-32 | Maximum parallelism for high throughput |

**Recommendation**: Start with **4 partitions** for dev/test, **8-16** for production.

### Message Retention

- **Basic/Standard**: 1-7 days
- **Premium/Dedicated**: 1-90 days

**Recommendation**: Use **7 days** (maximum for Standard tier) to allow recovery time if Fabric Eventstream has issues.

### Throughput Units (TU)

Each TU provides:
- **Ingress**: 1 MB/s or 1,000 events/s
- **Egress**: 2 MB/s or 2,000 events/s

**Calculation Example**:
- Simulator rate: 100 msg/min = 1.67 msg/s
- Average message size: 2.5 KB
- Throughput: 1.67 × 2.5 KB = 4.17 KB/s
- Required TUs: 1 (minimum)

For higher rates (1,000 msg/min = 16.67 msg/s):
- Throughput: 16.67 × 2.5 KB = 41.67 KB/s
- Required TUs: 1 (still within limits)

**Recommendation**: Start with **2 TUs** for buffer, enable **auto-inflate** to 10 TUs.

---

## Verification Steps

### 1. Verify in Azure Portal

1. Navigate to Event Hubs Namespace
2. Click "Metrics" in left menu
3. Add metric: "Incoming Messages"
4. Run simulator
5. Watch for incoming message count to increase

### 2. Verify with Azure CLI

```bash
# Get namespace details
az eventhubs namespace show \
  --name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev

# List Event Hubs
az eventhubs eventhub list \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev
```

### 3. Verify with Simulator

```powershell
cd simulator
python main.py
```

Look for:
```json
{"timestamp": "...", "level": "INFO", "message": "Event Hub publisher initialized successfully"}
{"timestamp": "...", "level": "INFO", "message": "Sent batch of 100 messages"}
```

---

## Monitoring Event Hub

### Portal Metrics (Recommended)

1. Navigate to Event Hub Namespace
2. Click "Metrics"
3. Add these metrics:
   - **Incoming Messages**: Messages received
   - **Outgoing Messages**: Messages consumed
   - **Incoming Bytes**: Data ingress
   - **Throttled Requests**: Capacity issues
   - **Server Errors**: Problems

### Enable Diagnostic Settings

1. Go to Event Hub Namespace
2. Click "Diagnostic settings"
3. Click "+ Add diagnostic setting"
4. Configure:
   ```
   Name: "eventhub-diagnostics"
   Logs: ☑ OperationalLogs, ☑ RuntimeAuditLogs
   Metrics: ☑ AllMetrics
   Destination: Send to Log Analytics workspace (create one if needed)
   ```

---

## Troubleshooting

### Issue: "Cannot connect to Event Hub"

**Check**:
1. Connection string is correct
2. Event Hub name matches
3. Network connectivity to Azure
4. Firewall rules (if any)

**Solution**:
```powershell
# Test connectivity
Test-NetConnection -ComputerName eh-idoc-fabric-dev-001.servicebus.windows.net -Port 5671
```

### Issue: "Unauthorized access"

**Check**:
1. Shared Access Policy has "Send" rights
2. Connection string includes the correct policy name
3. Key hasn't been regenerated

**Solution**: Regenerate keys if needed:
```bash
az eventhubs eventhub authorization-rule keys renew \
  --name simulator-send \
  --eventhub-name idoc-events \
  --namespace-name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --key primary
```

### Issue: "Quota exceeded" or "Throttling"

**Check**:
- Current throughput units
- Message rate vs capacity
- Partition distribution

**Solution**: Increase throughput units:
```bash
az eventhubs namespace update \
  --name eh-idoc-fabric-dev-001 \
  --resource-group rg-idoc-fabric-dev \
  --capacity 5
```

---

## Cost Estimation

### Standard Tier Pricing (US East, approximate)

| Component | Unit | Monthly Cost |
|-----------|------|--------------|
| Namespace | Fixed | $0 |
| Throughput Unit | Per TU | $21.92/TU |
| Ingress | Per million events | $0.028 |
| Capture | Per GB | $0.10 (not used) |

**Example Calculation**:
- 2 TUs × $21.92 = $43.84/month
- 1M events × $0.028 = $0.028
- **Total**: ~$44/month for development

For production (10 TUs, 50M events/month):
- 10 TUs × $21.92 = $219.20
- 50M events × $0.028 = $1.40
- **Total**: ~$220/month

---

## Security Best Practices

1. ✅ **Use separate policies** for send and listen
2. ✅ **Store connection strings** in Azure Key Vault (production)
3. ✅ **Use Azure AD authentication** for production (instead of connection strings)
4. ✅ **Enable VNet integration** for production
5. ✅ **Enable diagnostic logging**
6. ✅ **Rotate keys regularly** (every 90 days)
7. ✅ **Use managed identities** when possible

### Azure AD Authentication (Advanced)

For production, use Azure AD instead of connection strings:

1. **Enable managed identity** on your compute resource
2. **Grant permissions**:
   ```bash
   az role assignment create \
     --role "Azure Event Hubs Data Sender" \
     --assignee <managed-identity-id> \
     --scope /subscriptions/<sub-id>/resourceGroups/rg-idoc-fabric-dev/providers/Microsoft.EventHub/namespaces/eh-idoc-fabric-dev-001
   ```
3. **Update simulator configuration**:
   ```yaml
   eventhub:
     use_azure_credential: true
     namespace: "eh-idoc-fabric-dev-001"
     eventhub_name: "idoc-events"
   ```

---

## Next Steps

1. ✅ Create Event Hub (you just did this!)
2. ⏩ Configure simulator with connection string
3. ⏩ Run simulator and verify messages
4. ⏩ Set up Fabric Eventstream to consume messages
5. ⏩ Monitor Event Hub metrics

**Ready to run the simulator!** Go back to [QUICKSTART.md](QUICKSTART.md) to configure and run.
