# Workshop Quick Reference Card

> **Quick reference for commands, concepts, and resources used throughout the workshop**

---

## 📦 Essential Commands

### Azure CLI

```bash
# Login
az login

# Set subscription
az account set --subscription "Your Subscription"

# Create resource group
az group create --name rg-fabric-sap-idocs --location eastus

# Deploy Bicep template
az deployment group create \
  --resource-group rg-fabric-sap-idocs \
  --template-file template.bicep

# Get Event Hub connection string
az eventhubs namespace authorization-rule keys list \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace> \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv
```

### Python Environment

```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (Linux/Mac)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Deactivate
deactivate
```

### IDoc Simulator

```bash
# Generate 100 messages
python main.py --count 100

# Continuous generation
python main.py --count 0

# With verbose logging
python main.py --count 50 --verbose
```

---

## 📊 KQL Quick Reference

### Basic Queries

```kql
// Take first 10 rows
TableName
| take 10

// Filter by condition
TableName
| where ColumnName == "value"

// Count rows
TableName
| count

// Group and aggregate
TableName
| summarize count() by ColumnName

// Time-based filter
TableName
| where ingestion_time() > ago(1h)

// Sort results
TableName
| order by ColumnName desc

// Select specific columns
TableName
| project Column1, Column2, Column3
```

### Advanced Analytics

```kql
// Time series aggregation
TableName
| summarize count() by bin(timestamp, 1h)
| render timechart

// Percentiles
TableName
| summarize 
    p50 = percentile(ResponseTime, 50),
    p95 = percentile(ResponseTime, 95),
    p99 = percentile(ResponseTime, 99)

// Join tables
Table1
| join kind=inner (Table2) on KeyColumn

// Moving average
TableName
| make-series Value = avg(Metric) default=0 on timestamp step 1h
| extend MA = series_fir(Value, repeat(1, 5))
```

---

## 🔐 Security & RLS

### Configure OneLake Security RLS

**OneLake Security** is configured through the **Fabric Portal UI**, providing storage-layer security across all Fabric engines:

**Steps:**
1. Open Fabric Portal → Lakehouse → SQL Analytics Endpoint
2. Navigate to **Security** → **Manage security roles**
3. Click **+ New role** (e.g., `CARRIER-FEDEX`)
4. Add filter predicate using DAX:
   ```dax
   [carrier_id] = "CARRIER-FEDEX-GROUP"
   ```
5. Assign Service Principal to role

**Key Difference from SQL Server RLS:**
- ❌ No `CREATE FUNCTION` or `CREATE SECURITY POLICY` SQL code
- ✅ UI-based configuration with DAX filter expressions
- ✅ Works across KQL, Spark, SQL, Power BI, GraphQL automatically

### Test RLS Access

**Via SQL Analytics Endpoint:**
```sql
-- Query as Service Principal (automatically filtered by RLS)
SELECT carrier_id, COUNT(*) as shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id
-- Returns only CARRIER-FEDEX-GROUP when authenticated as FedEx SP
```

**Via GraphQL API:**
```graphql
query GetShipments {
  gold_shipments_in_transits(first: 10) {
    items {
      carrier_id
      shipment_number
    }
  }
}
# Automatically filtered based on Service Principal's RLS role
```

---

## 🌐 GraphQL Quick Reference

### Basic Query

```graphql
query GetShipments {
  shipments(limit: 10) {
    edges {
      node {
        id
        shipmentNumber
        shipDate
        carrier {
          name
        }
        customer {
          name
        }
      }
    }
    pageInfo {
      hasNextPage
    }
    totalCount
  }
}
```

### With Filters

```graphql
query FilteredShipments {
  shipments(
    filters: {
      startDate: "2025-01-01"
      endDate: "2025-01-31"
      status: IN_TRANSIT
    }
    limit: 20
  ) {
    edges {
      node {
        shipmentNumber
        status
      }
    }
  }
}
```

### Using Variables

```graphql
query GetShipment($id: ID!) {
  shipment(id: $id) {
    shipmentNumber
    shipDate
    carrier { name }
  }
}

# Variables:
{
  "id": "SHIP-001234"
}
```

---

## 🔧 Delta Lake Commands

### Table Operations

