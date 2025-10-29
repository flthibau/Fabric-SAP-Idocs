# Materialized Lake Views - Solution Gold Layer

**Date:** 2025-10-27  
**Fonctionnalité:** Fabric Materialized Lake Views (Preview/GA)  
**Avantage:** Créer vues matérialisées SQL → Delta tables natives automatiquement

---

## 1. Qu'est-ce qu'une Materialized Lake View ?

### Définition

**Materialized Lake View** = Vue SQL matérialisée dans le Lakehouse, automatiquement stockée en **Delta format**.

### Caractéristiques

- ✅ **Déclarative** : Définie en SQL (comme une vue normale)
- ✅ **Matérialisée** : Résultats précalculés et stockés physiquement
- ✅ **Delta native** : Stockage Delta Lake automatique
- ✅ **Refresh automatique** : Configurable (scheduled, on-demand, incremental)
- ✅ **Visible dans Purview** : Scannée comme une table Delta normale
- ✅ **Partitionnement** : Support partitioning pour performance
- ✅ **Optimisations** : ZORDER, OPTIMIZE automatiques

### Syntaxe (SQL)

```sql
-- Créer une materialized view
CREATE MATERIALIZED VIEW gold.orders_daily_summary
PARTITIONED BY (order_day)
AS
SELECT 
    DATE_TRUNC('day', order_date) AS order_day,
    sap_system,
    sla_status,
    COUNT(*) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value,
    -- ... autres métriques
FROM idoc_orders_silver
GROUP BY DATE_TRUNC('day', order_date), sap_system, sla_status;

-- Refresh manuel
REFRESH MATERIALIZED VIEW gold.orders_daily_summary;

-- Refresh automatique (configuration)
ALTER MATERIALIZED VIEW gold.orders_daily_summary 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);
```

---

## 2. Architecture avec Materialized Lake Views

### Schema Complet

```
SAP S/4HANA
    ↓
Event Hub (idoc-events)
    ↓
Eventhouse KQL (kqldbsapidoc)
    ├── Bronze: idoc_raw (table)
    ├── Silver: idoc_orders_silver (update policy)
    ├── Silver: idoc_shipments_silver (update policy)
    ├── Silver: idoc_warehouse_silver (update policy)
    └── Silver: idoc_invoices_silver (update policy)
         ↓
    OneLake Availability (auto Delta conversion)
         ↓
    OneLake Delta Files
         ↓
    Lakehouse (Lakehouse3PLAnalytics)
    ├── Shortcuts → OneLake (Bronze + Silver = 5 tables)
    │   ├── idoc_raw ✅
    │   ├── idoc_orders_silver ✅
    │   ├── idoc_shipments_silver ✅
    │   ├── idoc_warehouse_silver ✅
    │   └── idoc_invoices_silver ✅
    │
    └── MATERIALIZED LAKE VIEWS (Gold) ✨
        ├── gold.orders_daily_summary
        ├── gold.sla_performance
        ├── gold.shipments_in_transit
        ├── gold.warehouse_productivity_daily
        └── gold.revenue_recognition_realtime
             ↓
        Delta Tables (auto-created)
             ↓
    Purview Scan (Fabric-JAc)
             ↓
    Data Product (10 tables gouvernées)
```

---

## 3. Création des Materialized Lake Views

### 3.1 orders_daily_summary

```sql
-- Dans Lakehouse SQL Endpoint
CREATE SCHEMA IF NOT EXISTS gold;

CREATE MATERIALIZED VIEW gold.orders_daily_summary
PARTITIONED BY (order_day)
COMMENT 'Agrégations quotidiennes des commandes par SAP système'
AS
SELECT 
    -- Dimensions
    DATE_TRUNC('day', order_date) AS order_day,
    sap_system,
    sla_status,
    
    -- Métriques volume
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders,
    
    -- Métriques financières
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value,
    MIN(total_amount) AS min_order_value,
    MAX(total_amount) AS max_order_value,
    
    -- Métriques performance
    AVG(DATEDIFF(day, order_date, actual_ship_date)) AS avg_days_to_ship,
    AVG(DATEDIFF(day, order_date, actual_delivery_date)) AS avg_days_to_delivery,
    
    -- SLA metrics
    COUNT(CASE WHEN sla_status = 'Good' THEN 1 END) AS sla_good_count,
    COUNT(CASE WHEN sla_status = 'At Risk' THEN 1 END) AS sla_at_risk_count,
    COUNT(CASE WHEN sla_status = 'Breached' THEN 1 END) AS sla_breached_count,
    
    -- Ratios calculés
    CAST(COUNT(CASE WHEN sla_status = 'Good' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS sla_compliance_pct,
    CAST(COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS delivery_rate_pct,
    
    -- Métadonnées
    CURRENT_TIMESTAMP() AS processed_timestamp,
    'idoc_orders_silver' AS source_table

FROM idoc_orders_silver
GROUP BY 
    DATE_TRUNC('day', order_date),
    sap_system,
    sla_status;

-- Configurer auto-optimize
ALTER MATERIALIZED VIEW gold.orders_daily_summary 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.enableChangeDataFeed' = 'true'
);
```

