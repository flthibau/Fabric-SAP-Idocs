# Quick Start - Fabric Eventstream Configuration# Démarrage Rapide - Configuration Fabric Eventstream



## ✅ Prerequisites Complete## ✅ Préparation terminée



The consumer group `fabric-consumer` has been successfully created!Le consumer group `fabric-consumer` a été créé avec succès !



``````

Event Hub Namespace: ehns-fabric-sap-idocs.servicebus.windows.netEvent Hub Namespace: eh-idoc-flt8076.servicebus.windows.net

Event Hub: eh-sap-idocsEvent Hub: idoc-events

Consumer Group: fabric-consumerConsumer Group: fabric-consumer

Partitions: 4Partitions: 4

Retention: 168 hours (7 days)Retention: 168 heures (7 jours)

Status: ActiveStatus: Active

``````



------



## 🚀 Next Steps in Microsoft Fabric## 🚀 Étapes suivantes dans Microsoft Fabric



### Step 1: Access Your Fabric Workspace### Étape 1 : Accéder à votre workspace Fabric



1. Open [Microsoft Fabric](https://app.fabric.microsoft.com)1. Ouvrez [Microsoft Fabric](https://app.fabric.microsoft.com)

2. Select or create a workspace2. Sélectionnez ou créez un workspace

3. Ensure you have a **Fabric capacity** (F64 or higher) assigned3. Assurez-vous d'avoir une **capacité F64** (ou supérieure) assignée



### Step 2: Create the Eventstream### Étape 2 : Créer l'Eventstream



1. In your workspace, click **+ New**1. Dans votre workspace, cliquez sur **+ New**

2. Select **Real-Time Intelligence** → **Eventstream**2. Sélectionnez **Real-Time Intelligence** → **Eventstream**

3. Name: `trd-stream-sapidocs-eventstream`3. Nom : `evs-sap-idoc-ingest`

4. Click **Create**4. Cliquez sur **Create**



### Step 3: Configure Event Hub Source### Étape 3 : Configurer la source Event Hub



In the Eventstream canvas:Dans le canvas de l'Eventstream :



1. Click **Add source**1. Cliquez sur **Add source**

2. Select **Azure Event Hubs**2. Sélectionnez **Azure Event Hubs**

3. Configure with these parameters:3. Configurez avec ces paramètres :



```yaml```yaml

Connection name: conn-eventhub-sap-idocsConnection name: conn-eventhub-idoc

Authentication kind: Organizational account (Entra ID)Authentication kind: Organizational account (Entra ID)



Event Hub namespace: ehns-fabric-sap-idocs.servicebus.windows.netEvent Hub namespace: eh-idoc-flt8076.servicebus.windows.net

Event Hub: eh-sap-idocsEvent Hub: idoc-events

Consumer group: fabric-consumerConsumer group: fabric-consumer



Data format: JSONData format: JSON

``````



4. Test the connection4. Testez la connexion

5. Click **Create source**5. Cliquez sur **Create source**



### Step 4: Verify Data Reception### Étape 4 : Vérifier la réception des données



1. In the Eventstream, click **Data preview**1. Dans l'Eventstream, cliquez sur **Data preview**

2. You should see IDoc messages appearing in real-time2. Vous devriez voir les messages IDoc apparaître en temps réel

3. Verify the JSON structure:3. Vérifiez la structure JSON :

   - `idoc_type`   - `idoc_type`

   - `message_type`   - `message_type`

   - `sap_system`   - `sap_system`

   - `timestamp`   - `timestamp`

   - `control` (object)   - `control` (object)

   - `data` (object)   - `data` (object)



### Step 5: Create KQL Database (Destination)### Étape 5 : Créer une KQL Database (destination)



1. In the canvas, click **Add destination**1. Dans le canvas, cliquez sur **Add destination**

2. Select **KQL Database**2. Sélectionnez **KQL Database**

3. Create or select database: `kqldbsapidoc`3. Créez ou sélectionnez une base : `kqldb-sap-idoc`

4. Table: `idoc_raw`4. Table : `idoc_raw`

5. Let Fabric auto-detect the schema5. Laissez Fabric détecter le schéma automatiquement

6. Suggested mapping:6. Mapping suggéré :



``````

idoc_type     → stringidoc_type     → string

message_type  → stringmessage_type  → string

sap_system    → stringsap_system    → string

timestamp     → datetimetimestamp     → datetime

control       → dynamiccontrol       → dynamic

data          → dynamicdata          → dynamic

``````



7. Enable ingestion7. Activez l'ingestion



### Step 6: Test Data in KQL Database### Étape 6 : Tester les données dans KQL Database



1. Open KQL Database `kqldbsapidoc`1. Ouvrez la KQL Database `kqldb-sap-idoc`

2. Create a **KQL Queryset**2. Créez un **KQL Queryset**

3. Test this query:3. Testez cette requête :



```kql```kql

idoc_rawidoc_raw

| take 10| take 10

| order by timestamp desc| order by timestamp desc

| project timestamp, idoc_type, message_type, sap_system| project timestamp, idoc_type, message_type, sap_system

``````



You should see IDoc messages!Vous devriez voir les messages IDoc !



------



## 📊 Essential KQL Queries## 📊 Requêtes KQL essentielles



### Volume by IDoc Type### Volume par type d'IDoc



```kql```kql

idoc_rawidoc_raw

| summarize count() by message_type| summarize count() by message_type

| render piechart| render piechart

``````



### Messages per Hour (Last 24h)### Messages par heure (dernières 24h)



```kql```kql

idoc_rawidoc_raw

| where timestamp > ago(24h)| where timestamp > ago(24h)

| summarize count() by bin(timestamp, 1h)| summarize count() by bin(timestamp, 1h)

| render timechart| render timechart

``````



### Ingestion Latency### Latence d'ingestion



```kql```kql

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| extend ingestion_time = ingestion_time()| extend ingestion_time = ingestion_time()

| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))

