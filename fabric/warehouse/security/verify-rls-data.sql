-- ============================================================================
-- VERIFICATION DES DONNEES RLS DANS LES TABLES GOLD
-- ============================================================================
-- Purpose: Verifier que les colonnes RLS contiennent les valeurs attendues
--          avant de configurer OneLake RLS
-- Date: October 29, 2025
-- ============================================================================

-- ============================================================================
-- 1. VERIFICATION FEDEX CARRIER (carrier_id = 'CARRIER-FEDEX-GROUP')
-- ============================================================================

PRINT '============================================================================';
PRINT '1. VERIFICATION FEDEX CARRIER';
PRINT '============================================================================';
PRINT '';

-- Table: gold_shipments_in_transit
PRINT '--- gold_shipments_in_transit ---';
SELECT 
    'gold_shipments_in_transit' AS table_name,
    carrier_id,
    COUNT(*) AS row_count,
    MIN(shipment_number) AS sample_shipment,
    MAX(snapshot_timestamp) AS latest_update
FROM gold_shipments_in_transit
WHERE carrier_id = 'CARRIER-FEDEX-GROU'
GROUP BY carrier_id;

-- Verification: Existe-t-il des donnees CARRIER-FEDEX-GROU ?
IF NOT EXISTS (SELECT 1 FROM gold_shipments_in_transit WHERE carrier_id = 'CARRIER-FEDEX-GROU')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec carrier_id = ''CARRIER-FEDEX-GROU'' trouvee!';
    PRINT '    Action requise: Regenerer les donnees avec le simulateur';
END
ELSE
BEGIN
    PRINT '✅ Donnees CARRIER-FEDEX-GROU trouvees dans gold_shipments_in_transit';
END

PRINT '';

-- Table: gold_sla_performance
PRINT '--- gold_sla_performance ---';
SELECT 
    'gold_sla_performance' AS table_name,
    carrier_id,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_number) AS unique_orders,
    AVG(processing_days) AS avg_processing_days
FROM gold_sla_performance
WHERE carrier_id = 'CARRIER-FEDEX-GROU'
GROUP BY carrier_id;

-- Verification
IF NOT EXISTS (SELECT 1 FROM gold_sla_performance WHERE carrier_id = 'CARRIER-FEDEX-GROU')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec carrier_id = ''CARRIER-FEDEX-GROU'' trouvee!';
END
ELSE
BEGIN
    PRINT '✅ Donnees CARRIER-FEDEX-GROU trouvees dans gold_sla_performance';
END

PRINT '';
PRINT '';

-- ============================================================================
-- 2. VERIFICATION WAREHOUSE PARTNER (warehouse_partner_id = 'PARTNER_WH003')
-- ============================================================================

PRINT '============================================================================';
PRINT '2. VERIFICATION WAREHOUSE PARTNER';
PRINT '============================================================================';
PRINT '';

-- Table: gold_warehouse_productivity_daily
PRINT '--- gold_warehouse_productivity_daily ---';
SELECT 
    'gold_warehouse_productivity_daily' AS table_name,
    warehouse_partner_id,
    warehouse_partner_name,
    COUNT(*) AS row_count,
    SUM(total_movements) AS total_movements,
    AVG(productivity_variance_pct) AS avg_productivity_variance
FROM gold_warehouse_productivity_daily
WHERE warehouse_partner_id = 'PARTNER_WH003'
GROUP BY warehouse_partner_id, warehouse_partner_name;

-- Verification
IF NOT EXISTS (SELECT 1 FROM gold_warehouse_productivity_daily WHERE warehouse_partner_id = 'PARTNER_WH003')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec warehouse_partner_id = ''PARTNER_WH003'' trouvee!';
    PRINT '    Action requise: Regenerer les donnees avec le simulateur';
END
ELSE
BEGIN
    PRINT '✅ Donnees PARTNER_WH003 trouvees dans gold_warehouse_productivity_daily';
END

PRINT '';
PRINT '';

-- ============================================================================
-- 3. VERIFICATION CUSTOMER (partner_access_scope = 'CUSTOMER')
-- ============================================================================

PRINT '============================================================================';
PRINT '3. VERIFICATION CUSTOMER';
PRINT '============================================================================';
PRINT '';

-- Table: gold_orders_daily_summary
PRINT '--- gold_orders_daily_summary ---';
SELECT 
    'gold_orders_daily_summary' AS table_name,
    partner_access_scope,
    customer_id,
    customer_name,
    COUNT(*) AS row_count,
    SUM(total_orders) AS sum_total_orders,
    SUM(total_revenue) AS sum_total_revenue
FROM gold_orders_daily_summary
WHERE partner_access_scope = 'CUSTOMER'
GROUP BY partner_access_scope, customer_id, customer_name;

IF NOT EXISTS (SELECT 1 FROM gold_orders_daily_summary WHERE partner_access_scope = 'CUSTOMER')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec partner_access_scope = ''CUSTOMER'' trouvee!';
END
ELSE
BEGIN
    PRINT '✅ Donnees CUSTOMER trouvees dans gold_orders_daily_summary';
END

PRINT '';

