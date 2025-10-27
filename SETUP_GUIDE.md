# 🚀 Setup Guide - SAP IDoc to Microsoft Fabric Pipeline

## Overview

This guide walks you through deploying a complete real-time SAP IDoc ingestion pipeline using Microsoft Fabric and Azure Event Hub.

**What You'll Build:**
```
Python IDoc Simulator → Azure Event Hub → Fabric Eventstream → KQL Database
```

**Status:** ✅ Fully functional with 605+ messages validated

---

## Architecture

### Azure Components
- **Event Hub Namespace**: `eh-idoc-flt8076.servicebus.windows.net`
- **Event Hub**: `idoc-events` (4 partitions, 7-day retention)
- **Consumer Group**: `fabric-consumer`

### Microsoft Fabric Components
- **Workspace**: SAP-IDoc-Fabric (`ad53e547-23dc-46b0-ab5f-2acbaf0eec64`)
- **Eventhouse**: kqldbsapidoc (`f91aaea3-7889-4415-851c-f4258a2fff6b`)
- **KQL Database**: kqldbsapidoc
- **Eventstream**: SAPIdocIngest (`22c57137-e45f-4116-8b5b-e9849614bf17`)

### KQL Table Schema
- **Table**: `idoc_raw` (9 columns, 90-day retention)
- **Streaming**: Enabled
- **Columns**: idoc_type, message_type, sap_system, timestamp, control, data, EventProcessedUtcTime, PartitionId, EventEnqueuedUtcTime

---

## Prerequisites

### Tools Required
- Python 3.11+
- Azure CLI
- PowerShell 7+
- VS Code (recommended)
- Git
- uvx (for MCP server)

### Azure/Fabric Access
- Azure subscription
- Microsoft Fabric workspace with F64+ capacity
- Permissions: Azure Event Hubs Data Receiver, Workspace Contributor

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git
cd Fabric-SAP-Idocs
```

### 2. Deploy Azure Event Hub

```powershell
# Login to Azure
az login

# Create Resource Group
az group create --name rg-idoc-fabric-dev --location westeurope

# Create Event Hub Namespace
az eventhubs namespace create \
  --name eh-idoc-flt8076 \
  --resource-group rg-idoc-fabric-dev \
  --location westeurope \
  --sku Standard

# Create Event Hub
az eventhubs eventhub create \
  --name idoc-events \
  --namespace-name eh-idoc-flt8076 \
  --resource-group rg-idoc-fabric-dev \
  --partition-count 4 \
  --message-retention 7

# Create Consumer Group
az eventhubs eventhub consumer-group create \
  --name fabric-consumer \
  --eventhub-name idoc-events \
  --namespace-name eh-idoc-flt8076 \
  --resource-group rg-idoc-fabric-dev
```

### 3. Configure Python Simulator

```powershell
cd simulator
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create `simulator/config/config.yaml`:
```yaml
eventhub:
  connection_string: "Endpoint=sb://eh-idoc-flt8076.servicebus.windows.net/;..."
  name: "idoc-events"

sap:
  system: "S4HPRD"
  client: "100"
```

Test the simulator:
```powershell
python main.py --count 5
```

### 4. Create Fabric Workspace

