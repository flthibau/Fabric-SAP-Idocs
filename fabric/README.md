# Microsoft Fabric Components# Microsoft Fabric Components



## Overview## Overview



This folder contains all configuration and resources for ingesting and analyzing SAP IDoc messages in Microsoft Fabric Real-Time Intelligence.# Microsoft Fabric - Ingestion et Analyse des IDocs SAP



## 📋 SummaryCe dossier contient toute la configuration et les ressources pour ingérer et analyser les messages IDoc SAP dans Microsoft Fabric Real-Time Intelligence.



This solution enables:## 📋 Vue d'ensemble

- 📥 **Ingest** IDoc messages from Azure Event Hub to Fabric

- 📊 **Analyze** real-time data with KQL DatabaseCette solution permet de :

- 📈 **Visualize** metrics with Power BI and Fabric dashboards- 📥 **Ingérer** les messages IDoc depuis Azure Event Hub vers Fabric

- 🔔 **Alert** on anomalies and exceptions- 📊 **Analyser** les données en temps réel avec KQL Database

- 📈 **Visualiser** les métriques avec Power BI et dashboards Fabric

## 🏗️ Architecture- 🔔 **Alerter** sur les anomalies et exceptions



```## 🏗️ Architecture

┌─────────────────┐      ┌──────────────────┐      ┌─────────────────────────┐

│  Python         │─────▶│  Azure Event Hub │─────▶│  Fabric Eventstream     │```

│  Simulator      │      │  eh-sap-idocs    │      │  trd-stream-sapidocs    │┌─────────────────┐      ┌──────────────────┐      ┌─────────────────────────┐

└─────────────────┘      └──────────────────┘      └──────────┬──────────────┘│  Simulateur     │─────▶│  Azure Event Hub │─────▶│  Fabric Eventstream     │

                                                               ││  Python         │      │  idoc-events     │      │  evs-sap-idoc-ingest    │

                              ┌────────────────────────────────┴─────────────┐└─────────────────┘      └──────────────────┘      └──────────┬──────────────┘

                              │                                              │                                                               │

                              ▼                                              ▼                              ┌────────────────────────────────┴─────────────┐

                     ┌─────────────────────┐                   ┌──────────────────────┐                              │                                              │

                     │  KQL Database       │                   │   Lakehouse          │                              ▼                                              ▼

                     │  kqldbsapidoc       │                   │   (optional)         │                     ┌─────────────────────┐                   ┌──────────────────────┐

                     │  - Real-time query  │                   │   - Long-term store  │                     │  KQL Database       │                   │   Lakehouse          │

                     │  - KQL analysis     │                   │   - Archives         │                     │  kqldb-sap-idoc     │                   │   lh-sap-idoc        │

                     └──────────┬──────────┘                   └──────────────────────┘                     │  - Analyse RTI      │                   │   - Stockage LT      │

                                │                     │  - Requêtes KQL     │                   │   - Archives         │

                     ┌──────────┴──────────┐                     └──────────┬──────────┘                   └──────────────────────┘

                     │                     │                                │

                     ▼                     ▼                     ┌──────────┴──────────┐

            ┌─────────────────┐   ┌──────────────────┐                     │                     │

            │  Power BI       │   │  Data Activator  │                     ▼                     ▼

            │  Dashboards     │   │  Alerts          │            ┌─────────────────┐   ┌──────────────────┐

            └─────────────────┘   └──────────────────┘            │  Power BI       │   │  Data Activator  │

```            │  Dashboards     │   │  Alertes         │

            └─────────────────┘   └──────────────────┘

## 📁 Folder Structure```



```## 📁 Structure du dossier

fabric/

├── README.md                      # This file```

├── README_KQL_QUERIES.md          # KQL query collectionfabric/

├── eventstream/├── README.md                      # Ce fichier

│   ├── EVENTSTREAM_SETUP.md       # Eventstream setup guide├── README_KQL_QUERIES.md          # Collection de requêtes KQL

│   └── setup-fabric-connection.ps1 # Setup script├── eventstream/

├── data-engineering/│   ├── EVENTSTREAM_SETUP.md       # Guide configuration Eventstream

│   ├── notebooks/                 # Fabric notebooks (transformations)│   └── setup-fabric-connection.ps1 # Script de préparation

