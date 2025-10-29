# Gold Layer dans Lakehouse - Architecture Delta Native

**Date:** 2025-10-27  
**Approach:** Recréer la couche Gold dans le Lakehouse avec des tables Delta natives  
**Avantage:** Tables visibles dans Purview pour gouvernance complète

---

## 1. Problème Résolu

### Problème Initial
- ❌ OneLake Availability n'exporte PAS les vues matérialisées (Gold) d'Eventhouse
- ❌ Purview ne peut pas gouverner les KPIs Gold
- ❌ Lineage incomplet (Silver → Gold invisible)

### Solution
- ✅ **Créer tables Delta natives** dans le Lakehouse
- ✅ **Notebooks Spark** lisent Silver (via shortcuts) → écrivent Gold (Delta)
- ✅ **Purview scan** découvre automatiquement toutes les tables (Bronze + Silver + Gold)
- ✅ **Gouvernance complète** : 10 tables dans le Data Product

---

## 2. Architecture Complète

```
SAP S/4HANA
    ↓
Event Hub (idoc-events)
    ↓
Eventhouse KQL (kqldbsapidoc)
    ├── Bronze: idoc_raw (table physique)
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
    └── Notebooks Spark (PySpark)
         ├── Read: Silver tables (via shortcuts)
         ├── Transform: Business logic (agrégations, calculs)
         └── Write: Gold tables (Delta native)
              ├── orders_daily_summary
              ├── sla_performance
              ├── shipments_in_transit
              ├── warehouse_productivity_daily
              └── revenue_recognition_realtime
         ↓
    Purview Scan (Fabric-JAc)
         ↓
    Data Product (10 tables gouvernées)
    ├── Input Ports: Event Hub, SAP
    ├── Data Assets: 1 Bronze + 4 Silver + 5 Gold
    ├── Business Glossary: 6 termes
    ├── Data Quality: 30+ rules
    └── Output Ports: GraphQL API, Power BI
```

---

## 3. Tables Gold - Spécifications

### 3.1 orders_daily_summary

**Description:** Agrégations quotidiennes des commandes par SAP système

**Source:** `idoc_orders_silver` (via shortcut)

**Grain:** Jour × SAP System × SLA Status

**Colonnes:**
| Colonne | Type | Description | Calcul |
|---------|------|-------------|--------|
| order_day | date | Jour de la commande | `date_trunc('day', order_date)` |
| sap_system | string | Système SAP source | Grouping |
| sla_status | string | Statut SLA | Grouping |
| total_orders | bigint | Nombre total commandes | `COUNT(*)` |
| delivered_orders | bigint | Commandes livrées | `COUNT(WHERE status=Delivered)` |
| cancelled_orders | bigint | Commandes annulées | `COUNT(WHERE status=Cancelled)` |
| total_revenue | decimal(18,2) | Revenu total | `SUM(total_amount)` |
| avg_order_value | decimal(18,2) | Valeur moyenne commande | `AVG(total_amount)` |
| avg_days_to_ship | decimal(5,2) | Délai moyen expédition | `AVG(actual_ship_date - order_date)` |
| avg_days_to_delivery | decimal(5,2) | Délai moyen livraison | `AVG(actual_delivery_date - order_date)` |
| sla_compliance_pct | decimal(5,2) | % conformité SLA | `(sla_good_count / total_orders) * 100` |
| delivery_rate_pct | decimal(5,2) | % livraisons | `(delivered_orders / total_orders) * 100` |
| processed_timestamp | timestamp | Horodatage traitement | `current_timestamp()` |

**Partitioning:** `order_day` (partition par jour)

**Optimization:** `ZORDER BY (sap_system, sla_status)`

**Refresh:** Daily at 2 AM + on-demand trigger

**Owner:** Order Fulfillment Manager

**Use Cases:** UC1 - Dashboard Exécutif

---

### 3.2 sla_performance

**Description:** Tracking SLA temps réel avec classification enrichie

**Source:** `idoc_orders_silver` + `idoc_shipments_silver` (JOIN)

