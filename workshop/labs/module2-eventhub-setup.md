# Module 2: Event Hub Setup and IDoc Ingestion

## 🎯 Learning Objectives

By the end of this module, you will be able to:
- ✅ Create and configure Azure Event Hubs for SAP IDoc ingestion
- ✅ Understand SAP IDoc message structure and format
- ✅ Configure the IDoc simulator to generate test data
- ✅ Send test messages to Event Hub
- ✅ Monitor and validate message ingestion
- ✅ Troubleshoot common Event Hub connection issues

## ⏱️ Estimated Time

**90 minutes** (30 min setup + 45 min hands-on + 15 min validation)

## 📋 Prerequisites

Before starting this module, ensure you have:

### Required
- ✅ **Azure Subscription** with Owner or Contributor role
- ✅ **Azure CLI** or **PowerShell Az module** installed
- ✅ **Python 3.11+** installed and configured
- ✅ **Git** installed
- ✅ Completed **Module 1** (Architecture Overview)

### Recommended
- Visual Studio Code or similar code editor
- Basic understanding of JSON format
- Familiarity with Azure Portal

### Cost Considerations

Running this module will incur Azure costs:
- **Event Hubs Standard Tier**: ~$0.73/day (~$22/month for 2 throughput units)
- **Data Ingress**: $0.028 per million events (negligible for testing)
- **Estimated Total**: ~$1-2 for completing this module

**💡 Tip**: Delete resources after completing the workshop to minimize costs.

---

## 📚 Part 1: Understanding SAP IDocs

### What is an IDoc?

**IDoc** (Intermediate Document) is SAP's standard format for exchanging business data between systems. Think of it as a "digital document" that represents a business transaction.

### IDoc Structure

An IDoc consists of three main components:

```
┌─────────────────────────────────────┐
│         Control Record              │  ← Metadata (sender, receiver, type)
├─────────────────────────────────────┤
│         Data Records                │  ← Business data (segments)
│  ┌──────────────────────────────┐   │
│  │ E1EDK01 - Header             │   │
│  │ E1EDKA1 - Partner Info       │   │
│  │ E1EDP01 - Line Items         │   │
│  │   ├─ E1EDP19 - Material ID   │   │  ← Nested segments
│  │   ├─ E1EDP26 - Pricing       │   │
│  │   └─ E1EDP20 - Schedule      │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│         Status Records              │  ← Processing status (optional)
└─────────────────────────────────────┘
```

### IDoc Types Used in This Workshop

| IDoc Type | Message Type | Business Purpose | Example Use Case |
|-----------|--------------|------------------|------------------|
| **ORDERS05** | ORDERS | Purchase/Sales Orders | Customer places order |
| **SHPMNT** | SHPMNT | Shipment Information | Carrier picks up goods |
| **DESADV** | DESADV | Delivery Notification | Planned delivery notice |
| **INVOIC** | INVOIC | Invoice Document | Billing for shipment |
| **WHSCON** | WHSCON | Warehouse Confirmation | Goods received |

### Sample IDoc Structure

The workshop includes a complete sample IDoc at `workshop/samples/sample-idoc.json`. Here's a simplified view:

```json
{
  "idoc_type": "ORDERS05",
  "message_type": "ORDERS",
  "sap_system": "S4HPRD",
  "timestamp": "2024-11-03T10:00:00.000Z",
  "control": {
    "docnum": "1234567890123456",
    "mestyp": "ORDERS",
    "sndprn": "SALES"
  },
  "data": {
    "E1EDK01": [{
      "belnr": "ORD-2024-001",
      "customer_id": "CUST001",
      "customer_name": "ACME Corporation"
    }],
    "E1EDP01": [{
      "segnam": "E1EDP01",
      "matnr": "MAT001",
      "arktx": "Premium Widget A",
      "menge": "10.000",
      "netwr": "255.00"
    }, {
      "segnam": "E1EDP19",
      "idtnr": "MAT001",
      "ktext": "Premium Widget A"
    }]
  },
  "order_summary": {
    "total_value": 255.0,
    "currency": "USD"
  }
}
```