│   └── pipelines/                 # Data pipelines├── data-engineering/

└── warehouse/│   ├── notebooks/                 # Notebooks Fabric (transformations)

    └── schema/                    # Table schemas│   └── pipelines/                 # Data pipelines

        ├── recreate-idoc-table-optimized.kql└── warehouse/

        ├── validate-ingestion.kql    └── schema/                    # Schémas de tables

        └── diagnose-mapping-issue.kql```

```

## 🚀 Démarrage rapide

## 🚀 Quick Start

### Prérequis

### Prerequisites

✅ Azure Event Hub déployé et opérationnel (`eh-idoc-flt8076/idoc-events`)  

✅ Azure Event Hub deployed and operational (`ehns-fabric-sap-idocs/eh-sap-idocs`)  ✅ Messages IDoc envoyés depuis le simulateur  

✅ IDoc messages sent from simulator  ✅ Workspace Microsoft Fabric avec capacité F64 (ou supérieure)  

✅ Microsoft Fabric workspace with capacity (F64+)  ✅ Permissions : Contributor sur workspace + Event Hubs Data Receiver  

✅ Permissions: Contributor on workspace + Event Hubs Data Receiver  

### Étape 1 : Préparer la connexion

### Step 1: Prepare Connection

Exécutez le script de configuration pour créer le consumer group et vérifier les permissions :

Run the configuration script to create consumer group and verify permissions:

```powershell

```powershellcd fabric\eventstream

cd fabric\eventstream.\setup-fabric-connection.ps1

.\setup-fabric-connection.ps1```

```

Ce script :

This script:- Crée le consumer group `fabric-consumer`

- Creates consumer group `fabric-consumer`- Vérifie/assigne les permissions RBAC

- Verifies/assigns RBAC permissions- Affiche les informations de connexion

- Displays connection information

### Étape 2 : Créer l'Eventstream

### Step 2: Create Eventstream

1. Ouvrez votre workspace Fabric

1. Open your Fabric workspace2. Créez un **Eventstream** : `evs-sap-idoc-ingest`

2. Create an **Eventstream**: `trd-stream-sapidocs-eventstream`3. Suivez le guide détaillé : [`eventstream/EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md)

3. Follow detailed guide: [`eventstream/EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md)

### Étape 3 : Créer la KQL Database

### Step 3: Create KQL Database

1. Dans Fabric, créez une **KQL Database** : `kqldb-sap-idoc`

1. In Fabric, create a **KQL Database**: `kqldbsapidoc`2. Ajoutez une destination depuis l'Eventstream vers cette database

2. Add destination from Eventstream to this database3. Créez la table `idoc_raw` avec le schema détecté

3. Create table `idoc_raw` with auto-detected schema

### Étape 4 : Analyser les données

### Step 4: Analyze Data

Utilisez les requêtes KQL du fichier [`README_KQL_QUERIES.md`](./README_KQL_QUERIES.md) :

Use KQL queries from [`README_KQL_QUERIES.md`](./README_KQL_QUERIES.md):

```kql

```kql// Aperçu des derniers messages

// Latest messages overviewidoc_raw

idoc_raw| take 10

| take 10| order by timestamp desc

| order by timestamp desc| project timestamp, idoc_type, message_type, sap_system

| project timestamp, message_type, sap_system```

```

```kql

## 📊 Key Use Cases// Distribution des types d'IDoc

idoc_raw

### 1. Real-time Monitoring| summarize count() by message_type

| render piechart

**Dashboard**: Volume, latency, errors```

```kql

idoc_raw## 📊 Cas d'usage

| where timestamp > ago(1h)

| summarize count() by bin(timestamp, 5m), message_type### 1. Monitoring en temps réel

| render timechart

```**Objectif** : Surveiller le flux de messages SAP en temps réel



### 2. Business Intelligence**Requête KQL** :

```kql

**Power BI**: idoc_raw

- Volume by IDoc type (pie chart)| where timestamp > ago(5m)

- Hourly trend (line chart)| summarize Messages = count() by bin(timestamp, 30s), message_type

- Top customers/products (bar chart)| render timechart

- Latency KPIs (card)```



### 3. Anomaly Detection**Dashboard** : Créez un tile Fabric rafraîchi toutes les 30 secondes



**Data Activator**:---

- Error messages (`status != "03"`)