-- Table: gold_shipments_in_transit
PRINT '--- gold_shipments_in_transit ---';
SELECT 
    'gold_shipments_in_transit' AS table_name,
    partner_access_scope,
    customer_id,
    customer_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT shipment_number) AS unique_shipments
FROM gold_shipments_in_transit
WHERE partner_access_scope = 'CUSTOMER'
GROUP BY partner_access_scope, customer_id, customer_name;

IF NOT EXISTS (SELECT 1 FROM gold_shipments_in_transit WHERE partner_access_scope = 'CUSTOMER')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec partner_access_scope = ''CUSTOMER'' trouvee!';
END
ELSE
BEGIN
    PRINT '✅ Donnees CUSTOMER trouvees dans gold_shipments_in_transit';
END

PRINT '';

-- Table: gold_revenue_recognition_realtime
PRINT '--- gold_revenue_recognition_realtime ---';
SELECT 
    'gold_revenue_recognition_realtime' AS table_name,
    partner_access_scope,
    customer_id,
    customer_name,
    COUNT(*) AS row_count,
    SUM(total_revenue) AS sum_revenue,
    SUM(total_due) AS sum_due
FROM gold_revenue_recognition_realtime
WHERE partner_access_scope = 'CUSTOMER'
GROUP BY partner_access_scope, customer_id, customer_name;

IF NOT EXISTS (SELECT 1 FROM gold_revenue_recognition_realtime WHERE partner_access_scope = 'CUSTOMER')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec partner_access_scope = ''CUSTOMER'' trouvee!';
END
ELSE
BEGIN
    PRINT '✅ Donnees CUSTOMER trouvees dans gold_revenue_recognition_realtime';
END

PRINT '';

-- Table: gold_sla_performance (CUSTOMER)
PRINT '--- gold_sla_performance (Customer View) ---';
SELECT 
    'gold_sla_performance' AS table_name,
    partner_access_scope,
    customer_id,
    customer_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_number) AS unique_orders
FROM gold_sla_performance
WHERE partner_access_scope = 'CUSTOMER'
GROUP BY partner_access_scope, customer_id, customer_name;

IF NOT EXISTS (SELECT 1 FROM gold_sla_performance WHERE partner_access_scope = 'CUSTOMER')
BEGIN
    PRINT '⚠️  ATTENTION: Aucune donnee avec partner_access_scope = ''CUSTOMER'' trouvee!';
END
ELSE
BEGIN
    PRINT '✅ Donnees CUSTOMER trouvees dans gold_sla_performance';
END

PRINT '';
PRINT '';

-- ============================================================================
-- 4. RESUME GLOBAL - VERIFICATION DE TOUTES LES VALEURS RLS
-- ============================================================================

PRINT '============================================================================';
PRINT '4. RESUME GLOBAL - VALEURS DISTINCTES DANS COLONNES RLS';
PRINT '============================================================================';
PRINT '';

-- Toutes les valeurs carrier_id dans gold_shipments_in_transit
PRINT '--- Carriers disponibles (gold_shipments_in_transit) ---';
SELECT 
    carrier_id,
    COUNT(*) AS shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id
ORDER BY COUNT(*) DESC;

PRINT '';

-- Toutes les valeurs warehouse_partner_id dans gold_warehouse_productivity_daily
PRINT '--- Warehouse Partners disponibles (gold_warehouse_productivity_daily) ---';
SELECT 
    warehouse_partner_id,
    warehouse_partner_name,
    COUNT(*) AS row_count
FROM gold_warehouse_productivity_daily
GROUP BY warehouse_partner_id, warehouse_partner_name
ORDER BY COUNT(*) DESC;

PRINT '';

-- Toutes les valeurs partner_access_scope dans gold_orders_daily_summary
PRINT '--- Partner Access Scopes disponibles (gold_orders_daily_summary) ---';
SELECT 
    partner_access_scope,
    COUNT(*) AS row_count,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM gold_orders_daily_summary
GROUP BY partner_access_scope
ORDER BY COUNT(*) DESC;

PRINT '';
PRINT '';

-- ============================================================================
-- 5. TEST DE FILTRAGE SIMULE (Preview du RLS)
-- ============================================================================

PRINT '============================================================================';
PRINT '5. PREVIEW DU FILTRAGE RLS';
PRINT '============================================================================';
PRINT '';

PRINT '--- FedEx Carrier View (Simulated) ---';
PRINT 'Query: SELECT TOP 5 * FROM gold_shipments_in_transit WHERE carrier_id = ''CARRIER-FEDEX-GROU''';
SELECT TOP 5
    shipment_number,
    carrier_id,
    carrier_name,
    delay_status,
    days_in_transit
FROM gold_shipments_in_transit
WHERE carrier_id = 'CARRIER-FEDEX-GROU'
ORDER BY snapshot_timestamp DESC;

PRINT '';

PRINT '--- Warehouse Partner View (Simulated) ---';
PRINT 'Query: SELECT TOP 5 * FROM gold_warehouse_productivity_daily WHERE warehouse_partner_id = ''PARTNER_WH003''';
SELECT TOP 5
    movement_day,
    warehouse_id,
    warehouse_partner_id,
    performance_status,
    total_movements