**Grain:** Order level (1 ligne = 1 commande)

**Colonnes:**
| Colonne | Type | Description | Calcul |
|---------|------|-------------|--------|
| order_number | string | N° commande (PK) | - |
| customer_id | string | Client | - |
| sap_system | string | Système SAP | - |
| order_date | date | Date commande | - |
| requested_delivery_date | date | Date demandée client | - |
| promised_delivery_date | date | Date promise 3PL | - |
| actual_ship_date | date | Date expédition réelle | - |
| actual_delivery_date | date | Date livraison réelle | - |
| processing_days | int | Jours de traitement | `actual_ship_date - order_date` |
| total_cycle_days | int | Cycle total | `actual_delivery_date - order_date` |
| sla_target_days | int | Target SLA (constant) | `1` |
| sla_compliance | string | Good / At Risk / Breached | Business logic |
| sla_variance_hours | decimal(10,2) | Écart vs SLA (heures) | `(processing_days - sla_target_days) * 24` |
| on_time_delivery | boolean | Livré à temps ? | `actual_delivery_date <= promised_delivery_date` |
| is_critical | boolean | Commande critique ? | `sla_breached AND total_amount > 10000` |
| carrier_name | string | Transporteur | From shipment |

**Partitioning:** `order_date`

**Optimization:** `ZORDER BY (sla_status, customer_id)`

**Refresh:** Daily at 2 AM + real-time trigger

**Owner:** COO

**Use Cases:** UC1, UC3

---

### 3.3 shipments_in_transit

**Description:** Expéditions en cours avec ETA

**Source:** `idoc_shipments_silver` (filtre: In Transit)

**Grain:** Shipment level (snapshot temps réel)

**Colonnes:**
| Colonne | Type | Description | Calcul |
|---------|------|-------------|--------|
| shipment_number | string | N° expédition (PK) | - |
| order_reference | string | N° commande liée | - |
| customer_id | string | Client | - |
| origin_location | string | Origine | - |
| destination_location | string | Destination | - |
| carrier_name | string | Transporteur | - |
| planned_ship_date | date | Date expédition prévue | - |
| actual_ship_date | date | Date expédition réelle | - |
| planned_delivery_date | date | Date livraison prévue | - |
| days_in_transit | int | Jours en transit | `current_date - actual_ship_date` |
| days_until_planned_delivery | int | Jours restants | `planned_delivery_date - current_date` |
| eta_date | date | ETA (estimated arrival) | `planned_delivery_date` |
| delay_status | string | On Track / At Risk / Delayed | Business logic |
| days_delayed | int | Jours de retard | `MAX(0, -days_until_planned_delivery)` |
| priority | string | High / Medium / Normal | Based on delay + value |
| shipment_value | decimal(18,2) | Valeur expédition | - |
| snapshot_timestamp | timestamp | Horodatage snapshot | `current_timestamp()` |

**Partitioning:** Aucune (table snapshot petite)

**Refresh:** **Overwrite complet** toutes les 15 minutes (pas de merge)

**Owner:** Transportation Manager

**Use Cases:** UC2 - Suivi Opérations

---

### 3.4 warehouse_productivity_daily

**Description:** KPI entrepôt quotidien

**Source:** `idoc_warehouse_silver`

**Grain:** Jour × Warehouse × Movement Type

**Colonnes:**
| Colonne | Type | Description | Calcul |
|---------|------|-------------|--------|
| movement_day | date | Jour du mouvement | `date_trunc('day', movement_timestamp)` |
| warehouse_id | string | Entrepôt | Grouping |
| movement_type | string | Type mouvement (GR/GI/Transfer) | Grouping |
| total_movements | bigint | Nombre mouvements | `COUNT(*)` |
| total_quantity | decimal(18,3) | Quantité totale | `SUM(quantity)` |
| unique_materials | bigint | Matériaux distincts | `COUNT(DISTINCT material_number)` |
| unique_operators | bigint | Opérateurs distincts | `COUNT(DISTINCT operator_id)` |
| avg_processing_time_min | decimal(10,2) | Temps moyen (min) | `AVG(processing_time_minutes)` |
| exception_count | bigint | Mouvements avec exception | `COUNT(WHERE exception_flag=true)` |
| exception_rate_pct | decimal(5,2) | % exceptions | `(exception_count / total_movements) * 100` |
| movements_per_hour | decimal(10,2) | Productivité (mvt/h) | `total_movements / 8` (journée 8h) |
| productivity_target | decimal(10,2) | Target (constant) | `100` pallets/hour |
| productivity_variance_pct | decimal(5,2) | Écart vs target | `((actual - target) / target) * 100` |

