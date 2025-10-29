# 🚀 GUIDE D'EXÉCUTION - Mise à jour B2B des schémas Eventhouse et Lakehouse

**Date:** 2025-10-28  
**Objectif:** Ajouter les colonnes B2B (carrier_id, customer_id, warehouse_partner_id) pour le partage de données multi-tenant

---

## 📋 Ordre d'exécution

### ✅ ÉTAPE 1 : Mettre à jour la vue IDocSummary dans Eventhouse

**Fichier:** `fabric/warehouse/schema/add-b2b-partner-columns.kql`

**Où exécuter:**
- Ouvrir Fabric Portal → Eventhouse `kqldbsapidoc`
- URL: https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/f91aaea3-7889-4415-851c-f4258a2fff6b/query

**Actions:**
1. Copier le contenu complet du fichier `add-b2b-partner-columns.kql`
2. Coller dans Query Editor
3. Exécuter (F5)

**Résultat attendu:**
```
✓ Helper functions created/updated
✓ Materialized view IDocSummary recreated with B2B columns
✓ B2B PARTNER COLUMNS ADDED
```

**Colonnes ajoutées à IDocSummary:**
- `carrier_id`
- `carrier_name`
- `customer_id`
- `customer_name`
- `warehouse_partner_id`
- `warehouse_partner_name`
- `partner_access_scope`

---

### ✅ ÉTAPE 2 : Mettre à jour les tables Silver

**Fichier:** `fabric/warehouse/schema/update-silver-tables-b2b.kql`

**Où exécuter:**
- Même Eventhouse `kqldbsapidoc`

**Actions:**
1. Copier le contenu de `update-silver-tables-b2b.kql`
2. Coller dans Query Editor
3. Exécuter (F5)

**⚠️ ATTENTION:** Ce script va **DROP et recréer** les 4 tables Silver :
- `idoc_shipments_silver`
- `idoc_orders_silver`
- `idoc_warehouse_silver`
- `idoc_invoices_silver`

**Résultat attendu:**
```
✓ idoc_shipments_silver updated with B2B columns
✓ idoc_orders_silver updated with B2B columns
✓ idoc_warehouse_silver updated with B2B columns
✓ idoc_invoices_silver updated with B2B columns
✓ ALL SILVER TABLES UPDATED
```

**Colonnes B2B ajoutées:**

| Table | Nouvelles colonnes |
|-------|-------------------|
| `idoc_shipments_silver` | carrier_id, carrier_name_b2b, customer_id, customer_name, partner_access_scope |
| `idoc_orders_silver` | customer_id, customer_name, partner_access_scope |
| `idoc_warehouse_silver` | warehouse_partner_id, warehouse_partner_name, partner_access_scope |
| `idoc_invoices_silver` | customer_id, customer_name, partner_access_scope |

---

### ✅ ÉTAPE 3 : Mettre à jour les vues Gold Materialized Lake Views

**Fichier:** À créer - `fabric/data-engineering/notebooks/Update_Gold_MLVs_B2B.ipynb`

**Où exécuter:**
- Fabric Portal → Lakehouse `Lakehouse3PL` → Notebooks

**Actions:**
1. Ouvrir le notebook existant `Create_Gold_Materialized_Lake_Views`
2. Ajouter les nouvelles colonnes B2B dans les requêtes SQL :

**Modifications requises pour chaque vue Gold:**

#### `gold_shipments_in_transit`
```sql
CREATE OR REPLACE VIEW gold_shipments_in_transit AS
SELECT 
    shipment_number,
    tracking_number,
    -- *** NOUVELLES COLONNES B2B ***
    carrier_id,
    carrier_name_b2b AS carrier_name,
    customer_id,
    customer_name,
    partner_access_scope,
    -- Colonnes existantes
    order_number,
    origin_location,
    destination_location,
    planned_delivery_date,
    estimated_delivery_date,
    shipment_status,
    current_location,
    total_weight_kg,
    ingestion_timestamp
FROM kqldbsapidoc.idoc_shipments_silver
WHERE is_in_transit = true
```