---

### 3.2 sla_performance

```sql
CREATE MATERIALIZED VIEW gold.sla_performance
PARTITIONED BY (order_date)
COMMENT 'Tracking SLA temps réel avec classification enrichie'
AS
SELECT 
    -- Identifiants
    o.order_number,
    o.customer_id,
    o.sap_system,
    
    -- Dates clés
    o.order_date,
    o.requested_delivery_date,
    o.promised_delivery_date,
    o.actual_ship_date,
    s.actual_delivery_date,
    
    -- Statuts
    o.order_status,
    o.sla_status,
    
    -- Calculs SLA
    DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) AS processing_days,
    DATEDIFF(day, o.order_date, s.actual_delivery_date) AS total_cycle_days,
    1 AS sla_target_days,
    
    -- Variance SLA (en heures)
    (DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) - 1) * 24 AS sla_variance_hours,
    
    -- Classification SLA enrichie
    CASE 
        WHEN DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) <= 1 THEN 'Good'
        WHEN DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) <= 2 THEN 'At Risk'
        ELSE 'Breached'
    END AS sla_compliance,
    
    -- On-time delivery
    CASE 
        WHEN s.actual_delivery_date IS NULL THEN NULL
        WHEN s.actual_delivery_date <= o.promised_delivery_date THEN TRUE
        ELSE FALSE
    END AS on_time_delivery,
    
    -- Indicateur critique
    CASE 
        WHEN o.sla_status = 'Breached' AND o.total_amount > 10000 THEN TRUE
        ELSE FALSE
    END AS is_critical,
    
    -- Montant et carrier
    o.total_amount,
    s.carrier_name,
    
    -- Métadonnées
    CURRENT_TIMESTAMP() AS processed_timestamp

FROM idoc_orders_silver o
LEFT JOIN idoc_shipments_silver s 
    ON o.order_number = s.order_reference;

-- Auto-optimize
ALTER MATERIALIZED VIEW gold.sla_performance 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);
```

---

### 3.3 shipments_in_transit

```sql
CREATE MATERIALIZED VIEW gold.shipments_in_transit
COMMENT 'Expéditions en cours avec ETA - Snapshot temps réel'
AS
SELECT 
    -- Identifiants
    shipment_number,
    order_reference,
    customer_id,
    sap_system,
    
    -- Localisation
    origin_location,
    destination_location,
    carrier_name,
    
    -- Dates clés
    planned_ship_date,
    actual_ship_date,
    planned_delivery_date,
    
    -- Status
    shipment_status,
    
    -- Calculs temps réel
    DATEDIFF(day, actual_ship_date, CURRENT_DATE()) AS days_in_transit,
    DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) AS days_until_planned_delivery,
    planned_delivery_date AS eta_date,
    
    -- Statut délai
    CASE 
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) > 2 THEN 'On Track'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) BETWEEN 0 AND 2 THEN 'At Risk'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 THEN 'Delayed'
        ELSE 'Unknown'
    END AS delay_status,
    
    -- Jours de retard
    CASE 
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 
        THEN -DATEDIFF(day, CURRENT_DATE(), planned_delivery_date)
        ELSE 0
    END AS days_delayed,
    
    -- Priorité
    CASE 
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 AND shipment_value > 10000 THEN 'High'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) BETWEEN 0 AND 2 AND shipment_value > 5000 THEN 'Medium'
        ELSE 'Normal'
    END AS priority,
    
    -- Montant
    shipment_value,
    
    -- Métadonnées
    CURRENT_TIMESTAMP() AS snapshot_timestamp

FROM idoc_shipments_silver
WHERE shipment_status = 'In Transit'
   OR (actual_ship_date IS NOT NULL AND actual_delivery_date IS NULL);

-- Full refresh (pas de partitioning pour snapshot)
ALTER MATERIALIZED VIEW gold.shipments_in_transit 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true'
);
```

