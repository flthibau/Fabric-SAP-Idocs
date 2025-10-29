# Gold Layer - Notebooks Implementation Guide

**Created:** 2025-10-27  
**Purpose:** Guide d'implémentation des notebooks Gold Layer dans Fabric  
**Architecture:** Silver (shortcuts OneLake) → Spark Notebooks → Gold (Delta tables natives)

---

## 📁 Structure des Fichiers

```
fabric/data-engineering/
├── notebooks/
│   ├── gold_layer_orders_summary.py          ✅ CRÉÉ
│   ├── gold_layer_sla_performance.py          ✅ CRÉÉ
│   ├── gold_layer_shipments_in_transit.py     ✅ CRÉÉ
│   ├── gold_layer_warehouse_productivity.py   ✅ CRÉÉ
│   └── gold_layer_revenue_recognition.py      ✅ CRÉÉ
└── pipelines/
    └── pipeline_gold_layer_refresh.json       ✅ CRÉÉ
```

---

## 🚀 Déploiement dans Fabric

### Étape 1: Uploader les Notebooks

#### Via Fabric Portal (UI)

1. **Ouvrir Workspace JAc**
   ```
   https://app.fabric.microsoft.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64
   ```

2. **Pour chaque notebook:**
   - Cliquer sur `+ New` → `Notebook`
   - Dans le notebook vide, cliquer sur le menu `...` → `Import`
   - Sélectionner le fichier `.py` correspondant
   - OU copier/coller directement le contenu du fichier
   - Renommer le notebook:
     * `Gold Layer - Orders Summary`
     * `Gold Layer - SLA Performance`
     * `Gold Layer - Shipments In Transit`
     * `Gold Layer - Warehouse Productivity`
     * `Gold Layer - Revenue Recognition`
   - Sauvegarder (Ctrl+S)

3. **Configurer Lakehouse par défaut:**
   - Dans chaque notebook, cliquer sur `Add` (en haut à gauche)
   - Sélectionner `Lakehouse`
   - Choisir `Lakehouse3PLAnalytics`
   - Cliquer `Add`
   - Le Lakehouse apparaît maintenant dans la sidebar gauche

#### Via Git (Recommandé pour production)

```bash
# Cloner le repo dans Fabric Workspace
1. Dans Fabric Portal → Workspace Settings → Git integration
2. Connect to Git
3. Repository URL: https://github.com/flthibau/Fabric-SAP-Idocs
4. Branch: main
5. Path: fabric/data-engineering/notebooks
6. Sync

# Les notebooks apparaissent automatiquement dans le workspace
```

---

### Étape 2: Tester les Notebooks Individuellement

#### Test 1: Orders Summary

```python
# Dans Fabric Notebook: Gold Layer - Orders Summary
# Cliquer sur "Run All" ou Ctrl+Shift+Enter

# Vérifier résultats attendus:
# 1. Source rows: [nombre de lignes dans idoc_orders_silver]
# 2. Gold rows computed: [nombre de jours × systèmes × SLA status]
# 3. Table orders_daily_summary créée dans Tables/
# 4. MERGE completed successfully
# 5. Summary affichée avec total_orders, avg_sla_compliance_pct
```

**Validation:**
- Aller dans Lakehouse → Tables → Vérifier `orders_daily_summary` existe
- Cliquer sur la table → Preview data
- Vérifier colonnes: order_day, sap_system, sla_status, total_orders, total_revenue, sla_compliance_pct

**Durée attendue:** 2-5 minutes

---

#### Test 2: SLA Performance

```python
# Notebook: Gold Layer - SLA Performance
# Run All

# Vérifier:
# 1. Orders + Shipments jointure réussie
# 2. SLA metrics calculés (processing_days, sla_compliance, on_time_delivery)
# 3. Table sla_performance créée
# 4. Summary par sla_compliance affiché
```

**Validation:**
- Table `sla_performance` existe
- Colonnes: order_number, processing_days, sla_compliance, is_critical, on_time_delivery
- Data quality: Aucune ligne avec processing_days < 0

**Durée attendue:** 3-7 minutes (JOIN coûteux)

---

#### Test 3: Shipments In Transit