**Partitioning:** `movement_day`

**Optimization:** `ZORDER BY (warehouse_id, movement_type)`

**Refresh:** Daily at 2 AM

**Owner:** Warehouse Manager

**Use Cases:** UC1, UC3

---

### 3.5 revenue_recognition_realtime

**Description:** Performance financière temps réel

**Source:** `idoc_invoices_silver`

**Grain:** Jour × Customer

**Colonnes:**
| Colonne | Type | Description | Calcul |
|---------|------|-------------|--------|
| invoice_day | date | Jour facturation | `date_trunc('day', invoice_date)` |
| customer_id | string | Client | Grouping |
| sap_system | string | Système SAP | Grouping |
| total_invoices | bigint | Nombre factures | `COUNT(*)` |
| total_revenue | decimal(18,2) | Revenu total | `SUM(total_amount)` |
| total_paid | decimal(18,2) | Montant payé | `SUM(amount_paid)` |
| total_due | decimal(18,2) | Montant dû | `SUM(amount_due)` |
| overdue_invoices | bigint | Factures en retard | `COUNT(WHERE payment_status=Overdue)` |
| avg_days_to_payment | decimal(5,2) | DSO (Days Sales Outstanding) | `AVG(payment_date - invoice_date)` |
| aging_current | decimal(18,2) | Bucket: Current (0 days) | `SUM(amount WHERE aging=Current)` |
| aging_1_30 | decimal(18,2) | Bucket: 1-30 jours | `SUM(amount WHERE aging=1-30)` |
| aging_31_60 | decimal(18,2) | Bucket: 31-60 jours | `SUM(amount WHERE aging=31-60)` |
| aging_61_90 | decimal(18,2) | Bucket: 61-90 jours | `SUM(amount WHERE aging=61-90)` |
| aging_90_plus | decimal(18,2) | Bucket: 90+ jours | `SUM(amount WHERE aging=90+)` |
| collection_efficiency_pct | decimal(5,2) | % collecté | `(total_paid / total_revenue) * 100` |

**Partitioning:** `invoice_day`

**Optimization:** `ZORDER BY (customer_id, sap_system)`

**Refresh:** Daily at 2 AM + real-time trigger

**Owner:** Finance Manager

**Use Cases:** UC1, UC4

---

## 4. Notebooks Spark - Détails Techniques

### 4.1 gold_layer_orders_summary.py

**Contenu:** Voir fichier `fabric/data-engineering/notebooks/gold_layer_orders_summary.py`

**Sections:**
1. **Configuration** : Variables, logging
2. **Read Silver** : Lecture via `spark.table(SOURCE_TABLE)`
3. **Business Logic** : Agrégations avec `groupBy()`, calculs `withColumn()`
4. **Write Delta** : Mode **MERGE** (upsert) pour idempotence
5. **Optimize** : `OPTIMIZE` + `ZORDER` + `VACUUM`
6. **Data Quality** : Validation nulls, ranges, consistency
7. **Summary** : Rapport exécution

**Paramètres:**
- Aucun (tout hardcodé pour simplicité)
- Future: Ajouter `start_date`, `end_date` pour backfill

**Durée estimée:** 3-5 minutes (selon volumétrie)

**Dépendances:**
- `pyspark.sql`
- `delta.tables`

---

### 4.2 gold_layer_sla_performance.py

**Logique spéciale:** **JOIN** Orders + Shipments