FROM gold_warehouse_productivity_daily
WHERE warehouse_partner_id = 'PARTNER_WH003'
ORDER BY movement_day DESC;

PRINT '';

PRINT '--- Customer View (Simulated) ---';
PRINT 'Query: SELECT TOP 5 * FROM gold_orders_daily_summary WHERE partner_access_scope = ''CUSTOMER''';
SELECT TOP 5
    order_day,
    customer_id,
    partner_access_scope,
    total_orders,
    total_revenue,
    sla_compliance_pct
FROM gold_orders_daily_summary
WHERE partner_access_scope = 'CUSTOMER'
ORDER BY order_day DESC;

PRINT '';
PRINT '';

-- ============================================================================
-- 6. CHECKLIST DE VALIDATION FINALE
-- ============================================================================

PRINT '============================================================================';
PRINT '6. CHECKLIST DE VALIDATION';
PRINT '============================================================================';
PRINT '';

DECLARE @FedExShipments INT = (SELECT COUNT(*) FROM gold_shipments_in_transit WHERE carrier_id = 'CARRIER-FEDEX-GROU');
DECLARE @FedExSLA INT = (SELECT COUNT(*) FROM gold_sla_performance WHERE carrier_id = 'CARRIER-FEDEX-GROU');
DECLARE @WarehousePartner INT = (SELECT COUNT(*) FROM gold_warehouse_productivity_daily WHERE warehouse_partner_id = 'PARTNER_WH003');
DECLARE @CustomerOrders INT = (SELECT COUNT(*) FROM gold_orders_daily_summary WHERE partner_access_scope = 'CUSTOMER');
DECLARE @CustomerShipments INT = (SELECT COUNT(*) FROM gold_shipments_in_transit WHERE partner_access_scope = 'CUSTOMER');
DECLARE @CustomerRevenue INT = (SELECT COUNT(*) FROM gold_revenue_recognition_realtime WHERE partner_access_scope = 'CUSTOMER');
DECLARE @CustomerSLA INT = (SELECT COUNT(*) FROM gold_sla_performance WHERE partner_access_scope = 'CUSTOMER');

PRINT 'FEDEX CARRIER (CARRIER-FEDEX-GROU):';
PRINT '  [' + CASE WHEN @FedExShipments > 0 THEN 'X' ELSE ' ' END + '] gold_shipments_in_transit: ' + CAST(@FedExShipments AS VARCHAR) + ' rows';
PRINT '  [' + CASE WHEN @FedExSLA > 0 THEN 'X' ELSE ' ' END + '] gold_sla_performance: ' + CAST(@FedExSLA AS VARCHAR) + ' rows';
PRINT '';

PRINT 'WAREHOUSE PARTNER (PARTNER_WH003):';
PRINT '  [' + CASE WHEN @WarehousePartner > 0 THEN 'X' ELSE ' ' END + '] gold_warehouse_productivity_daily: ' + CAST(@WarehousePartner AS VARCHAR) + ' rows';
PRINT '';

PRINT 'CUSTOMER (CUSTOMER):';
PRINT '  [' + CASE WHEN @CustomerOrders > 0 THEN 'X' ELSE ' ' END + '] gold_orders_daily_summary: ' + CAST(@CustomerOrders AS VARCHAR) + ' rows';
PRINT '  [' + CASE WHEN @CustomerShipments > 0 THEN 'X' ELSE ' ' END + '] gold_shipments_in_transit: ' + CAST(@CustomerShipments AS VARCHAR) + ' rows';
PRINT '  [' + CASE WHEN @CustomerRevenue > 0 THEN 'X' ELSE ' ' END + '] gold_revenue_recognition_realtime: ' + CAST(@CustomerRevenue AS VARCHAR) + ' rows';
PRINT '  [' + CASE WHEN @CustomerSLA > 0 THEN 'X' ELSE ' ' END + '] gold_sla_performance: ' + CAST(@CustomerSLA AS VARCHAR) + ' rows';
PRINT '';

IF @FedExShipments > 0 AND @FedExSLA > 0 AND @WarehousePartner > 0 AND @CustomerOrders > 0 AND @CustomerShipments > 0 AND @CustomerRevenue > 0 AND @CustomerSLA > 0
BEGIN
    PRINT '✅ VALIDATION COMPLETE: Toutes les tables contiennent les donnees RLS attendues!';
    PRINT '   Vous pouvez configurer OneLake RLS en toute confiance.';
END
ELSE
BEGIN
    PRINT '⚠️  VALIDATION INCOMPLETE: Certaines tables manquent de donnees RLS.';
    PRINT '   Actions requises:';
    PRINT '   1. Regenerer les donnees: cd simulator; python main.py --count 100';
    PRINT '   2. Attendre la synchronisation du mirroring (1-2 minutes)';
    PRINT '   3. Re-executer le notebook Gold Views dans Fabric Portal';
    PRINT '   4. Relancer ce script de verification';
END

PRINT '';
PRINT '============================================================================';
PRINT 'FIN DE LA VERIFICATION';
PRINT '============================================================================';
