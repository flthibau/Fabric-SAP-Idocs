# Module 4: Data Lakehouse

> **Building the Gold layer in OneLake using mirrored Bronze/Silver data and Materialized Lake Views**

⏱️ **Duration**: 120 minutes | 🎯 **Level**: Intermediate | 📋 **Prerequisites**: Modules 1-3 completed

---

## 📖 Module Overview

Implement the Gold layer of the medallion architecture in Microsoft Fabric Lakehouse. This module focuses on creating business-ready dimensional models using materialized lake views that query the automatically mirrored Bronze and Silver Delta tables from Eventhouse.

### Learning Objectives

- ✅ Understand medallion architecture with Eventhouse and Lakehouse integration
- ✅ Create Fabric Lakehouse and configure OneLake storage
- ✅ Understand OneLake mirroring from Eventhouse to Lakehouse
- ✅ Create Gold layer business views using materialized lake views
- ✅ Design star schema (dimensions and facts)
- ✅ Optimize Delta tables for query performance

---

## 📚 Medallion Architecture in Fabric

```
┌─────────────────────────────────────────────────────┐
│  Bronze Layer (Raw) - EVENTHOUSE                    │
│  • Real-time IDoc data ingestion                    │
│  • KQL tables in Eventhouse                         │
│  • Auto-mirrored to Lakehouse as Delta tables       │
└──────────────┬──────────────────────────────────────┘
               ↓ KQL Update Policies (Real-Time)
┌─────────────────────────────────────────────────────┐
│  Silver Layer (Cleansed) - EVENTHOUSE               │
│  • Parsed and normalized via KQL                    │
│  • Data quality checks                              │
│  • Real-time transformations                        │
│  • Auto-mirrored to Lakehouse as Delta tables       │
└──────────────┬──────────────────────────────────────┘
               ↓ Mirroring to OneLake
┌─────────────────────────────────────────────────────┐
│  Mirrored Bronze/Silver - LAKEHOUSE                 │
│  • Automatic sync from Eventhouse                   │
│  • Delta Lake format                                │
│  • Available for analytics engines                  │
└──────────────┬──────────────────────────────────────┘
               ↓ Materialized Lake Views
┌─────────────────────────────────────────────────────┐
│  Gold Layer (Business) - LAKEHOUSE                  │
│  • Dimensions & Facts                               │
│  • Materialized lake views                          │
│  • Star schema design                               │
│  • Optimized for queries                            │
└─────────────────────────────────────────────────────┘
```

**Key Concept**: 
- **Bronze & Silver** layers reside in **Eventhouse** for real-time processing
- **Bronze & Silver** are automatically **mirrored** to **Lakehouse** as Delta tables via OneLake
- **Gold** layer is created in **Lakehouse** using **materialized lake views** that query the mirrored Silver Delta tables

---

## 🧪 Hands-On Labs

### Lab 1: Create Lakehouse and Verify Mirroring

**Steps**:
1. Create Lakehouse: `lakehouse_3pl`
2. Configure OneLake storage
3. Verify Bronze and Silver tables from Eventhouse are mirrored
4. Create folder structure for Gold layer:
   ```
   /Files/gold/dimensions/
   /Files/gold/facts/
   ```

**Verify Mirroring**:
After setting up Eventhouse Bronze and Silver layers in Module 3, they should automatically appear in the Lakehouse as Delta tables via OneLake mirroring.

```sql
-- In Lakehouse SQL endpoint, verify mirrored tables
SHOW TABLES;

-- Should see:
-- bronze_idocs (mirrored from Eventhouse)
-- silver_shipments (mirrored from Eventhouse)
-- silver_orders (mirrored from Eventhouse)

-- Query mirrored Silver data
SELECT * FROM silver_shipments LIMIT 10;
SELECT * FROM silver_orders LIMIT 10;
```

---

### Lab 2: Understand OneLake Mirroring

**What is OneLake Mirroring?**

OneLake provides automatic, continuous replication of Eventhouse tables to Lakehouse as Delta tables. This enables:
- ✅ Real-time data in Eventhouse (KQL queries)
- ✅ Analytics-ready data in Lakehouse (Spark, SQL, Power BI)
- ✅ No manual ETL needed
- ✅ Single source of truth via OneLake

**Configuration** (typically automatic, no code needed):
The mirroring happens automatically when both Eventhouse and Lakehouse are in the same workspace and OneLake.


---


### Lab 3: Build Gold Layer - Dimension Tables

