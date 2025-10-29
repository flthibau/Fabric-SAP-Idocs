-- ===================================================================
-- CREATE GOLD LAYER - MATERIALIZED LAKE VIEWS
-- ===================================================================
-- Lakehouse: Lakehouse3PLAnalytics
-- Schema: gold
-- Tables source: Silver layer (shortcuts OneLake)
-- Output: 5 materialized views → Delta tables automatiques
-- Date: 2025-10-27

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

SELECT '✅ Materialized View gold.orders_daily_summary created' AS status;

-- ===================================================================
-- 2. SLA PERFORMANCE
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.sla_performance;

CREATE MATERIALIZED VIEW gold.sla_performance
PARTITIONED BY (order_date)
COMMENT 'Tracking SLA temps réel avec classification enrichie'
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
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);

SELECT '✅ Materialized View gold.sla_performance created' AS status;

-- ===================================================================
-- 3. SHIPMENTS IN TRANSIT
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.shipments_in_transit;

CREATE MATERIALIZED VIEW gold.shipments_in_transit
COMMENT 'Expéditions en cours avec ETA - Snapshot temps réel'
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
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);

SELECT '✅ Materialized View gold.shipments_in_transit created' AS status;

-- ===================================================================
-- 4. WAREHOUSE PRODUCTIVITY DAILY
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.warehouse_productivity_daily;

CREATE MATERIALIZED VIEW gold.warehouse_productivity_daily
PARTITIONED BY (movement_day)
COMMENT 'KPI entrepôt quotidien avec productivité et exceptions'
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
    COUNT(CASE WHEN exception_type = 'Damage' THEN 1 END) AS damage_count,
    COUNT(CASE WHEN exception_type = 'Shortage' THEN 1 END) AS shortage_count,
    COUNT(CASE WHEN exception_type = 'Quality' THEN 1 END) AS quality_count,
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
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT operator_id), 2) AS movements_per_operator,
    CURRENT_TIMESTAMP() AS processed_timestamp
FROM idoc_warehouse_silver
GROUP BY DATE_TRUNC('day', movement_timestamp), warehouse_id, movement_type, sap_system;

ALTER MATERIALIZED VIEW gold.warehouse_productivity_daily 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.dataSkippingNumIndexedCols' = '3'
);

SELECT '✅ Materialized View gold.warehouse_productivity_daily created' AS status;

-- ===================================================================
-- 5. REVENUE RECOGNITION REALTIME
-- ===================================================================
DROP MATERIALIZED VIEW IF EXISTS gold.revenue_recognition_realtime;

CREATE MATERIALIZED VIEW gold.revenue_recognition_realtime
PARTITIONED BY (invoice_day)
COMMENT 'Performance financière temps réel avec aging buckets'
AS
SELECT 
    DATE_TRUNC('day', invoice_date) AS invoice_day,
    customer_id,
    sap_system,
    COUNT(*) AS total_invoices,
    COUNT(DISTINCT invoice_number) AS unique_invoices,
    SUM(total_amount) AS total_revenue,
    SUM(amount_paid) AS total_paid,
    SUM(amount_due) AS total_due,
    COUNT(CASE WHEN payment_status = 'Pending' THEN 1 END) AS pending_invoices,
    COUNT(CASE WHEN payment_status = 'Partial' THEN 1 END) AS partial_invoices,
    COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) AS paid_invoices,
    COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) AS overdue_invoices,
    COALESCE(SUM(CASE WHEN aging_bucket = 'Current' THEN amount_due END), 0) AS aging_current,
    COALESCE(SUM(CASE WHEN aging_bucket = '1-30' THEN amount_due END), 0) AS aging_1_30,
    COALESCE(SUM(CASE WHEN aging_bucket = '31-60' THEN amount_due END), 0) AS aging_31_60,
    COALESCE(SUM(CASE WHEN aging_bucket = '61-90' THEN amount_due END), 0) AS aging_61_90,
    COALESCE(SUM(CASE WHEN aging_bucket = '90+' THEN amount_due END), 0) AS aging_90_plus,
    AVG(CASE WHEN payment_date IS NOT NULL THEN DATEDIFF(day, invoice_date, payment_date) END) AS avg_days_to_payment,
    AVG(total_amount) AS avg_invoice_value,
    CAST(CASE WHEN SUM(total_amount) > 0 THEN SUM(amount_paid) * 100.0 / SUM(total_amount) ELSE 0 END AS DECIMAL(5,2)) AS collection_efficiency_pct,
    CAST(COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS payment_rate_pct,
    CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS overdue_rate_pct,
    30 AS dso_target_days,
    AVG(CASE WHEN payment_date IS NOT NULL THEN DATEDIFF(day, invoice_date, payment_date) END) - 30 AS dso_variance_days,
    CASE 
        WHEN CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) > 20 THEN 'High'
        WHEN CAST(COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) > 10 THEN 'Medium'
        ELSE 'Low'
    END AS collection_risk,
    CURRENT_TIMESTAMP() AS processed_timestamp
FROM idoc_invoices_silver
GROUP BY DATE_TRUNC('day', invoice_date), customer_id, sap_system;

ALTER MATERIALIZED VIEW gold.revenue_recognition_realtime 
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.enableChangeDataFeed' = 'true'
);

SELECT '✅ Materialized View gold.revenue_recognition_realtime created' AS status;

-- ===================================================================
-- SUMMARY
-- ===================================================================
SELECT '';
SELECT '========================================';
SELECT '  MATERIALIZED LAKE VIEWS - CREATED';
SELECT '========================================';
SELECT 'Schema: gold';
SELECT 'Views created: 5';
SELECT '  ✅ orders_daily_summary (partitioned by order_day)';
SELECT '  ✅ sla_performance (partitioned by order_date)';
SELECT '  ✅ shipments_in_transit (snapshot)';
SELECT '  ✅ warehouse_productivity_daily (partitioned by movement_day)';
SELECT '  ✅ revenue_recognition_realtime (partitioned by invoice_day)';
SELECT '';
SELECT 'Next steps:';
SELECT '1. Refresh views: REFRESH MATERIALIZED VIEW gold.<view_name>';
SELECT '2. Verify tables: SHOW TABLES IN gold';
SELECT '3. Test queries: SELECT * FROM gold.orders_daily_summary LIMIT 10';
SELECT '4. Trigger Purview scan';
SELECT '========================================';