**📄 View the complete sample**: [sample-idoc.json](../samples/sample-idoc.json)

---

## 🔧 Part 2: Event Hub Creation

### Overview

Azure Event Hubs is a fully managed, real-time data streaming platform that will receive SAP IDoc messages from our simulator and feed them into Microsoft Fabric.

### Architecture Flow

```
┌──────────────┐    AMQP/TLS    ┌──────────────┐    Eventstream    ┌──────────────┐
│   IDoc       │  ─────────────> │  Event Hub   │ ────────────────> │   Fabric     │
│  Simulator   │   (Port 5671)   │  Namespace   │                   │  Eventhouse  │
└──────────────┘                 └──────────────┘                   └──────────────┘
```

### Deployment Methods

Choose one of the following methods to create your Event Hub:

#### ✅ **Method 1: Automated Deployment (Recommended)**

**Best for**: Quick setup, reproducible environments

```powershell
# Clone the repository (if not already done)
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git
cd Fabric-SAP-Idocs/infrastructure

# Run the deployment script
.\deploy-eventhub.ps1 `
    -ResourceGroup "rg-idoc-fabric-dev" `
    -Location "eastus" `
    -EventHubNamespace "eh-idoc-fabric-$(Get-Random -Maximum 9999)" `
    -EventHubName "idoc-events"
```

**What this script does**:
1. ✅ Creates resource group
2. ✅ Creates Event Hubs namespace (Standard tier, 2 throughput units)
3. ✅ Creates Event Hub with 4 partitions and 7-day retention
4. ✅ Creates shared access policies (send and listen)
5. ✅ Retrieves connection strings
6. ✅ Saves configuration to `.env` file

**Expected Output**:
```
========================================
Deployment Complete!
========================================

Resource Group: rg-idoc-fabric-dev
Event Hub Namespace: eh-idoc-fabric-dev-1234
Event Hub Name: idoc-events

Simulator (Send):
Endpoint=sb://eh-idoc-fabric-dev-1234.servicebus.windows.net/;...

✅ Connection strings saved to: eventhub-connection-strings.txt
```

**⏭️ Skip to Part 3** if using this method.

---

#### **Method 2: Azure Portal (Step-by-Step)**

**Best for**: First-time users, learning the UI

##### Step 2.1: Create Event Hubs Namespace

1. **Sign in to Azure Portal**
   - Navigate to https://portal.azure.com

2. **Create Resource**
   - Click **"+ Create a resource"**
   - Search for **"Event Hubs"**
   - Click **"Create"**

3. **Configure Namespace Basics**
   ```
   Subscription: [Your Azure subscription]
   Resource Group: [Create new] "rg-idoc-fabric-dev"
   Namespace name: "eh-idoc-fabric-dev-001" (must be globally unique)
   Location: [Your preferred region, e.g., "East US"]
   Pricing tier: "Standard"
   Throughput units: 2
   ```

4. **Configure Advanced Settings**
   - **Enable Auto-Inflate**: ✅ Yes
   - **Maximum throughput units**: 10
   - **Enable Kafka**: Leave default
   - **Availability zone**: Leave default

5. **Review + Create**
   - Click **"Review + create"**
   - Verify settings
   - Click **"Create"**
   - Wait 2-3 minutes for deployment ⏳

##### Step 2.2: Create Event Hub

1. **Navigate to Namespace**
   - Go to **"Event Hubs Namespaces"**
   - Click on your namespace (e.g., "eh-idoc-fabric-dev-001")

2. **Create Event Hub**
   - Click **"+ Event Hub"** at the top
   
3. **Configure Event Hub**
   ```
   Name: "idoc-events"
   Partition count: 4
   Message retention: 7 (days)
   Cleanup policy: Delete (default)
   Capture: Disabled
   ```

4. **Create**
   - Click **"Create"**
   - Wait ~30 seconds

##### Step 2.3: Create Shared Access Policies

1. **Navigate to Event Hub**
   - Click on **"idoc-events"** (your Event Hub)