```python
# Notebook: Gold Layer - Shipments In Transit
# Run All

# Vérifier:
# 1. Filtre In Transit appliqué (actual_ship_date NOT NULL, actual_delivery_date NULL)
# 2. ETA et delay metrics calculés
# 3. Table shipments_in_transit OVERWRITTEN (pas merge)
# 4. Top delayed shipments affichés
```

**Validation:**
- Table `shipments_in_transit` existe
- Snapshot temps réel uniquement (pas d'historique)
- Colonnes: days_in_transit, days_until_planned_delivery, delay_status, priority

**Durée attendue:** 1-3 minutes

---

#### Test 4: Warehouse Productivity

```python
# Notebook: Gold Layer - Warehouse Productivity
# Run All

# Vérifier:
# 1. Agrégations par jour × warehouse × movement_type
# 2. Productivité calculée (movements_per_hour, quantity_per_hour)
# 3. Exception rate calculé
# 4. Table warehouse_productivity_daily créée
```

**Validation:**
- Table `warehouse_productivity_daily` existe
- Colonnes: movement_day, warehouse_id, quantity_per_hour, exception_rate_pct, performance_status
- Productivity target = 100

**Durée attendue:** 2-5 minutes

---

#### Test 5: Revenue Recognition

```python
# Notebook: Gold Layer - Revenue Recognition
# Run All

# Vérifier:
# 1. Agrégations par jour × customer
# 2. Aging buckets calculés (Current, 1-30, 31-60, 61-90, 90+)
# 3. DSO (Days Sales Outstanding) calculé
# 4. Collection efficiency calculé
# 5. Table revenue_recognition_realtime créée
```

**Validation:**
- Table `revenue_recognition_realtime` existe
- Colonnes: invoice_day, customer_id, total_revenue, total_paid, total_due, aging buckets, collection_efficiency_pct
- Data quality: total_paid + total_due = total_revenue (± 1 cent)

**Durée attendue:** 2-5 minutes

---

### Étape 3: Créer le Pipeline d'Orchestration

#### Via Fabric Portal

1. **Créer nouveau Pipeline:**
   ```
   Workspace JAc → + New → Data pipeline
   Nom: "Gold Layer - Daily Refresh"
   ```

2. **Ajouter 5 activités Notebook (parallèle):**
   - Dans le canvas, glisser-déposer `Notebook` (5 fois)
   - Configurer chaque activité:
     
     **Activité 1:**
     - Name: `Orders Daily Summary`
     - Notebook: `Gold Layer - Orders Summary`
     - Lakehouse: `Lakehouse3PLAnalytics`
     - Timeout: 10 minutes
     - Retry: 2
     
     **Activité 2:**
     - Name: `SLA Performance`
     - Notebook: `Gold Layer - SLA Performance`
     - Timeout: 10 minutes
     - Retry: 2
     
     **Activité 3:**
     - Name: `Shipments In Transit`
     - Notebook: `Gold Layer - Shipments In Transit`
     - Timeout: 5 minutes
     - Retry: 2
     
     **Activité 4:**
     - Name: `Warehouse Productivity`
     - Notebook: `Gold Layer - Warehouse Productivity`
     - Timeout: 10 minutes
     - Retry: 2
     
     **Activité 5:**
     - Name: `Revenue Recognition`
     - Notebook: `Gold Layer - Revenue Recognition`
     - Timeout: 10 minutes
     - Retry: 2

3. **Ajouter activité Web (trigger Purview scan):**
   - Après les 5 notebooks (dépendance: "On Success")
   - Name: `Trigger Purview Scan`
   - URL: `https://stpurview.scan.purview.azure.com/datasources/Fabric-JAc/scans/Scan-DKT/run?api-version=2022-07-01-preview`
   - Method: `POST`
   - Authentication: `Managed Identity`
   - Body:
     ```json
     {
       "scanLevel": "Full"
     }
     ```

4. **Configurer Schedule Trigger:**
   - Dans Pipeline → Settings → Triggers
   - + New → Schedule
   - Name: `Daily Refresh 2AM`
   - Recurrence: Daily
   - Time: 02:00 AM (UTC)
   - Start date: Aujourd'hui
   - Activer le trigger

5. **Sauvegarder et Publier:**
   - Save → Publish

---

### Étape 4: Exécution Manuelle Initiale

1. **Déclencher pipeline:**
   ```
   Pipeline → Run
   ```

2. **Monitorer l'exécution:**
   - Aller dans `Monitor` (sidebar gauche)
   - Pipeline runs → Voir le run en cours
   - Cliquer sur le run pour voir détails
   - Vérifier que les 5 notebooks s'exécutent en parallèle
   - Attendre succès (durée estimée: 10-15 minutes)

3. **Vérifier résultats:**
   - Lakehouse → Tables → Devrait voir **10 tables total**:
     * 5 shortcuts (Bronze + Silver): idoc_raw, idoc_orders_silver, idoc_shipments_silver, idoc_warehouse_silver, idoc_invoices_silver
     * 5 tables Delta natives (Gold): orders_daily_summary, sla_performance, shipments_in_transit, warehouse_productivity_daily, revenue_recognition_realtime

4. **Tester queries SQL:**
   ```sql
   -- Dans Lakehouse SQL Endpoint
   
   -- Liste toutes les tables
   SHOW TABLES;
   
   -- Test table Gold - Orders Summary
   SELECT * FROM orders_daily_summary
   WHERE order_day >= CURRENT_DATE - INTERVAL 7 DAYS
   ORDER BY order_day DESC, total_orders DESC
   LIMIT 100;
   
   -- Test table Gold - SLA Performance
   SELECT 
       sla_compliance,
       COUNT(*) as order_count,
       ROUND(AVG(processing_days), 2) as avg_processing_days,
       COUNT(CASE WHEN is_critical THEN 1 END) as critical_orders
   FROM sla_performance
   GROUP BY sla_compliance
   ORDER BY order_count DESC;
   
   -- Test table Gold - Shipments In Transit
   SELECT * FROM shipments_in_transit
   WHERE delay_status = 'Delayed'
   ORDER BY days_delayed DESC, shipment_value DESC
   LIMIT 20;
   
   -- Test table Gold - Warehouse Productivity
   SELECT 
       warehouse_id,
       ROUND(AVG(quantity_per_hour), 2) as avg_productivity,
       ROUND(AVG(exception_rate_pct), 2) as avg_exception_rate,
       COUNT(*) as total_days
   FROM warehouse_productivity_daily
   WHERE movement_day >= CURRENT_DATE - INTERVAL 30 DAYS
   GROUP BY warehouse_id
   ORDER BY avg_productivity DESC;
   
   -- Test table Gold - Revenue Recognition
   SELECT 
       customer_id,
       SUM(total_revenue) as total_revenue,
       SUM(aging_90_plus) as at_risk_amount,
       ROUND(AVG(collection_efficiency_pct), 2) as avg_collection_efficiency
   FROM revenue_recognition_realtime
   WHERE invoice_day >= CURRENT_DATE - INTERVAL 90 DAYS
   GROUP BY customer_id
   ORDER BY total_revenue DESC
   LIMIT 10;
   ```

---

## 🔍 Purview Integration

### Étape 5: Déclencher Scan Purview

Le scan Purview est déclenché automatiquement par le pipeline après création des tables Gold.

**Vérification manuelle si nécessaire:**

```bash
cd governance/purview
python purview_automation.py
```

### Étape 6: Vérifier Assets Découverts

1. **Via Portal Purview:**
   ```
   https://web.purview.azure.com/resource/stpurview
   Data Map → Sources → Fabric-JAc → Browse assets
   ```

2. **Via Script Python:**
   ```bash
   cd governance/purview
   python list_discovered_assets.py
   ```

3. **Résultats attendus:**
   - **10 tables découvertes:**
     * 1 Bronze: `idoc_raw`
     * 4 Silver: `idoc_orders_silver`, `idoc_shipments_silver`, `idoc_warehouse_silver`, `idoc_invoices_silver`
     * 5 Gold: `orders_daily_summary`, `sla_performance`, `shipments_in_transit`, `warehouse_productivity_daily`, `revenue_recognition_realtime`
   
   - **Métadonnées pour chaque table:**
     * Schema complet (colonnes, types)
     * Qualified name
     * Collection assignment
     * Lakehouse parent

---

## 📊 Création Data Product Purview

### Étape 7: Créer Business Domain

**Via Portal Purview:**

1. Data Catalog → Domains → + New Domain
2. Configuration:
   - Name: `3PL Real-Time Analytics`
   - Description: "Business Domain for Third-Party Logistics (3PL) real-time analytics covering order management, shipment tracking, warehouse operations, and financial processes"
   - Owner: [Votre email]
   - Experts: [Équipe 3PL]
   - Collection: Bronze (ou root)
3. Create

### Étape 8: Créer Data Product

**Dans le Business Domain créé:**

1. + New Data Product
2. Configuration:
   - Name: `3PL Real-Time Analytics Data Product`
   - Description: "Real-time analytics platform for 3PL operations combining SAP IDoc ingestion, streaming processing, and analytical reporting"
   - Owner: [Votre email]
   
3. **Input Ports:**
   - Event Hub: `eh-idoc-flt8076/idoc-events`
   - SAP System: `S4HPRD Client 100`
   
4. **Output Ports:**
   - Lakehouse Delta Tables: `Lakehouse3PLAnalytics`
   - GraphQL API (planned)
   - Power BI (planned)
   
5. **Data Assets (ajouter les 10 tables):**
   - Bronze Layer:
     * `idoc_raw`
   - Silver Layer:
     * `idoc_orders_silver`
     * `idoc_shipments_silver`
     * `idoc_warehouse_silver`
     * `idoc_invoices_silver`
   - Gold Layer:
     * `orders_daily_summary`
     * `sla_performance`
     * `shipments_in_transit`
     * `warehouse_productivity_daily`
     * `revenue_recognition_realtime`
   
6. **Business Glossary:**
   - Lier les 6 termes existants:
     * Order
     * Shipment
     * SLA Compliance %
     * On-Time Delivery %
     * Warehouse Productivity
     * Days Sales Outstanding (DSO)
   
7. **KPIs:**
   - SLA Compliance % (target >95%)
   - On-Time Delivery % (target >98%)
   - Warehouse Productivity (target >100 pallets/hour)
   - Days Sales Outstanding (target <30 days)

8. Create

---

## ✅ Validation Complète

### Checklist Final

- [ ] **Notebooks créés (5):**
  - [ ] Orders Summary
  - [ ] SLA Performance
  - [ ] Shipments In Transit
  - [ ] Warehouse Productivity
  - [ ] Revenue Recognition

- [ ] **Notebooks testés individuellement:**
  - [ ] Tous s'exécutent sans erreur
  - [ ] Tables Delta créées dans Lakehouse
  - [ ] Data quality checks passent

- [ ] **Pipeline créé:**
  - [ ] 5 notebooks orchestrés
  - [ ] Trigger Purview scan configuré
  - [ ] Schedule trigger actif (2 AM daily)

- [ ] **Pipeline exécuté avec succès:**
  - [ ] Run manuel initial réussi
  - [ ] 10 tables visibles dans Lakehouse
  - [ ] Queries SQL fonctionnelles

- [ ] **Purview Scan réussi:**
  - [ ] 10 tables découvertes
  - [ ] Métadonnées complètes (schemas)
  - [ ] Assets visibles dans Data Map

- [ ] **Data Product créé:**
  - [ ] Business Domain créé
  - [ ] Data Product configuré
  - [ ] 10 tables associées
  - [ ] Business Glossary lié
  - [ ] KPIs documentés

---

## 🎯 Résultat Final

```
Purview Data Product "3PL Real-Time Analytics"
│
├── Input Ports
│   ├── SAP S/4HANA (S4HPRD Client 100)
│   └── Azure Event Hub (eh-idoc-flt8076/idoc-events)
│
├── Data Assets (10 tables gouvernées)
│   ├── Bronze Layer (1)
│   │   └── idoc_raw
│   ├── Silver Layer (4)
│   │   ├── idoc_orders_silver
│   │   ├── idoc_shipments_silver
│   │   ├── idoc_warehouse_silver
│   │   └── idoc_invoices_silver
│   └── Gold Layer (5) ✨ NOUVEAU
│       ├── orders_daily_summary
│       ├── sla_performance
│       ├── shipments_in_transit
│       ├── warehouse_productivity_daily
│       └── revenue_recognition_realtime
│
├── Business Glossary (6 termes)
│   ├── Order
│   ├── Shipment
│   ├── SLA Compliance %
│   ├── On-Time Delivery %
│   ├── Warehouse Productivity
│   └── Days Sales Outstanding (DSO)
│
├── Data Quality Rules (30+)
│   ├── Bronze: 5 rules
│   ├── Silver: 15 rules
│   └── Gold: 10+ rules
│
├── Lineage (complet)
│   └── SAP → Event Hub → Eventhouse → OneLake → Lakehouse Silver → Spark → Lakehouse Gold ✅
│
└── Output Ports
    ├── Lakehouse3PLAnalytics (10 tables Delta)
    ├── GraphQL API (planned)
    └── Power BI (planned)
```

---

## 📈 Monitoring & Maintenance

### Dashboard Monitoring (Fabric)

```
Workspace → Monitor → Pipeline runs
- Voir historique exécutions
- Durée moyenne: 10-15 minutes
- Taux de succès: >95%
- Alertes si échec
```

### Data Quality Monitoring

```sql
-- Dans Lakehouse SQL Endpoint

-- Vérifier freshness des tables Gold
SELECT 
    'orders_daily_summary' as table_name,
    MAX(order_day) as latest_day,
    DATEDIFF(day, MAX(order_day), CURRENT_DATE) as days_old
FROM orders_daily_summary
UNION ALL
SELECT 
    'sla_performance',
    MAX(order_date),
    DATEDIFF(day, MAX(order_date), CURRENT_DATE)
FROM sla_performance
UNION ALL
SELECT 
    'warehouse_productivity_daily',
    MAX(movement_day),
    DATEDIFF(day, MAX(movement_day), CURRENT_DATE)
FROM warehouse_productivity_daily;

-- Alerte si days_old > 1 (données pas rafraîchies)
```

### Maintenance Mensuelle

- [ ] Review performance notebooks (durée exécution)
- [ ] Optimize Delta tables (OPTIMIZE + ZORDER)
- [ ] Vacuum old files (>7 jours)
- [ ] Review Data Quality failures
- [ ] Update documentation si changements

---

## 🆘 Troubleshooting

### Problème: Notebook échoue avec "Table not found"

**Cause:** Shortcut Silver pas encore créé ou OneLake pas sync

**Solution:**
```bash
# Vérifier shortcuts dans Lakehouse
Lakehouse → Tables → Devrait voir 5 shortcuts (icone lien)

# Si manquant, recréer shortcuts OneLake
# Ou attendre sync OneLake (2-5 minutes après activation)
```

### Problème: MERGE échoue avec "Schema mismatch"

**Cause:** Schema Silver a changé

**Solution:**
```python
# Dans notebook, ajouter option:
df_gold.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true")  # Force schema update
    .saveAsTable(TARGET_TABLE)
```

### Problème: Pipeline timeout

**Cause:** Volumétrie trop élevée

**Solution:**
```json
// Augmenter timeout dans pipeline
{
  "policy": {
    "timeout": "0.00:30:00",  // 30 minutes au lieu de 10
    "retry": 2
  }
}
```

### Problème: Purview scan ne découvre pas toutes les tables

**Cause:** Scan partiel ou cache

**Solution:**
```bash
# Trigger full scan manuel
cd governance/purview
python purview_automation.py --scan-level Full

# Attendre 5-10 minutes
# Re-vérifier assets
python list_discovered_assets.py
```

---

## 📚 Ressources

- **Documentation complète:** `governance/LAKEHOUSE-GOLD-LAYER-APPROACH.md`
- **Architecture analysis:** `governance/DATA-PRODUCT-ARCHITECTURE-ANALYSIS.md`
- **Data Quality rules:** `governance/DATA-QUALITY-RULES.md`
- **Lineage:** `governance/DATA-LINEAGE.md`
- **Business Glossary:** `governance/BUSINESS-GLOSSARY.md`

---

**Prochaine étape:** Déployer les notebooks dans Fabric et exécuter le pipeline initial !