- Abnormal volume (`> 2x average`)### 2. Analyse des performances

- High latency (`> 5 min`)

**Objectif** : Identifier les goulots d'étranglement

### 4. Long-term Archiving

**Requête KQL** :

**Lakehouse**:```kql

- Partitioning: YYYY/MM/DDidoc_raw

- Format: Delta/Parquet| extend ingestion_time = ingestion_time()

- Retention: Unlimited| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))

| summarize 

## 🔧 Components    Latence_P50 = percentile(latency_seconds, 50),

    Latence_P95 = percentile(latency_seconds, 95)

### Eventstream    by bin(timestamp, 5m)

| render timechart

**Name**: `trd-stream-sapidocs-eventstream````



**Source**:---

- Azure Event Hub: `ehns-fabric-sap-idocs/eh-sap-idocs`

- Consumer group: `fabric-consumer`### 3. Détection d'anomalies

- Authentication: Entra ID

**Objectif** : Alerter sur les messages en erreur

**Destinations**:

1. **KQL Database**: `kqldbsapidoc` (real-time queries)**Requête KQL** :

2. **Lakehouse**: Long-term storage (optional)```kql

3. **Reflex**: Alerts (optional)idoc_raw

| where tostring(control.status) != "03"

### KQL Database| project timestamp, message_type, docnum=control.docnum, status=control.status

| order by timestamp desc

**Name**: `kqldbsapidoc````



**Main Table**: `idoc_raw`**Alerte** : Configurez Data Activator / Reflex pour déclencher une alerte Teams/Email



**Schema**:---

```kql

.show table idoc_raw schema### 4. Analyse métier

```

**Objectif** : Analyser les commandes par client

**Key Columns**:

- `message_type` (string): IDoc type (ORDERS, DESADV, etc.)**Requête KQL** :

- `timestamp` (datetime): Message timestamp```kql

- `system_id` (string): SAP systemidoc_raw

- `document_number` (string): Document number| where message_type == "ORDERS05"

- `control` (dynamic): Control segment| extend NumCommande = control.docnum

- `data` (dynamic): IDoc data payload| extend Client = tostring(data.E1EDK01[0].BELNR)

| summarize Total_Commandes = count() by Client

### Data Engineering| top 10 by Total_Commandes desc

| render columnchart

**Notebooks**: Transformations and enrichment```

- Extract business fields

- Join with reference data---

- Create aggregated views

## 🔧 Configuration avancée

**Pipelines**: Scheduled transformations

- Bronze → Silver → Gold### Lakehouse pour archivage

- Data quality checks

- Incremental loadsPour un stockage long terme, ajoutez une destination Lakehouse :



## 📈 Analytics Examples1. Créez un **Lakehouse** : `lh-sap-idoc`

2. Depuis l'Eventstream, ajoutez destination → Lakehouse

### Volume Analysis3. Table : `idoc_events` (mode Append)

4. Partitioning : Par date (année/mois/jour)

```kql

idoc_raw### Data pipeline pour transformations

| summarize count() by message_type

| order by count_ descPour transformer les données avant stockage :

| render barchart

```1. Créez un **Data Pipeline**

2. Source : KQL Database `idoc_raw`

### Latency Tracking3. Transformations :

   - Extraction des champs métier (numéros de commande, montants)

```kql   - Enrichissement (lookup tables, conversions)

idoc_raw   - Agrégations

| where timestamp > ago(24h)4. Destination : Warehouse ou Lakehouse

| extend ingestion_lag = datetime_diff('second', ingestion_time(), timestamp)

| summarize ### Power BI Real-time

    avg_lag = avg(ingestion_lag),

    p95_lag = percentile(ingestion_lag, 95)Créez un rapport Power BI connecté au KQL Database :

    by bin(timestamp, 1h)

| render timechart1. Power BI Desktop → Get Data → **KQL Database**

```2. Connexion : `kqldb-sap-idoc`

3. Mode : **DirectQuery** (pour temps réel)

### Error Detection4. Créez des visuels (cartes, graphiques, tableaux)

5. Publiez sur Fabric avec refresh automatique

```kql

idoc_raw---

| extend status_code = tostring(control.status)

| where status_code != "03"## 📖 Documentation

| summarize errors = count() by message_type, status_code

| order by errors desc| Fichier | Description |

```|---------|-------------|

