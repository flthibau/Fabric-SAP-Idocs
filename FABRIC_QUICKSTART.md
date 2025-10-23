# Démarrage Rapide - Configuration Fabric Eventstream

## ✅ Préparation terminée

Le consumer group `fabric-consumer` a été créé avec succès !

```
Event Hub Namespace: eh-idoc-flt8076.servicebus.windows.net
Event Hub: idoc-events
Consumer Group: fabric-consumer
Partitions: 4
Retention: 168 heures (7 jours)
Status: Active
```

---

## 🚀 Étapes suivantes dans Microsoft Fabric

### Étape 1 : Accéder à votre workspace Fabric

1. Ouvrez [Microsoft Fabric](https://app.fabric.microsoft.com)
2. Sélectionnez ou créez un workspace
3. Assurez-vous d'avoir une **capacité F64** (ou supérieure) assignée

### Étape 2 : Créer l'Eventstream

1. Dans votre workspace, cliquez sur **+ New**
2. Sélectionnez **Real-Time Intelligence** → **Eventstream**
3. Nom : `evs-sap-idoc-ingest`
4. Cliquez sur **Create**

### Étape 3 : Configurer la source Event Hub

Dans le canvas de l'Eventstream :

1. Cliquez sur **Add source**
2. Sélectionnez **Azure Event Hubs**
3. Configurez avec ces paramètres :

```yaml
Connection name: conn-eventhub-idoc
Authentication kind: Organizational account (Entra ID)

Event Hub namespace: eh-idoc-flt8076.servicebus.windows.net
Event Hub: idoc-events
Consumer group: fabric-consumer

Data format: JSON
```

4. Testez la connexion
5. Cliquez sur **Create source**

### Étape 4 : Vérifier la réception des données

1. Dans l'Eventstream, cliquez sur **Data preview**
2. Vous devriez voir les messages IDoc apparaître en temps réel
3. Vérifiez la structure JSON :
   - `idoc_type`
   - `message_type`
   - `sap_system`
   - `timestamp`
   - `control` (object)
   - `data` (object)

### Étape 5 : Créer une KQL Database (destination)

1. Dans le canvas, cliquez sur **Add destination**
2. Sélectionnez **KQL Database**
3. Créez ou sélectionnez une base : `kqldb-sap-idoc`
4. Table : `idoc_raw`
5. Laissez Fabric détecter le schéma automatiquement
6. Mapping suggéré :

```
idoc_type     → string
message_type  → string
sap_system    → string
timestamp     → datetime
control       → dynamic
data          → dynamic
```

7. Activez l'ingestion

### Étape 6 : Tester les données dans KQL Database

1. Ouvrez la KQL Database `kqldb-sap-idoc`
2. Créez un **KQL Queryset**
3. Testez cette requête :

```kql
idoc_raw
| take 10
| order by timestamp desc
| project timestamp, idoc_type, message_type, sap_system
```

Vous devriez voir les messages IDoc !

---

## 📊 Requêtes KQL essentielles

### Volume par type d'IDoc

```kql
idoc_raw
| summarize count() by message_type
| render piechart
```

### Messages par heure (dernières 24h)

```kql
idoc_raw
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart
```

### Latence d'ingestion

```kql
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize 
    Latence_Moyenne = avg(latency_seconds),
    Latence_P95 = percentile(latency_seconds, 95)
```

### Messages avec erreurs

```kql
idoc_raw
| extend Statut = tostring(control.status)
| where Statut != "03"
| project timestamp, message_type, docnum=control.docnum, Statut
| order by timestamp desc
```

👉 **Pour plus de requêtes** : consultez [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) (50+ exemples)

---

## 🧪 Tester avec le simulateur

### Envoyer des messages de test

```powershell
cd simulator
python main.py
```

Le simulateur enverra :
- **10 messages/minute**
- Types : ORDERS (25%), WHSCON (30%), DESADV (20%), SHPMNT (15%), INVOICE (10%)
- Durée : 1 heure (configurable dans `.env`)

### Vérifier la réception (sans Fabric)

```powershell
python read_eventhub.py --max 5
```

**Note** : Utilisez le consumer group par défaut (`$Default`) pour le CLI, et `fabric-consumer` pour Fabric.

---

## 🎯 Prochaines étapes recommandées

### 1. Créer un Dashboard Power BI

- Connectez Power BI Desktop à `kqldb-sap-idoc`
- Mode : **DirectQuery** (pour temps réel)
- Créez des visuels : volume, latence, erreurs
- Publiez sur Fabric avec auto-refresh (30s)

### 2. Configurer des alertes avec Data Activator

- Créez un **Reflex**
- Conditions d'alerte :
  - Volume anormal (`> 2x moyenne`)
  - Messages en erreur (`status != "03"`)
  - Latence élevée (`> 5 minutes`)
- Notifications : Teams, Email

### 3. Archiver dans Lakehouse

- Créez un **Lakehouse** : `lh-sap-idoc`
- Ajoutez destination Eventstream → Lakehouse
- Table : `idoc_events`
- Partitioning : Par date (YYYY/MM/DD)
- Retention : Illimitée

### 4. Transformer avec Data Pipeline

- Créez un **Data Pipeline**
- Source : `kqldb-sap-idoc.idoc_raw`
- Transformations :
  - Extraction champs métier (N° commande, montants)
  - Enrichissement (clients, produits)
  - Agrégations
- Destination : Warehouse (Silver/Gold)

---

## 📚 Documentation complète

| Document | Description |
|----------|-------------|
| [`fabric/eventstream/EVENTSTREAM_SETUP.md`](./fabric/eventstream/EVENTSTREAM_SETUP.md) | Guide détaillé configuration Eventstream |
| [`fabric/README_KQL_QUERIES.md`](./fabric/README_KQL_QUERIES.md) | 50+ requêtes KQL (monitoring, analyse, alertes) |
| [`fabric/README.md`](./fabric/README.md) | Architecture et cas d'usage Fabric |
| [`simulator/README.md`](./simulator/README.md) | Documentation du simulateur IDoc |
| [`simulator/CLI_USAGE.md`](./simulator/CLI_USAGE.md) | Guide du CLI reader Event Hub |

---

## ❓ Troubleshooting

### Eventstream ne reçoit pas de données

**Solutions** :
1. Vérifiez que le simulateur envoie des messages : `python main.py`
2. Testez avec le CLI : `python read_eventhub.py --max 5`
3. Vérifiez le consumer group dans Fabric (doit être `fabric-consumer`)
4. Vérifiez les permissions RBAC : relancez `.\fabric\eventstream\setup-fabric-connection.ps1`

### Erreur "Cannot authenticate"

**Solutions** :
1. Vérifiez que vous êtes connecté à Azure : `az account show`
2. Vérifiez les permissions : Eventstream utilise votre compte Entra ID
3. Le rôle **Azure Event Hubs Data Receiver** doit être assigné

### Latence élevée

**Solutions** :
1. Vérifiez la charge du namespace (métriques dans Azure Portal)
2. Augmentez les Throughput Units si nécessaire (actuellement : 2 TU)
3. Vérifiez le consumer lag dans les métriques Eventstream

---

## 📞 Support

Pour toute question :
1. Consultez la [documentation Microsoft Fabric](https://learn.microsoft.com/fabric/)
2. Testez avec le CLI : `python simulator/read_eventhub.py --max 1 --details`
3. Vérifiez les logs dans l'Eventstream (onglet **Metrics**)

---

## ✅ Checklist de validation

- [ ] Consumer group `fabric-consumer` créé
- [ ] Permissions RBAC assignées
- [ ] Eventstream créé dans Fabric
- [ ] Source Event Hub configurée
- [ ] Data preview affiche des messages
- [ ] KQL Database créée
- [ ] Table `idoc_raw` reçoit des données
- [ ] Requêtes KQL fonctionnent
- [ ] Dashboard créé (optionnel)
- [ ] Alertes configurées (optionnel)

**Bon travail ! 🎉**