```python
df_joined = df_orders.alias("o").join(
    df_shipments.alias("s"),
    col("o.order_number") == col("s.order_reference"),
    "left"  # Left join car certaines commandes n'ont pas encore d'expédition
)
```

**Calculs SLA enrichis:**
- `processing_days` = `actual_ship_date - order_date`
- `sla_variance_hours` = `(processing_days - 1) * 24`
- `is_critical` = `sla_breached AND total_amount > 10000`
- `on_time_delivery` = `actual_delivery_date <= promised_delivery_date`

**Mode écriture:** **MERGE** sur `order_number` (PK)

---

### 4.3 gold_layer_shipments_in_transit.py

**Logique spéciale:** **Filtre + Snapshot**

```python
# Filtre: In Transit uniquement
df_in_transit = df_shipments.filter(
    (col("shipment_status") == "In Transit") |
    (col("actual_ship_date").isNotNull() & col("actual_delivery_date").isNull())
)
```

**Calculs temps réel:**
- `days_in_transit` = `current_date - actual_ship_date`
- `days_until_planned_delivery` = `planned_delivery_date - current_date`
- `delay_status` = Business logic (On Track / At Risk / Delayed)
- `priority` = Based on `delay_status` + `shipment_value`

**Mode écriture:** **OVERWRITE complet** (pas de merge)
- Raison: Snapshot temps réel, on veut uniquement l'état actuel
- Données historiques pas nécessaires (expéditions passées = livrées)

**Tri:** Par `priority DESC`, `days_delayed DESC`

---

## 5. Pipeline Orchestration

### 5.1 Fabric Pipeline - pipeline_gold_layer_refresh.json

**Activités (5 notebooks en parallèle):**
1. Orders Daily Summary
2. SLA Performance
3. Shipments In Transit
4. Warehouse Productivity
5. Revenue Recognition

**Dépendance:** Aucune entre notebooks (exécution parallèle)

**Après tous les notebooks:**
6. **Trigger Purview Scan** (Web Activity)
   - Endpoint: `/datasources/Fabric-JAc/scans/Scan-DKT/run`
   - Auth: Managed Identity
   - Body: `{"scanLevel": "Full"}`

7. **Send Success Notification** (optionnel)
   - Logic App ou Teams webhook

**Paramètres:**
- `IncrementalLoad` (bool): Si true, charge uniquement données récentes (future)
- `BackfillDays` (int): Nombre de jours à backfiller (default: 7)

---

### 5.2 Triggers

#### Daily Refresh (Schedule)
```json
{
  "name": "Daily Refresh 2AM",
  "type": "ScheduleTrigger",
  "recurrence": {
    "frequency": "Day",
    "interval": 1,
    "schedule": {
      "hours": [2],
      "minutes": [0]
    }
  }
}
```

**Justification:** 2 AM = fenêtre batch, peu d'activité utilisateur

#### On Silver Update (Event-driven)
```json
{
  "name": "On Silver Update",
  "type": "BlobEventsTrigger",
  "blobPathBeginsWith": "/Lakehouse3PLAnalytics/Tables/idoc_",
  "events": ["Microsoft.Storage.BlobCreated"]
}
```

**Justification:** Refresh Gold dès que Silver est mis à jour (near real-time)

**Note:** Event trigger nécessite OneLake avec Event Grid (vérifier disponibilité)

---

## 6. Avantages de cette Approche

### 6.1 Gouvernance Purview Complète

| Aspect | Avant (Hybrid) | Après (Lakehouse Gold) |
|--------|----------------|------------------------|
| **Tables gouvernées** | 5 (Bronze + Silver) | 10 (Bronze + Silver + Gold) |
| **Lineage** | Partiel (Silver only) | Complet (Bronze → Silver → Gold) |
| **Data Quality** | 15 rules (Silver) | 30+ rules (tous layers) |
| **Business Terms** | 6 termes | 6 termes + mappings Gold |
| **Visibilité métier** | Technique (Silver) | Business (KPIs Gold) |

✅ **Data Product complet** : Toutes les couches Medallion dans catalogue

---

### 6.2 Performance