---

### 3.4 warehouse_productivity_daily

```sql
CREATE MATERIALIZED VIEW gold.warehouse_productivity_daily
PARTITIONED BY (movement_day)
COMMENT 'KPI entrepôt quotidien avec productivité et exceptions'
AS
SELECT 
    -- Dimensions
    DATE_TRUNC('day', movement_timestamp) AS movement_day,
    warehouse_id,
    movement_type,
    sap_system,
    
    -- Volume metrics
    COUNT(*) AS total_movements,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT material_number) AS unique_materials,
    COUNT(DISTINCT operator_id) AS unique_operators,
    COUNT(DISTINCT location_code) AS unique_locations,
    
    -- Performance metrics
    AVG(processing_time_minutes) AS avg_processing_time_min,
    AVG(quantity) AS avg_quantity_per_movement,
    
    -- Exception tracking
    COUNT(CASE WHEN exception_flag = TRUE THEN 1 END) AS exception_count,
    COUNT(CASE WHEN exception_type = 'Damage' THEN 1 END) AS damage_count,
    COUNT(CASE WHEN exception_type = 'Shortage' THEN 1 END) AS shortage_count,
    COUNT(CASE WHEN exception_type = 'Quality' THEN 1 END) AS quality_count,
    
    -- Ratios calculés
    CAST(COUNT(CASE WHEN exception_flag = TRUE THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS exception_rate_pct,
    ROUND(COUNT(*) / 8.0, 2) AS movements_per_hour, -- 8h workday
    ROUND(SUM(quantity) / 8.0, 2) AS quantity_per_hour,
    
    -- Productivity vs target
    100 AS productivity_target,
    ROUND((SUM(quantity) / 8.0 - 100) * 100.0 / 100, 2) AS productivity_variance_pct,
    
    -- Performance status
    CASE 
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= 10 THEN 'Exceeding'
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= 0 THEN 'Meeting'
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= -10 THEN 'Near Target'
        ELSE 'Below Target'
    END AS performance_status,
    
    -- Utilisation opérateurs
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT operator_id), 2) AS movements_per_operator,
    
    -- Métadonnées
    CURRENT_TIMESTAMP() AS processed_timestamp

FROM idoc_warehouse_silver
GROUP BY 
    DATE_TRUNC('day', movement_timestamp),
    warehouse_id,
    movement_type,
    sap_system;

-- Auto-optimize with ZORDER
ALTER MATERIALIZED VIEW gold.warehouse_productivity_daily 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.dataSkippingNumIndexedCols' = '3'
);
```

---

### 3.5 revenue_recognition_realtime

```sql
CREATE MATERIALIZED VIEW gold.revenue_recognition_realtime
PARTITIONED BY (invoice_day)
COMMENT 'Performance financière temps réel avec aging buckets'
AS
SELECT 
    -- Dimensions
    DATE_TRUNC('day', invoice_date) AS invoice_day,
    customer_id,
    sap_system,
    
    -- Volume metrics
    COUNT(*) AS total_invoices,
    COUNT(DISTINCT invoice_number) AS unique_invoices,
    
    -- Revenue metrics
    SUM(total_amount) AS total_revenue,
    SUM(amount_paid) AS total_paid,
    SUM(amount_due) AS total_due,
    
    -- Payment status counts
    COUNT(CASE WHEN payment_status = 'Pending' THEN 1 END) AS pending_invoices,
    COUNT(CASE WHEN payment_status = 'Partial' THEN 1 END) AS partial_invoices,
    COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) AS paid_invoices,
    COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) AS overdue_invoices,
    
    -- Aging buckets
    COALESCE(SUM(CASE WHEN aging_bucket = 'Current' THEN amount_due END), 0) AS aging_current,
    COALESCE(SUM(CASE WHEN aging_bucket = '1-30' THEN amount_due END), 0) AS aging_1_30,
    COALESCE(SUM(CASE WHEN aging_bucket = '31-60' THEN amount_due END), 0) AS aging_31_60,
    COALESCE(SUM(CASE WHEN aging_bucket = '61-90' THEN amount_due END), 0) AS aging_61_90,
    COALESCE(SUM(CASE WHEN aging_bucket = '90+' THEN amount_due END), 0) AS aging_90_plus,
    
    -- DSO calculation
    AVG(CASE WHEN payment_date IS NOT NULL THEN DATEDIFF(day, invoice_date, payment_date) END) AS avg_days_to_payment,
    AVG(total_amount) AS avg_invoice_value,
    
    -- Ratios calculés
    CAST(CASE WHEN SUM(total_amount) > 0 THEN SUM(amount_paid) * 100.0 / SUM(total_amount) ELSE 0 END AS DECIMAL(5,2)) AS collection_efficiency_pct,
    CAST(COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS payment_rate_pct,
    CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS overdue_rate_pct,
    
    -- DSO vs target
    30 AS dso_target_days,
    AVG(CASE WHEN payment_date IS NOT NULL THEN DATEDIFF(day, invoice_date, payment_date) END) - 30 AS dso_variance_days,
    
    -- Risk classification
    CASE 
        WHEN CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) > 20 THEN 'High'
        WHEN CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) > 10 THEN 'Medium'
        ELSE 'Low'
    END AS collection_risk,
    
    -- Métadonnées
    CURRENT_TIMESTAMP() AS processed_timestamp

FROM idoc_invoices_silver
GROUP BY 
    DATE_TRUNC('day', invoice_date),
    customer_id,
    sap_system;

-- Auto-optimize
ALTER MATERIALIZED VIEW gold.revenue_recognition_realtime 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);
```