#### `gold_orders_summary`
```sql
CREATE OR REPLACE VIEW gold_orders_summary AS
SELECT 
    order_number,
    -- *** NOUVELLES COLONNES B2B ***
    customer_id,
    customer_name,
    partner_access_scope,
    -- Colonnes existantes
    order_date,
    requested_delivery_date,
    order_status,
    fulfillment_status,
    total_value,
    currency,
    total_quantity,
    line_item_count,
    ingestion_timestamp
FROM kqldbsapidoc.idoc_orders_silver
```

#### `gold_warehouse_productivity`
```sql
CREATE OR REPLACE VIEW gold_warehouse_productivity AS
SELECT 
    warehouse_id,
    -- *** NOUVELLES COLONNES B2B ***
    warehouse_partner_id,
    warehouse_partner_name,
    partner_access_scope,
    -- Colonnes existantes
    operation_type,
    operation_date,
    confirmation_date,
    COUNT(*) AS operation_count,
    SUM(quantity) AS total_quantity,
    SUM(weight_kg) AS total_weight_kg,
    ingestion_timestamp
FROM kqldbsapidoc.idoc_warehouse_silver
GROUP BY 
    warehouse_id,
    warehouse_partner_id,
    warehouse_partner_name,
    partner_access_scope,
    operation_type,
    operation_date,
    confirmation_date,
    ingestion_timestamp
```

#### `gold_sla_performance`
```sql
CREATE OR REPLACE VIEW gold_sla_performance AS
SELECT 
    -- *** NOUVELLES COLONNES B2B ***
    carrier_id,
    carrier_name_b2b AS carrier_name,
    partner_access_scope,
    -- Colonnes existantes
    CAST(planned_delivery_date AS DATE) AS delivery_date,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) AS on_time_deliveries,
    CAST(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS sla_compliance_pct,
    AVG(delivery_delay_hours) AS avg_delay_hours
FROM kqldbsapidoc.idoc_shipments_silver
WHERE actual_delivery_date IS NOT NULL
GROUP BY 
    carrier_id,
    carrier_name_b2b,
    partner_access_scope,
    CAST(planned_delivery_date AS DATE)
```

#### `gold_revenue_realtime`
```sql
CREATE OR REPLACE VIEW gold_revenue_realtime AS
SELECT 
    -- *** NOUVELLES COLONNES B2B ***
    customer_id,
    customer_name,
    partner_access_scope,
    -- Colonnes existantes
    CAST(invoice_date AS DATE) AS revenue_date,
    currency,
    COUNT(*) AS invoice_count,
    SUM(invoice_amount) AS total_invoice_amount,
    SUM(tax_amount) AS total_tax_amount,
    SUM(total_amount) AS total_revenue,
    ingestion_timestamp
FROM kqldbsapidoc.idoc_invoices_silver
GROUP BY 
    customer_id,
    customer_name,
    partner_access_scope,
    CAST(invoice_date AS DATE),
    currency,
    ingestion_timestamp
```

---

### ⏸️ ÉTAPE 4 : Régénérer les données IDoc avec les nouveaux champs

**Après** avoir mis à jour tous les schémas :

```powershell
cd simulator
python main.py --count 100
```

**Validation:** Vérifier qu'Event Hub reçoit les IDocs avec les nouveaux champs :
- `carrier_id` (ex: "CARRIER-DHL-EXPRE")
- `customer_name` (ex: "Acme Manufacturing Co")
- `warehouse_partner_id` (ex: "PARTNER-WH003")

---

### ⏸️ ÉTAPE 5 : Valider l'ingestion des données B2B

**Dans Eventhouse:**
```kql
// Vérifier que IDocSummary contient les nouveaux champs
IDocSummary
| where timestamp > ago(1h)
| take 10
| project 
    timestamp,
    message_type,
    carrier_id,
    carrier_name,
    customer_id,
    customer_name,
    warehouse_partner_id,
    partner_access_scope
```