| [EVENTSTREAM_SETUP.md](./eventstream/EVENTSTREAM_SETUP.md) | Guide complet configuration Eventstream |

### Top Customers| [README_KQL_QUERIES.md](./README_KQL_QUERIES.md) | Collection de 50+ requêtes KQL |

| [setup-fabric-connection.ps1](./eventstream/setup-fabric-connection.ps1) | Script PowerShell de préparation |

```kql

idoc_raw## 🔍 Troubleshooting

| where message_type == "ORDERS"

| extend customer = tostring(data.customer_id)### ❌ Eventstream ne reçoit pas de données

| summarize order_count = count() by customer

| top 10 by order_count**Causes possibles** :

| render barchart- Consumer group partagé avec le CLI reader

```- Permissions RBAC manquantes

- Event Hub vide

## 🔔 Alert Configuration

**Solution** :

### Data Activator Reflex```powershell

# Créer un consumer group dédié

**Alert Name**: `IDoc Error Detection`.\eventstream\setup-fabric-connection.ps1



**Condition**:# Vérifier qu'il y a des messages

```kqlcd ..\simulator

idoc_rawpython read_eventhub.py --max 5

| extend status = tostring(control.status)```

| where status != "03"

| count---

```

### ❌ Erreur de parsing JSON

**Threshold**: > 0 errors in 5 minutes

**Cause** : Format de données incorrect dans la source

**Action**: Send Teams notification

**Solution** :

## 📚 Resources1. Dans Eventstream, éditez la source

2. Data format : **JSON**

### Documentation3. Testez avec un message : `python read_eventhub.py --max 1 --details`



| Document | Description |---

|----------|-------------|

| [EVENTSTREAM_SETUP.md](./eventstream/EVENTSTREAM_SETUP.md) | Detailed Eventstream configuration |### ❌ Latence élevée

| [README_KQL_QUERIES.md](./README_KQL_QUERIES.md) | 50+ KQL query examples |

| [../SETUP_GUIDE.md](../SETUP_GUIDE.md) | Complete setup guide |**Cause** : Consumer lag, partition skew

| [../FABRIC_QUICKSTART.md](../FABRIC_QUICKSTART.md) | Quick start (5 min) |

**Solution** :

### Microsoft Learn```kql

// Vérifier la latence

