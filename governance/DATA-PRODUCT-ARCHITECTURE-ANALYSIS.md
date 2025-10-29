# Data Product Architecture - Analyse et Recommandations

**Date:** 2025-10-27  
**Sujet:** Nécessité de la couche Gold pour le Data Product 3PL Analytics  
**Problème Identifié:** Les vues matérialisées (Gold layer) n'apparaissent pas dans OneLake/Lakehouse

---

## 1. Problème Technique : Vues Matérialisées et OneLake

### 1.1 Comportement Observé

**OneLake Availability** convertit automatiquement en Delta Lake :
- ✅ **Tables physiques** (idoc_raw, idoc_orders_silver, etc.)
- ❌ **Vues matérialisées** (orders_daily_summary, sla_performance, etc.)

**Raison:** OneLake Availability exporte uniquement les **tables stockées physiquement**, pas les vues (même matérialisées).

### 1.2 Impact sur l'Architecture

```
Eventhouse (KQL)
├── Bronze: idoc_raw ✅ → Delta dans OneLake
├── Silver: idoc_orders_silver ✅ → Delta dans OneLake
├── Silver: idoc_shipments_silver ✅ → Delta dans OneLake
├── Silver: idoc_warehouse_silver ✅ → Delta dans OneLake
├── Silver: idoc_invoices_silver ✅ → Delta dans OneLake
└── Gold: orders_daily_summary ❌ → PAS dans OneLake (vue matérialisée)
    Gold: sla_performance ❌ → PAS dans OneLake
    Gold: shipments_in_transit ❌ → PAS dans OneLake
    Gold: warehouse_productivity_daily ❌ → PAS dans OneLake
    Gold: revenue_recognition_realtime ❌ → PAS dans OneLake
```

**Conséquence:** Le Data Product Purview ne pourra gouverner QUE Bronze + Silver (5 tables), pas les KPIs Gold.

---

## 2. Analyse du Besoin Métier

### 2.1 Use Cases du Data Product

Référence : `governance/3PL-DATA-PRODUCT-DOMAIN-MODEL.md`

