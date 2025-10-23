# Configuration Eventstream dans Microsoft Fabric

## Vue d'ensemble

Ce guide vous aide à configurer un Eventstream dans Microsoft Fabric Real-Time Intelligence pour capturer les messages IDoc depuis Azure Event Hub.

## Prérequis

- ✅ Event Hub déployé et opérationnel (`eh-idoc-flt8076/idoc-events`)
- ✅ Messages IDoc envoyés avec succès (100 messages testés)
- ✅ Workspace Microsoft Fabric avec capacité activée
- ✅ Permissions : Contributor sur Fabric workspace + Event Hubs Data Receiver sur Event Hub

## Étape 1 : Créer l'Eventstream

### 1.1 Dans Microsoft Fabric

1. Ouvrez votre workspace Fabric
2. Cliquez sur **+ New** → **Real-Time Intelligence** → **Eventstream**
3. Nommez l'Eventstream : `evs-sap-idoc-ingest`
4. Cliquez sur **Create**

### 1.2 Configuration de la source Event Hub

1. Dans le canvas Eventstream, cliquez sur **Add source**
2. Sélectionnez **Azure Event Hubs**
3. Configurez la connexion :

   **Paramètres de connexion :**
   ```
   Connection name: conn-eventhub-idoc
   Authentication kind: Organizational account (Entra ID)
   
   Event Hub namespace: eh-idoc-flt8076.servicebus.windows.net
   Event Hub: idoc-events
   Consumer group: $Default (ou créez fabric-consumer)
   ```

4. Testez la connexion
5. Cliquez sur **Next**

### 1.3 Configuration du format de données

1. **Data format** : JSON
2. **Schema preview** : Laissez Fabric détecter automatiquement le schema
3. Vérifiez que les champs suivants sont détectés :
   - `idoc_type` (string)
   - `message_type` (string)
   - `sap_system` (string)
   - `timestamp` (datetime/string)
   - `control` (object)
   - `data` (object)

4. Cliquez sur **Create source**

## Étape 2 : Créer le Consumer Group (Recommandé)

Pour éviter les conflits avec le CLI reader, créez un consumer group dédié :

```bash
az eventhubs eventhub consumer-group create \
  --resource-group rg-idoc-fabric-dev \
  --namespace-name eh-idoc-flt8076 \
  --eventhub-name idoc-events \
  --name fabric-consumer
```

Puis mettez à jour la source Eventstream pour utiliser `fabric-consumer`.

## Étape 3 : Assigner les permissions RBAC

Fabric nécessite le rôle Data Receiver sur Event Hub :

### Option A : Via le portail Azure

1. Allez dans Azure Portal → Event Hub `idoc-events`
2. **Access Control (IAM)** → **Add role assignment**
3. Rôle : **Azure Event Hubs Data Receiver**
4. Assignez à : Votre identité Fabric ou Managed Identity du workspace

### Option B : Via Azure CLI

```bash
# Récupérer l'Object ID de votre compte
az ad signed-in-user show --query id -o tsv

# Assigner le rôle
az role assignment create \
  --assignee <object-id> \
  --role "Azure Event Hubs Data Receiver" \
  --scope "/subscriptions/f79d4407-99c6-4d64-88fc-848fb05d5476/resourceGroups/rg-idoc-fabric-dev/providers/Microsoft.EventHub/namespaces/eh-idoc-flt8076/eventhubs/idoc-events"
```

## Étape 4 : Ajouter une destination

### Option 1 : KQL Database (Recommandé pour l'analyse)

1. Dans le canvas Eventstream, cliquez sur la sortie
2. **Add destination** → **KQL Database**
3. Créez ou sélectionnez une base de données : `kqldb-sap-idoc`
4. Créez une table : `idoc_raw`
5. Mapping de colonnes :
   ```
   - idoc_type → string
   - message_type → string
   - sap_system → string
   - timestamp → datetime
   - control → dynamic
   - data → dynamic
   ```

### Option 2 : Lakehouse (Pour le stockage long terme)

1. **Add destination** → **Lakehouse**
2. Sélectionnez ou créez un Lakehouse : `lh-sap-idoc`
3. Table : `idoc_events`
4. Write mode : **Append**