2. **Create Send Policy (for Simulator)**
   - Click **"Shared access policies"** in left menu
   - Click **"+ Add"**
   - **Policy name**: `simulator-send`
   - **Permissions**: ☑️ Send (only)
   - Click **"Create"**

3. **Create Listen Policy (for Fabric)**
   - Click **"+ Add"** again
   - **Policy name**: `fabric-listen`
   - **Permissions**: ☑️ Listen (only)
   - Click **"Create"**

##### Step 2.4: Get Connection String

1. **Open Simulator Policy**
   - Click on **"simulator-send"** policy
   
2. **Copy Connection String**
   - Copy **"Connection string–primary key"**
   - It should look like:
   ```
   Endpoint=sb://eh-idoc-fabric-dev-001.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=xxxxx;EntityPath=idoc-events
   ```

3. **Save for Later**
   - **Important**: Save this connection string securely
   - You'll need it in Part 3

---

#### **Method 3: Azure CLI**

**Best for**: Automation, scripting, DevOps

```bash
# Login to Azure
az login
az account set --subscription "Your Subscription Name"

# Variables
RESOURCE_GROUP="rg-idoc-fabric-dev"
LOCATION="eastus"
NAMESPACE="eh-idoc-fabric-dev-001"
EVENTHUB="idoc-events"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create Event Hubs namespace
az eventhubs namespace create \
  --name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard \
  --capacity 2 \
  --enable-auto-inflate true \
  --maximum-throughput-units 10

# Create Event Hub
az eventhubs eventhub create \
  --name $EVENTHUB \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --partition-count 4 \
  --message-retention 7

# Create authorization rules
az eventhubs eventhub authorization-rule create \
  --name simulator-send \
  --eventhub-name $EVENTHUB \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --rights Send

az eventhubs eventhub authorization-rule create \
  --name fabric-listen \
  --eventhub-name $EVENTHUB \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --rights Listen

# Get connection string
az eventhubs eventhub authorization-rule keys list \
  --name simulator-send \
  --eventhub-name $EVENTHUB \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --query primaryConnectionString \
  --output tsv
```

---

## ⚙️ Part 3: Simulator Configuration

### Overview

The IDoc Simulator is a Python application that generates realistic SAP IDoc messages and publishes them to Event Hub.

### Step 3.1: Install Python Dependencies

```bash
# Navigate to simulator directory
cd simulator

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# Windows:
.\venv\Scripts\Activate.ps1
# macOS/Linux:
source venv/bin/activate

# Install required packages
pip install -r requirements.txt
```

**Expected packages installed**:
- `azure-eventhub` - Event Hub client
- `azure-identity` - Azure authentication
- `pydantic` - Data validation
- `pyyaml` - Configuration parsing
- `python-dotenv` - Environment variables

### Step 3.2: Configure Connection String

Create a `.env` file in the `simulator` folder:

```bash
# Copy example file
cp .env.example .env

# Edit .env file (use nano, vim, or VS Code)
nano .env
```

**Add your connection details**:

```ini
# Azure Event Hub Configuration
EVENT_HUB_CONNECTION_STRING=Endpoint=sb://YOUR-NAMESPACE.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=YOUR-KEY;EntityPath=idoc-events
EVENT_HUB_NAME=idoc-events

# SAP Configuration
SAP_SYSTEM_ID=S4HPRD
SAP_CLIENT=100
SAP_SENDER=3PLSYSTEM

# Simulator Settings
MESSAGE_RATE=10
BATCH_SIZE=100
RUN_DURATION_SECONDS=60

# Master Data Configuration
WAREHOUSE_COUNT=5
CUSTOMER_COUNT=100
CARRIER_COUNT=20

# Logging
LOG_LEVEL=INFO
```

**🔑 Important Configuration Parameters**:

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| `EVENT_HUB_CONNECTION_STRING` | Full connection string from Azure | From Part 2 |
| `EVENT_HUB_NAME` | Event Hub instance name | `idoc-events` |
| `MESSAGE_RATE` | Messages per minute | `10` (testing), `100` (demo) |
| `BATCH_SIZE` | Messages per batch | `100` |
| `RUN_DURATION_SECONDS` | How long to run | `60` (1 min), `3600` (1 hour) |

