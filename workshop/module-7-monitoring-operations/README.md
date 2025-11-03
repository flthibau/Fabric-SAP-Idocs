# Module 7: Monitoring & Operations

> **Setting up monitoring and operational dashboards**

⏱️ **Duration**: 90 minutes | 🎯 **Level**: Intermediate | 📋 **Prerequisites**: All previous modules completed

---

## 📖 Module Overview

Establish comprehensive monitoring, alerting, and operational dashboards to ensure the data product runs reliably and meets SLA requirements.

### Learning Objectives

- ✅ Configure Azure Monitor and Application Insights
- ✅ Set up Fabric monitoring capabilities
- ✅ Create KQL queries for operational metrics
- ✅ Implement alerting and notifications
- ✅ Build operational dashboards
- ✅ Optimize performance
- ✅ Create troubleshooting runbooks

---

## 📚 Monitoring Architecture

```
┌─────────────────────────────────────────────────────┐
│         Data Sources & Telemetry                    │
├─────────────────────────────────────────────────────┤
│  • Event Hub Metrics                                │
│  • Fabric Eventstream Logs                          │
│  • Lakehouse Query Performance                      │
│  • GraphQL API Traces                               │
│  • APIM Request Logs                                │
└──────────────┬──────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────┐
│         Azure Monitor / Log Analytics               │
│  • Centralized log aggregation                      │
│  • Metrics collection                               │
│  • KQL query interface                              │
└──────────────┬──────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────┐
│         Alerts & Dashboards                         │
│  • Alert rules                                      │
│  • Action groups (email, webhook, SMS)              │
│  • Azure Dashboards                                 │
│  • Power BI reports                                 │
└─────────────────────────────────────────────────────┘
```

---

## 🧪 Hands-On Labs

### Lab 1: Configure Azure Monitor

**Create Log Analytics Workspace**:

```bash
# Create workspace
az monitor log-analytics workspace create \
  --resource-group rg-fabric-sap-idocs \
  --workspace-name law-fabric-sap-idocs \
  --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-fabric-sap-idocs \
  --workspace-name law-fabric-sap-idocs \
  --query customerId -o tsv)
```

**Enable diagnostic settings on Event Hub**:

```bash
EVENT_HUB_ID="/subscriptions/<sub-id>/resourceGroups/rg-fabric-sap-idocs/providers/Microsoft.EventHub/namespaces/eh-idoc-flt8076"

az monitor diagnostic-settings create \
  --resource $EVENT_HUB_ID \
  --name "send-to-law" \
  --workspace $WORKSPACE_ID \
  --logs '[
    {
      "category": "OperationalLogs",
      "enabled": true,
      "retentionPolicy": {"enabled": false, "days": 0}
    },
    {
      "category": "AutoScaleLogs",
      "enabled": true,
      "retentionPolicy": {"enabled": false, "days": 0}
    }
  ]' \
  --metrics '[
    {
      "category": "AllMetrics",
      "enabled": true,
      "retentionPolicy": {"enabled": false, "days": 0}
    }
  ]'
```

**Enable diagnostic settings on APIM**:

```bash
APIM_ID="/subscriptions/<sub-id>/resourceGroups/rg-fabric-sap-idocs/providers/Microsoft.ApiManagement/service/apim-3pl-logistics"

az monitor diagnostic-settings create \
  --resource $APIM_ID \
  --name "send-to-law" \
  --workspace $WORKSPACE_ID \
  --logs '[
    {
      "category": "GatewayLogs",
      "enabled": true
    }
  ]' \
  --metrics '[
    {
      "category": "AllMetrics",
      "enabled": true
    }
  ]'
```

---

### Lab 2: Operational KQL Queries

**Event Hub Monitoring**:

```kql
// Incoming message rate
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where Category == "OperationalLogs"
| where OperationName == "Incoming Messages"
| summarize MessageCount = sum(EventCount) by bin(TimeGenerated, 5m)
| render timechart

// Error rate
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where Category == "OperationalLogs"
| where Level == "Error"
| summarize ErrorCount = count() by bin(TimeGenerated, 5m), OperationName
| render timechart

// Throttling events
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where OperationName contains "Throttle"
| project TimeGenerated, OperationName, Resource, CallerIpAddress
| order by TimeGenerated desc
```

**APIM Monitoring**:

```kql
// API request volume by partner
ApiManagementGatewayLogs
| where OperationId == "partner-logistics-api"
| extend PartnerId = tostring(parse_json(RequestHeaders)["X-Partner-ID"])
| summarize RequestCount = count() by bin(TimeGenerated, 5m), PartnerId
| render timechart

// Response time percentiles
ApiManagementGatewayLogs
| where OperationId == "partner-logistics-api"
| summarize 
    p50 = percentile(ResponseTime, 50),
    p95 = percentile(ResponseTime, 95),
    p99 = percentile(ResponseTime, 99)
  by bin(TimeGenerated, 5m)
| render timechart

// Error rate by status code
ApiManagementGatewayLogs
| where ResponseCode >= 400
| summarize ErrorCount = count() by bin(TimeGenerated, 5m), ResponseCode
| render timechart

// Top slow queries
ApiManagementGatewayLogs
| where OperationId == "partner-logistics-api"
| top 20 by ResponseTime desc
| project TimeGenerated, RequestIpAddress, RequestUrl, ResponseTime, ResponseCode
```

**Fabric Lakehouse Performance**:

```kql
// Query in Fabric Real-Time Intelligence

// Table sizes and growth
database("<database-name>").Tables
| project TableName, TotalExtents, TotalOriginalSize, TotalExtentSize
| order by TotalExtentSize desc

// Query performance
.show queries
| where StartedOn > ago(24h)
| summarize 
    QueryCount = count(),
    AvgDuration = avg(Duration),
    MaxDuration = max(Duration)
  by bin(StartedOn, 1h)
| render timechart

// Ingestion metrics
.show ingestion failures
| where FailedOn > ago(24h)
| summarize FailureCount = count() by bin(FailedOn, 1h), FailureKind
| render timechart
```

---

### Lab 3: Create Alert Rules

**Event Hub ingestion failure alert**:

```bash
# Create action group
az monitor action-group create \
  --name ag-data-team \
  --resource-group rg-fabric-sap-idocs \
  --short-name DataTeam \
  --email-receiver name=DataTeam email=data-team@company.com

# Create alert rule
az monitor metrics alert create \
  --name "Event Hub Ingestion Failures" \
  --resource-group rg-fabric-sap-idocs \
  --scopes $EVENT_HUB_ID \
  --condition "avg ServerErrors > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action ag-data-team \
  --description "Alert when Event Hub has more than 10 server errors in 5 minutes" \
  --severity 2
```

**API response time alert**:

```bash
az monitor metrics alert create \
  --name "API High Latency" \
  --resource-group rg-fabric-sap-idocs \
  --scopes $APIM_ID \
  --condition "avg Duration > 1000" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action ag-data-team \
  --description "Alert when API response time exceeds 1 second" \
  --severity 3
```

**Log-based alert for data quality**:

```bash
# Create scheduled query alert
az monitor scheduled-query create \
  --name "Data Quality Issues" \
  --resource-group rg-fabric-sap-idocs \
  --scopes $WORKSPACE_ID \
  --condition "count > 10" \
  --condition-query "
    CustomLogs 
    | where Category == 'DataQuality' 
    | where Severity == 'Critical'
    | summarize count()
  " \
  --window-size 15m \
  --evaluation-frequency 5m \
  --action ag-data-team \
  --description "Alert on critical data quality issues" \
  --severity 1
```

---

### Lab 4: Build Operational Dashboard

**Azure Portal Dashboard JSON**:

```json
{
  "properties": {
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "resourceId",
                  "value": "/subscriptions/<sub-id>/resourceGroups/rg-fabric-sap-idocs/providers/Microsoft.EventHub/namespaces/eh-idoc-flt8076"
                },
                {
                  "name": "timeRange",
                  "value": "PT1H"
                },
                {
                  "name": "chartType",
                  "value": "Line"
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {
                "content": {
                  "chartType": "Line",
                  "metrics": [
                    {
                      "name": "IncomingMessages",
                      "aggregationType": "Total"
                    }
                  ]
                }
              }
            }
          },
          "1": {
            "position": {
              "x": 6,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "resourceId",
                  "value": "/subscriptions/<sub-id>/resourceGroups/rg-fabric-sap-idocs/providers/Microsoft.ApiManagement/service/apim-3pl-logistics"
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {
                "content": {
                  "metrics": [
                    {
                      "name": "TotalRequests",
                      "aggregationType": "Total"
                    },
                    {
                      "name": "FailedRequests",
                      "aggregationType": "Total"
                    }
                  ]
                }
              }
            }
          }
        }
      }
    },
    "metadata": {
      "model": {
        "timeRange": {
          "value": {
            "relative": {
              "duration": 24,
              "timeUnit": 1
            }
          },
          "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  },
  "name": "SAP IDoc Data Product - Operations Dashboard",
  "type": "Microsoft.Portal/dashboards",
  "location": "eastus",
  "tags": {
    "hidden-title": "SAP IDoc Operations"
  }
}
```

**Power BI Real-Time Dashboard**:

Create Power BI report connected to:
1. **Log Analytics** - System metrics
2. **Fabric Eventhouse** - Data quality metrics
3. **APIM Analytics** - API usage

Key visuals:
- Message ingestion rate (last 24h)
- API request volume by partner
- Response time percentiles
- Error rate trends
- Data quality scores
- SLA compliance metrics

---

### Lab 5: Performance Optimization

**Delta Table Optimization**:

```sql
-- Optimize frequently queried tables
OPTIMIZE gold.shipments
ZORDER BY (customer_id, ship_date);

OPTIMIZE gold.orders
ZORDER BY (customer_id, order_date);

-- Vacuum old versions
VACUUM gold.shipments RETAIN 168 HOURS;
VACUUM gold.orders RETAIN 168 HOURS;

-- Update statistics
ANALYZE TABLE gold.shipments COMPUTE STATISTICS;
ANALYZE TABLE gold.orders COMPUTE STATISTICS FOR ALL COLUMNS;
```

**Query Performance Tuning**:

```sql
-- Add indexes on frequently filtered columns
CREATE INDEX idx_shipments_customer ON gold.shipments(customer_id, ship_date);
CREATE INDEX idx_shipments_carrier ON gold.shipments(carrier_id, ship_date);

-- Create materialized views for common queries
CREATE MATERIALIZED VIEW gold.mv_shipments_daily
AS
SELECT 
    ship_date,
    customer_id,
    carrier_id,
    COUNT(*) as shipment_count,
    SUM(total_weight) as total_weight,
    SUM(total_value) as total_value
FROM gold.shipments
GROUP BY ship_date, customer_id, carrier_id;

-- Refresh materialized view (scheduled)
REFRESH MATERIALIZED VIEW gold.mv_shipments_daily;
```

**APIM Caching**:

```xml
<policies>
  <inbound>
    <!-- Cache common queries for 5 minutes -->
    <cache-lookup vary-by-developer="false" 
                  vary-by-developer-groups="false">
      <vary-by-header>X-Partner-ID</vary-by-header>
      <vary-by-query-parameter>limit</vary-by-query-parameter>
      <vary-by-query-parameter>startDate</vary-by-query-parameter>
    </cache-lookup>
  </inbound>
  
  <outbound>
    <cache-store duration="300" />
  </outbound>
</policies>
```

---

### Lab 6: Troubleshooting Runbooks

**Runbook: Event Hub Ingestion Failure**

