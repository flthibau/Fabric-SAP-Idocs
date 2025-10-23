# Microsoft Fabric Components

## Overview

# Microsoft Fabric - Ingestion et Analyse des IDocs SAP

Ce dossier contient toute la configuration et les ressources pour ingérer et analyser les messages IDoc SAP dans Microsoft Fabric Real-Time Intelligence.

## 📋 Vue d'ensemble

Cette solution permet de :
- 📥 **Ingérer** les messages IDoc depuis Azure Event Hub vers Fabric
- 📊 **Analyser** les données en temps réel avec KQL Database
- 📈 **Visualiser** les métriques avec Power BI et dashboards Fabric
- 🔔 **Alerter** sur les anomalies et exceptions

## 🏗️ Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────────────┐
│  Simulateur     │─────▶│  Azure Event Hub │─────▶│  Fabric Eventstream     │
│  Python         │      │  idoc-events     │      │  evs-sap-idoc-ingest    │
└─────────────────┘      └──────────────────┘      └──────────┬──────────────┘
                                                               │
                              ┌────────────────────────────────┴─────────────┐
                              │                                              │
                              ▼                                              ▼
                     ┌─────────────────────┐                   ┌──────────────────────┐
                     │  KQL Database       │                   │   Lakehouse          │
                     │  kqldb-sap-idoc     │                   │   lh-sap-idoc        │
                     │  - Analyse RTI      │                   │   - Stockage LT      │
                     │  - Requêtes KQL     │                   │   - Archives         │
                     └──────────┬──────────┘                   └──────────────────────┘
                                │
                     ┌──────────┴──────────┐
                     │                     │
                     ▼                     ▼
            ┌─────────────────┐   ┌──────────────────┐
            │  Power BI       │   │  Data Activator  │
            │  Dashboards     │   │  Alertes         │
            └─────────────────┘   └──────────────────┘
```

## 📁 Structure du dossier

```
fabric/
├── README.md                      # Ce fichier
├── README_KQL_QUERIES.md          # Collection de requêtes KQL
├── eventstream/
│   ├── EVENTSTREAM_SETUP.md       # Guide configuration Eventstream
│   └── setup-fabric-connection.ps1 # Script de préparation
├── data-engineering/
│   ├── notebooks/                 # Notebooks Fabric (transformations)
│   └── pipelines/                 # Data pipelines
└── warehouse/
    └── schema/                    # Schémas de tables
```

## 🚀 Démarrage rapide

### Prérequis

✅ Azure Event Hub déployé et opérationnel (`eh-idoc-flt8076/idoc-events`)  
✅ Messages IDoc envoyés depuis le simulateur  
✅ Workspace Microsoft Fabric avec capacité F64 (ou supérieure)  
✅ Permissions : Contributor sur workspace + Event Hubs Data Receiver  

### Étape 1 : Préparer la connexion

Exécutez le script de configuration pour créer le consumer group et vérifier les permissions :

```powershell
cd fabric\eventstream
.\setup-fabric-connection.ps1
```

Ce script :
- Crée le consumer group `fabric-consumer`
- Vérifie/assigne les permissions RBAC
- Affiche les informations de connexion

### Étape 2 : Créer l'Eventstream

1. Ouvrez votre workspace Fabric
2. Créez un **Eventstream** : `evs-sap-idoc-ingest`
3. Suivez le guide détaillé : [`eventstream/EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md)

### Étape 3 : Créer la KQL Database

1. Dans Fabric, créez une **KQL Database** : `kqldb-sap-idoc`
2. Ajoutez une destination depuis l'Eventstream vers cette database
3. Créez la table `idoc_raw` avec le schema détecté

### Étape 4 : Analyser les données

Utilisez les requêtes KQL du fichier [`README_KQL_QUERIES.md`](./README_KQL_QUERIES.md) :

```kql
// Aperçu des derniers messages
idoc_raw
| take 10
| order by timestamp desc
| project timestamp, idoc_type, message_type, sap_system
```

```kql
// Distribution des types d'IDoc
idoc_raw
| summarize count() by message_type
| render piechart
```

## 📊 Cas d'usage

### 1. Monitoring en temps réel

**Objectif** : Surveiller le flux de messages SAP en temps réel

**Requête KQL** :
```kql
idoc_raw
| where timestamp > ago(5m)
| summarize Messages = count() by bin(timestamp, 30s), message_type
| render timechart
```

**Dashboard** : Créez un tile Fabric rafraîchi toutes les 30 secondes

---

### 2. Analyse des performances

**Objectif** : Identifier les goulots d'étranglement

**Requête KQL** :
```kql
idoc_raw
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize 
    Latence_P50 = percentile(latency_seconds, 50),
    Latence_P95 = percentile(latency_seconds, 95)
    by bin(timestamp, 5m)
| render timechart
```