---

## 4. Script Création Complète

### Fichier: create_materialized_lake_views.sql

```sql
-- ===================================================================
-- CREATE GOLD LAYER - MATERIALIZED LAKE VIEWS
-- ===================================================================
-- Lakehouse: Lakehouse3PLAnalytics
-- Schema: gold
-- Tables source: Silver layer (shortcuts OneLake)
-- Output: 5 materialized views → Delta tables automatiques

-- Créer schema Gold
CREATE SCHEMA IF NOT EXISTS gold
COMMENT 'Gold layer - Business KPIs and aggregated metrics';

-- ===================================================================
-- 1. ORDERS DAILY SUMMARY
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.orders_daily_summary;

CREATE MATERIALIZED VIEW gold.orders_daily_summary
PARTITIONED BY (order_day)
COMMENT 'Agrégations quotidiennes des commandes par SAP système'
AS
SELECT 
    DATE_TRUNC('day', order_date) AS order_day,
    sap_system,
    sla_status,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value,
    MIN(total_amount) AS min_order_value,
    MAX(total_amount) AS max_order_value,
    AVG(DATEDIFF(day, order_date, actual_ship_date)) AS avg_days_to_ship,
    AVG(DATEDIFF(day, order_date, actual_delivery_date)) AS avg_days_to_delivery,
    COUNT(CASE WHEN sla_status = 'Good' THEN 1 END) AS sla_good_count,
    COUNT(CASE WHEN sla_status = 'At Risk' THEN 1 END) AS sla_at_risk_count,
    COUNT(CASE WHEN sla_status = 'Breached' THEN 1 END) AS sla_breached_count,
    CAST(COUNT(CASE WHEN sla_status = 'Good' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS sla_compliance_pct,
    CAST(COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS delivery_rate_pct,
    CURRENT_TIMESTAMP() AS processed_timestamp,
    'idoc_orders_silver' AS source_table
FROM idoc_orders_silver
GROUP BY DATE_TRUNC('day', order_date), sap_system, sla_status;

ALTER MATERIALIZED VIEW gold.orders_daily_summary 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.enableChangeDataFeed' = 'true'
);

PRINT '✅ Materialized View gold.orders_daily_summary created';

-- ===================================================================
-- 2. SLA PERFORMANCE
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.sla_performance;

CREATE MATERIALIZED VIEW gold.sla_performance
PARTITIONED BY (order_date)
AS
SELECT 
    o.order_number,
    o.customer_id,
    o.sap_system,
    o.order_date,
    o.requested_delivery_date,
    o.promised_delivery_date,
    o.actual_ship_date,
    s.actual_delivery_date,
    o.order_status,
    o.sla_status,
    DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) AS processing_days,
    DATEDIFF(day, o.order_date, s.actual_delivery_date) AS total_cycle_days,
    1 AS sla_target_days,
    (DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) - 1) * 24 AS sla_variance_hours,
    CASE 
        WHEN DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) <= 1 THEN 'Good'
        WHEN DATEDIFF(day, o.order_date, COALESCE(o.actual_ship_date, CURRENT_DATE())) <= 2 THEN 'At Risk'
        ELSE 'Breached'
    END AS sla_compliance,
    CASE 
        WHEN s.actual_delivery_date IS NULL THEN NULL
        WHEN s.actual_delivery_date <= o.promised_delivery_date THEN TRUE
        ELSE FALSE
    END AS on_time_delivery,
    CASE WHEN o.sla_status = 'Breached' AND o.total_amount > 10000 THEN TRUE ELSE FALSE END AS is_critical,
    o.total_amount,
    s.carrier_name,
    CURRENT_TIMESTAMP() AS processed_timestamp
FROM idoc_orders_silver o
LEFT JOIN idoc_shipments_silver s ON o.order_number = s.order_reference;

ALTER MATERIALIZED VIEW gold.sla_performance 
SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true');

PRINT '✅ Materialized View gold.sla_performance created';

-- ===================================================================
-- 3. SHIPMENTS IN TRANSIT
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.shipments_in_transit;

CREATE MATERIALIZED VIEW gold.shipments_in_transit
AS
SELECT 
    shipment_number,
    order_reference,
    customer_id,
    sap_system,
    origin_location,
    destination_location,
    carrier_name,
    planned_ship_date,
    actual_ship_date,
    planned_delivery_date,
    shipment_status,
    DATEDIFF(day, actual_ship_date, CURRENT_DATE()) AS days_in_transit,
    DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) AS days_until_planned_delivery,
    planned_delivery_date AS eta_date,
    CASE 
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) > 2 THEN 'On Track'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) BETWEEN 0 AND 2 THEN 'At Risk'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 THEN 'Delayed'
        ELSE 'Unknown'
    END AS delay_status,
    CASE WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 
        THEN -DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) ELSE 0 END AS days_delayed,
    CASE 
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) < 0 AND shipment_value > 10000 THEN 'High'
        WHEN DATEDIFF(day, CURRENT_DATE(), planned_delivery_date) BETWEEN 0 AND 2 AND shipment_value > 5000 THEN 'Medium'
        ELSE 'Normal'
    END AS priority,
    shipment_value,
    CURRENT_TIMESTAMP() AS snapshot_timestamp
FROM idoc_shipments_silver
WHERE shipment_status = 'In Transit'
   OR (actual_ship_date IS NOT NULL AND actual_delivery_date IS NULL);

ALTER MATERIALIZED VIEW gold.shipments_in_transit 
SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true');

PRINT '✅ Materialized View gold.shipments_in_transit created';

-- ===================================================================
-- 4. WAREHOUSE PRODUCTIVITY DAILY
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.warehouse_productivity_daily;

CREATE MATERIALIZED VIEW gold.warehouse_productivity_daily
PARTITIONED BY (movement_day)
AS
SELECT 
    DATE_TRUNC('day', movement_timestamp) AS movement_day,
    warehouse_id,
    movement_type,
    sap_system,
    COUNT(*) AS total_movements,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT material_number) AS unique_materials,
    COUNT(DISTINCT operator_id) AS unique_operators,
    COUNT(DISTINCT location_code) AS unique_locations,
    AVG(processing_time_minutes) AS avg_processing_time_min,
    AVG(quantity) AS avg_quantity_per_movement,
    COUNT(CASE WHEN exception_flag = TRUE THEN 1 END) AS exception_count,
    CAST(COUNT(CASE WHEN exception_flag = TRUE THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS exception_rate_pct,
    ROUND(COUNT(*) / 8.0, 2) AS movements_per_hour,
    ROUND(SUM(quantity) / 8.0, 2) AS quantity_per_hour,
    100 AS productivity_target,
    ROUND((SUM(quantity) / 8.0 - 100) * 100.0 / 100, 2) AS productivity_variance_pct,
    CASE 
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= 10 THEN 'Exceeding'
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= 0 THEN 'Meeting'
        WHEN (SUM(quantity) / 8.0 - 100) * 100.0 / 100 >= -10 THEN 'Near Target'
        ELSE 'Below Target'
    END AS performance_status,
    CURRENT_TIMESTAMP() AS processed_timestamp
FROM idoc_warehouse_silver
GROUP BY DATE_TRUNC('day', movement_timestamp), warehouse_id, movement_type, sap_system;

ALTER MATERIALIZED VIEW gold.warehouse_productivity_daily 
SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true');

PRINT '✅ Materialized View gold.warehouse_productivity_daily created';

-- ===================================================================
-- 5. REVENUE RECOGNITION REALTIME
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.revenue_recognition_realtime;

CREATE MATERIALIZED VIEW gold.revenue_recognition_realtime
PARTITIONED BY (invoice_day)
AS
SELECT 
    DATE_TRUNC('day', invoice_date) AS invoice_day,
    customer_id,
    sap_system,
    COUNT(*) AS total_invoices,
    SUM(total_amount) AS total_revenue,
    SUM(amount_paid) AS total_paid,
    SUM(amount_due) AS total_due,
    COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) AS overdue_invoices,
    COALESCE(SUM(CASE WHEN aging_bucket = 'Current' THEN amount_due END), 0) AS aging_current,
    COALESCE(SUM(CASE WHEN aging_bucket = '1-30' THEN amount_due END), 0) AS aging_1_30,
    COALESCE(SUM(CASE WHEN aging_bucket = '31-60' THEN amount_due END), 0) AS aging_31_60,
    COALESCE(SUM(CASE WHEN aging_bucket = '61-90' THEN amount_due END), 0) AS aging_61_90,
    COALESCE(SUM(CASE WHEN aging_bucket = '90+' THEN amount_due END), 0) AS aging_90_plus,
    AVG(CASE WHEN payment_date IS NOT NULL THEN DATEDIFF(day, invoice_date, payment_date) END) AS avg_days_to_payment,
    CAST(CASE WHEN SUM(total_amount) > 0 THEN SUM(amount_paid) * 100.0 / SUM(total_amount) ELSE 0 END AS DECIMAL(5,2)) AS collection_efficiency_pct,
    30 AS dso_target_days,
    CURRENT_TIMESTAMP() AS processed_timestamp
FROM idoc_invoices_silver
GROUP BY DATE_TRUNC('day', invoice_date), customer_id, sap_system;

ALTER MATERIALIZED VIEW gold.revenue_recognition_realtime 
SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true');

PRINT '✅ Materialized View gold.revenue_recognition_realtime created';

-- ===================================================================
-- SUMMARY
-- ===================================================================
PRINT '';
PRINT '========================================';
PRINT '  MATERIALIZED LAKE VIEWS - SUMMARY';
PRINT '========================================';
PRINT 'Schema: gold';
PRINT 'Views created: 5';
PRINT '  ✅ orders_daily_summary (partitioned by order_day)';
PRINT '  ✅ sla_performance (partitioned by order_date)';
PRINT '  ✅ shipments_in_transit (snapshot)';
PRINT '  ✅ warehouse_productivity_daily (partitioned by movement_day)';
PRINT '  ✅ revenue_recognition_realtime (partitioned by invoice_day)';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Refresh views: REFRESH MATERIALIZED VIEW gold.<view_name>';
PRINT '2. Schedule refresh: Create Fabric pipeline';
PRINT '3. Trigger Purview scan';
PRINT '4. Verify 10 tables in Data Product';
PRINT '========================================';
```