| KPI | Eventhouse Materialized View | Lakehouse Delta Table |
|-----|------------------------------|----------------------|
| **Query latency** | <50ms (KQL natif) | ~100-200ms (Spark SQL) |
| **Refresh latency** | <1 min (auto real-time) | 5-15 min (pipeline batch) |
| **Scalability** | Excellent (KQL optimisé) | Excellent (Spark auto-scale) |
| **Concurrency** | Très élevée | Élevée |

⚖️ **Trade-off acceptable** : Légère dégradation perf MAIS gouvernance complète

---

### 6.3 Flexibilité

✅ **Python/PySpark** : Plus flexible que KQL pour logique complexe
- Librairies ML (scikit-learn, pandas)
- UDFs personnalisées
- Intégrations externes (APIs, DBs)

✅ **Contrôle total** : 
- Choix partitioning strategy
- Tuning optimisations (ZORDER, VACUUM)
- Gestion versions (Time Travel)

✅ **Évolutivité** :
- Facile d'ajouter nouvelles tables Gold
- Notebooks modulaires (1 notebook = 1 table)

---

### 6.4 Compatibilité

✅ **Power BI** : DirectQuery sur Delta Lake (optimisé)

✅ **Spark** : Lecture native Delta (pas de conversion)

✅ **GraphQL API** : Peut lire Lakehouse OU Eventhouse (choix)

✅ **Purview** : Scan automatique Delta (natif Fabric)

---

## 7. Inconvénients et Mitigations

### 7.1 Latence Accrue

**Problème:** Pipeline batch (5-15 min) vs materialized views (temps réel)

**Mitigation:**
- ✅ **Event-driven trigger** : Refresh dès que Silver update
- ✅ **Incremental load** : Traiter uniquement nouvelles données (future)
- ✅ **Hybrid approach** : GraphQL lit Eventhouse pour queries temps réel critiques

**Décision:** Acceptable pour use cases batch (Dashboard exécutif quotidien)

---

### 7.2 Duplication Données

**Problème:** Gold existe dans Eventhouse (materialized views) ET Lakehouse (Delta)

**Mitigation:**
- ✅ **Supprimer materialized views Eventhouse** : Garder uniquement Delta
- ⚠️ **OU garder les deux** : Eventhouse pour temps réel, Lakehouse pour gouvernance

**Recommandation:** Garder les deux temporairement, supprimer Eventhouse Gold après validation

---

### 7.3 Coût Compute Spark

**Problème:** Notebooks Spark = compute additionnel vs KQL natif

**Mitigation:**
- ✅ **Spark pool auto-scale** : Paye uniquement usage réel
- ✅ **Optimisation notebooks** : Minimize transformations, use broadcast joins
- ✅ **Schedule off-peak** : 2 AM = coût réduit

**Estimation coût:** ~$5-10/jour pour 5 notebooks (dépend volumétrie)

---

### 7.4 Maintenance Code

**Problème:** 5 notebooks Python à maintenir vs 5 vues KQL (déclaratif)

**Mitigation:**
- ✅ **Templates standardisés** : Réutiliser structure commune
- ✅ **CI/CD** : Tests automatisés sur notebooks (pytest)
- ✅ **Documentation** : Inline comments + README

**Effort:** ~1 jour/mois maintenance (évolutions, bugs)

---

## 8. Plan de Déploiement

### Phase 1: Développement (1 semaine)

**Jour 1-2:** Créer notebooks
- [x] gold_layer_orders_summary.py ✅
- [x] gold_layer_sla_performance.py ✅
- [x] gold_layer_shipments_in_transit.py ✅
- [ ] gold_layer_warehouse_productivity.py
- [ ] gold_layer_revenue_recognition.py

**Jour 3:** Créer pipeline
- [ ] Pipeline Fabric avec orchestration
- [ ] Configurer triggers (schedule + event)

**Jour 4:** Tests unitaires
- [ ] Test chaque notebook indépendamment
- [ ] Valider data quality
- [ ] Vérifier performance (<10 min total)