**Purpose**: Create dimension tables for the star schema that will be used in Gold layer facts.

**Dimensions to Create**:

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
USING DELTA
LOCATION 'Files/gold/dimensions/customer';

-- Dimension: Carrier
CREATE TABLE gold_dim_carrier (
    carrier_key INT GENERATED ALWAYS AS IDENTITY,
    carrier_id STRING,
    carrier_name STRING,
    service_type STRING,
    is_current BOOLEAN
)
USING DELTA
LOCATION 'Files/gold/dimensions/carrier';

-- Dimension: Location
CREATE TABLE gold_dim_location (
    location_key INT GENERATED ALWAYS AS IDENTITY,
    location_id STRING,
    location_name STRING,
    city STRING,
    state STRING,
    country STRING,
    is_current BOOLEAN
)
USING DELTA
LOCATION 'Files/gold/dimensions/location';
```

**Populate Dimensions from Mirrored Silver**:

```sql
-- Populate Customer dimension from mirrored Silver data
INSERT INTO gold_dim_customer (customer_id, customer_name, customer_type, region, valid_from, is_current)
SELECT DISTINCT
    customer_id,
    customer_name,
    'EXTERNAL' as customer_type,
    'US-EAST' as region,
    current_date() as valid_from,
    true as is_current
FROM silver_shipments
WHERE customer_id IS NOT NULL
  AND customer_id NOT IN (SELECT customer_id FROM gold_dim_customer WHERE is_current = true);

-- Populate Carrier dimension
INSERT INTO gold_dim_carrier (carrier_id, carrier_name, service_type, is_current)
SELECT DISTINCT
    carrier_id,
    carrier_id as carrier_name,
    'GROUND' as service_type,
    true as is_current
FROM silver_shipments
WHERE carrier_id IS NOT NULL
  AND carrier_id NOT IN (SELECT carrier_id FROM gold_dim_carrier WHERE is_current = true);
```

---

### Lab 4: Build Gold Layer - Fact Tables with Materialized Lake Views

**Purpose**: Create fact tables using materialized lake views that query the mirrored Silver Delta tables. Materialized lake views provide incremental refresh and optimize query performance.

**Create Fact Table Using Materialized Lake View**:

```sql
-- Create fact_shipment as a materialized lake view
CREATE MATERIALIZED VIEW gold_fact_shipment
AS
SELECT 
    s.shipment_id,
    c.customer_key,
    cr.carrier_key,
    CAST(date_format(s.ship_date, 'yyyyMMdd') AS INT) as ship_date_key,
    CAST(date_format(s.delivery_date, 'yyyyMMdd') AS INT) as delivery_date_key,
    s.total_weight,
    0 as total_value, -- Placeholder, would join with orders if available
    CASE WHEN s.delivery_date <= s.ship_date + INTERVAL 7 DAYS THEN true ELSE false END as on_time_delivery_flag,
    datediff(s.delivery_date, s.ship_date) as delivery_delay_days,
    s.ship_date,
    s.delivery_date,
    s.status,
    s.created_timestamp
FROM silver_shipments s
LEFT JOIN gold_dim_customer c ON s.customer_id = c.customer_id AND c.is_current = true
LEFT JOIN gold_dim_carrier cr ON s.carrier_id = cr.carrier_id AND cr.is_current = true;

-- Create fact_order as a materialized lake view  
CREATE MATERIALIZED VIEW gold_fact_order
AS
SELECT 
    o.order_id,
    c.customer_key,
    CAST(date_format(o.order_date, 'yyyyMMdd') AS INT) as order_date_key,
    o.order_number,
    o.total_value,
    o.status,
    o.order_date,
    o.created_timestamp
FROM silver_orders o
LEFT JOIN gold_dim_customer c ON o.customer_id = c.customer_id AND c.is_current = true;
```

**Benefits of Materialized Lake Views**:
- ✅ Incremental refresh (only processes new/changed data)
- ✅ Automatically maintains materialized results
- ✅ Optimized query performance
- ✅ Seamless integration with Power BI Direct Lake mode

**Refresh Materialized Views**:
```sql
-- Manually refresh a materialized view
REFRESH MATERIALIZED VIEW gold_fact_shipment;