---

## 🚀 Part 4: Sending Test Messages

### Step 4.1: Validate Connection

**Before sending messages**, test your Event Hub connection:

```powershell
# Run from workshop/scripts directory
cd ../workshop/scripts
.\test-eventhub-connection.ps1
```

**Expected Output**:
```
========================================
Event Hub Connection Test
========================================

📝 Parsing connection string...
✓ Endpoint: eh-idoc-fabric-dev-001.servicebus.windows.net
✓ Shared Access Key Name: simulator-send
✓ Entity Path (Event Hub Name): idoc-events

🌐 Testing network connectivity...
✓ Network connection successful (Port 5671 - AMQP over TLS)

🐍 Checking Python environment...
✓ Python installed: Python 3.11.0
✓ azure-eventhub package installed

✅ Connection test complete!
```

**❌ If you see errors**, check:
- Connection string is correctly copied
- No extra spaces or line breaks
- Event Hub namespace exists
- Firewall allows outbound port 5671

### Step 4.2: Run Quick Test

Send a single test message to verify everything works:

```bash
# Navigate to simulator directory
cd ../../simulator

# Run the Event Hub test script
python test_eventhub.py
```

**Expected Output**:
```
Testing Entra ID connection to:
  Namespace: eh-idoc-fabric-dev-001.servicebus.windows.net
  Event Hub: idoc-events

✓ Producer created successfully with Entra ID
✓ Batch created successfully (max size: 1048576 bytes)
✓ Test message added to batch
✓ Batch sent successfully!

✅ Event Hub connection test with Entra ID PASSED!
```

### Step 4.3: Generate Sample IDocs

Now let's generate realistic IDoc messages:

```bash
# Run simulator with default settings (10 messages/min for 1 minute)
python main.py

# Or run with custom parameters
python main.py --message-rate 50 --duration 120 --idoc-types ORDERS SHPMNT
```

**Command-line Options**:
```
--message-rate    Messages per minute (default: 10)
--duration        Run duration in seconds (default: 60)
--idoc-types      Types to generate (default: all)
--batch-size      Messages per batch (default: 100)
--test-mode       Dry run without sending (default: false)
```

**Example Output**:
```
2024-11-03 10:00:00 [INFO] Starting IDoc Simulator
2024-11-03 10:00:00 [INFO] Configuration loaded successfully
2024-11-03 10:00:00 [INFO] Event Hub publisher initialized
2024-11-03 10:00:00 [INFO] Generating master data: 100 customers, 5 warehouses, 20 carriers
2024-11-03 10:00:00 [INFO] Starting message generation...
2024-11-03 10:00:05 [INFO] Generated 10 IDocs [ORDERS: 4, SHPMNT: 3, DESADV: 3]
2024-11-03 10:00:05 [INFO] Sent batch of 10 messages (25.6 KB)
2024-11-03 10:00:10 [INFO] Generated 10 IDocs [ORDERS: 5, SHPMNT: 2, DESADV: 3]
2024-11-03 10:00:10 [INFO] Sent batch of 10 messages (26.1 KB)
...
2024-11-03 10:01:00 [INFO] Simulation complete!
2024-11-03 10:01:00 [INFO] Total messages sent: 100
2024-11-03 10:01:00 [INFO] Total data sent: 256.4 KB
2024-11-03 10:01:00 [INFO] Average rate: 100 msg/min
```

### Step 4.4: Generate High-Volume Test Data (Optional)

For performance testing:

```bash
# Generate 1000 messages over 10 minutes
python main.py --message-rate 100 --duration 600

# Generate specific IDoc types
python main.py --idoc-types ORDERS --message-rate 200 --duration 300
```

---

## 📊 Part 5: Monitoring and Validation

### Step 5.1: View Metrics in Azure Portal

1. **Navigate to Event Hub Namespace**
   - Open Azure Portal
   - Go to **Event Hubs Namespaces**
   - Click on your namespace

2. **Open Metrics**
   - Click **"Metrics"** in left menu
   - Click **"+ New chart"**