---

### 3. Détection d'anomalies

**Objectif** : Alerter sur les messages en erreur

**Requête KQL** :
```kql
idoc_raw
| where tostring(control.status) != "03"
| project timestamp, message_type, docnum=control.docnum, status=control.status
| order by timestamp desc
```

**Alerte** : Configurez Data Activator / Reflex pour déclencher une alerte Teams/Email

---

### 4. Analyse métier

**Objectif** : Analyser les commandes par client

**Requête KQL** :
```kql
idoc_raw
| where message_type == "ORDERS05"
| extend NumCommande = control.docnum
| extend Client = tostring(data.E1EDK01[0].BELNR)
| summarize Total_Commandes = count() by Client
| top 10 by Total_Commandes desc
| render columnchart
```

---

## 🔧 Configuration avancée

### Lakehouse pour archivage

Pour un stockage long terme, ajoutez une destination Lakehouse :

1. Créez un **Lakehouse** : `lh-sap-idoc`
2. Depuis l'Eventstream, ajoutez destination → Lakehouse
3. Table : `idoc_events` (mode Append)
4. Partitioning : Par date (année/mois/jour)

### Data pipeline pour transformations

Pour transformer les données avant stockage :

1. Créez un **Data Pipeline**
2. Source : KQL Database `idoc_raw`
3. Transformations :
   - Extraction des champs métier (numéros de commande, montants)
   - Enrichissement (lookup tables, conversions)
   - Agrégations
4. Destination : Warehouse ou Lakehouse

### Power BI Real-time

Créez un rapport Power BI connecté au KQL Database :

1. Power BI Desktop → Get Data → **KQL Database**
2. Connexion : `kqldb-sap-idoc`
3. Mode : **DirectQuery** (pour temps réel)
4. Créez des visuels (cartes, graphiques, tableaux)
5. Publiez sur Fabric avec refresh automatique

---

## 📖 Documentation

| Fichier | Description |
|---------|-------------|
| [EVENTSTREAM_SETUP.md](./eventstream/EVENTSTREAM_SETUP.md) | Guide complet configuration Eventstream |
| [README_KQL_QUERIES.md](./README_KQL_QUERIES.md) | Collection de 50+ requêtes KQL |
| [setup-fabric-connection.ps1](./eventstream/setup-fabric-connection.ps1) | Script PowerShell de préparation |

## 🔍 Troubleshooting

### ❌ Eventstream ne reçoit pas de données

**Causes possibles** :
- Consumer group partagé avec le CLI reader
- Permissions RBAC manquantes
- Event Hub vide

**Solution** :
```powershell
# Créer un consumer group dédié
.\eventstream\setup-fabric-connection.ps1

# Vérifier qu'il y a des messages
cd ..\simulator
python read_eventhub.py --max 5
```

---

### ❌ Erreur de parsing JSON

**Cause** : Format de données incorrect dans la source

**Solution** :
1. Dans Eventstream, éditez la source
2. Data format : **JSON**
3. Testez avec un message : `python read_eventhub.py --max 1 --details`

---

### ❌ Latence élevée

**Cause** : Consumer lag, partition skew

**Solution** :
```kql
// Vérifier la latence
idoc_raw
| extend ingestion_time = ingestion_time()
| extend latency = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize avg(latency), percentile(latency, 95)
```

Augmentez le nombre de partitions si nécessaire.

---

## 🎯 Prochaines étapes

1. ✅ **Configurer l'Eventstream** → [`EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md)
2. 📊 **Analyser avec KQL** → [`README_KQL_QUERIES.md`](./README_KQL_QUERIES.md)
3. 📈 **Créer un dashboard Power BI** temps réel
4. 🔔 **Configurer des alertes** avec Data Activator
5. 🗄️ **Archiver dans Lakehouse** pour le long terme
6. 🔄 **Transformer avec pipelines** pour enrichissement

---

## 📚 Ressources