1. Open [Microsoft Fabric Portal](https://app.fabric.microsoft.com)
2. Create Workspace: **SAP-IDoc-Fabric**
3. Assign F64+ capacity
4. Note the Workspace ID

### 5. Create Eventhouse & KQL Database

In Fabric Portal:
1. Create Eventhouse: `kqldbsapidoc`
2. KQL Database auto-creates with same name
3. Note Cluster URI and Eventhouse ID

### 6. Create Data Connection

1. Open Eventhouse → Data connections → New
2. Select **Azure Event Hubs**
3. Configure:
   - Name: `EventHub-idoc-events`
   - Namespace: `eh-idoc-flt8076.servicebus.windows.net`
   - Event Hub: `idoc-events`
   - Consumer group: `fabric-consumer`
   - Authentication: Organizational account (Entra ID)
4. Note the Data Connection ID

### 7. Create Eventstream

**Option A: Via Fabric Portal (Recommended)**
1. Create Eventstream: `SAPIdocIngest`
2. Add Source → Azure Event Hub → Select data connection
3. Add Destination → Eventhouse → Select `kqldbsapidoc`
4. Set mode: **Direct ingestion**
5. Publish

**Option B: Via PowerShell (Hybrid)**
```powershell
cd fabric\eventstream
.\create-eventstream-hybrid.ps1 `
  -WorkspaceName "SAP-IDoc-Fabric" `
  -EventstreamName "SAPIdocIngest" `
  -EventhouseName "kqldbsapidoc" `
  -DataConnectionId "<your-connection-id>"
```

### 8. Install MCP Server (Optional)

Enable KQL queries from VS Code/GitHub Copilot:

Edit `%APPDATA%\Code\User\globalStorage\github.copilot\globalState\mcp.json`:
```json
{
  "mcpServers": {
    "fabric-rti": {
      "command": "uvx",
      "args": ["microsoft-fabric-rti-mcp"],
      "env": {
        "KUSTO_SERVICE_URI": "https://trd-50gjamacvb06uc7dnr.z8.kusto.fabric.microsoft.com",
        "KUSTO_SERVICE_DEFAULT_DB": "kqldbsapidoc"
      }
    }
  }
}
```

Restart VS Code.

### 9. Create KQL Table

**Via MCP Server (in VS Code Copilot Chat):**
```
Execute the script fabric/warehouse/schema/recreate-idoc-table-optimized.kql
```

**Via Fabric Portal:**
1. Open KQL Database → Query
2. Copy content from `fabric/warehouse/schema/recreate-idoc-table-optimized.kql`
3. Paste and Run (F5)

### 10. Configure Eventstream Destination

1. Open Eventstream → Live mode
2. Click Eventhouse destination → Configure
3. Select table: `idoc_raw`
4. Save

### 11. Test End-to-End

Send messages:
```powershell
cd simulator
python main.py --count 10
```

Validate in Fabric:
```kql
// Count messages
idoc_raw | count

// View latest messages
idoc_raw
| top 10 by timestamp desc
| project timestamp, idoc_type, message_type, sap_system

// Distribution by type
idoc_raw
| summarize count() by message_type
| render piechart
```

**Expected Result:** 10+ messages with proper distribution

---

## Validation Checklist

- [ ] Event Hub created and accessible
- [ ] Consumer group `fabric-consumer` exists
- [ ] Simulator sends messages (tested with --count 5)
- [ ] Fabric Workspace created with F64+ capacity
- [ ] Eventhouse and KQL Database created
- [ ] Data Connection configured
- [ ] Eventstream created and published
- [ ] Table `idoc_raw` created with 9 columns
- [ ] MCP server installed (optional)
- [ ] Messages arriving in KQL table
- [ ] All columns populated
- [ ] KQL queries working

---

## Validated Results

✅ **Pipeline tested with 605 messages:**
- WHSCON: 193 messages (32%)
- ORDERS: 144 messages (24%)
- DESADV: 127 messages (21%)
- SHPMNT: 92 messages (15%)
- INVOIC: 44 messages (7%)

✅ **All columns populated correctly**

---

## Key Documentation

| File | Description |
|------|-------------|
| `README.md` | Project overview |
| `FABRIC_QUICKSTART.md` | Fabric quick start (5 min) |
| `SESSION_SUMMARY.md` | Session history |
| `fabric/eventstream/HYBRID_APPROACH_GUIDE.md` | Eventstream automation |
| `fabric/warehouse/schema/recreate-idoc-table-optimized.kql` | KQL table schema |
| `simulator/QUICKSTART.md` | Simulator guide |

---

## Troubleshooting

### Simulator Issues
**Error:** `ImportError: No module named 'azure'`
```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Eventstream Not Receiving Data
1. Check consumer group is `fabric-consumer`
2. Verify RBAC permissions
3. Ensure Eventstream is published
4. Test simulator: `python main.py --count 5`

### Empty KQL Columns
**Cause:** Column names don't match JSON fields

**Solution:** Use `recreate-idoc-table-optimized.kql` with snake_case columns

### MCP Server Issues
1. Check `mcp.json` location
2. Restart VS Code completely
3. Verify `uvx` installed: `uvx --version`
4. Validate environment variables

---

## Next Steps

### Phase 2: Transformation
- [ ] Create materialized views
- [ ] Implement business transformations
- [ ] Create Silver/Gold tables

### Phase 3: GraphQL API
- [ ] Define GraphQL schema
- [ ] Implement resolvers
- [ ] Deploy to Azure Container Apps

### Phase 4: Governance
- [ ] Integrate Microsoft Purview
- [ ] Define data quality rules
- [ ] Catalog assets

### Phase 5: Visualization
- [ ] Power BI real-time dashboard
- [ ] Data Activator alerts
- [ ] Operational monitoring

---

## Success Metrics

| Metric | Target | Result |
|--------|--------|--------|
| Messages sent | > 100 | ✅ 605 |
| Ingestion success | > 99% | ✅ 100% |
| Columns populated | 9/9 | ✅ 9/9 |
| Average latency | < 5 min | ✅ < 1 min |
| Functional KQL queries | > 5 | ✅ 10+ |

---

## Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Eventstream Guide](https://learn.microsoft.com/fabric/real-time-intelligence/event-streams/overview)
- [KQL Database Tutorial](https://learn.microsoft.com/fabric/real-time-intelligence/create-database)
- [KQL Query Language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [GitHub Repository](https://github.com/flthibau/Fabric-SAP-Idocs)

---

**Version:** 1.0  
**Last Updated:** October 24, 2025  
**Status:** Production Ready ✅
