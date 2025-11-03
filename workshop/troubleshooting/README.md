# Workshop Troubleshooting Guide

> **Common issues and solutions for the SAP IDoc Fabric workshop**

---

## 📋 Table of Contents

1. [Environment Setup Issues](#environment-setup-issues)
2. [Event Hub Issues](#event-hub-issues)
3. [Fabric Workspace Issues](#fabric-workspace-issues)
4. [Simulator Issues](#simulator-issues)
5. [API Issues](#api-issues)
6. [Security & RLS Issues](#security--rls-issues)
7. [Performance Issues](#performance-issues)
8. [Getting Help](#getting-help)

---

## Environment Setup Issues

### Azure CLI Authentication Fails

**Symptom**: `az login` fails or returns authentication error

**Solutions**:
```bash
# Clear cached credentials
az account clear

# Login with specific tenant
az login --tenant <tenant-id>

# Use device code flow (for remote sessions)
az login --use-device-code

# Login with service principal
az login --service-principal \
  --username <app-id> \
  --password <password> \
  --tenant <tenant-id>
```

### Python Virtual Environment Issues

**Symptom**: Cannot activate virtual environment or packages not found

**Solutions**:
```bash
# Recreate virtual environment
rm -rf venv
python -m venv venv

# Ensure you're using the right Python
which python  # Linux/Mac
where python  # Windows

# Verify activation
# You should see (venv) in your prompt
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install packages again
pip install -r requirements.txt
```

### Missing Dependencies

**Symptom**: `ModuleNotFoundError` when running Python scripts

**Solutions**:
```bash
# Verify virtual environment is activated
which python  # Should show path in venv folder

# Reinstall all dependencies
pip install --upgrade -r requirements.txt

# Install specific package
pip install azure-eventhub

# Check installed packages
pip list
```

---

## Event Hub Issues

### Connection String Issues

**Symptom**: `EventHubError: The messaging entity could not be found`

**Solutions**:
```bash
# Verify connection string format
echo $EVENT_HUB_CONNECTION_STRING

# Should look like:
# Endpoint=sb://namespace.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=...

# Get correct connection string
az eventhubs namespace authorization-rule keys list \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace-name> \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv

# Verify Event Hub exists
az eventhubs eventhub show \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace-name> \
  --name idoc-events
```

### Throttling Errors

**Symptom**: `ServerBusyError` or `QuotaExceededException`

**Solutions**:
```bash
# Check current throughput units
az eventhubs namespace show \
  --resource-group rg-fabric-sap-idocs \
  --name <namespace-name> \
  --query "sku.capacity"

# Increase throughput units
az eventhubs namespace update \
  --resource-group rg-fabric-sap-idocs \
  --name <namespace-name> \
  --capacity 2

# Enable auto-inflate
az eventhubs namespace update \
  --resource-group rg-fabric-sap-idocs \
  --name <namespace-name> \
  --enable-auto-inflate true \
  --maximum-throughput-units 10

# Check metrics in portal
# Look for "Throttled Requests" metric
```

### Network/Firewall Issues

**Symptom**: Connection timeout or "Connection refused"

**Solutions**:
```bash
# Test connectivity
telnet <namespace>.servicebus.windows.net 5671

# Check if firewall is blocking port 5671 or 443
# Event Hub supports both AMQP (5671) and HTTPS (443)

# Use HTTPS transport (in code)
# Add to Python:
from azure.eventhub import TransportType
producer = EventHubProducerClient.from_connection_string(
    conn_str,
    eventhub_name=eh_name,
    transport_type=TransportType.AmqpOverWebsocket  # Uses port 443
)

# Check Event Hub firewall rules
az eventhubs namespace network-rule-set show \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace-name>
```

---

## Fabric Workspace Issues

### Cannot Access Workspace

**Symptom**: "Access Denied" when trying to open Fabric workspace

**Solutions**:
1. **Check Fabric License**:
   - Ensure you have Fabric capacity assigned
   - Verify capacity is running (not paused)

2. **Check Workspace Permissions**:
   - Go to Workspace Settings → Users
   - Ensure you have Admin or Member role
   - Ask workspace admin to grant access

3. **Verify Fabric is Enabled**:
   - Check Azure subscription has Fabric enabled
   - Contact admin to enable Fabric

### Eventstream Won't Start

**Symptom**: Eventstream shows error or won't start

**Solutions**:
```bash
# Check Event Hub connection
# In Eventstream source settings:
# - Verify connection string
# - Check consumer group exists
# - Ensure Event Hub namespace is running

# Verify consumer group
az eventhubs eventhub consumer-group show \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace> \
  --eventhub-name idoc-events \
  --name fabric-ingest

# Create if missing
az eventhubs eventhub consumer-group create \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace> \
  --eventhub-name idoc-events \
  --name fabric-ingest

# Check Eventstream error logs
# In Fabric portal: Eventstream → Monitoring → Error logs
```

### Lakehouse Tables Not Appearing

**Symptom**: Created tables don't show up in Lakehouse

**Solutions**:
1. **Refresh Lakehouse**:
   - Click refresh button in Lakehouse explorer
   - Wait 30-60 seconds for metadata sync

2. **Check Table Location**:
   ```sql
   -- Verify table exists
   SHOW TABLES IN lakehouse_3pl;
   
   -- Check table location
   DESCRIBE FORMATTED lakehouse_3pl.bronze_idocs;
   ```

3. **Recreate Table**:
   ```sql
   DROP TABLE IF EXISTS lakehouse_3pl.bronze_idocs;
   
   CREATE TABLE lakehouse_3pl.bronze_idocs (...)
   USING DELTA
   LOCATION 'Files/bronze/idocs';
   ```

---

## Simulator Issues

### Simulator Won't Generate Messages

**Symptom**: Simulator runs but no messages are generated

**Solutions**:
```bash
# Check configuration
cat config.yaml

# Verify environment variables
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
print('EVENT_HUB_CONNECTION_STRING:', os.getenv('EVENT_HUB_CONNECTION_STRING')[:50] + '...')
print('EVENT_HUB_NAME:', os.getenv('EVENT_HUB_NAME'))
"

# Run with debug logging
python main.py --count 10 --verbose

# Test Event Hub connection
python test_connection.py
```

### Invalid IDoc Format

**Symptom**: Messages generated but fail validation

**Solutions**:
1. **Review IDoc schema**:
   ```bash
   # Check schema definitions
   cat simulator/idoc_schemas/shipment_schema.py
   ```

2. **Validate single message**:
   ```python
   from idoc_generator import IdocGenerator
   import yaml
   
   with open('config.yaml') as f:
       config = yaml.safe_load(f)
   
   gen = IdocGenerator(config)
   message = gen.generate_single('SHPMNT')
   print(json.dumps(message, indent=2))
   ```

3. **Check error logs**:
   - Review Eventstream error logs in Fabric
   - Check dead-letter queue if configured

---

## API Issues

### GraphQL API Not Accessible

**Symptom**: Cannot connect to GraphQL endpoint

**Solutions**:
1. **Verify GraphQL is enabled**:
   - In Fabric Lakehouse → Settings
   - Check "GraphQL API" is enabled
   - Copy correct endpoint URL

2. **Test endpoint**:
   ```bash
   # Simple connectivity test
   curl https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql
   ```

3. **Check authentication**:
   ```bash
   # Get valid token
   az account get-access-token --resource https://api.fabric.microsoft.com
   
   # Test with token
   curl -H "Authorization: Bearer <token>" \
        https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql
   ```

### OAuth2 Token Issues

**Symptom**: 401 Unauthorized when calling API

**Solutions**:
```powershell
# Verify Service Principal
az ad sp show --id <sp-id>

# Check app roles assigned
az ad app permission list --id <app-id>

# Get fresh token
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

# Decode JWT to verify claims
# Use https://jwt.ms to decode token
Write-Host $response.access_token
```

### APIM Returns 500 Error

**Symptom**: API Management returns internal server error

**Solutions**:
1. **Check APIM logs**:
   ```bash
   # Enable diagnostic logs
   az monitor diagnostic-settings create \
     --resource <apim-resource-id> \
     --workspace <law-id> \
     --logs '[{"category": "GatewayLogs", "enabled": true}]'
   
   # Query logs
   # In Log Analytics:
   ```kql
   ApiManagementGatewayLogs
   | where ResponseCode >= 500
   | order by TimeGenerated desc
   | take 20
   ```

2. **Test backend directly**:
   ```bash
   # Bypass APIM and test GraphQL directly
   curl -X POST \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"query": "{ shipments(limit: 1) { edges { node { shipmentNumber } } } }"}' \
     https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql
   ```

---

## Security & RLS Issues

### RLS Not Filtering Data

**Symptom**: User sees data they shouldn't (RLS not working)

**Solutions**:
```sql
-- Verify security policy exists and is enabled
SELECT 
    name,
    is_enabled,
    is_schema_bound
FROM sys.security_policies;

-- Check predicate definition
SELECT 
    sp.name AS policy_name,
    o.name AS table_name,
    spp.predicate_definition
FROM sys.security_policies sp
JOIN sys.security_predicates spp ON sp.object_id = spp.object_id
JOIN sys.objects o ON spp.target_object_id = o.object_id;

-- Test with specific session context
EXEC sp_set_session_context 'PartnerID', 'FEDEX', @read_only = 1;
SELECT * FROM gold.shipments;
-- Should only return FEDEX shipments

-- Verify session context is set
SELECT SESSION_CONTEXT(N'PartnerID');

-- Check if user is in admin role (admins see all)
SELECT IS_MEMBER('DataAdmin');
```

### Service Principal Can't Access Data

**Symptom**: Service Principal authentication works but returns no data

**Solutions**:
1. **Grant workspace access**:
   - Add Service Principal to Fabric workspace
   - Role: Viewer (for read-only API access)

2. **Verify RLS configuration**:
   ```sql
   -- Check if partner_id column exists
   SELECT partner_id FROM gold.shipments LIMIT 1;
   
   -- Verify partner_id values match SP claim
   SELECT DISTINCT partner_id FROM gold.shipments;
   ```

3. **Check JWT claims**:
   - Decode token at https://jwt.ms
   - Verify `partner_id` claim is present
   - Ensure claim value matches data in tables

---

## Performance Issues

### Slow Query Performance

**Symptom**: GraphQL queries take > 1 second

**Solutions**:
```sql
-- Check query execution plan
EXPLAIN SELECT * FROM gold.shipments 
WHERE customer_id = 'ACME' AND ship_date >= '2025-01-01';

-- Add missing indexes
CREATE INDEX idx_shipments_customer_date 
ON gold.shipments(customer_id, ship_date);

-- Optimize Delta tables
OPTIMIZE gold.shipments
ZORDER BY (customer_id, ship_date);

-- Update statistics
ANALYZE TABLE gold.shipments COMPUTE STATISTICS FOR ALL COLUMNS;

-- Check table size and partitions
DESCRIBE DETAIL gold.shipments;
```

### High API Latency

**Symptom**: APIM reports high response times

**Solutions**:
1. **Enable caching in APIM**:
   ```xml
   <cache-lookup vary-by-developer="false">
     <vary-by-header>X-Partner-ID</vary-by-header>
   </cache-lookup>
   ```

2. **Optimize GraphQL queries**:
   - Add pagination (limit results)
   - Avoid deep nesting
   - Use DataLoaders to prevent N+1 queries

3. **Scale Fabric capacity**:
   - Increase Fabric capacity tier
   - Monitor CPU/memory usage

---

## Getting Help

### Self-Help Resources

1. **Documentation**:
   - [Main README](../README.md)
   - [Architecture Guide](../../docs/architecture.md)
   - [Module Guides](../)

2. **Azure Documentation**:
   - [Event Hubs Docs](https://learn.microsoft.com/azure/event-hubs/)
   - [Microsoft Fabric Docs](https://learn.microsoft.com/fabric/)
   - [APIM Docs](https://learn.microsoft.com/azure/api-management/)

### Community Support

1. **GitHub Issues**:
   - Search existing issues: [Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
   - Create new issue with:
     - Error message
     - Steps to reproduce
     - Environment details

2. **GitHub Discussions**:
   - Ask questions: [Discussions](https://github.com/flthibau/Fabric-SAP-Idocs/discussions)
   - Share experiences
   - Help others

### Reporting Bugs

When reporting bugs, include:

```markdown
**Environment**:
- OS: [Windows/Linux/Mac]
- Python version: [output of `python --version`]
- Azure CLI version: [output of `az --version`]
- Module: [which module you're working on]

**Steps to Reproduce**:
1. [First step]
2. [Second step]
3. [...]

**Expected Behavior**:
[What you expected to happen]

**Actual Behavior**:
[What actually happened]

**Error Messages**:
```
[Paste error messages here]
```

**Screenshots**:
[If applicable]
```

---

**[← Back to Workshop Home](../README.md)**