-- Set automatic refresh schedule (via Fabric UI or API)
-- Refresh every hour or based on data changes
```

---

### Lab 5: Create Gold Layer Aggregation Views

**Purpose**: Create business-ready aggregated views for common analytics queries.

```sql
-- Daily shipment summary view
CREATE OR REPLACE VIEW gold_shipments_daily_summary AS
SELECT 
    f.ship_date,
    c.customer_id,
    c.customer_name,
    cr.carrier_id,
    cr.carrier_name,
    COUNT(*) as shipment_count,
    SUM(f.total_weight) as total_weight,
    SUM(CASE WHEN f.on_time_delivery_flag THEN 1 ELSE 0 END) as on_time_count,
    ROUND(100.0 * SUM(CASE WHEN f.on_time_delivery_flag THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_rate,
    AVG(f.delivery_delay_days) as avg_delay_days
FROM gold_fact_shipment f
JOIN gold_dim_customer c ON f.customer_key = c.customer_key
JOIN gold_dim_carrier cr ON f.carrier_key = cr.carrier_key
GROUP BY f.ship_date, c.customer_id, c.customer_name, cr.carrier_id, cr.carrier_name;

-- Customer performance metrics
CREATE OR REPLACE VIEW gold_customer_metrics AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_type,
    COUNT(DISTINCT f.shipment_id) as total_shipments,
    SUM(f.total_weight) as total_weight,
    SUM(f.total_value) as total_value,
    ROUND(100.0 * SUM(CASE WHEN f.on_time_delivery_flag THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_rate,
    MAX(f.ship_date) as last_shipment_date
FROM gold_fact_shipment f
JOIN gold_dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.customer_id, c.customer_name, c.customer_type;

-- Carrier performance metrics
CREATE OR REPLACE VIEW gold_carrier_metrics AS
SELECT 
    cr.carrier_id,
    cr.carrier_name,
    COUNT(DISTINCT f.shipment_id) as total_shipments,
    SUM(f.total_weight) as total_weight,
    ROUND(100.0 * SUM(CASE WHEN f.on_time_delivery_flag THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_rate,
    AVG(f.delivery_delay_days) as avg_delay_days,
    MAX(f.ship_date) as last_shipment_date
FROM gold_fact_shipment f
JOIN gold_dim_carrier cr ON f.carrier_key = cr.carrier_key
GROUP BY cr.carrier_id, cr.carrier_name;
```

---

### Lab 6: Optimize Gold Layer Delta Tables

**Optimization Commands**:

```sql
-- Optimize dimension tables with Z-Ordering
OPTIMIZE gold_dim_customer
ZORDER BY (customer_id);

OPTIMIZE gold_dim_carrier
ZORDER BY (carrier_id);

-- Note: Materialized views are automatically optimized by Fabric

-- Vacuum old versions (retain 7 days)
VACUUM gold_dim_customer RETAIN 168 HOURS;
VACUUM gold_dim_carrier RETAIN 168 HOURS;

-- Compute statistics for query optimization
ANALYZE TABLE gold_dim_customer COMPUTE STATISTICS FOR ALL COLUMNS;
ANALYZE TABLE gold_dim_carrier COMPUTE STATISTICS FOR ALL COLUMNS;
```

---

## 📋 Best Practices

**Bronze Layer (in Eventhouse)**:
- ✅ Keep raw data as-is for audit trail
- ✅ Partition by ingestion date and type
- ✅ Use KQL tables for real-time queries

**Silver Layer (in Eventhouse)**:
- ✅ Use KQL update policies for real-time transformation
- ✅ Implement data quality checks in KQL
- ✅ Deduplicate records automatically
- ✅ Automatic mirroring to Lakehouse ensures analytics availability

**Gold Layer (in Lakehouse)**:
- ✅ Design for query performance using star schema
- ✅ Use materialized lake views for incremental refresh
- ✅ Create aggregation views for common analytics patterns
- ✅ Optimize with Z-Ordering on frequently queried columns

**OneLake Mirroring**:
- ✅ Automatic - no manual ETL needed
- ✅ Real-time sync from Eventhouse to Lakehouse
- ✅ Provides single source of truth via OneLake
- ✅ Enables multi-engine access (KQL, Spark, SQL, Power BI)

---

## ✅ Module Completion

**Summary**: Built Gold layer in Lakehouse using materialized lake views that query mirrored Silver Delta tables from Eventhouse, completing the medallion architecture

**Next**: [Module 5: Security & Governance](../module-5-security-governance/README.md) - Implement RLS and Purview integration

---

**[← Module 3](../module-3-real-time-intelligence/README.md)** | **[Home](../README.md)** | **[Module 5 →](../module-5-security-governance/README.md)**