| summarize | summarize 

    Average_Latency = avg(latency_seconds),    Latence_Moyenne = avg(latency_seconds),

    P95_Latency = percentile(latency_seconds, 95)    Latence_P95 = percentile(latency_seconds, 95)

``````



### Error Messages### Messages avec erreurs



```kql```kql

idoc_rawidoc_raw

| extend Status = tostring(control.status)| extend Statut = tostring(control.status)

| where Status != "03"| where Statut != "03"

| project timestamp, message_type, docnum=control.docnum, Status| project timestamp, message_type, docnum=control.docnum, Statut

| order by timestamp desc| order by timestamp desc

``````



👉 **For more queries**: See [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) (50+ examples)👉 **Pour plus de requêtes** : consultez [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) (50+ exemples)



------



## 🧪 Test with the Simulator## 🧪 Tester avec le simulateur



### Send Test Messages### Envoyer des messages de test



```powershell```powershell

cd simulatorcd simulator

python main.pypython main.py

``````



The simulator will send:Le simulateur enverra :

- **10 messages/minute**- **10 messages/minute**

- Types: ORDERS (20%), WHSCON (20%), DESADV (20%), SHPMNT (20%), INVOIC (20%)- Types : ORDERS (25%), WHSCON (30%), DESADV (20%), SHPMNT (15%), INVOICE (10%)

- Duration: 1 hour (configurable in `.env`)- Durée : 1 heure (configurable dans `.env`)



### Verify Reception (without Fabric)### Vérifier la réception (sans Fabric)



```powershell```powershell

python read_eventhub.py --max 5python read_eventhub.py --max 5

``````



**Note**: Use default consumer group (`$Default`) for CLI, and `fabric-consumer` for Fabric.**Note** : Utilisez le consumer group par défaut (`$Default`) pour le CLI, et `fabric-consumer` pour Fabric.



------



## 🎯 Recommended Next Steps## 🎯 Prochaines étapes recommandées



### 1. Create a Power BI Dashboard### 1. Créer un Dashboard Power BI



- Connect Power BI Desktop to `kqldbsapidoc`- Connectez Power BI Desktop à `kqldb-sap-idoc`

- Mode: **DirectQuery** (for real-time)- Mode : **DirectQuery** (pour temps réel)

- Create visuals: volume, latency, errors- Créez des visuels : volume, latence, erreurs

- Publish to Fabric with auto-refresh (30s)- Publiez sur Fabric avec auto-refresh (30s)



### 2. Configure Alerts with Data Activator### 2. Configurer des alertes avec Data Activator



- Create a **Reflex**- Créez un **Reflex**

- Alert conditions:- Conditions d'alerte :

  - Abnormal volume (`> 2x average`)  - Volume anormal (`> 2x moyenne`)

  - Error messages (`status != "03"`)  - Messages en erreur (`status != "03"`)

  - High latency (`> 5 minutes`)  - Latence élevée (`> 5 minutes`)

- Notifications: Teams, Email- Notifications : Teams, Email



### 3. Archive in Lakehouse### 3. Archiver dans Lakehouse



- Create a **Lakehouse**: `lh-sap-idoc`- Créez un **Lakehouse** : `lh-sap-idoc`

- Add Eventstream destination → Lakehouse- Ajoutez destination Eventstream → Lakehouse

- Table: `idoc_events`- Table : `idoc_events`

- Partitioning: By date (YYYY/MM/DD)- Partitioning : Par date (YYYY/MM/DD)

- Retention: Unlimited- Retention : Illimitée



### 4. Transform with Data Pipeline### 4. Transformer avec Data Pipeline



- Create a **Data Pipeline**- Créez un **Data Pipeline**

- Source: `kqldbsapidoc.idoc_raw`- Source : `kqldb-sap-idoc.idoc_raw`

- Transformations:- Transformations :

  - Extract business fields (order numbers, amounts)  - Extraction champs métier (N° commande, montants)

  - Enrichment (customers, products)  - Enrichissement (clients, produits)

  - Aggregations  - Agrégations