3. **Add Key Metrics**

   **Chart 1: Incoming Messages**
   ```
   Metric: Incoming Messages
   Aggregation: Sum
   Time range: Last 30 minutes
   ```

   **Chart 2: Incoming Bytes**
   ```
   Metric: Incoming Bytes
   Aggregation: Sum
   Time range: Last 30 minutes
   ```

   **Chart 3: Throttled Requests (should be zero)**
   ```
   Metric: Throttled Requests
   Aggregation: Sum
   Time range: Last 30 minutes
   ```

4. **What to Look For**:
   - ✅ **Incoming Messages**: Should match messages sent (~100 for 1-minute test)
   - ✅ **Incoming Bytes**: Should show data volume (~250-300 KB for 100 messages)
   - ✅ **Throttled Requests**: Should be **0** (if not, increase throughput units)
   - ✅ **Server Errors**: Should be **0**

### Step 5.2: Enable Diagnostic Logging (Optional but Recommended)

**For production environments**, enable diagnostic logging:

1. **Navigate to Event Hub Namespace**
2. **Click "Diagnostic settings"**
3. **Click "+ Add diagnostic setting"**

**Configuration**:
```
Name: eventhub-diagnostics
Logs:
  ☑ OperationalLogs
  ☑ RuntimeAuditLogs
  ☑ AutoScaleLogs
Metrics:
  ☑ AllMetrics
Destination:
  ☑ Send to Log Analytics workspace
  [Create new workspace or select existing]
```

### Step 5.3: Query Event Hub Data (Advanced)

If you configured diagnostic logging, you can query logs:

```kql
// Last 100 incoming requests
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where Category == "OperationalLogs"
| where OperationName == "Send"
| order by TimeGenerated desc
| take 100

// Count of messages by hour
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where Category == "OperationalLogs"
| where OperationName == "Send"
| summarize MessageCount = count() by bin(TimeGenerated, 1h)
| render timechart
```

---

## 🔍 Part 6: Common Issues and Solutions

### Issue 1: Connection String Not Working

**Symptoms**:
```
❌ Error: Unauthorized access. Check credentials.
```

**Solutions**:
1. Verify connection string has no extra spaces or line breaks
2. Check the policy has "Send" permission
3. Regenerate the key:
   ```bash
   az eventhubs eventhub authorization-rule keys renew \
     --name simulator-send \
     --eventhub-name idoc-events \
     --namespace-name YOUR_NAMESPACE \
     --resource-group rg-idoc-fabric-dev \
     --key primary
   ```
4. Update `.env` file with new connection string

### Issue 2: Network Connection Failed

**Symptoms**:
```
❌ Network connection failed to ... on port 5671
```

**Solutions**:
1. **Check Firewall**: Ensure outbound port 5671 (AMQP over TLS) is allowed
2. **Corporate Network**: May need to whitelist `*.servicebus.windows.net`
3. **VPN/Proxy**: Disable or configure to allow Azure connections
4. **Test Connectivity**:
   ```powershell
   Test-NetConnection -ComputerName YOUR-NAMESPACE.servicebus.windows.net -Port 5671
   ```

### Issue 3: Python Package Not Found

**Symptoms**:
```
ModuleNotFoundError: No module named 'azure.eventhub'
```

**Solutions**:
1. **Activate virtual environment**:
   ```bash
   # Windows
   .\venv\Scripts\Activate.ps1
   # macOS/Linux
   source venv/bin/activate
   ```
2. **Reinstall packages**:
   ```bash
   pip install --force-reinstall -r requirements.txt
   ```
3. **Check Python version** (must be 3.11+):
   ```bash
   python --version
   ```

### Issue 4: Throttling (Quota Exceeded)

**Symptoms**:
```
⚠ Warning: Throttled Requests detected
```

**Solutions**:
1. **Reduce message rate** in `.env`:
   ```ini
   MESSAGE_RATE=5  # Reduce from 10 to 5
   ```
2. **Increase throughput units**:
   ```bash
   az eventhubs namespace update \
     --name YOUR_NAMESPACE \
     --resource-group rg-idoc-fabric-dev \
     --capacity 5
   ```
