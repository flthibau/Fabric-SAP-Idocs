# Module 4: Data Lakehouse

> **Building Bronze/Silver/Gold layers in OneLake with Delta Lake**

⏱️ **Duration**: 120 minutes | 🎯 **Level**: Intermediate | 📋 **Prerequisites**: Modules 1-3 completed

---

## 📖 Module Overview

Implement the medallion architecture pattern (Bronze/Silver/Gold) in Microsoft Fabric Lakehouse using Delta Lake for ACID transactions and optimal query performance.

### Learning Objectives

- ✅ Understand medallion architecture pattern
- ✅ Create Fabric Lakehouse and configure OneLake storage
- ✅ Build Bronze layer for raw data ingestion
- ✅ Implement Silver layer transformations with PySpark
- ✅ Create Gold layer business views
- ✅ Optimize Delta tables and configure shortcuts

---

## 📚 Medallion Architecture

```
┌─────────────────────────────────────────────────────┐
│  Bronze Layer (Raw)                                 │
│  • As-is IDoc data                                  │
│  • JSON/Parquet format                              │
│  • Partitioned by date & type                       │
└──────────────┬──────────────────────────────────────┘
               ↓ Cleansing & Normalization
┌─────────────────────────────────────────────────────┐
│  Silver Layer (Cleansed)                            │
│  • Parsed and normalized                            │
│  • Data quality checks                              │
│  • Deduplication                                    │
│  • Delta Lake tables                                │
└──────────────┬──────────────────────────────────────┘
               ↓ Aggregation & Business Logic
┌─────────────────────────────────────────────────────┐
│  Gold Layer (Business)                              │
│  • Dimensions & Facts                               │
│  • Materialized aggregations                        │
│  • Star schema design                               │
│  • Optimized for queries                            │
└─────────────────────────────────────────────────────┘
```

---

## 🧪 Hands-On Labs

### Lab 1: Create Lakehouse

**Steps**:
1. Create Lakehouse: `lakehouse_3pl`
2. Configure OneLake storage
3. Create folder structure:
   ```
   /Files/bronze/idocs/
   /Files/silver/shipments/
   /Files/silver/orders/
   /Files/gold/dimensions/
   /Files/gold/facts/
   ```

---

### Lab 2: Build Bronze Layer

**Eventstream to Lakehouse Configuration**:

```python
# Destination: Lakehouse Bronze Table
{
  "workspace": "SAP-3PL-Workspace",
  "lakehouse": "lakehouse_3pl",
  "table": "bronze_idocs",
  "dataFormat": "JSON",
  "partitionBy": ["processing_date", "idoc_type"]
}
```

**Create Bronze Table**:

```sql
CREATE TABLE bronze_idocs (
    idoc_number STRING,
    idoc_type STRING,
    message_type STRING,
    partner_number STRING,
    raw_payload STRING,
    ingestion_timestamp TIMESTAMP,
    processing_date DATE,
    source_system STRING
)
USING DELTA
PARTITIONED BY (processing_date, idoc_type)
LOCATION 'Files/bronze/idocs';
```

---

### Lab 3: Build Silver Layer

**PySpark Transformation Notebook**:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from delta.tables import DeltaTable

# Read from Bronze
bronze_df = spark.read.table("lakehouse_3pl.bronze_idocs") \
    .filter(col("idoc_type") == "SHPMNT") \
    .filter(col("processing_date") == current_date())

# Parse JSON payload
from pyspark.sql.types import *

shipment_schema = StructType([
    StructField("header", StructType([
        StructField("shipment_id", StringType()),
        StructField("shipment_number", StringType()),
        StructField("ship_date", DateType()),
        StructField("delivery_date", DateType())
    ])),
    StructField("customer", StructType([
        StructField("customer_id", StringType()),
        StructField("customer_name", StringType())
    ])),
    StructField("carrier", StructType([
        StructField("carrier_id", StringType()),
        StructField("carrier_name", StringType())
    ]))
])