- Destination: Warehouse (Silver/Gold)- Destination : Warehouse (Silver/Gold)



------



## 📚 Complete Documentation## 📚 Documentation complète



| Document | Description || Document | Description |

|----------|-------------||----------|-------------|

| [`SETUP_GUIDE.md`](./SETUP_GUIDE.md) | ⭐ **START HERE** - Complete setup guide || [`fabric/eventstream/EVENTSTREAM_SETUP.md`](./fabric/eventstream/EVENTSTREAM_SETUP.md) | Guide détaillé configuration Eventstream |

| [`fabric/eventstream/EVENTSTREAM_SETUP.md`](./fabric/eventstream/EVENTSTREAM_SETUP.md) | Detailed Eventstream configuration || [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) | 50+ requêtes KQL (monitoring, analyse, alertes) |

| [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) | 50+ KQL queries (monitoring, analysis, alerts) || [`fabric/README.md`](./fabric/README.md) | Architecture et cas d'usage Fabric |

| [`fabric/README.md`](./fabric/README.md) | Architecture and Fabric use cases || [`simulator/README.md`](./simulator/README.md) | Documentation du simulateur IDoc |

| [`simulator/README.md`](./simulator/README.md) | IDoc simulator documentation || [`simulator/CLI_USAGE.md`](./simulator/CLI_USAGE.md) | Guide du CLI reader Event Hub |

| [`MCP_SERVER_GUIDE.md`](./MCP_SERVER_GUIDE.md) | MCP server configuration |

---

---

## ❓ Troubleshooting

## ❓ Troubleshooting

### Eventstream ne reçoit pas de données

### Eventstream Not Receiving Data

**Solutions** :

**Solutions**:1. Vérifiez que le simulateur envoie des messages : `python main.py`

1. Verify simulator is sending messages: `python main.py`2. Testez avec le CLI : `python read_eventhub.py --max 5`

2. Test with CLI: `python read_eventhub.py --max 5`3. Vérifiez le consumer group dans Fabric (doit être `fabric-consumer`)

3. Check consumer group in Fabric (must be `fabric-consumer`)4. Vérifiez les permissions RBAC : relancez `.\fabric\eventstream\setup-fabric-connection.ps1`

4. Verify RBAC permissions: re-run `.\fabric\eventstream\setup-fabric-connection.ps1`

### Erreur "Cannot authenticate"

### "Cannot authenticate" Error

**Solutions** :

**Solutions**:1. Vérifiez que vous êtes connecté à Azure : `az account show`

1. Verify Azure login: `az account show`2. Vérifiez les permissions : Eventstream utilise votre compte Entra ID

2. Check permissions: Eventstream uses your Entra ID account3. Le rôle **Azure Event Hubs Data Receiver** doit être assigné

3. Role **Azure Event Hubs Data Receiver** must be assigned

### Latence élevée

### High Latency

**Solutions** :

**Solutions**:1. Vérifiez la charge du namespace (métriques dans Azure Portal)

1. Check namespace load (metrics in Azure Portal)2. Augmentez les Throughput Units si nécessaire (actuellement : 2 TU)

2. Increase Throughput Units if needed (currently: 2 TU)3. Vérifiez le consumer lag dans les métriques Eventstream

3. Check consumer lag in Eventstream metrics

---

---

## 📞 Support

## 📞 Support

Pour toute question :

For questions:1. Consultez la [documentation Microsoft Fabric](https://learn.microsoft.com/fabric/)

1. Refer to [Microsoft Fabric documentation](https://learn.microsoft.com/fabric/)2. Testez avec le CLI : `python simulator/read_eventhub.py --max 1 --details`

2. Test with CLI: `python simulator/read_eventhub.py --max 1 --details`3. Vérifiez les logs dans l'Eventstream (onglet **Metrics**)

3. Check logs in Eventstream (**Metrics** tab)

---

---

## ✅ Checklist de validation

## ✅ Validation Checklist

- [ ] Consumer group `fabric-consumer` créé

- [ ] Consumer group `fabric-consumer` created- [ ] Permissions RBAC assignées

- [ ] RBAC permissions assigned- [ ] Eventstream créé dans Fabric

- [ ] Eventstream created in Fabric- [ ] Source Event Hub configurée

- [ ] Event Hub source configured- [ ] Data preview affiche des messages

- [ ] Data preview shows messages- [ ] KQL Database créée

- [ ] KQL Database created- [ ] Table `idoc_raw` reçoit des données

- [ ] Table `idoc_raw` receiving data- [ ] Requêtes KQL fonctionnent

- [ ] KQL queries working- [ ] Dashboard créé (optionnel)

- [ ] Dashboard created (optional)- [ ] Alertes configurées (optionnel)

- [ ] Alerts configured (optional)

**Bon travail ! 🎉**

**Great work! 🎉**