```markdown
## Symptom
- Alert: "Event Hub Ingestion Failures"
- Messages not flowing to Eventhouse

## Investigation
1. Check Event Hub metrics in Azure Portal
   - Incoming/Outgoing messages
   - Server errors
   - Throttling requests

2. Query Log Analytics
   ```kql
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.EVENTHUB"
   | where Level == "Error"
   | order by TimeGenerated desc
   | take 50
   ```

3. Check Eventstream status in Fabric
   - Is stream running?
   - Check error logs

## Common Causes
- **Throttling**: Increase throughput units
- **Connection issues**: Check firewall rules
- **Consumer lag**: Scale consumers or increase partitions
- **Authentication**: Verify connection string

## Resolution
1. Temporary: Restart Eventstream
2. Permanent: Address root cause (throttling, scale, etc.)

## Prevention
- Enable auto-inflate on Event Hub
- Monitor throughput utilization
- Set up proactive alerts
```

**Runbook: API High Latency**

```markdown
## Symptom
- Alert: "API High Latency"
- Response times > 1 second

## Investigation
1. Check APIM Analytics
   - Identify slow operations
   - Check backend response time vs. APIM overhead

2. Query Log Analytics
   ```kql
   ApiManagementGatewayLogs
   | where ResponseTime > 1000
   | summarize count(), avg(ResponseTime) by OperationId, BackendUrl
   | order by avg_ResponseTime desc
   ```

3. Check Fabric query performance
   ```sql
   -- In Fabric Warehouse
   .show queries
   | where Duration > 1s
   | order by Duration desc
   ```

## Common Causes
- **Unoptimized queries**: Missing indexes, full table scans
- **Large result sets**: No pagination
- **RLS overhead**: Complex security predicates
- **Cache misses**: Cold cache

## Resolution
1. Optimize slow queries (add indexes, Z-ordering)
2. Implement/improve caching in APIM
3. Add pagination to GraphQL queries
4. Review and optimize RLS predicates

## Prevention
- Regular Delta table optimization
- Monitor query patterns
- Implement proper caching strategy
- Load testing before production
```

---

## 📋 SLA Monitoring

**Key Metrics**:

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Availability** | 99.9% | < 99.5% |
| **Ingestion Latency** | < 1 min | > 5 min |
| **API Response Time (p95)** | < 500ms | > 1000ms |
| **Data Freshness** | < 5 min | > 10 min |
| **Error Rate** | < 0.1% | > 1% |

**SLA Dashboard Query**:

```kql
// Calculate SLA compliance
let TotalRequests = ApiManagementGatewayLogs
  | where TimeGenerated > ago(30d)
  | count;

let SuccessfulRequests = ApiManagementGatewayLogs
  | where TimeGenerated > ago(30d)
  | where ResponseCode < 400
  | count;

print 
  TotalRequests,
  SuccessfulRequests,
  Availability = round(100.0 * SuccessfulRequests / TotalRequests, 2),
  SLATarget = 99.9,
  SLAMet = iff(100.0 * SuccessfulRequests / TotalRequests >= 99.9, "Yes", "No")
```

---

## ✅ Module Completion

### Summary

In this module, you learned:

- ✅ Configure Azure Monitor and Log Analytics
- ✅ Create operational KQL queries
- ✅ Set up alerts and notifications
- ✅ Build operational dashboards
- ✅ Optimize performance
- ✅ Create troubleshooting runbooks
- ✅ Monitor SLA compliance

### Workshop Complete! 🎉

**Congratulations!** You've completed all 7 modules and built a production-ready SAP IDoc data product with:

- ✅ Real-time data ingestion
- ✅ Medallion architecture (Bronze/Silver/Gold)
- ✅ Row-Level Security
- ✅ GraphQL and REST APIs
- ✅ Microsoft Purview governance
- ✅ Comprehensive monitoring

**Next Steps**:
1. Review the [Reference Architecture](../../docs/architecture.md)
2. Explore the [Demo Application](../../demo-app/)
3. Customize for your specific use case
4. Join the community and contribute

---

**[← Module 6](../module-6-api-development/README.md)** | **[Back to Workshop Home](../README.md)**