**Jour 5:** Tests end-to-end
- [ ] Exécution pipeline complète
- [ ] Vérifier 5 tables Delta créées
- [ ] Valider données (sampling)

---

### Phase 2: Déploiement Production (3 jours)

**Jour 6:** Déploiement initial
- [ ] Uploader notebooks dans Fabric Workspace
- [ ] Créer pipeline dans Fabric
- [ ] Activer trigger schedule (2 AM)
- [ ] **Première exécution manuelle**

**Jour 7:** Purview Integration
- [ ] Trigger scan Purview sur Lakehouse
- [ ] Vérifier 10 tables découvertes (5 shortcuts + 5 Delta natives)
- [ ] Créer Business Domain
- [ ] Créer Data Product
- [ ] Associer 10 tables

**Jour 8:** Validation & Monitoring
- [ ] Dashboard monitoring pipeline (durée, succès/échec)
- [ ] Alertes email si échec
- [ ] Documentation opérationnelle

---

### Phase 3: Optimisation (ongoing)

**Semaine 2-4:**
- [ ] Tuning performance (ZORDER, partitions)
- [ ] Incremental load (charger delta uniquement)
- [ ] Event-driven trigger (si disponible)
- [ ] Data Quality rules dans Purview (30+ rules)
- [ ] Lineage mappings complets

---

## 9. Commandes Utiles

### Créer notebooks dans Fabric

```bash
# Via Fabric Portal
1. Ouvrir Workspace "JAc"
2. New → Notebook
3. Coller contenu gold_layer_orders_summary.py
4. Save as "Gold Layer - Orders Summary"
5. Répéter pour chaque notebook
```

### Tester notebook localement (Spark)

```python
# Dans VS Code avec PySpark
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Gold Layer Test") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Lire table Silver (simulée)
df = spark.read.parquet("path/to/silver/idoc_orders_silver")

# Exécuter logique business
# ... (code notebook)

# Écrire résultat
df_gold.write.format("delta").mode("overwrite").save("path/to/gold")
```

### Exécuter pipeline via API

```bash
# Trigger manuel
POST https://api.fabric.microsoft.com/v1/workspaces/{workspace-id}/items/{pipeline-id}/jobs/instances?jobType=Pipeline
Authorization: Bearer {token}
Content-Type: application/json

{
  "executionData": {
    "parameters": {
      "IncrementalLoad": false,
      "BackfillDays": 7
    }
  }
}
```

### Vérifier tables Delta créées

```sql
-- Dans Lakehouse SQL Endpoint
SHOW TABLES;

-- Vérifier partitions
DESCRIBE EXTENDED orders_daily_summary;

-- Query sample
SELECT * FROM orders_daily_summary
WHERE order_day >= CURRENT_DATE - INTERVAL 7 DAYS
ORDER BY order_day DESC, total_orders DESC
LIMIT 100;
```

---

## 10. Conclusion

### ✅ Approche Recommandée : **Lakehouse Gold Layer (Delta Native)**

**Raisons:**
1. **Gouvernance complète** : 10 tables dans Purview (vs 5)
2. **Lineage complet** : Bronze → Silver → Gold visible
3. **Data Quality** : 30+ rules sur tous layers
4. **Compatibilité** : Power BI, Spark, GraphQL
5. **Flexibilité** : Python pour logique complexe

**Trade-offs acceptés:**
- Latence +5-10 min (batch) vs temps réel (acceptable pour dashboards quotidiens)
- Coût compute Spark (~$5-10/jour)
- Maintenance notebooks (1 jour/mois)

**Résultat final:**
```
Data Product "3PL Real-Time Analytics"
├── Bronze: 1 table (idoc_raw)
├── Silver: 4 tables (orders, shipments, warehouse, invoices)
└── Gold: 5 tables (KPIs métier)
    → Total: 10 tables gouvernées dans Purview ✅
    → Lineage complet ✅
    → Data Quality rules: 30+ ✅
    → Business Glossary: 6 termes ✅
```

**Prochaine étape:** Compléter les 2 notebooks manquants + créer le pipeline !