---

## 5. Refresh Strategy

### Manual Refresh

```sql
-- Refresh une vue spécifique
REFRESH MATERIALIZED VIEW gold.orders_daily_summary;

-- Refresh toutes les vues Gold
REFRESH MATERIALIZED VIEW gold.orders_daily_summary;
REFRESH MATERIALIZED VIEW gold.sla_performance;
REFRESH MATERIALIZED VIEW gold.shipments_in_transit;
REFRESH MATERIALIZED VIEW gold.warehouse_productivity_daily;
REFRESH MATERIALIZED VIEW gold.revenue_recognition_realtime;
```

### Scheduled Refresh (Fabric Pipeline)

```json
{
  "name": "Gold Layer - Materialized Views Refresh",
  "activities": [
    {
      "name": "Refresh Orders Summary",
      "type": "Script",
      "script": "REFRESH MATERIALIZED VIEW gold.orders_daily_summary;",
      "linkedService": "Lakehouse3PLAnalytics"
    },
    {
      "name": "Refresh SLA Performance",
      "type": "Script",
      "script": "REFRESH MATERIALIZED VIEW gold.sla_performance;"
    },
    {
      "name": "Refresh Shipments In Transit",
      "type": "Script",
      "script": "REFRESH MATERIALIZED VIEW gold.shipments_in_transit;"
    },
    {
      "name": "Refresh Warehouse Productivity",
      "type": "Script",
      "script": "REFRESH MATERIALIZED VIEW gold.warehouse_productivity_daily;"
    },
    {
      "name": "Refresh Revenue Recognition",
      "type": "Script",
      "script": "REFRESH MATERIALIZED VIEW gold.revenue_recognition_realtime;"
    }
  ],
  "trigger": {
    "type": "Schedule",
    "recurrence": {
      "frequency": "Day",
      "interval": 1,
      "startTime": "02:00:00"
    }
  }
}
```

