# Module 4: Lakehouse Medallion Architecture

**Estimated Time:** 120 minutes  
**Difficulty:** Advanced  
**Prerequisites:** Modules 1-3 completed, familiarity with PySpark or SQL

---

## 🎯 Learning Objectives

By completing this module, you will:

- ✅ Understand the **Medallion Architecture** pattern (Bronze → Silver → Gold)
- ✅ Build a **Bronze layer** for raw SAP IDoc data ingestion
- ✅ Transform data into a **Silver layer** with cleansing and validation
- ✅ Create **Gold layer** business views and aggregations
- ✅ Implement **data quality checks** at each layer
- ✅ Apply **performance optimization** techniques for Delta Lake
- ✅ Follow **best practices** for production data pipelines

---

## 📚 Table of Contents

1. [Medallion Architecture Concepts](#1-medallion-architecture-concepts)
2. [Bronze Layer: Raw Data Ingestion](#2-bronze-layer-raw-data-ingestion)
3. [Silver Layer: Data Cleansing](#3-silver-layer-data-cleansing)
4. [Gold Layer: Business Views](#4-gold-layer-business-views)
5. [Data Quality Checks](#5-data-quality-checks)
6. [Performance Optimization](#6-performance-optimization)
7. [Best Practices](#7-best-practices)
8. [Hands-On Lab Exercises](#8-hands-on-lab-exercises)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Medallion Architecture Concepts

### 1.1 What is Medallion Architecture?

The **Medallion Architecture** is a data design pattern that organizes data into three progressive layers of quality and refinement:

```
┌─────────────────────────────────────────────────────────────────┐
│                     🥉 BRONZE LAYER                              │
│                        (Raw Data)                                │
│                                                                  │
│  • Stores raw data exactly as received from source systems      │
│  • Minimal to no transformation                                 │
│  • Preserves data lineage and audit trail                       │
│  • Append-only or overwrite based on requirements               │
│  • Retention: 90-365 days                                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Validation + Parsing
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     🥈 SILVER LAYER                              │
│                   (Cleansed & Validated)                         │
│                                                                  │
│  • Cleaned and validated data                                   │
│  • Standardized formats and schemas                             │
│  • Deduplicated records                                         │
│  • Business logic applied (enrichment, calculations)            │
│  • Retention: 1-7 years                                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Aggregation + Modeling
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     🥇 GOLD LAYER                                │
│                  (Business-Ready Analytics)                      │
│                                                                  │
│  • Pre-aggregated metrics and KPIs                              │
│  • Business-specific views (orders, shipments, revenue)         │
│  • Optimized for fast query performance                         │
│  • Ready for BI tools, APIs, and applications                   │
│  • Retention: 7+ years or per compliance requirements           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Why Use Medallion Architecture?

**Benefits:**

1. **Data Quality**: Progressive refinement ensures high-quality data for analytics
2. **Flexibility**: Raw data preserved for reprocessing and new use cases
3. **Performance**: Optimized layers reduce query latency
4. **Governance**: Clear lineage from source to consumption
5. **Scalability**: Incremental processing reduces compute costs
6. **Maintainability**: Separation of concerns makes debugging easier

**Real-World Example - 3PL Logistics:**

| Layer | Example | Purpose |
|-------|---------|---------|
| **Bronze** | `idoc_raw` | All SAP IDoc messages as JSON (ORDERS, DESADV, INVOIC) |
| **Silver** | `idoc_orders_silver` | Parsed orders with validated fields (OrderNumber, Customer, Amount) |
| **Gold** | `orders_daily_summary` | Daily order metrics (total orders, revenue, SLA compliance %) |

---

### 1.3 Medallion vs. Traditional Data Warehouse

| Aspect | Traditional DW | Medallion (Data Lakehouse) |
|--------|---------------|----------------------------|
| **Storage Format** | Proprietary (SQL Server, Oracle) | Open format (Delta Lake, Parquet) |
| **Schema** | Rigid, pre-defined | Flexible, schema-on-read |
| **Data Types** | Structured only | Structured, semi-structured, unstructured |
| **Cost** | High (compute+storage coupled) | Low (storage cheap, compute on-demand) |
| **Processing** | ETL (Extract-Transform-Load) | ELT (Extract-Load-Transform) |
| **Time to Value** | Weeks/months | Days/hours |

---

## 2. Bronze Layer: Raw Data Ingestion

### 2.1 Bronze Layer Characteristics

**Purpose:** Store raw data exactly as received from SAP Event Hub

**Key Principles:**
- ✅ **Immutability**: Original data never modified (append-only)
- ✅ **Completeness**: All fields captured, even if not immediately needed
- ✅ **Simplicity**: Minimal transformation (format conversions only)
- ✅ **Traceability**: Metadata for lineage (ingestion time, source system)

**Example Table: `idoc_raw`**

```sql
-- Bronze Layer Schema
CREATE TABLE idoc_raw (
    message_id STRING,              -- Unique message identifier
    idoc_type STRING,               -- IDoc type (ORDERS, DESADV, INVOIC)
    message_type STRING,            -- Message category
    sap_system STRING,              -- Source SAP system
    sap_client STRING,              -- SAP client number
    timestamp TIMESTAMP,            -- Message timestamp from SAP
    control STRUCT<...>,            -- IDoc control segment (nested JSON)
    data ARRAY<STRUCT<...>>,        -- IDoc data segments (array of records)
    event_enqueued_utc TIMESTAMP,   -- Event Hub timestamp
    partition_id STRING,            -- Event Hub partition
    processed_at TIMESTAMP          -- Lakehouse ingestion timestamp
)
USING DELTA
PARTITIONED BY (DATE(timestamp))
LOCATION 'Tables/bronze/idoc_raw';
```

### 2.2 Bronze Ingestion Pattern

**Option A: Streaming from Eventhouse via Mirroring**

Microsoft Fabric can mirror Eventhouse tables to Lakehouse automatically:

1. **Configure Mirroring** (in Eventhouse):
   ```
   Settings → Mirroring → Add Destination
   - Source: kqldb_sapidoc.idoc_raw
   - Destination: Lakehouse.Tables.idoc_raw
   - Mode: Continuous (real-time)
   - Format: Delta Lake
   ```

2. **Automatic Sync**:
   - Data flows continuously from Eventhouse → Lakehouse
   - No code required
   - Sub-minute latency

**Option B: Spark Notebook (Batch Load)**

```python
# Bronze Layer - Batch Ingestion from Eventhouse
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, col

# Read from Eventhouse using KQL endpoint
df_raw = spark.read \
    .format("kusto") \
    .option("kustoCluster", "https://<your-cluster>.kusto.fabric.microsoft.com") \
    .option("kustoDatabase", "kqldbsapidoc") \
    .option("kustoQuery", "idoc_raw | where ingestion_time() > ago(1h)") \
    .load()

# Add processing metadata
df_bronze = df_raw.withColumn("processed_at", current_timestamp())

# Write to Bronze table (append mode)
df_bronze.write \
    .format("delta") \
    .mode("append") \
    .partitionBy("timestamp") \
    .saveAsTable("idoc_raw")

print(f"✅ Ingested {df_bronze.count()} records to Bronze layer")
```

### 2.3 Bronze Data Quality Checks

Even in Bronze, apply minimal validation:

```python
from pyspark.sql.functions import col, count, when

# Check 1: Required fields not null
null_check = df_bronze.select([
    count(when(col(c).isNull(), 1)).alias(f"{c}_nulls")
    for c in ["message_id", "idoc_type", "sap_system", "timestamp"]
])

null_check.show()

# Check 2: Valid IDoc types
valid_idoc_types = ["ORDERS", "DESADV", "SHPMNT", "INVOIC", "WHSCON"]
invalid_idocs = df_bronze.filter(~col("idoc_type").isin(valid_idoc_types))

if invalid_idocs.count() > 0:
    print(f"⚠️ Warning: {invalid_idocs.count()} records with invalid IDoc types")
    invalid_idocs.select("idoc_type").distinct().show()

# Check 3: No duplicate message_ids (within batch)
duplicates = df_bronze.groupBy("message_id").count().filter(col("count") > 1)
if duplicates.count() > 0:
    print(f"⚠️ Warning: {duplicates.count()} duplicate message IDs detected")
```

---

## 3. Silver Layer: Data Cleansing

### 3.1 Silver Layer Characteristics

**Purpose:** Transform raw data into clean, business-ready datasets

**Key Transformations:**
1. **Parsing**: Extract fields from nested JSON/XML structures
2. **Validation**: Enforce data types, ranges, business rules
3. **Standardization**: Consistent formats (dates, currencies, codes)
4. **Deduplication**: Keep latest version of each entity
5. **Enrichment**: Add calculated fields, lookups, derived values

**Example Table: `idoc_orders_silver`**

```sql
-- Silver Layer Schema
CREATE TABLE idoc_orders_silver (
    order_number STRING,            -- Primary key
    order_type STRING,              -- Order type code (ZOR, ZRET, etc.)
    order_date DATE,                -- Order creation date
    customer_number STRING,         -- Customer ID
    customer_name STRING,           -- Customer name (denormalized)
    ship_to_address STRUCT<...>,    -- Shipping address (structured)
    delivery_date DATE,             -- Promised delivery date
    actual_ship_date DATE,          -- Actual shipment date (nullable)
    actual_delivery_date DATE,      -- Actual delivery date (nullable)
    total_amount DECIMAL(15,2),     -- Order total in base currency
    currency STRING,                -- Currency code (USD, EUR)
    line_items ARRAY<STRUCT<...>>,  -- Order line items
    order_status STRING,            -- Status (Pending, Shipped, Delivered, Cancelled)
    sap_system STRING,              -- Source system
    sla_status STRING,              -- SLA compliance (Good, At Risk, Breached)
    sla_days_remaining INT,         -- Days until SLA breach
    partner_access_scope STRING,    -- For Row-Level Security (customer ID)
    processed_timestamp TIMESTAMP   -- Silver layer processing time
)
USING DELTA
PARTITIONED BY (order_date)
LOCATION 'Tables/silver/idoc_orders_silver';
```

### 3.2 Silver Transformation Pattern

**Full Transformation Example:**

```python
# Silver Layer - Transform Bronze to Silver (Orders)
from pyspark.sql.functions import (
    col, to_date, when, datediff, current_timestamp,
    explode, get_json_object, struct, array
)

# Read Bronze layer
df_bronze = spark.table("idoc_raw").filter(col("idoc_type") == "ORDERS")

# Parse nested JSON control segment
df_parsed = df_bronze.select(
    col("message_id"),
    col("sap_system"),
    col("timestamp"),
    get_json_object(col("control"), "$.DOCNUM").alias("order_number"),
    get_json_object(col("control"), "$.DOCTYP").alias("order_type"),
    to_date(get_json_object(col("control"), "$.DOCDATE"), "yyyyMMdd").alias("order_date"),
    get_json_object(col("data"), "$[0].CUSTOMER_ID").alias("customer_number"),
    get_json_object(col("data"), "$[0].CUSTOMER_NAME").alias("customer_name"),
    to_date(get_json_object(col("data"), "$[0].DELIVERY_DATE"), "yyyyMMdd").alias("delivery_date"),
    get_json_object(col("data"), "$[0].TOTAL_AMOUNT").cast("decimal(15,2)").alias("total_amount"),
    get_json_object(col("data"), "$[0].CURRENCY").alias("currency"),
    col("data")  # Keep full data array for line items parsing
)

# Deduplicate - keep latest version per order number
from pyspark.sql.window import Window
window_spec = Window.partitionBy("order_number").orderBy(col("timestamp").desc())

df_dedup = df_parsed.withColumn("row_num", row_number().over(window_spec)) \
                    .filter(col("row_num") == 1) \
                    .drop("row_num")

# Calculate SLA status
df_silver = df_dedup.withColumn(
    "sla_days_remaining",
    datediff(col("delivery_date"), current_date())
).withColumn(
    "sla_status",
    when(col("sla_days_remaining") >= 3, "Good")
    .when(col("sla_days_remaining").between(1, 2), "At Risk")
    .otherwise("Breached")
)

# Add order status (simplified logic)
df_silver = df_silver.withColumn(
    "order_status",
    when(col("actual_delivery_date").isNotNull(), "Delivered")
    .when(col("actual_ship_date").isNotNull(), "Shipped")
    .otherwise("Pending")
)

# Add RLS scope (customer ID for row-level security)
df_silver = df_silver.withColumn("partner_access_scope", col("customer_number"))

# Add processing timestamp
df_silver = df_silver.withColumn("processed_timestamp", current_timestamp())

# Write to Silver table (merge for idempotency)
from delta.tables import DeltaTable

if DeltaTable.isDeltaTable(spark, "Tables/silver/idoc_orders_silver"):
    delta_table = DeltaTable.forPath(spark, "Tables/silver/idoc_orders_silver")
    
    delta_table.alias("target").merge(
        df_silver.alias("source"),
        "target.order_number = source.order_number AND target.sap_system = source.sap_system"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
else:
    df_silver.write \
        .format("delta") \
        .mode("overwrite") \
        .partitionBy("order_date") \
        .saveAsTable("idoc_orders_silver")

print(f"✅ Processed {df_silver.count()} orders to Silver layer")
```

### 3.3 Silver Data Quality Checks

**Comprehensive Validation:**

```python
from pyspark.sql.functions import col, count, when, isnan

# Quality Check 1: Mandatory fields completeness
mandatory_fields = ["order_number", "order_date", "customer_number", "total_amount"]
completeness_check = df_silver.select([
    (count("*") - count(col(c))).alias(f"{c}_missing")
    for c in mandatory_fields
])

print("=== COMPLETENESS CHECK ===")
completeness_check.show()

# Quality Check 2: Data type validation
print("=== DATA TYPE VALIDATION ===")
# Check negative amounts
negative_amounts = df_silver.filter(col("total_amount") < 0).count()
print(f"Negative amounts: {negative_amounts}")

# Check future order dates
future_dates = df_silver.filter(col("order_date") > current_date()).count()
print(f"Future order dates: {future_dates}")

# Quality Check 3: Business rule validation
print("=== BUSINESS RULES ===")
# Check delivery date is after order date
invalid_dates = df_silver.filter(col("delivery_date") < col("order_date")).count()
print(f"Invalid delivery dates (before order date): {invalid_dates}")

# Quality Check 4: Referential integrity
print("=== REFERENTIAL INTEGRITY ===")
# Check known currency codes
valid_currencies = ["USD", "EUR", "GBP", "JPY"]
invalid_currency = df_silver.filter(~col("currency").isin(valid_currencies)).count()
print(f"Invalid currency codes: {invalid_currency}")

# Quality Summary
total_rows = df_silver.count()
quality_score = 100 - ((negative_amounts + future_dates + invalid_dates + invalid_currency) / total_rows * 100)
print(f"\n✅ Overall Data Quality Score: {quality_score:.2f}%")
```

---

## 4. Gold Layer: Business Views

### 4.1 Gold Layer Characteristics

**Purpose:** Pre-aggregated, business-ready datasets optimized for analytics and APIs

**Key Features:**
1. **Aggregations**: Daily/weekly/monthly summaries
2. **KPIs**: Pre-calculated metrics (SLA %, revenue, throughput)
3. **Denormalization**: Join multiple sources for fast queries
4. **Materialized Views**: Refresh on schedule or event-driven
5. **API-Ready**: Optimized for sub-100ms query latency

**Example Table: `orders_daily_summary`**

```sql
-- Gold Layer Schema
CREATE TABLE orders_daily_summary (
    order_day DATE,                 -- Summary date
    sap_system STRING,              -- SAP system
    sla_status STRING,              -- SLA category
    partner_access_scope STRING,    -- Customer ID (for RLS)
    total_orders INT,               -- Count of orders
    delivered_orders INT,           -- Count delivered
    cancelled_orders INT,           -- Count cancelled
    total_revenue DECIMAL(18,2),    -- Total order value
    avg_order_value DECIMAL(15,2),  -- Average order value
    min_order_value DECIMAL(15,2),  -- Minimum order value
    max_order_value DECIMAL(15,2),  -- Maximum order value
    avg_days_to_ship DECIMAL(5,2),  -- Average days from order to ship
    avg_days_to_delivery DECIMAL(5,2), -- Average days from order to delivery
    sla_compliance_pct DECIMAL(5,2), -- % of orders with Good SLA status
    delivery_rate_pct DECIMAL(5,2),  -- % of orders delivered
    cancellation_rate_pct DECIMAL(5,2), -- % of orders cancelled
    processed_timestamp TIMESTAMP   -- Last update time
)
USING DELTA
PARTITIONED BY (order_day)
LOCATION 'Tables/gold/orders_daily_summary';
```

### 4.2 Gold Aggregation Pattern

**Daily Summary Example:**

```python
# Gold Layer - Daily Orders Summary
from pyspark.sql.functions import (
    col, count, sum as _sum, avg, min as _min, max as _max,
    date_trunc, current_timestamp, when, datediff
)

# Read Silver layer
df_silver = spark.table("idoc_orders_silver")

# Aggregate by day, system, SLA status, and partner (for RLS)
df_gold = df_silver.groupBy(
    date_trunc("day", col("order_date")).alias("order_day"),
    col("sap_system"),
    col("sla_status"),
    col("partner_access_scope")
).agg(
    # Volume metrics
    count("*").alias("total_orders"),
    count(when(col("order_status") == "Delivered", 1)).alias("delivered_orders"),
    count(when(col("order_status") == "Cancelled", 1)).alias("cancelled_orders"),
    
    # Financial metrics
    _sum("total_amount").alias("total_revenue"),
    avg("total_amount").alias("avg_order_value"),
    _min("total_amount").alias("min_order_value"),
    _max("total_amount").alias("max_order_value"),
    
    # Performance metrics
    avg(datediff(col("actual_ship_date"), col("order_date"))).alias("avg_days_to_ship"),
    avg(datediff(col("actual_delivery_date"), col("order_date"))).alias("avg_days_to_delivery")
)

# Calculate percentages
df_gold = df_gold.withColumn(
    "sla_compliance_pct",
    when(col("sla_status") == "Good", col("total_orders")).otherwise(0) / col("total_orders") * 100
).withColumn(
    "delivery_rate_pct",
    col("delivered_orders") / col("total_orders") * 100
).withColumn(
    "cancellation_rate_pct",
    col("cancelled_orders") / col("total_orders") * 100
)

# Add metadata
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())

# Write to Gold table (upsert)
from delta.tables import DeltaTable

if DeltaTable.isDeltaTable(spark, "Tables/gold/orders_daily_summary"):
    delta_table = DeltaTable.forPath(spark, "Tables/gold/orders_daily_summary")
    
    delta_table.alias("target").merge(
        df_gold.alias("source"),
        """target.order_day = source.order_day 
           AND target.sap_system = source.sap_system 
           AND target.sla_status = source.sla_status
           AND target.partner_access_scope = source.partner_access_scope"""
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
else:
    df_gold.write \
        .format("delta") \
        .mode("overwrite") \
        .partitionBy("order_day") \
        .saveAsTable("orders_daily_summary")

print(f"✅ Aggregated {df_gold.count()} daily summaries to Gold layer")
```

### 4.3 Gold Real-Time Views

For real-time metrics (current state), use continuous aggregation:

```python
# Gold Layer - Real-Time Shipments in Transit
from pyspark.sql.functions import current_date, col

df_silver_shipments = spark.table("idoc_shipments_silver")

# Filter only active shipments
df_in_transit = df_silver_shipments.filter(
    (col("shipment_status") == "In Transit") &
    (col("actual_delivery_date").isNull())
)

# Aggregate by carrier and destination
df_gold_realtime = df_in_transit.groupBy(
    col("carrier"),
    col("destination_country"),
    col("partner_access_scope")
).agg(
    count("*").alias("active_shipments"),
    count(when(col("expected_delivery_date") == current_date(), 1)).alias("arriving_today"),
    count(when(col("expected_delivery_date") < current_date(), 1)).alias("delayed_shipments"),
    avg(datediff(col("expected_delivery_date"), col("ship_date"))).alias("avg_transit_days")
)

# Save as materialized view (refreshed every 5 minutes)
df_gold_realtime.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable("shipments_in_transit")

print(f"✅ Updated real-time shipment view: {df_gold_realtime.count()} carrier/destination combinations")
```

---

## 5. Data Quality Checks

### 5.1 Data Quality Framework

Implement a comprehensive data quality framework across all layers:

```python
# Data Quality Framework
from pyspark.sql.functions import col, count, when, isnan, isnull
from datetime import datetime

class DataQualityChecker:
    """Data quality validation framework for Medallion Architecture"""
    
    def __init__(self, spark, table_name, layer):
        self.spark = spark
        self.table_name = table_name
        self.layer = layer
        self.results = []
    
    def check_completeness(self, mandatory_fields):
        """Check that mandatory fields have no nulls"""
        df = self.spark.table(self.table_name)
        
        for field in mandatory_fields:
            null_count = df.filter(col(field).isNull()).count()
            total_count = df.count()
            completeness_pct = ((total_count - null_count) / total_count * 100) if total_count > 0 else 0
            
            self.results.append({
                "check": "Completeness",
                "field": field,
                "status": "PASS" if completeness_pct == 100 else "FAIL",
                "value": f"{completeness_pct:.2f}%",
                "details": f"{null_count} nulls out of {total_count}"
            })
        
        return self
    
    def check_uniqueness(self, unique_fields):
        """Check that specified fields have unique values"""
        df = self.spark.table(self.table_name)
        
        for field in unique_fields:
            total_count = df.count()
            distinct_count = df.select(field).distinct().count()
            uniqueness_pct = (distinct_count / total_count * 100) if total_count > 0 else 0
            
            self.results.append({
                "check": "Uniqueness",
                "field": field,
                "status": "PASS" if uniqueness_pct == 100 else "FAIL",
                "value": f"{uniqueness_pct:.2f}%",
                "details": f"{total_count - distinct_count} duplicates"
            })
        
        return self
    
    def check_validity(self, field, valid_values):
        """Check that field values are in allowed set"""
        df = self.spark.table(self.table_name)
        
        invalid_count = df.filter(~col(field).isin(valid_values)).count()
        total_count = df.count()
        validity_pct = ((total_count - invalid_count) / total_count * 100) if total_count > 0 else 0
        
        self.results.append({
            "check": "Validity",
            "field": field,
            "status": "PASS" if validity_pct == 100 else "FAIL",
            "value": f"{validity_pct:.2f}%",
            "details": f"{invalid_count} invalid values"
        })
        
        return self
    
    def check_timeliness(self, timestamp_field, max_age_hours=24):
        """Check that data is not too old"""
        df = self.spark.table(self.table_name)
        
        from pyspark.sql.functions import current_timestamp, hour
        
        old_records = df.filter(
            hour(current_timestamp() - col(timestamp_field)) > max_age_hours
        ).count()
        total_count = df.count()
        timeliness_pct = ((total_count - old_records) / total_count * 100) if total_count > 0 else 0
        
        self.results.append({
            "check": "Timeliness",
            "field": timestamp_field,
            "status": "PASS" if timeliness_pct >= 95 else "FAIL",
            "value": f"{timeliness_pct:.2f}%",
            "details": f"{old_records} records older than {max_age_hours}h"
        })
        
        return self
    
    def generate_report(self):
        """Generate quality report"""
        import pandas as pd
        
        df_report = pd.DataFrame(self.results)
        
        print(f"\n{'='*80}")
        print(f"DATA QUALITY REPORT - {self.layer.upper()} LAYER")
        print(f"Table: {self.table_name}")
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*80}\n")
        print(df_report.to_string(index=False))
        print(f"\n{'='*80}")
        
        # Summary
        total_checks = len(self.results)
        passed_checks = len([r for r in self.results if r["status"] == "PASS"])
        quality_score = (passed_checks / total_checks * 100) if total_checks > 0 else 0
        
        print(f"\nQuality Score: {quality_score:.2f}% ({passed_checks}/{total_checks} checks passed)")
        
        if quality_score < 95:
            print("⚠️ WARNING: Quality score below 95% threshold!")
        else:
            print("✅ Quality score meets standards")
        
        return df_report

# Example usage
qc = DataQualityChecker(spark, "idoc_orders_silver", "Silver")

qc.check_completeness(["order_number", "order_date", "customer_number", "total_amount"]) \
  .check_uniqueness(["order_number"]) \
  .check_validity("currency", ["USD", "EUR", "GBP", "JPY"]) \
  .check_validity("order_status", ["Pending", "Shipped", "Delivered", "Cancelled"]) \
  .check_timeliness("processed_timestamp", max_age_hours=24) \
  .generate_report()
```

### 5.2 Automated Quality Monitoring

Set up automated quality checks with alerts:

```python
# Automated Quality Monitoring with Alerts
def run_quality_checks_with_alerts(table_name, layer, alert_threshold=95):
    """Run quality checks and send alerts if score below threshold"""
    
    qc = DataQualityChecker(spark, table_name, layer)
    
    # Define checks based on layer
    if layer == "Bronze":
        qc.check_completeness(["message_id", "idoc_type", "sap_system", "timestamp"]) \
          .check_uniqueness(["message_id"])
    
    elif layer == "Silver":
        qc.check_completeness(["order_number", "order_date", "customer_number"]) \
          .check_uniqueness(["order_number"]) \
          .check_validity("currency", ["USD", "EUR", "GBP", "JPY"]) \
          .check_timeliness("processed_timestamp", max_age_hours=24)
    
    elif layer == "Gold":
        qc.check_completeness(["order_day", "total_orders", "total_revenue"]) \
          .check_timeliness("processed_timestamp", max_age_hours=6)
    
    # Generate report
    report_df = qc.generate_report()
    
    # Calculate quality score
    passed = len([r for r in qc.results if r["status"] == "PASS"])
    total = len(qc.results)
    quality_score = (passed / total * 100) if total > 0 else 0
    
    # Send alert if below threshold
    if quality_score < alert_threshold:
        send_alert(
            subject=f"⚠️ Data Quality Alert - {layer} Layer",
            message=f"Table {table_name} quality score: {quality_score:.2f}%\n\n{report_df.to_string()}",
            severity="HIGH"
        )
    
    return quality_score

def send_alert(subject, message, severity="INFO"):
    """Send alert via email/Teams/Slack"""
    # Implement your alerting mechanism here
    print(f"\n📧 ALERT ({severity}): {subject}")
    print(message)

# Run checks on all layers
quality_scores = {
    "Bronze": run_quality_checks_with_alerts("idoc_raw", "Bronze"),
    "Silver": run_quality_checks_with_alerts("idoc_orders_silver", "Silver"),
    "Gold": run_quality_checks_with_alerts("orders_daily_summary", "Gold")
}

print(f"\n=== OVERALL QUALITY SUMMARY ===")
for layer, score in quality_scores.items():
    status = "✅" if score >= 95 else "⚠️"
    print(f"{status} {layer}: {score:.2f}%")
```

---

## 6. Performance Optimization

### 6.1 Delta Lake Optimization Techniques

**OPTIMIZE Command:**

```sql
-- Compact small files into larger files (target: 1GB per file)
OPTIMIZE idoc_orders_silver;

-- Z-ORDER indexing for frequently filtered columns
OPTIMIZE idoc_orders_silver
ZORDER BY (customer_number, order_date, sap_system);

-- View optimization statistics
DESCRIBE HISTORY idoc_orders_silver;
```

**VACUUM Command:**

```sql
-- Remove old file versions (default retention: 7 days)
VACUUM idoc_orders_silver RETAIN 168 HOURS;

-- Aggressive cleanup (3 days)
VACUUM idoc_orders_silver RETAIN 72 HOURS;
```

**Partitioning Strategy:**

```python
# Optimal partitioning for time-series data
df.write \
    .format("delta") \
    .mode("append") \
    .partitionBy("order_date")  # Partition by date for time-based queries
    .saveAsTable("idoc_orders_silver")

# Multi-level partitioning for very large datasets
df.write \
    .format("delta") \
    .mode("append") \
    .partitionBy("year", "month", "day")  # Year/Month/Day partitions
    .saveAsTable("idoc_orders_silver_partitioned")
```

### 6.2 Caching Strategies

```python
# Cache frequently accessed Silver tables
df_orders = spark.table("idoc_orders_silver")
df_orders.cache()
df_orders.count()  # Materialize cache

# Use persist for custom storage levels
from pyspark import StorageLevel
df_orders.persist(StorageLevel.MEMORY_AND_DISK)

# Clear cache when done
df_orders.unpersist()
```

### 6.3 Query Optimization

**Predicate Pushdown:**

```python
# Good: Filter pushed down to storage layer
df = spark.table("idoc_orders_silver") \
    .filter(col("order_date") >= "2024-01-01") \
    .filter(col("customer_number") == "CUST123")

# Bad: Filter after loading entire table
df = spark.table("idoc_orders_silver")
df = df.filter(col("order_date") >= "2024-01-01")
```

**Column Pruning:**

```python
# Good: Select only needed columns
df = spark.table("idoc_orders_silver") \
    .select("order_number", "total_amount", "order_date")

# Bad: Select all columns
df = spark.table("idoc_orders_silver")  # Loads all columns
```

**Broadcast Joins:**

```python
from pyspark.sql.functions import broadcast

# Broadcast small dimension tables for faster joins
df_orders = spark.table("idoc_orders_silver")
df_customers = spark.table("dim_customers")  # Small lookup table

# Force broadcast join
df_result = df_orders.join(
    broadcast(df_customers),
    df_orders.customer_number == df_customers.customer_id
)
```

### 6.4 Performance Monitoring

```python
# Query plan analysis
df = spark.table("idoc_orders_silver").filter(col("order_date") >= "2024-01-01")
df.explain(extended=True)  # View physical plan

# Execution metrics
df.cache()
df.count()
spark.sparkContext.statusTracker().getJobIdsForGroup()
```

---

## 7. Best Practices

### 7.1 Schema Management

**Schema Evolution:**

```python
# Enable schema evolution for adding new columns
df_new.write \
    .format("delta") \
    .mode("append") \
    .option("mergeSchema", "true")  # Allow schema evolution
    .saveAsTable("idoc_orders_silver")

# Add column to existing table
spark.sql("""
    ALTER TABLE idoc_orders_silver
    ADD COLUMN priority_level STRING
""")
```

**Schema Enforcement:**

```python
# Define explicit schema for validation
from pyspark.sql.types import StructType, StructField, StringType, DateType, DecimalType

schema = StructType([
    StructField("order_number", StringType(), nullable=False),
    StructField("order_date", DateType(), nullable=False),
    StructField("total_amount", DecimalType(15, 2), nullable=False),
    StructField("currency", StringType(), nullable=False)
])

# Read with schema validation
df = spark.read.schema(schema).table("idoc_orders_silver")
```

### 7.2 Incremental Processing

**Watermark-based Processing:**

```python
# Track last processed timestamp
last_processed = spark.sql("""
    SELECT MAX(processed_timestamp) as max_ts
    FROM idoc_orders_silver
""").collect()[0]["max_ts"]

# Process only new records
df_new = spark.table("idoc_raw") \
    .filter(col("timestamp") > last_processed) \
    .filter(col("idoc_type") == "ORDERS")

# Transform and append
df_silver = transform_to_silver(df_new)
df_silver.write.format("delta").mode("append").saveAsTable("idoc_orders_silver")
```

### 7.3 Error Handling

```python
# Robust error handling with dead letter queue
from pyspark.sql.functions import col, when

try:
    df_bronze = spark.table("idoc_raw")
    
    # Separate good and bad records
    df_good = df_bronze.filter(
        col("idoc_type").isin(["ORDERS", "DESADV", "INVOIC"]) &
        col("message_id").isNotNull()
    )
    
    df_bad = df_bronze.filter(
        ~col("idoc_type").isin(["ORDERS", "DESADV", "INVOIC"]) |
        col("message_id").isNull()
    )
    
    # Process good records
    df_silver = transform_to_silver(df_good)
    df_silver.write.format("delta").mode("append").saveAsTable("idoc_orders_silver")
    
    # Write bad records to quarantine
    if df_bad.count() > 0:
        df_bad.withColumn("error_reason", lit("Invalid IDoc type or missing message_id")) \
              .withColumn("quarantine_timestamp", current_timestamp()) \
              .write.format("delta").mode("append").saveAsTable("quarantine_records")
        
        print(f"⚠️ {df_bad.count()} records moved to quarantine")
    
except Exception as e:
    print(f"❌ Error in transformation: {str(e)}")
    # Log error and send alert
    send_alert(
        subject="Pipeline Failure",
        message=f"Silver layer transformation failed: {str(e)}",
        severity="CRITICAL"
    )
    raise
```

### 7.4 Testing Strategy

```python
# Unit test for transformation logic
def test_sla_calculation():
    """Test SLA status calculation logic"""
    from pyspark.sql import Row
    from datetime import datetime, timedelta
    
    # Create test data
    test_data = [
        Row(order_number="ORD001", order_date=datetime(2024, 1, 1), delivery_date=datetime(2024, 1, 10)),
        Row(order_number="ORD002", order_date=datetime(2024, 1, 1), delivery_date=datetime(2024, 1, 4)),
        Row(order_number="ORD003", order_date=datetime(2024, 1, 1), delivery_date=datetime(2024, 1, 2))
    ]
    
    df_test = spark.createDataFrame(test_data)
    
    # Apply transformation
    df_result = df_test.withColumn(
        "sla_days_remaining",
        datediff(col("delivery_date"), current_date())
    ).withColumn(
        "sla_status",
        when(col("sla_days_remaining") >= 3, "Good")
        .when(col("sla_days_remaining").between(1, 2), "At Risk")
        .otherwise("Breached")
    )
    
    # Assertions
    results = df_result.collect()
    assert results[0]["sla_status"] in ["Good", "At Risk", "Breached"]
    
    print("✅ SLA calculation test passed")

# Run test
test_sla_calculation()
```

### 7.5 Documentation Standards

```python
# Document table metadata
spark.sql("""
    ALTER TABLE idoc_orders_silver
    SET TBLPROPERTIES (
        'description' = 'Silver layer - SAP Orders with parsed and validated fields',
        'quality_level' = 'Silver',
        'data_classification' = 'Internal',
        'pii_fields' = 'customer_name,ship_to_address',
        'retention_days' = '2555',
        'source_system' = 'SAP S/4HANA',
        'owner' = '3PL Analytics Team',
        'created_date' = '2024-11-01',
        'refresh_frequency' = 'Every 15 minutes'
    )
""")

# Document column descriptions
spark.sql("""
    ALTER TABLE idoc_orders_silver
    ALTER COLUMN order_number COMMENT 'Unique order identifier from SAP (10-digit alphanumeric)';
    
    ALTER TABLE idoc_orders_silver
    ALTER COLUMN sla_status COMMENT 'SLA compliance status: Good (>=3 days), At Risk (1-2 days), Breached (<1 day)';
""")
```

---

## 8. Hands-On Lab Exercises

### Exercise 1: Build Bronze Layer

**Objective:** Create a Bronze table for raw IDoc data

**Tasks:**
1. Create `idoc_raw` table with proper schema
2. Ingest sample data from Eventhouse
3. Implement basic validation (non-null message_id)
4. Partition by date

**Solution:**
See `/workshop/notebooks/bronze-to-silver.ipynb`

---

### Exercise 2: Transform to Silver Layer

**Objective:** Parse and cleanse orders data

**Tasks:**
1. Read from Bronze layer (filter ORDERS IDoc type)
2. Parse nested JSON fields (order_number, customer, amount)
3. Deduplicate by order_number (keep latest)
4. Calculate SLA status
5. Write to `idoc_orders_silver` with merge logic

**Solution:**
See `/workshop/notebooks/bronze-to-silver.ipynb`

---

### Exercise 3: Create Gold Aggregations

**Objective:** Build daily order summary

**Tasks:**
1. Read from Silver layer
2. Group by day, system, SLA status
3. Calculate metrics (count, sum, avg)
4. Calculate percentages (SLA compliance, delivery rate)
5. Write to `orders_daily_summary`

**Solution:**
See `/workshop/notebooks/silver-to-gold.ipynb`

---

### Exercise 4: Implement Data Quality Framework

**Objective:** Validate data quality at each layer

**Tasks:**
1. Check completeness (mandatory fields)
2. Check uniqueness (primary keys)
3. Check validity (allowed values)
4. Check timeliness (data freshness)
5. Generate quality report

**Solution:**
See Section 5.1 for complete framework code

---

### Exercise 5: Optimize Performance

**Objective:** Apply optimization techniques

**Tasks:**
1. Run OPTIMIZE on Silver table
2. Apply Z-ORDER on frequently filtered columns
3. Set up table partitioning
4. Measure query performance before/after

**Solution:**
See Section 6 for optimization commands

---

## 9. Troubleshooting

### Common Issues and Solutions

#### Issue 1: Slow Query Performance

**Symptoms:** Queries taking minutes instead of seconds

**Solutions:**
1. **Check partitioning:**
   ```sql
   DESCRIBE DETAIL idoc_orders_silver;
   -- Verify partition column is used in WHERE clause
   ```

2. **Run OPTIMIZE:**
   ```sql
   OPTIMIZE idoc_orders_silver ZORDER BY (customer_number, order_date);
   ```

3. **Review query plan:**
   ```python
   df.explain()  # Look for full table scans
   ```

---

#### Issue 2: Schema Evolution Errors

**Symptoms:** `AnalysisException: Cannot resolve column`

**Solutions:**
1. **Enable schema merging:**
   ```python
   df.write.option("mergeSchema", "true").mode("append").saveAsTable("table_name")
   ```

2. **Add missing column explicitly:**
   ```sql
   ALTER TABLE table_name ADD COLUMN new_column STRING;
   ```

---

#### Issue 3: Duplicate Records in Silver

**Symptoms:** Same order appearing multiple times

**Solutions:**
1. **Implement proper deduplication:**
   ```python
   from pyspark.sql.window import Window
   from pyspark.sql.functions import row_number
   
   window_spec = Window.partitionBy("order_number").orderBy(col("timestamp").desc())
   df_dedup = df.withColumn("row_num", row_number().over(window_spec)) \
                .filter(col("row_num") == 1) \
                .drop("row_num")
   ```

2. **Use merge instead of append:**
   ```python
   delta_table.merge(df, "target.order_number = source.order_number") \
              .whenMatchedUpdateAll() \
              .whenNotMatchedInsertAll() \
              .execute()
   ```

---

#### Issue 4: Data Quality Failures

**Symptoms:** Quality checks failing consistently

**Solutions:**
1. **Investigate source data:**
   ```sql
   SELECT * FROM idoc_raw WHERE message_id IS NULL LIMIT 100;
   ```

2. **Implement quarantine process:**
   ```python
   df_bad.write.format("delta").mode("append").saveAsTable("quarantine_records")
   ```

3. **Adjust thresholds if needed:**
   ```python
   run_quality_checks_with_alerts("table_name", "Silver", alert_threshold=90)
   ```

---

## 🎓 Module Summary

### What You Learned

✅ **Medallion Architecture**: Bronze → Silver → Gold pattern for data quality  
✅ **Bronze Layer**: Raw data ingestion with minimal transformation  
✅ **Silver Layer**: Cleansed, validated, and enriched datasets  
✅ **Gold Layer**: Pre-aggregated business metrics and KPIs  
✅ **Data Quality**: Comprehensive validation framework  
✅ **Performance**: Optimization techniques for Delta Lake  
✅ **Best Practices**: Schema management, error handling, testing

### Key Takeaways

1. **Progressive Refinement**: Each layer adds value and quality
2. **Immutability**: Bronze layer preserves original data
3. **Idempotency**: Upsert logic ensures consistent results
4. **Quality First**: Validate at every layer
5. **Optimize Early**: Partitioning and Z-ORDER improve performance
6. **Document Everything**: Metadata enables governance

---

## 📚 Additional Resources

### Microsoft Learn

- [Fabric Lakehouse Overview](https://learn.microsoft.com/fabric/data-engineering/lakehouse-overview)
- [Delta Lake Guide](https://learn.microsoft.com/fabric/data-engineering/delta-optimization-and-v-order)
- [Data Quality in Fabric](https://learn.microsoft.com/fabric/data-quality/data-quality-overview)

### Community

- [Medallion Architecture Pattern](https://www.databricks.com/glossary/medallion-architecture)
- [Delta Lake Best Practices](https://delta.io/learn/best-practices/)
- [Fabric Community](https://community.fabric.microsoft.com)

---

## ➡️ Next Steps

Ready to continue? Proceed to:

**[Module 5: OneLake Security and Row-Level Security](./module5-security-rls.md)**

Learn how to implement enterprise-grade security with Row-Level Security (RLS) across all Fabric engines.

---

**🌟 Great job completing Module 4! You now have the foundation to build production-grade data lakehouses.**

**Questions or feedback?** Open an issue on [GitHub](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
