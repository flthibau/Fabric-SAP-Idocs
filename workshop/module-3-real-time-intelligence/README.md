# Module 3: Real-Time Intelligence

> **Working with Eventhouse and KQL queries for real-time analytics**

⏱️ **Duration**: 90 minutes | 🎯 **Level**: Intermediate | 📋 **Prerequisites**: Modules 1-2 completed

---

## 📖 Module Overview

Learn to leverage Microsoft Fabric Real-Time Intelligence for sub-second analytics on SAP IDoc data using Eventhouse and KQL (Kusto Query Language).

### Learning Objectives

- ✅ Understand Fabric Real-Time Intelligence architecture
- ✅ Create and configure Eventhouse (KQL Database)
- ✅ Set up Eventstream for real-time ingestion
- ✅ Write KQL queries for data exploration and analytics
- ✅ Build real-time dashboards and visualizations
- ✅ Implement streaming transformations

---

## 📚 Key Concepts

### Real-Time Intelligence Components

```
Azure Event Hub → Eventstream → Eventhouse → KQL Queries → Dashboards
```

**Eventhouse**: KQL Database optimized for streaming and time-series data
**Eventstream**: No-code stream processing and routing
**KQL**: Powerful query language for log and telemetry data

---

## 🧪 Hands-On Labs

### Lab 1: Create Eventhouse

**Steps**:
1. Open Fabric workspace
2. Create new Eventhouse: `kql-3pl-logistics`
3. Create KQL Database: `idoc_realtime`
4. Configure data retention and caching

**Expected Outcome**: Eventhouse ready for data ingestion

---

### Lab 2: Configure Eventstream

**Steps**:
1. Create Eventstream: `idoc-ingestion-stream`
2. Add Event Hub source
3. Configure destination (Eventhouse)
4. Add data transformations
5. Start stream processing

**Configuration**:
```json
{
  "source": {
    "type": "EventHub",
    "namespace": "eh-idoc-flt8076",
    "eventHub": "idoc-events",
    "consumerGroup": "fabric-ingest"
  },
  "destination": {
    "type": "Eventhouse",
    "database": "idoc_realtime",
    "table": "idoc_raw",
    "dataFormat": "JSON",
    "mappingName": "idoc_mapping"
  }
}
```

---

### Lab 3: Write KQL Queries

**Basic Queries**:

```kql
// View recent messages
idoc_raw
| take 100

// Count by IDoc type
idoc_raw
| summarize count() by idoc_type

// Shipments in last hour
idoc_raw
| where ingestion_time() > ago(1h)
| where idoc_type == "SHPMNT"
| project timestamp, shipment_id, carrier_id, ship_date

// Carrier performance
idoc_raw
| where idoc_type == "SHPMNT"
| summarize 
    ShipmentCount = count(),
    AvgWeight = avg(todouble(weight_kg))
  by carrier_id
| order by ShipmentCount desc

// Time series analysis
idoc_raw
| where ingestion_time() > ago(24h)
| summarize count() by bin(ingestion_time(), 1h), idoc_type
| render timechart
```

**Advanced Analytics**:

```kql
// On-time delivery rate
idoc_raw
| where idoc_type == "DESADV"
| extend 
    IsOnTime = actual_delivery_date <= estimated_delivery_date,
    DelayDays = datetime_diff('day', actual_delivery_date, estimated_delivery_date)
| summarize 
    TotalDeliveries = count(),
    OnTimeDeliveries = countif(IsOnTime),
    AvgDelay = avg(DelayDays)
  by carrier_id
| extend OnTimeRate = round(100.0 * OnTimeDeliveries / TotalDeliveries, 2)
| order by OnTimeRate desc

// Anomaly detection
idoc_raw
| where idoc_type == "SHPMNT"
| make-series Count = count() default=0 on ingestion_time() step 1h
| extend anomalies = series_decompose_anomalies(Count, 1.5)
| mv-expand ingestion_time to typeof(datetime), Count to typeof(long), anomalies to typeof(double)
| where anomalies != 0
| project ingestion_time, Count, anomaly_score=anomalies
```

---

### Lab 4: Create Real-Time Dashboard

**Steps**:
1. Create new Real-Time Dashboard in Fabric
2. Add data source (Eventhouse)
3. Create tiles with KQL queries:
   - Message volume over time
   - Distribution by IDoc type
   - Carrier performance metrics
   - Recent shipments table
4. Configure auto-refresh
5. Add filters and parameters

**Sample Tile Configuration**:
```json
{
  "title": "Shipments by Carrier (Last 24h)",
  "query": "idoc_raw | where ingestion_time() > ago(24h) and idoc_type == 'SHPMNT' | summarize count() by carrier_id | render piechart",
  "refreshInterval": "1m",
  "visualizationType": "pieChart"
}
```

---

## 📋 Knowledge Check

1. What query language is used in Eventhouse? **KQL**
2. What is the typical ingestion latency for Eventhouse? **< 1 second**
3. How do you filter data in the last hour? **`where ingestion_time() > ago(1h)`**

---

## ✅ Module Completion

**Next**: [Module 4: Data Lakehouse](../module-4-data-lakehouse/README.md) - Build Bronze/Silver/Gold layers

---

**[← Module 2](../module-2-event-hub/README.md)** | **[Home](../README.md)** | **[Module 4 →](../module-4-data-lakehouse/README.md)**