#### **UC1: Dashboard Exécutif - Vue d'ensemble quotidienne**
**Consommateur:** COO, VP Operations  
**Besoin:**
- SLA Compliance % global (aujourd'hui)
- On-Time Delivery % global (aujourd'hui)
- Warehouse Productivity moyenne (aujourd'hui)
- Revenue réalisé (aujourd'hui)

**Données requises:**
- ✅ **orders_daily_summary** → Agrégations quotidiennes par SAP système
- ✅ **sla_performance** → Tracking SLA temps réel
- ✅ **warehouse_productivity_daily** → KPI entrepôt quotidien
- ✅ **revenue_recognition_realtime** → Revenus temps réel

**Couche:** **GOLD** ⚠️

---

#### **UC2: Opérations - Suivi temps réel des expéditions**
**Consommateur:** Transportation Manager, Customer Service  
**Besoin:**
- Liste des expéditions en transit (statut, ETA)
- Alertes sur retards (planned vs actual delivery)
- Drill-down sur commande spécifique

**Données requises:**
- ✅ **shipments_in_transit** → Filtre statut "In Transit" avec calcul ETA
- 🔄 **idoc_shipments_silver** → Détails transaction level (fallback)

**Couche:** **GOLD préféré**, Silver acceptable

---

#### **UC3: Analyse - Drill-down sur commandes problématiques**
**Consommateur:** Order Fulfillment Manager  
**Besoin:**
- Lister toutes les commandes avec SLA "At Risk" ou "Breached"
- Voir historique complet d'une commande (création → livraison)
- Identifier root cause des retards

**Données requises:**
- 🔄 **idoc_orders_silver** → Données transactionnelles complètes
- ✅ **sla_performance** → Classification SLA précalculée

**Couche:** **SILVER + GOLD**

---

#### **UC4: Finance - Suivi des encaissements**
**Consommateur:** Finance Manager  
**Besoin:**
- DSO (Days Sales Outstanding) actuel
- Aging buckets des factures impayées
- Liste des factures >90 jours

**Données requises:**
- 🔄 **idoc_invoices_silver** → Données factures complètes
- ✅ **revenue_recognition_realtime** → Agrégations financières

**Couche:** **SILVER + GOLD**

---

### 2.2 Synthèse des Besoins

| Use Case | Silver Suffisant ? | Gold Requis ? | Justification |
|----------|-------------------|---------------|---------------|
| **UC1: Dashboard Exécutif** | ❌ Non | ✅ Oui | KPIs précalculés essentiels (perf <100ms) |
| **UC2: Suivi Expéditions** | 🔄 Possible | ✅ Préféré | Gold optimise les filtres temps réel |
| **UC3: Drill-down Commandes** | ✅ Oui | 🔄 Nice-to-have | Silver contient données granulaires |
| **UC4: Finance** | ✅ Oui | 🔄 Nice-to-have | Silver a aging_bucket calculé |

**Conclusion:** Gold **NON STRICTEMENT OBLIGATOIRE** mais **FORTEMENT RECOMMANDÉ** pour :
1. Performance API (<100ms SLA)
2. Simplicité consommation (KPIs précalculés)
3. Réduction charge query (agrégations pré-calculées)

---

## 3. Options d'Architecture

### Option 1: **Silver-Only Data Product** (sans Gold)

#### Architecture
```
SAP → Event Hub → Eventhouse KQL → OneLake Delta → Lakehouse Shortcuts → Purview Data Product
                       ↓
                  Silver Tables (4)
                  ✅ idoc_orders_silver
                  ✅ idoc_shipments_silver
                  ✅ idoc_warehouse_silver
                  ✅ idoc_invoices_silver
```

#### Avantages
- ✅ Fonctionne avec OneLake Availability (pas de blocage technique)
- ✅ Gouvernance Purview sur toutes les données source
- ✅ Données granulaires disponibles pour analyses ad-hoc
- ✅ Pas de duplication (Gold = vues sur Silver)

#### Inconvénients
- ❌ **API GraphQL lente** : Agrégations à la volée sur millions de lignes
  - Exemple: `SLA Compliance %` → Scan complet `idoc_orders_silver` à chaque appel
  - Latence estimée: **500ms-2s** vs objectif <100ms
- ❌ **Dashboards Power BI lents** : Même problème pour visuals DAX
- ❌ **Complexité consommation** : Utilisateurs doivent écrire agrégations
- ❌ **Charge compute élevée** : Agrégations répétées (pas de cache)

#### Faisabilité Métier
- 🟡 **UC1 (Dashboard Exécutif):** ⚠️ Faisable MAIS ne respecte pas SLA <100ms
- 🟢 **UC2 (Suivi Expéditions):** ✅ OK si filtres indexed (shipment_status)
- 🟢 **UC3 (Drill-down):** ✅ OK (besoin granulaire)
- 🟢 **UC4 (Finance):** ✅ OK (calculs simples)

**Verdict:** ⚠️ **Viable MAIS performance dégradée pour cas prioritaire (UC1)**

---

### Option 2: **Lakehouse Gold Layer** (recréer Gold dans Lakehouse)

#### Architecture
```
SAP → Event Hub → Eventhouse KQL → OneLake Delta → Lakehouse Shortcuts (Silver)
                                                          ↓
                                                    Lakehouse Notebook (Spark)
                                                          ↓
                                                    Gold Tables (Delta)
                                                    ✅ orders_daily_summary
                                                    ✅ sla_performance
                                                    ✅ shipments_in_transit
                                                    ✅ warehouse_productivity_daily
                                                    ✅ revenue_recognition_realtime
                                                          ↓
                                                    Purview Data Product
```

#### Implémentation
1. **Lakehouse Notebooks PySpark** : Lire Silver via shortcuts → Agréger → Écrire Gold (Delta)
2. **Pipelines Fabric** : Orchestrer notebooks (schedule quotidien + trigger temps réel)
3. **Purview Scan** : Découvre automatiquement les tables Gold (Delta natives)

#### Avantages
- ✅ **Gold disponible dans Purview** : Gouvernance complète (10 tables)
- ✅ **Performance API** : Lectures directes sur agrégations (SLA <100ms ✅)
- ✅ **Compatibilité Power BI** : DirectQuery sur Delta optimisé
- ✅ **Contrôle total** : Logique agrégation en Python (vs KQL)
- ✅ **Scalabilité** : Spark auto-scale sur gros volumes

#### Inconvénients
- ❌ **Complexité** : Code Spark à maintenir (vs vues matérialisées KQL auto)
- ❌ **Latence accrue** : Pipeline batch (5-15 min) vs vues matérialisées (<1 min)
- ❌ **Coût compute** : Spark clusters pour agrégations (vs KQL natif)
- ❌ **Duplication données** : Gold stocké 2x (Eventhouse + Lakehouse)

#### Faisabilité Métier
- 🟢 **UC1 (Dashboard Exécutif):** ✅ Parfait (KPIs précalculés, perf <100ms)
- 🟢 **UC2 (Suivi Expéditions):** ✅ OK
- 🟢 **UC3 (Drill-down):** ✅ OK (Silver + Gold disponibles)
- 🟢 **UC4 (Finance):** ✅ OK

**Verdict:** ✅ **Idéal pour use cases métier** mais coût dev/ops élevé

---

### Option 3: **Hybrid - GraphQL sur Eventhouse KQL** (pas de Lakehouse Gold)

#### Architecture
```
SAP → Event Hub → Eventhouse KQL (Bronze + Silver + Gold materialized views)
                       ↓                                  ↓
                  OneLake Delta                      GraphQL API
                  (Silver only)                      (query Eventhouse direct)
                       ↓
                  Lakehouse Shortcuts
                       ↓
                  Purview Data Product
                  (Silver only governance)
```

#### Implémentation
1. **Purview Data Product** : Gouverne uniquement Silver (4 tables)
2. **GraphQL API** : Connecte directement à Eventhouse KQL
   - Queries Gold : Lit vues matérialisées KQL (performance native)
   - Queries Silver : Lit tables Silver
3. **Power BI** : Connecte aussi directement à Eventhouse (pas via Lakehouse)

#### Avantages
- ✅ **Performance maximale** : KQL materialized views (latence <50ms)
- ✅ **Simplicité** : Pas de pipeline Spark à maintenir
- ✅ **Temps réel** : Vues matérialisées auto-refresh
- ✅ **Coût réduit** : Pas de compute Spark
- ✅ **Architecture naturelle** : Eventhouse conçu pour ça

#### Inconvénients
- ❌ **Gold pas dans Purview** : Gouvernance partielle (Bronze + Silver only)
- ❌ **Lineage incomplet** : Purview ne voit pas transformations Silver → Gold
- ❌ **Documentation manuelle** : KPIs Gold doivent être documentés hors Purview
- ❌ **2 sources de vérité** : Eventhouse (prod) + Lakehouse (gouvernance)

#### Faisabilité Métier
- 🟢 **UC1 (Dashboard Exécutif):** ✅ Parfait (KQL materialized views)
- 🟢 **UC2 (Suivi Expéditions):** ✅ Parfait
- 🟢 **UC3 (Drill-down):** ✅ OK
- 🟢 **UC4 (Finance):** ✅ OK

**Verdict:** ✅ **Meilleur compromis perf/simplicité** MAIS gouvernance incomplète

---

## 4. Recommandation Finale

### 4.1 Approche Recommandée : **Option 3 - Hybrid** avec plan évolution

#### Phase 1 (Immédiat - 2 semaines)
**Architecture:** Hybrid (Silver dans Purview, Gold dans Eventhouse)

**Implémentation:**
1. ✅ **Lakehouse shortcuts** : Bronze + Silver (FAIT)
2. ✅ **Purview Data Product** : Gouverne 5 tables (1 Bronze + 4 Silver)
3. ✅ **GraphQL API** : Connecte Eventhouse direct (lit vues matérialisées Gold)
4. ✅ **Power BI** : Connecte Eventhouse direct (perf optimale)
5. ✅ **Documentation** : Documenter KPIs Gold dans README.md + Purview Descriptions

**Justification:**
- Délivre use cases métier **rapidement** (pas de dev Spark)
- **Performance optimale** (KQL natif <50ms)
- Gouvernance **suffisante** pour phase 1 (Silver = données source)

**Limitations acceptées:**
- Gold pas dans Purview (documenté manuellement)
- Lineage partiel (Silver → Gold tracé via docs)

---

#### Phase 2 (Futur - 2-3 mois) [OPTIONNEL]
**Si besoin de gouvernance Gold dans Purview:**

**Option A : Eventhouse Upgrade**
- Attendre feature Microsoft : "OneLake Availability pour Materialized Views"
- Roadmap public : https://aka.ms/fabricroadmap
- ETA : Q1 2026 (à confirmer)

**Option B : Lakehouse Gold Layer**
- Implémenter Option 2 (Spark notebooks)
- Créer pipeline Silver → Gold dans Lakehouse
- Ajouter tables Gold au Data Product Purview

**Trigger Phase 2:**
- Audit compliance exige Gold dans catalogue (SOX, GDPR)
- Équipe préfère single source of truth (Lakehouse)
- Volumétrie Gold justifie séparation (>100GB)

---

### 4.2 Configuration Purview Data Product - Phase 1

#### Assets (5 tables Silver + Bronze)
```yaml
Bronze Layer:
  - idoc_raw (table)
    Classification: Internal Use
    Owner: Data Engineering
    Quality Rules: BRZ-001 (Message Structure Completeness)

Silver Layer:
  - idoc_orders_silver (table)
    Classification: Internal Use
    Owner: Order Fulfillment Manager
    Business Terms: Order, SLA Compliance %
    Quality Rules: SLV-ORD-001, SLV-ORD-002, SLV-ORD-003
    
  - idoc_shipments_silver (table)
    Classification: Internal Use
    Owner: Transportation Manager
    Business Terms: Shipment, On-Time Delivery %
    Quality Rules: SLV-SHP-001, SLV-SHP-002
    
  - idoc_warehouse_silver (table)
    Classification: Internal Use
    Owner: Warehouse Manager
    Business Terms: Warehouse Productivity
    Quality Rules: SLV-WHS-001
    
  - idoc_invoices_silver (table)
    Classification: Confidential
    Owner: Finance Manager
    Business Terms: Days Sales Outstanding (DSO)
    Quality Rules: SLV-INV-001, SLV-INV-002
    Retention: 2555 days (7 years)
```

#### Gold KPIs (Documentés mais pas gouvernés dans Purview Phase 1)
```markdown
## Gold Layer KPIs (Materialized Views in Eventhouse)

**Source:** Eventhouse KQL Database `kqldbsapidoc`
**Accès:** GraphQL API, Power BI Direct Query
**Refresh:** Real-time (materialized views auto-update)

### orders_daily_summary
- **Description:** Agrégations quotidiennes des commandes par SAP système
- **Calculs:** COUNT(orders), SUM(total_amount), AVG(processing_time)
- **Grain:** Jour × SAP System × SLA Status
- **Use Case:** UC1 - Dashboard Exécutif
- **Owner:** Order Fulfillment Manager
- **Source:** idoc_orders_silver

### sla_performance
- **Description:** Tracking SLA temps réel avec classification
- **Calculs:** SLA Status (Good/At Risk/Breached), Time to Shipment
- **Grain:** Order level (temps réel)
- **Use Case:** UC1, UC3
- **Owner:** COO
- **Source:** idoc_orders_silver + idoc_shipments_silver

### shipments_in_transit
- **Description:** Expéditions en cours avec ETA
- **Calculs:** Filtrage statut "In Transit", calcul ETA
- **Grain:** Shipment level (temps réel)
- **Use Case:** UC2 - Opérations
- **Owner:** Transportation Manager
- **Source:** idoc_shipments_silver

### warehouse_productivity_daily
- **Description:** KPI entrepôt quotidien
- **Calculs:** Movements per hour, Exception rate
- **Grain:** Jour × Warehouse × Movement Type
- **Use Case:** UC1, UC3
- **Owner:** Warehouse Manager
- **Source:** idoc_warehouse_silver

### revenue_recognition_realtime
- **Description:** Performance financière temps réel
- **Calculs:** Revenue par jour, DSO, Aging distribution
- **Grain:** Jour × Customer
- **Use Case:** UC1, UC4
- **Owner:** Finance Manager
- **Source:** idoc_invoices_silver
```

---

### 4.3 Lineage Documentation (compense absence Gold dans Purview)

Créer fichier `governance/GOLD-LAYER-LINEAGE.md`:

```markdown
# Gold Layer - Data Lineage (Outside Purview)

## Transformation: Silver → Gold

### orders_daily_summary
**Source Table:** idoc_orders_silver (Lakehouse)  
**Target View:** orders_daily_summary (Eventhouse)  
**Transformation Logic:**
```kql
idoc_orders_silver
| summarize 
    total_orders = count(),
    total_amount = sum(total_amount),
    avg_processing_time = avg(datetime_diff('minute', order_date, actual_ship_date))
  by 
    bin(order_date, 1d),
    sap_system,
    sla_status
```
**Refresh:** Real-time (materialized view)  
**Latency:** <1 minute from source update

[... autres transformations ...]
```

---

## 5. Plan d'Action

### ✅ Étape 1: Compléter Purview Data Product (Silver Only)
**Durée:** 1-2 jours

- [ ] Trigger scan Purview sur Lakehouse3PLAnalytics
- [ ] Vérifier découverte des 5 tables (1 Bronze + 4 Silver)
- [ ] Créer Business Domain "3PL Real-Time Analytics"
- [ ] Créer Data Product dans le Business Domain
- [ ] Associer 5 tables au Data Product
- [ ] Lier Business Glossary terms (6 termes)
- [ ] Configurer Data Quality rules (focus Silver: 15 rules)
- [ ] Documenter Input Ports (Event Hub, SAP)
- [ ] Documenter Output Ports (GraphQL API, Power BI)

---

### ✅ Étape 2: Documenter Gold Layer (Hors Purview)
**Durée:** 1 jour

- [ ] Créer `governance/GOLD-LAYER-DOCUMENTATION.md`
  - Description de chaque KPI
  - Logique de calcul (KQL)
  - Use cases métier
  - Ownership
  - SLA performance
- [ ] Créer `governance/GOLD-LAYER-LINEAGE.md`
  - Transformations Silver → Gold
  - Refresh frequency
  - Dependencies
- [ ] Ajouter section Gold dans `README.md`

---

### ✅ Étape 3: Implémenter GraphQL API sur Eventhouse
**Durée:** 1 semaine

- [ ] Créer GraphQL schema (types: OrderSummary, SLAPerformance, etc.)
- [ ] Implémenter resolvers connectés à Eventhouse KQL
  - Gold queries: Lit materialized views directement
  - Silver queries: Lit tables Silver
- [ ] Tester performance (<100ms P95)
- [ ] Déployer API (Azure Container Apps)

---

### 🔄 Étape 4 [OPTIONNEL]: Évaluer besoin Phase 2
**Durée:** 1 jour (dans 2-3 mois)

- [ ] Review audit compliance : Gold requis dans Purview ?
- [ ] Mesurer performance API : KQL suffisant ou besoin cache ?
- [ ] Décider : Rester Hybrid OU migrer vers Option 2 (Lakehouse Gold)

---

## 6. Conclusion

### Réponse à la question : "La couche Gold est-elle obligatoire ?"

**Non, pas strictement obligatoire POUR LE DATA PRODUCT PURVIEW.**

**MAIS fortement recommandée POUR LES USE CASES MÉTIER.**

### Stratégie adoptée :

1. **Purview Data Product** = Bronze + Silver (5 tables)
   - Gouvernance centralisée des données source
   - Quality rules, lineage, business glossary
   
2. **Gold Layer** = Eventhouse Materialized Views (hors Purview)
   - Performance optimale pour API/BI (<50ms)
   - Temps réel (auto-refresh)
   - Documenté manuellement (README + lineage docs)

3. **GraphQL API** = Connecte Eventhouse directement
   - UC1 (Dashboard) : Lit Gold (KPIs précalculés)
   - UC2 (Opérations) : Lit Gold (filtres optimisés)
   - UC3/UC4 (Analyse) : Lit Silver (drill-down granulaire)

### Avantages de cette approche :

- ✅ **Time-to-market rapide** : Pas de pipeline Spark à développer
- ✅ **Performance métier** : Use cases critiques <100ms SLA
- ✅ **Simplicité opérationnelle** : KQL natif (vs Spark maintenance)
- ✅ **Coût réduit** : Pas de compute Spark additionnel
- ✅ **Gouvernance suffisante** : Silver = données certifiées source

### Limitation acceptée (temporaire) :

- ⚠️ Gold pas dans catalogue Purview (compensé par documentation rigoureuse)

### Plan futur :

- Si Microsoft livre "OneLake Availability pour Materialized Views" → Migration automatique
- Si audit exige Gold dans Purview → Implémenter Option 2 (Lakehouse Gold layer)

---

**Prochaine action:** Trigger scan Purview et créer le Data Product sur les 5 tables Silver + Bronze.