**Dans Lakehouse:**
```sql
-- Vérifier les vues Gold
SELECT * FROM gold_shipments_in_transit LIMIT 10;
SELECT * FROM gold_orders_summary LIMIT 10;
SELECT * FROM gold_warehouse_productivity LIMIT 10;
```

---

## 🎯 Checklist de validation

### Eventhouse (kqldbsapidoc)
- [ ] IDocSummary recreated avec colonnes B2B
- [ ] idoc_shipments_silver a carrier_id, customer_id
- [ ] idoc_orders_silver a customer_id
- [ ] idoc_warehouse_silver a warehouse_partner_id
- [ ] idoc_invoices_silver a customer_id
- [ ] Update policies fonctionnelles

### Lakehouse (Lakehouse3PL)
- [ ] gold_shipments_in_transit a carrier_id, customer_id
- [ ] gold_orders_summary a customer_id
- [ ] gold_warehouse_productivity a warehouse_partner_id
- [ ] gold_sla_performance a carrier_id
- [ ] gold_revenue_realtime a customer_id

### Simulator
- [ ] Générer 100 IDocs de test
- [ ] Vérifier présence des champs B2B dans Event Hub
- [ ] Confirmer ingestion dans idoc_raw
- [ ] Valider extraction dans tables Silver
- [ ] Confirmer disponibilité dans vues Gold

---

## 📊 Requêtes de test B2B

### Test 1: Distribution des transporteurs
```kql
IDocSummary
| where message_type == "SHPMNT"
| summarize ShipmentCount = count() by carrier_id, carrier_name
| order by ShipmentCount desc
```

### Test 2: Distribution des clients
```kql
IDocSummary
| where message_type in ("ORDERS", "INVOIC")
| summarize 
    OrderCount = countif(message_type == "ORDERS"),
    InvoiceCount = countif(message_type == "INVOIC")
    by customer_id, customer_name
| order by OrderCount desc
```

### Test 3: Entrepôts partenaires
```kql
IDocSummary
| where message_type == "WHSCON" and warehouse_partner_id != ""
| summarize OperationCount = count() by warehouse_partner_id, warehouse_partner_name
| order by OperationCount desc
```

### Test 4: Couverture B2B
```kql
IDocSummary
| summarize 
    Total = count(),
    WithCarrier = countif(carrier_id != ""),
    WithCustomer = countif(customer_id != ""),
    WithWarehousePartner = countif(warehouse_partner_id != "")
| extend 
    CarrierCoverage = strcat(round(WithCarrier * 100.0 / Total, 1), "%"),
    CustomerCoverage = strcat(round(WithCustomer * 100.0 / Total, 1), "%"),
    PartnerCoverage = strcat(round(WithWarehousePartner * 100.0 / Total, 1), "%")
```

---

## ⚠️ Points d'attention

### Perte de données Silver
Les scripts DROP les tables Silver existantes. Si des données sont présentes :
1. **Backup recommandé** avant exécution
2. Les données seront re-matérialisées depuis `idoc_raw` via update policies
3. Si `idoc_raw` est vide, les tables Silver seront vides

### Temps d'exécution
- STEP 1 (Eventhouse IDocSummary): ~30 secondes
- STEP 2 (Silver tables): ~2 minutes (drop + recreate + backfill)
- STEP 3 (Gold MLVs): ~1 minute par vue (5 vues = 5 minutes)

### Rollback
Si problème, restaurer les schémas originaux :
- `fabric/warehouse/schema/recreate-idoc-table-optimized.kql`
- `fabric/warehouse/schema/create-silver-*.kql`
- `fabric/data-engineering/notebooks/Create_Gold_Materialized_Lake_Views.ipynb`

---

## 📞 Support

En cas de problème :
1. Vérifier les erreurs dans Query Results (Eventhouse)
2. Consulter `simulator/B2B_SCHEMA_ENHANCEMENTS.md` pour les détails des champs
3. Vérifier que Event Hub est accessible avec `az login`

---

**Prêt à commencer ?** → Exécuter ÉTAPE 1 dans Fabric Eventhouse Portal
