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
    "table": "bronze_idocs",
    "dataFormat": "JSON",
    "mappingName": "idoc_mapping"
  }
}
```

**Note**: This creates the Bronze layer in Eventhouse where raw IDoc data is ingested.

---

### Lab 3: Create Silver Layer with KQL Update Policies

**Steps**:
1. Create Silver layer tables in Eventhouse
2. Define KQL update policies to transform Bronze → Silver in real-time
3. Test the transformation pipeline
4. Verify data quality

**Create Silver Tables**:
```kql
// Create silver_shipments table
.create table silver_shipments (
    shipment_id: string,
    shipment_number: string,
    customer_id: string,
    customer_name: string,
    carrier_id: string,
    ship_date: datetime,
    delivery_date: datetime,
    total_weight: real,
    tracking_number: string,
    status: string,
    created_timestamp: datetime,
    source_idoc_number: string
)

// Create silver_orders table
.create table silver_orders (
    order_id: string,
    order_number: string,
    customer_id: string,
    order_date: datetime,
    total_value: real,
    status: string,
    created_timestamp: datetime,
    source_idoc_number: string
)
```

**Define KQL Update Policy (Bronze → Silver)**:
```kql
// Update policy for shipments transformation
.alter table silver_shipments policy update 
@'[{
    "IsEnabled": true,
    "Source": "bronze_idocs",
    "Query": "bronze_idocs | where idoc_type == \'SHPMNT\' | extend parsed = parse_json(raw_payload) | project shipment_id = tostring(parsed.header.shipment_id), shipment_number = tostring(parsed.header.shipment_number), customer_id = tostring(parsed.customer.customer_id), customer_name = tostring(parsed.customer.customer_name), carrier_id = tostring(parsed.carrier.carrier_id), ship_date = todatetime(parsed.header.ship_date), delivery_date = todatetime(parsed.header.delivery_date), total_weight = toreal(parsed.total_weight), tracking_number = tostring(parsed.tracking_number), status = tostring(parsed.status), created_timestamp = now(), source_idoc_number = idoc_number",
    "IsTransactional": false,
    "PropagateIngestionProperties": false
}]'

// Update policy for orders transformation
.alter table silver_orders policy update 
@'[{
    "IsEnabled": true,
    "Source": "bronze_idocs",
    "Query": "bronze_idocs | where idoc_type == \'ORDERS\' | extend parsed = parse_json(raw_payload) | project order_id = tostring(parsed.header.order_id), order_number = tostring(parsed.header.order_number), customer_id = tostring(parsed.customer.customer_id), order_date = todatetime(parsed.header.order_date), total_value = toreal(parsed.total_value), status = tostring(parsed.status), created_timestamp = now(), source_idoc_number = idoc_number",
    "IsTransactional": false,
    "PropagateIngestionProperties": false
}]'
```

**Verify Update Policies**:
```kql
// Check that policies are enabled
.show table silver_shipments policy update
.show table silver_orders policy update

// Query Silver layer data
silver_shipments
| take 10

silver_orders
| take 10
```

**Benefits of KQL Update Policies**:
- ✅ Real-time transformation (sub-second latency)
- ✅ Automatic processing as data arrives in Bronze
- ✅ No need for external ETL jobs
- ✅ Data quality checks can be embedded in the query

---

### Lab 4: Write KQL Queries

**Basic Queries**:

```kql
// View recent Bronze layer messages
bronze_idocs
| take 100

// Count by IDoc type in Bronze
bronze_idocs
| summarize count() by idoc_type

// View Silver layer shipments
silver_shipments
| take 100

// Shipments in last hour (Silver layer)
silver_shipments
| where created_timestamp > ago(1h)
| project shipment_id, carrier_id, ship_date, tracking_number

// Carrier performance from Silver layer
silver_shipments
| summarize 
    ShipmentCount = count(),
    AvgWeight = avg(total_weight)
  by carrier_id
| order by ShipmentCount desc

// Time series analysis on Bronze ingestion
bronze_idocs
| where ingestion_time() > ago(24h)
| summarize count() by bin(ingestion_time(), 1h), idoc_type
| render timechart
```

**Advanced Analytics**:

```kql
// On-time delivery rate from Silver layer
silver_shipments
| extend 
    IsOnTime = delivery_date <= ship_date + 7d,
    DelayDays = datetime_diff('day', delivery_date, ship_date)
| summarize 
    TotalDeliveries = count(),
    OnTimeDeliveries = countif(IsOnTime),
    AvgDelay = avg(DelayDays)
  by carrier_id
| extend OnTimeRate = round(100.0 * OnTimeDeliveries / TotalDeliveries, 2)
| order by OnTimeRate desc

// Anomaly detection on Silver shipments
silver_shipments
| make-series Count = count() default=0 on created_timestamp step 1h
| extend anomalies = series_decompose_anomalies(Count, 1.5)
| mv-expand created_timestamp to typeof(datetime), Count to typeof(long), anomalies to typeof(double)
| where anomalies != 0
| project ingestion_time, Count, anomaly_score=anomalies
```

---

### Lab 5: Create Real-Time Dashboard

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