# Transform to Silver
silver_df = bronze_df \
    .withColumn("parsed", from_json(col("raw_payload"), shipment_schema)) \
    .select(
        col("parsed.header.shipment_id").alias("shipment_id"),
        col("parsed.header.shipment_number").alias("shipment_number"),
        col("parsed.customer.customer_id").alias("customer_id"),
        col("parsed.customer.customer_name").alias("customer_name"),
        col("parsed.header.ship_date").alias("ship_date"),
        col("parsed.header.delivery_date").alias("delivery_date"),
        col("parsed.carrier.carrier_id").alias("carrier_id"),
        col("idoc_number").alias("source_idoc_number"),
        current_timestamp().alias("created_timestamp")
    ) \
    .filter(col("shipment_id").isNotNull())

# Data quality score
silver_df = silver_df.withColumn(
    "data_quality_score",
    when(col("customer_id").isNotNull() & col("carrier_id").isNotNull(), 1.0)
    .when(col("customer_id").isNotNull() | col("carrier_id").isNotNull(), 0.8)
    .otherwise(0.5)
)

# Upsert to Silver table
silver_table = DeltaTable.forName(spark, "lakehouse_3pl.silver_shipments")

silver_table.alias("target").merge(
    silver_df.alias("source"),
    "target.shipment_id = source.shipment_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

print(f"Processed {silver_df.count()} shipment records")
```

**Create Silver Tables**:

```sql
-- Shipments
CREATE TABLE silver_shipments (
    shipment_id STRING PRIMARY KEY,
    shipment_number STRING,
    customer_id STRING,
    customer_name STRING,
    carrier_id STRING,
    ship_date DATE,
    delivery_date DATE,
    origin_location STRING,
    destination_location STRING,
    total_weight DECIMAL(18,2),
    status STRING,
    data_quality_score DECIMAL(3,2),
    source_idoc_number STRING,
    created_timestamp TIMESTAMP,
    modified_timestamp TIMESTAMP
)
USING DELTA
PARTITIONED BY (ship_date);

-- Orders
CREATE TABLE silver_orders (
    order_id STRING PRIMARY KEY,
    order_number STRING,
    customer_id STRING,
    order_date DATE,
    total_value DECIMAL(18,2),
    status STRING,
    created_timestamp TIMESTAMP
)
USING DELTA
PARTITIONED BY (order_date);
```

---

### Lab 4: Build Gold Layer

**Create Dimensions**:

```sql
-- Dimension: Customer
CREATE TABLE gold_dim_customer (
    customer_key INT GENERATED ALWAYS AS IDENTITY,
    customer_id STRING,
    customer_name STRING,
    customer_type STRING,
    region STRING,
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN
)
USING DELTA;

-- Dimension: Carrier
CREATE TABLE gold_dim_carrier (
    carrier_key INT GENERATED ALWAYS AS IDENTITY,
    carrier_id STRING,
    carrier_name STRING,
    service_type STRING,
    is_current BOOLEAN
)
USING DELTA;
```

**Create Facts**:

```sql
-- Fact: Shipments
CREATE TABLE gold_fact_shipment (
    shipment_key BIGINT GENERATED ALWAYS AS IDENTITY,
    shipment_id STRING,
    customer_key INT,
    carrier_key INT,
    ship_date_key INT,
    delivery_date_key INT,
    total_weight DECIMAL(18,2),
    total_value DECIMAL(18,2),
    on_time_delivery_flag BOOLEAN,
    delivery_delay_days INT,
    created_timestamp TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES gold_dim_customer(customer_key),
    FOREIGN KEY (carrier_key) REFERENCES gold_dim_carrier(carrier_key)
)
USING DELTA
PARTITIONED BY (ship_date_key);
```

**Aggregation View**:

```sql
-- Materialized view for daily shipment summary
CREATE OR REPLACE VIEW gold_shipments_daily_summary AS
SELECT 
    ship_date,
    customer_id,
    carrier_id,
    COUNT(*) as shipment_count,
    SUM(total_weight) as total_weight,
    SUM(total_value) as total_value,
    SUM(CASE WHEN on_time_delivery_flag THEN 1 ELSE 0 END) as on_time_count,
    ROUND(100.0 * SUM(CASE WHEN on_time_delivery_flag THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_rate
FROM gold_fact_shipment f
JOIN gold_dim_customer c ON f.customer_key = c.customer_key
JOIN gold_dim_carrier cr ON f.carrier_key = cr.carrier_key
GROUP BY ship_date, customer_id, carrier_id;
```

---

### Lab 5: Optimize Delta Tables

**Optimization Commands**:

```sql
-- Optimize with Z-Ordering
OPTIMIZE silver_shipments
ZORDER BY (customer_id, ship_date);

OPTIMIZE gold_fact_shipment
ZORDER BY (customer_key, ship_date_key);

-- Vacuum old versions (retain 7 days)
VACUUM silver_shipments RETAIN 168 HOURS;
VACUUM gold_fact_shipment RETAIN 168 HOURS;

-- Table statistics
ANALYZE TABLE silver_shipments COMPUTE STATISTICS;
ANALYZE TABLE gold_fact_shipment COMPUTE STATISTICS FOR ALL COLUMNS;
```

**Schedule Optimization**:

```python
# In Spark notebook - schedule daily
from pyspark.sql.functions import current_date

def optimize_tables():
    tables = [
        "silver_shipments",
        "silver_orders", 
        "gold_fact_shipment"
    ]
    
    for table in tables:
        print(f"Optimizing {table}...")
        spark.sql(f"OPTIMIZE lakehouse_3pl.{table}")
        spark.sql(f"VACUUM lakehouse_3pl.{table} RETAIN 168 HOURS")

# Run daily via Fabric Pipeline
optimize_tables()
```

---

### Lab 6: Configure OneLake Shortcuts

**Create Shortcuts to Eventhouse**:

```python
# Python API to create shortcuts
import requests

def create_onelake_shortcut(
    workspace_id,
    lakehouse_id,
    shortcut_name,
    target_path,
    target_type="Eventhouse"
):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{lakehouse_id}/shortcuts"
    
    payload = {
        "name": shortcut_name,
        "path": "Files/shortcuts",
        "target": {
            "type": target_type,
            "path": target_path
        }
    }
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.post(url, json=payload, headers=headers)
    return response.json()

# Create shortcut to real-time data
create_onelake_shortcut(
    workspace_id="<workspace-id>",
    lakehouse_id="<lakehouse-id>",
    shortcut_name="realtime_shipments",
    target_path="/databases/idoc_realtime/tables/idoc_raw",
    target_type="Eventhouse"
)
```

---

## 📋 Best Practices

**Bronze Layer**:
- ✅ Keep raw data as-is for audit trail
- ✅ Partition by ingestion date and type
- ✅ Use JSON or Parquet for flexibility

**Silver Layer**:
- ✅ Implement data quality checks
- ✅ Deduplicate records
- ✅ Normalize data structure
- ✅ Use Delta Lake for ACID guarantees

**Gold Layer**:
- ✅ Design for query performance
- ✅ Use star/snowflake schema
- ✅ Create materialized aggregations
- ✅ Optimize with Z-Ordering

**Delta Table Management**:
- ✅ Regular OPTIMIZE operations
- ✅ VACUUM old versions
- ✅ Update table statistics
- ✅ Monitor table sizes

---

## ✅ Module Completion

**Summary**: Built complete medallion architecture with Bronze/Silver/Gold layers using Delta Lake

**Next**: [Module 5: Security & Governance](../module-5-security-governance/README.md) - Implement RLS and Purview integration

---

**[← Module 3](../module-3-real-time-intelligence/README.md)** | **[Home](../README.md)** | **[Module 5 →](../module-5-security-governance/README.md)**