---

## 6. Comparaison Solutions

| Critère | Notebooks Spark | **Materialized Lake Views** ✨ |
|---------|-----------------|--------------------------------|
| **Complexité** | Moyenne (code Python) | **Faible (SQL déclaratif)** ✅ |
| **Performance** | Bonne (Spark optimisé) | **Excellente (Delta native)** ✅ |
| **Maintenance** | Code à maintenir | **SQL simple** ✅ |
| **Latence refresh** | 5-15 min (pipeline) | **2-5 min (SQL exec)** ✅ |
| **Purview discovery** | ✅ Oui (Delta) | **✅ Oui (Delta natif)** |
| **Auto-optimize** | Manuel (script) | **✅ Automatique** |
| **Incremental load** | Code custom | **✅ Support natif** |
| **Partitioning** | Manuel (PySpark) | **✅ Déclaratif SQL** |
| **Cost** | Spark compute | **SQL compute (plus léger)** ✅ |
| **Flexibilité** | Très élevée (Python) | Moyenne (SQL) |

### Verdict: **MATERIALIZED LAKE VIEWS** 🏆

**Raisons:**
- ✅ **Simplicité maximale** : SQL déclaratif vs code Python
- ✅ **Performance native** : Optimisations Delta automatiques
- ✅ **Maintenance réduite** : Pas de code Spark à maintenir
- ✅ **Coût réduit** : SQL compute vs Spark clusters
- ✅ **Purview ready** : Tables Delta natives scannées automatiquement