- [Microsoft Fabric - Documentation officielle](https://learn.microsoft.com/fabric/)
- [Eventstream - Guide](https://learn.microsoft.com/fabric/real-time-intelligence/event-streams/overview)
- [KQL Database - Tutorial](https://learn.microsoft.com/fabric/real-time-intelligence/create-database)
- [KQL Query Language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [Power BI Real-time](https://learn.microsoft.com/fabric/real-time-intelligence/power-bi-data-connector)

---

## 💡 Support

Pour toute question ou problème :
1. Consultez la section Troubleshooting ci-dessus
2. Vérifiez les logs dans Eventstream (onglet Metrics)
3. Testez la connexion avec le CLI : `python ..\simulator\read_eventhub.py`
- Eventstream configuration
- Data Engineering pipelines (Spark)
- SQL Warehouse schema

## Structure

```
fabric/
├── eventstream/
│   └── eventstream-config.json       # Eventstream configuration
├── data-engineering/
│   ├── notebooks/
│   │   ├── bronze_to_silver.ipynb    # Bronze → Silver transformation
│   │   ├── silver_to_gold.ipynb      # Silver → Gold transformation
│   │   └── data_quality_checks.ipynb # Quality validation
│   └── pipelines/
│       ├── ingestion_pipeline.json   # Main ingestion pipeline
│       └── transformation_pipeline.json
└── warehouse/
    └── schema/
        ├── bronze_tables.sql         # Bronze layer DDL
        ├── silver_tables.sql         # Silver layer DDL
        ├── gold_dimensions.sql       # Gold dimension tables
        └── gold_facts.sql            # Gold fact tables
```

## Prerequisites

- Microsoft Fabric capacity (F64 or higher recommended)
- Fabric workspace created
- Lakehouse created: `sap-idoc-lakehouse`
- SQL Warehouse created: `sap-3pl-warehouse`
- Service Principal or User account with permissions

## Setup Instructions

### 1. Eventstream Setup

1. Navigate to your Fabric workspace
2. Create a new Eventstream: `sap-idoc-ingest`
3. Configure source (Event Hub)
4. Apply transformation from `eventstream/eventstream-config.json`
5. Set destination to Lakehouse

### 2. Lakehouse Configuration

```bash
# Create Lakehouse using Fabric API or UI
# Name: sap-idoc-lakehouse
```

Run DDL scripts in order:
1. `warehouse/schema/bronze_tables.sql`
2. `warehouse/schema/silver_tables.sql`
3. `warehouse/schema/gold_dimensions.sql`
4. `warehouse/schema/gold_facts.sql`

### 3. Data Engineering Pipelines

Import notebooks:
1. Upload notebooks to Fabric workspace
2. Attach to Lakehouse
3. Configure Spark settings

Schedule pipelines:
- Bronze to Silver: Every 5 minutes
- Silver to Gold: Every 15 minutes
- Data Quality: Hourly

## Medallion Architecture

### Bronze Layer (Raw)
- Purpose: Store raw IDoc messages
- Format: Delta Lake
- Retention: 90 days
- Partitioning: By date and IDoc type

### Silver Layer (Cleansed)
- Purpose: Cleaned and normalized data
- Format: Delta Lake
- Retention: 2 years
- Features: Deduplication, validation, standardization

### Gold Layer (Analytics)
- Purpose: Business-ready dimensional model
- Format: SQL Warehouse tables
- Retention: 7 years
- Design: Star schema with dimensions and facts

## Key Tables

| Table | Layer | Description |
|-------|-------|-------------|
| `bronze_idocs` | Bronze | Raw IDoc messages |
| `silver_shipments` | Silver | Cleansed shipment data |
| `silver_deliveries` | Silver | Cleansed delivery data |
| `dim_customer` | Gold | Customer dimension |
| `dim_location` | Gold | Location dimension |
| `fact_shipment` | Gold | Shipment fact table |

## Data Transformation Flow

```
Event Hub
    ↓
Eventstream (validation, enrichment)
    ↓
bronze_idocs (raw storage)
    ↓
Spark Notebook: bronze_to_silver
    ↓
silver_* tables (cleansed data)
    ↓
Spark Notebook: silver_to_gold
    ↓
dim_* & fact_* tables (analytics)
```

## Monitoring

- Use Fabric Monitoring for Eventstream metrics
- Check pipeline execution history
- Monitor Delta Lake table metrics
- Set up alerts for pipeline failures

## Performance Optimization

### Delta Lake Optimization

```sql
-- Optimize tables regularly
OPTIMIZE bronze_idocs ZORDER BY (idoc_type, processing_date);
OPTIMIZE silver_shipments ZORDER BY (customer_id, ship_date);

-- Vacuum old versions
VACUUM bronze_idocs RETAIN 168 HOURS;
VACUUM silver_shipments RETAIN 168 HOURS;
```

### Spark Configuration

```python
# Recommended Spark settings for notebooks
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
```

## Troubleshooting

### Eventstream Issues
- Check Event Hub connectivity
- Verify schema validation rules
- Review error logs in monitoring

### Pipeline Failures
- Check Spark logs
- Verify table permissions
- Ensure sufficient capacity

### Performance Issues
- Review partition strategy
- Optimize Delta tables
- Increase Spark compute resources

## Development Workflow

1. Develop transformations in notebooks
2. Test with sample data
3. Validate data quality
4. Deploy to production workspace
5. Schedule pipelines

## Contributing

When modifying Fabric components:
1. Test in development workspace
2. Document changes in notebook markdown
3. Update this README
4. Create backup of current configuration
5. Deploy changes incrementally

## Support

- Fabric Documentation: https://learn.microsoft.com/fabric/
- Internal Support: data-engineering@company.com