```sql
-- Create Delta table
CREATE TABLE table_name (
    col1 STRING,
    col2 INT,
    col3 DATE
)
USING DELTA
PARTITIONED BY (col3)
LOCATION 'Files/path/to/table';

-- Optimize table
OPTIMIZE table_name
ZORDER BY (col1, col2);

-- Vacuum old versions
VACUUM table_name RETAIN 168 HOURS;

-- Update statistics
ANALYZE TABLE table_name COMPUTE STATISTICS FOR ALL COLUMNS;

-- Time travel
SELECT * FROM table_name VERSION AS OF 5;
SELECT * FROM table_name TIMESTAMP AS OF '2025-01-15';

-- Table history
DESCRIBE HISTORY table_name;
```

### Merge (Upsert)

```python
from delta.tables import DeltaTable

delta_table = DeltaTable.forName(spark, "table_name")

delta_table.alias("target").merge(
    source_df.alias("source"),
    "target.id = source.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

---

## 🔍 Monitoring & Diagnostics

### Azure Monitor Queries

```kql
// Event Hub errors
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where Level == "Error"
| order by TimeGenerated desc
| take 50

// API performance
ApiManagementGatewayLogs
| summarize 
    AvgResponseTime = avg(ResponseTime),
    p95ResponseTime = percentile(ResponseTime, 95)
  by bin(TimeGenerated, 5m)
| render timechart

// Error rate
ApiManagementGatewayLogs
| where ResponseCode >= 400
| summarize ErrorCount = count() by bin(TimeGenerated, 5m), ResponseCode
| render timechart
```

### PowerShell - Get Token

```powershell
# Get OAuth2 token
$body = @{
    grant_type = "client_credentials"
    client_id = "<client-id>"
    client_secret = "<client-secret>"
    scope = "api://partner-logistics-api/.default"
}

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token" `
    -Body $body

$token = $response.access_token
```

---

## 📚 Key Concepts

### Medallion Architecture

- **Bronze**: Raw IDoc data ingested into Eventhouse (KQL tables)
- **Silver**: Cleansed, normalized data in Eventhouse (via KQL update policies)
- **Gold**: Business-ready aggregations and dimensions in Lakehouse (via materialized lake views)
- **Mirroring**: Bronze and Silver auto-mirror from Eventhouse to Lakehouse as Delta tables

### Event Hub Concepts

- **Partition**: Ordered sequence of events
- **Partition Key**: Determines routing to partitions
- **Consumer Group**: Independent view of event stream
- **Throughput Unit**: Measure of ingestion/egress capacity

### RLS Concepts

- **Security Predicate**: Filter function applied to queries
- **Blocking Predicate**: Prevents unauthorized INSERT/UPDATE/DELETE
- **Session Context**: Stores user identity for RLS evaluation
- **Schema Binding**: Ensures predicate references valid objects

---

## 🔗 Quick Links

### Documentation
- [Main Workshop README](./README.md)
- [Setup Guide](./setup/azure-setup.md)
- [Troubleshooting](./troubleshooting/README.md)
- [Project README](../README.md)

### Modules
- [Module 1: Architecture](./module-1-architecture/README.md)
- [Module 2: Event Hub](./module-2-event-hub/README.md)
- [Module 3: Real-Time Intelligence](./module-3-real-time-intelligence/README.md)
- [Module 4: Data Lakehouse](./module-4-data-lakehouse/README.md)
- [Module 5: Security & Governance](./module-5-security-governance/README.md)
- [Module 6: API Development](./module-6-api-development/README.md)
- [Module 7: Monitoring](./module-7-monitoring-operations/README.md)

### External Resources
- [Microsoft Fabric Docs](https://learn.microsoft.com/fabric/)
- [Azure Event Hubs](https://learn.microsoft.com/azure/event-hubs/)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [GraphQL Docs](https://graphql.org/learn/)
- [Delta Lake Guide](https://delta.io/)

---

## 💡 Tips & Best Practices

### Performance
- Use Z-ordering on frequently queried columns
- Implement pagination in API queries
- Cache common queries in APIM
- Optimize Delta tables regularly

### Security
- Rotate Service Principal secrets regularly
- Apply RLS at storage layer (OneLake)
- Use separate Service Principals per partner
- Store secrets in Azure Key Vault

### Monitoring
- Set up alerts for SLA violations
- Monitor API usage by partner
- Track data quality metrics
- Review error logs daily

### Development
- Use virtual environments for Python
- Test RLS with multiple identities
- Version control all configurations
- Document custom transformations

---

**[← Back to Workshop Home](./README.md)**