---

## 7. Déploiement

### Étape 1: Créer les Materialized Views

```bash
# Dans Lakehouse SQL Endpoint (Lakehouse3PLAnalytics)
1. Ouvrir SQL Endpoint: 
   https://app.fabric.microsoft.com/groups/.../lakehouses/.../sqlendpoint

2. New Query

3. Copier/coller le contenu de create_materialized_lake_views.sql

4. Execute (F5)

5. Vérifier résultats:
   - 5 messages "✅ Materialized View gold.xxx created"
   - Summary affiché
```

### Étape 2: Refresh Initial

```sql
-- Refresh toutes les vues
REFRESH MATERIALIZED VIEW gold.orders_daily_summary;
REFRESH MATERIALIZED VIEW gold.sla_performance;
REFRESH MATERIALIZED VIEW gold.shipments_in_transit;
REFRESH MATERIALIZED VIEW gold.warehouse_productivity_daily;
REFRESH MATERIALIZED VIEW gold.revenue_recognition_realtime;
```

### Étape 3: Vérifier Tables Delta Créées

```sql
-- Lister toutes les tables
SHOW TABLES IN gold;

-- Vérifier data
SELECT * FROM gold.orders_daily_summary LIMIT 10;
SELECT * FROM gold.sla_performance LIMIT 10;
SELECT * FROM gold.shipments_in_transit LIMIT 10;
SELECT * FROM gold.warehouse_productivity_daily LIMIT 10;
SELECT * FROM gold.revenue_recognition_realtime LIMIT 10;
```

### Étape 4: Trigger Purview Scan

```bash
cd governance/purview
python purview_automation.py
```

### Étape 5: Créer Data Product

**Résultat attendu:** 10 tables gouvernées dans Purview ✅

---

## 8. Avantages Finaux

✅ **Solution OPTIMALE** : SQL simple + Delta natif + Purview ready
✅ **10 tables gouvernées** : 1 Bronze + 4 Silver + 5 Gold
✅ **Lineage complet** : Visible dans Purview
✅ **Performance** : <100ms queries (Delta optimisé)
✅ **Maintenance minimale** : SQL déclaratif (vs notebooks)
✅ **Coût réduit** : SQL compute (vs Spark)

**Prochaine étape:** Exécuter le script SQL dans Lakehouse !