- [Microsoft Fabric](https://learn.microsoft.com/fabric/)idoc_raw

- [Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)| extend ingestion_time = ingestion_time()

- [Eventstream](https://learn.microsoft.com/fabric/real-time-intelligence/event-streams/overview)| extend latency = datetime_diff('second', ingestion_time, todatetime(timestamp))

- [KQL Database](https://learn.microsoft.com/fabric/real-time-intelligence/create-database)| summarize avg(latency), percentile(latency, 95)

- [KQL Language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)```



## 🧪 TestingAugmentez le nombre de partitions si nécessaire.



### Validate Ingestion---



```powershell## 🎯 Prochaines étapes

# Send test messages

cd simulator1. ✅ **Configurer l'Eventstream** → [`EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md)

python main.py2. 📊 **Analyser avec KQL** → [`README_KQL_QUERIES.md`](./README_KQL_QUERIES.md)

3. 📈 **Créer un dashboard Power BI** temps réel

# Verify in Fabric4. 🔔 **Configurer des alertes** avec Data Activator

# Open KQL Queryset and run:5. 🗄️ **Archiver dans Lakehouse** pour le long terme

idoc_raw | count6. 🔄 **Transformer avec pipelines** pour enrichissement

// Expected: > 0 messages

```---



### Performance Test## 📚 Ressources



```kql- [Microsoft Fabric - Documentation officielle](https://learn.microsoft.com/fabric/)

// Check ingestion rate- [Eventstream - Guide](https://learn.microsoft.com/fabric/real-time-intelligence/event-streams/overview)

idoc_raw- [KQL Database - Tutorial](https://learn.microsoft.com/fabric/real-time-intelligence/create-database)

| summarize count() by bin(ingestion_time(), 1m)- [KQL Query Language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

| render timechart- [Power BI Real-time](https://learn.microsoft.com/fabric/real-time-intelligence/power-bi-data-connector)

```

---

### Data Quality

## 💡 Support

```kql

// Check for missing fieldsPour toute question ou problème :

idoc_raw1. Consultez la section Troubleshooting ci-dessus

| summarize 2. Vérifiez les logs dans Eventstream (onglet Metrics)

    total = count(),3. Testez la connexion avec le CLI : `python ..\simulator\read_eventhub.py`

    missing_type = countif(isempty(message_type)),- Eventstream configuration

    missing_timestamp = countif(isnull(timestamp))- Data Engineering pipelines (Spark)

```- SQL Warehouse schema



## 🎯 Next Steps## Structure



1. ✅ Configure Eventstream (follow EVENTSTREAM_SETUP.md)```

2. ✅ Create KQL Databasefabric/

3. 📊 Build Power BI dashboard├── eventstream/

4. 🔔 Set up Data Activator alerts│   └── eventstream-config.json       # Eventstream configuration

5. 🗄️ Configure Lakehouse archiving├── data-engineering/

6. 🔄 Create data transformation pipeline│   ├── notebooks/

│   │   ├── bronze_to_silver.ipynb    # Bronze → Silver transformation

## 💡 Tips│   │   ├── silver_to_gold.ipynb      # Silver → Gold transformation

│   │   └── data_quality_checks.ipynb # Quality validation

### Performance Optimization│   └── pipelines/

│       ├── ingestion_pipeline.json   # Main ingestion pipeline

- Use **materialized views** for frequently queried aggregations│       └── transformation_pipeline.json

- Enable **row-level security** if needed└── warehouse/

- Partition Lakehouse by date for efficient queries    └── schema/

- Use **update policies** for automatic transformations        ├── bronze_tables.sql         # Bronze layer DDL

        ├── silver_tables.sql         # Silver layer DDL

### Best Practices        ├── gold_dimensions.sql       # Gold dimension tables

        └── gold_facts.sql            # Gold fact tables

- Monitor consumer lag in Eventstream metrics```

- Set retention policies on KQL tables

- Use **incremental refresh** in Power BI## Prerequisites

- Implement **data quality checks** in pipelines

- Document custom KQL queries in shared querysets- Microsoft Fabric capacity (F64 or higher recommended)

- Fabric workspace created

## ❓ Troubleshooting- Lakehouse created: `sap-idoc-lakehouse`

- SQL Warehouse created: `sap-3pl-warehouse`

### No Data in KQL Database- Service Principal or User account with permissions



**Check**:## Setup Instructions

1. Eventstream data preview shows messages

2. Destination is active### 1. Eventstream Setup

3. Consumer group is `fabric-consumer`

4. RBAC permissions are correct1. Navigate to your Fabric workspace

2. Create a new Eventstream: `sap-idoc-ingest`

**Solution**:3. Configure source (Event Hub)

```powershell4. Apply transformation from `eventstream/eventstream-config.json`

# Re-run setup script5. Set destination to Lakehouse

.\fabric\eventstream\setup-fabric-connection.ps1

```### 2. Lakehouse Configuration



### High Latency```bash

# Create Lakehouse using Fabric API or UI

**Check**:# Name: sap-idoc-lakehouse

1. Event Hub metrics (incoming/outgoing messages)```

2. Eventstream consumer lag

3. KQL Database ingestion queueRun DDL scripts in order:

1. `warehouse/schema/bronze_tables.sql`

**Solution**:2. `warehouse/schema/silver_tables.sql`

- Increase Event Hub throughput units3. `warehouse/schema/gold_dimensions.sql`

- Check for throttling in Azure Portal4. `warehouse/schema/gold_facts.sql`

- Verify network connectivity

### 3. Data Engineering Pipelines

### Query Performance

Import notebooks:

**Optimize**:1. Upload notebooks to Fabric workspace

```kql2. Attach to Lakehouse

// Use specific time ranges3. Configure Spark settings

idoc_raw

| where timestamp > ago(1h)  // Instead of full scanSchedule pipelines:

| where message_type == "ORDERS"  // Filter early- Bronze to Silver: Every 5 minutes

| project timestamp, document_number  // Select only needed columns- Silver to Gold: Every 15 minutes

```- Data Quality: Hourly



---## Medallion Architecture



**Ready to start?** Open [`EVENTSTREAM_SETUP.md`](./eventstream/EVENTSTREAM_SETUP.md) for step-by-step instructions!### Bronze Layer (Raw)

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