3. **Enable auto-inflate** (already enabled if you followed Method 1)

### Issue 5: Event Hub Not Receiving Messages

**Symptoms**:
- Simulator runs without errors
- But metrics show 0 incoming messages

**Solutions**:
1. **Check Event Hub name** matches in:
   - `.env` file: `EVENT_HUB_NAME=idoc-events`
   - Connection string: `EntityPath=idoc-events`
   - Azure Portal: Event Hub instance name
2. **Verify simulator is actually sending**:
   ```bash
   python main.py --test-mode  # Dry run to check logs
   ```
3. **Check Azure Portal metrics** with 5-minute refresh

### Issue 6: High Costs

**Symptoms**:
- Azure bill higher than expected

**Solutions**:
1. **Reduce throughput units**:
   ```bash
   az eventhubs namespace update \
     --name YOUR_NAMESPACE \
     --resource-group rg-idoc-fabric-dev \
     --capacity 1
   ```
2. **Shorten message retention**:
   ```bash
   az eventhubs eventhub update \
     --name idoc-events \
     --namespace-name YOUR_NAMESPACE \
     --resource-group rg-idoc-fabric-dev \
     --message-retention 1
   ```
3. **Delete resources when not in use**:
   ```bash
   az group delete --name rg-idoc-fabric-dev --yes --no-wait
   ```

---

## ✅ Validation Tests

Before proceeding to Module 3, complete these validation tests:

### Test 1: Configuration Validation
```powershell
# Run from workshop/scripts
.\test-eventhub-connection.ps1
```
**Expected**: All checks pass with ✓

### Test 2: Single Message Test
```bash
# Run from simulator directory
python test_eventhub.py
```
**Expected**: "✅ Event Hub connection test PASSED!"

### Test 3: Batch Message Test
```bash
# Send 100 messages
python main.py --message-rate 100 --duration 60
```
**Expected**: 
- No errors
- "Total messages sent: 100"
- Azure metrics show ~100 incoming messages

### Test 4: IDoc Structure Validation
```bash
# Inspect generated IDoc
cat ../workshop/samples/sample-idoc.json
```
**Expected**: Valid JSON with control, data, and order_summary sections

### Test 5: Metrics Validation

1. Go to Azure Portal → Event Hub Namespace → Metrics
2. Check "Incoming Messages" chart
3. **Expected**: Spike corresponding to your test run
4. **Expected**: No throttled requests or errors

---

## 📝 Hands-On Exercises

### Exercise 1: Generate Custom Order

**Goal**: Create a custom order IDoc with your own data

**Steps**:
1. Open `workshop/samples/sample-idoc.json`
2. Modify customer information:
   ```json
   "customer_id": "YOUR-COMPANY",
   "customer_name": "Your Company Name"
   ```
3. Change order details:
   ```json
   "belnr": "ORD-YOUR-001",
   "total_value": 500.0
   ```
4. Save and validate JSON format

### Exercise 2: Monitor Real-Time Ingestion

**Goal**: Watch messages flow in real-time

**Steps**:
1. Open Azure Portal → Event Hub → Metrics
2. Set time range to "Last 5 minutes"
3. Enable auto-refresh (30 seconds)
4. In terminal, run:
   ```bash
   python main.py --message-rate 60 --duration 300
   ```
5. Watch the metrics chart update in real-time

### Exercise 3: Test Different IDoc Types

**Goal**: Generate and compare different IDoc types

**Steps**:
1. Generate only ORDERS:
   ```bash
   python main.py --idoc-types ORDERS --message-rate 20 --duration 60
   ```
2. Check metrics and note message size
3. Generate only SHPMNT:
   ```bash
   python main.py --idoc-types SHPMNT --message-rate 20 --duration 60
   ```
4. Compare message sizes and structure
5. **Question**: Which IDoc type produces larger messages? Why?

### Exercise 4: Performance Testing

**Goal**: Find the maximum throughput

**Steps**:
1. Start with 100 msg/min:
   ```bash
   python main.py --message-rate 100 --duration 120
   ```