### Option 3 : Reflex (Pour les alertes temps réel)

1. **Add destination** → **Reflex**
2. Créez des triggers basés sur :
   - Erreurs dans les IDocs (status != "03")
   - Volume de messages anormal
   - Messages avec exceptions

## Étape 5 : Configurer les transformations (Optionnel)

Avant d'envoyer vers la destination, ajoutez des transformations :

### 5.1 Ajouter des colonnes calculées

1. Cliquez sur **Transform** dans le canvas
2. Ajoutez des colonnes :
   ```sql
   -- Extraire le type de document
   doc_type = CASE 
     WHEN idoc_type = 'ORDERS05' THEN 'Purchase Order'
     WHEN idoc_type = 'WHSCON01' THEN 'Warehouse Confirmation'
     WHEN idoc_type = 'DESADV01' THEN 'Delivery Note'
     WHEN idoc_type = 'SHPMNT05' THEN 'Shipment'
     WHEN idoc_type = 'INVOIC02' THEN 'Invoice'
     ELSE 'Unknown'
   END
   
   -- Extraire le numéro de document du control
   document_number = control.docnum
   
   -- Date de création
   created_date = control.credat
   
   -- Statut du document
   document_status = control.status
   ```

### 5.2 Filtrer les messages (si nécessaire)

```sql
-- Ne garder que les messages avec statut valide
WHERE control.status IN ('03', '30', '31')

-- Exclure les messages de test
WHERE sap_system != 'TESTENV'
```

## Étape 6 : Activer et tester

1. Cliquez sur **Publish** pour activer l'Eventstream
2. Lancez le simulateur pour envoyer des messages :
   ```bash
   cd simulator
   python main.py
   ```

3. Vérifiez dans Fabric :
   - **Data preview** dans Eventstream (vue temps réel)
   - Requête KQL Database :
     ```kql
     idoc_raw
     | take 10
     | order by timestamp desc
     ```

## Étape 7 : Monitoring et métriques

### Dans l'Eventstream

- **Metrics** : Messages reçus, erreurs, latence
- **Logs** : Erreurs de connexion, parsing

### Requêtes KQL utiles

```kql
// Volume par type d'IDoc (dernière heure)
idoc_raw
| where timestamp > ago(1h)
| summarize count() by message_type
| render columnchart

// Latence moyenne
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize avg(latency_seconds) by bin(timestamp, 5m)
| render timechart

// Erreurs (statut != 03)
idoc_raw
| where control.status != "03"
| project timestamp, idoc_type, message_type, status=control.status, docnum=control.docnum
| order by timestamp desc
```

## Architecture finale

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Simulateur     │─────▶│  Event Hub       │─────▶│  Eventstream    │
│  Python         │      │  idoc-events     │      │  (Fabric RTI)   │
└─────────────────┘      └──────────────────┘      └────────┬────────┘
                                                             │
                              ┌──────────────────────────────┴─────────────┐
                              │                                            │
                              ▼                                            ▼
                     ┌─────────────────┐                        ┌──────────────────┐
                     │  KQL Database   │                        │   Lakehouse      │
                     │  (Analyse RTI)  │                        │   (Stockage LT)  │
                     └─────────────────┘                        └──────────────────┘
```

## Troubleshooting

### Erreur : "Cannot connect to Event Hub"
- Vérifiez les permissions RBAC (Data Receiver)
- Vérifiez que le namespace est correct
- Testez avec le CLI reader : `python read_eventhub.py --max 1`

### Pas de données dans l'Eventstream
- Vérifiez que le simulateur envoie des messages
- Vérifiez le consumer group (utilisez un différent du CLI)
- Regardez les métriques dans Event Hub (portail Azure)

### Erreurs de parsing JSON
- Vérifiez le format de données dans la source (doit être JSON)
- Testez un message avec `python read_eventhub.py --max 1 --details`

## Prochaines étapes

1. ✅ Configurer l'Eventstream (ce guide)
2. 📊 Créer des vues et agrégations dans KQL Database
3. 📈 Créer des tableaux de bord Power BI temps réel
4. 🔔 Configurer des alertes avec Reflex
5. 🗄️ Archiver les données dans Lakehouse
6. 🔄 Implémenter la transformation des données (si nécessaire)