2. Check for throttling in Azure metrics
3. If no throttling, increase to 200 msg/min
4. Keep increasing until you see throttled requests
5. **Document**: Maximum rate before throttling occurs

---

## 🎓 Knowledge Check

Before moving to Module 3, ensure you can answer these questions:

1. **What are the three main components of an IDoc?**
   <details>
   <summary>Click to reveal answer</summary>
   Control Record (metadata), Data Records (business data segments), Status Records (processing status)
   </details>

2. **What port does Event Hub use for AMQP over TLS?**
   <details>
   <summary>Click to reveal answer</summary>
   Port 5671
   </details>

3. **What's the difference between "Send" and "Listen" permissions?**
   <details>
   <summary>Click to reveal answer</summary>
   Send permission allows publishing messages to Event Hub. Listen permission allows consuming/reading messages from Event Hub.
   </details>

4. **Why do we use separate access policies for simulator and Fabric?**
   <details>
   <summary>Click to reveal answer</summary>
   Principle of least privilege - each component only has the permissions it needs. Simulator needs Send, Fabric needs Listen.
   </details>

5. **What is a throughput unit in Event Hubs?**
   <details>
   <summary>Click to reveal answer</summary>
   A throughput unit provides 1 MB/s ingress or 2 MB/s egress, and up to 1000 events/second.
   </details>

---

## 📚 Additional Resources

### Documentation
- [Azure Event Hubs Overview](https://learn.microsoft.com/azure/event-hubs/)
- [Event Hubs Pricing](https://azure.microsoft.com/pricing/details/event-hubs/)
- [SAP IDoc Documentation](https://help.sap.com/docs/SAP_NETWEAVER/8f3819b0c24149b5959ab31070b64058/4ab977607df76914e10000000a42189b.html)

### Code Samples
- [Azure Event Hubs Python Samples](https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/eventhub/azure-eventhub/samples)
- [IDoc Schemas in this Repository](../../simulator/src/idoc_schemas/)

### Tools
- [Azure Storage Explorer](https://azure.microsoft.com/features/storage-explorer/) - For Event Hub Capture (if enabled)
- [Postman](https://www.postman.com/) - For API testing (used in Module 6)

---

## 🎯 Summary

In this module, you learned how to:
- ✅ Create and configure Azure Event Hubs for IDoc ingestion
- ✅ Understand SAP IDoc message structure
- ✅ Configure and run the IDoc simulator
- ✅ Send test messages to Event Hub
- ✅ Monitor ingestion using Azure Portal metrics
- ✅ Troubleshoot common issues

### Key Takeaways

1. **Event Hubs** provide a scalable, managed streaming platform for IDoc ingestion
2. **IDoc structure** consists of control records (metadata) and data segments (business data)
3. **Shared access policies** implement security with least-privilege access
4. **Monitoring metrics** is essential for validating ingestion and diagnosing issues
5. **Throughput units** determine your Event Hub capacity and should be sized appropriately

---

## ⏭️ Next Steps

**Congratulations!** You've successfully completed Module 2. 🎉

You now have:
- ✅ Working Event Hub receiving IDoc messages
- ✅ IDoc simulator generating realistic test data
- ✅ Monitoring and validation in place

**Ready to continue?**

Proceed to **[Module 3: KQL Queries and Real-Time Analytics](module3-kql-queries.md)** to learn how to analyze streaming IDoc data using Kusto Query Language in Fabric Eventhouse.

In Module 3, you'll:
- Set up Fabric Eventhouse
- Write KQL queries to analyze IDocs
- Create real-time dashboards
- Perform time-series analysis

---

## 📞 Getting Help

If you encounter issues not covered in this guide:

1. **Check logs** in the simulator output
2. **Review Azure Portal** Activity Log for resource-level errors
3. **Troubleshooting section** above
4. **Repository Issues**: [GitHub Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
5. **Microsoft Docs**: [Event Hubs Troubleshooting](https://learn.microsoft.com/azure/event-hubs/troubleshoot-issues)

---

**📌 Module Status**: ✅ Complete and tested  
**Last Updated**: November 3, 2024  
**Author**: Florent Thibault
