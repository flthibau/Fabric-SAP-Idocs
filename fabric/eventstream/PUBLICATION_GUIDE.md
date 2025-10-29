# Publication et Configuration Eventstream - Guide Rapide

## 📋 Contexte

**Eventstream créé:** SAPIdocIngestAuto  
**ID:** 5f8e31b6-4ec5-4511-a2f1-d846c0b2250f  
**Workspace:** SAP-IDoc-Fabric  
**Status:** Créé avec sources/destinations, pas encore publié

## 🎯 Objectif

Publier l'Eventstream et configurer la table KQL pour recevoir les données.

## 📝 Étapes de Publication

### 1. Ouvrir l'Eventstream

1. Naviguer vers https://app.fabric.microsoft.com
2. Workspace: **SAP-IDoc-Fabric**
3. Cliquer sur: **SAPIdocIngestAuto** (type: Eventstream)

### 2. Vérifier la Configuration

En mode **Edit**, vous devriez voir :
- **Source:** AzureEventHub
  - Connection: eh-idoc-flt8076.servicebus.windows.net
  - Event Hub: idoc-events
  - Consumer Group: fabric-consumer
  
- **Stream:** SAPIdocIngestAuto-stream

- **Destination:** Eventhouse
  - Eventhouse: kqldbsapidoc_auto
  - Database: kqldbsapidoc
  - Table: (à configurer)

### 3. Publier l'Eventstream

1. En haut à droite, cliquer **Publish**
2. Confirmer la publication
3. Attendre la publication (quelques secondes)
4. Le mode passe automatiquement de **Edit** à **Live**

### 4. Configurer la Destination KQL

#### Option A: Création Automatique (Recommandée pour test)

1. En mode **Live**, cliquer sur la destination **Eventhouse**
2. Cliquer **Configure**
3. Dans "Table name", entrer: `idoc_raw`
4. Sélectionner **Create new table**
5. Dans "Data format", sélectionner: **JSON**
6. Cliquer **Save**

✅ Fabric créera automatiquement la table avec le schéma détecté.

#### Option B: Table Pré-créée (Pour schéma personnalisé)

**Si vous voulez un schéma spécifique:**

1. Ouvrir KQL Database **kqldbsapidoc** dans un nouvel onglet
2. Exécuter le script KQL: `fabric/warehouse/schema/create-idoc-raw-table.kql`
3. Revenir à l'Eventstream
4. Configurer destination:
   - Table name: `idoc_raw`
   - Sélectionner **Use existing table**
   - Mapping: `idoc_raw_mapping`
5. Cliquer **Save**

### 5. Vérifier le Status

En mode **Live**, vérifier :
- **Source:** Statut vert (Connected)
- **Stream:** Flux actif
- **Destination:** Statut vert (Connected)

## 🧪 Test de Validation

### Envoyer des messages de test

```powershell
cd c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\simulator
python main.py --count 5
```

### Vérifier l'ingestion dans KQL

Ouvrir KQL Database et exécuter :

```kql
// Compter les messages reçus
idoc_raw
| count

// Voir les derniers messages
idoc_raw
| top 10 by EventTimestamp desc

// Vérifier par type IDoc
idoc_raw
| summarize Count=count() by IDocType
| order by Count desc
```

## ⚠️ Troubleshooting

### L'Eventstream ne publie pas

**Symptôme:** Erreur lors de la publication  
**Solution:** Vérifier que la Data Connection Event Hub est valide

```powershell
# Tester la connexion Event Hub
az eventhubs eventhub show --name idoc-events --namespace-name eh-idoc-flt8076 --resource-group rg-idoc-fabric-dev
```

### La destination n'apparaît pas

**Symptôme:** Destination Eventhouse absente après publication  
**Solution:** Ré-exporter et vérifier le JSON

```powershell
fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngestAuto.Eventstream" -o "validation" -f
cat validation/SAPIdocIngestAuto.Eventstream/eventstream.json
```

### Pas de données dans la table KQL

**Symptôme:** `idoc_raw | count` retourne 0  
**Solutions:**

1. Vérifier que l'Eventstream est publié et en mode Live
2. Vérifier le statut des sources/destinations (doivent être verts)
3. Vérifier que le simulateur envoie des messages :
   ```powershell
   cd simulator
   python main.py --count 1
   # Vérifier la sortie : "Successfully sent 1 messages"
   ```
4. Vérifier les erreurs dans Event Hub :
   ```powershell
   az eventhubs eventhub show --name idoc-events --namespace-name eh-idoc-flt8076 --resource-group rg-idoc-fabric-dev --query "status"
   ```

### Format JSON incorrect

**Symptôme:** Messages dans Event Hub mais pas dans KQL  
**Solution:** Vérifier le mapping JSON

```kql
// Voir les données brutes si la table simple est utilisée
idoc_raw
| take 1
| project data

// Créer un nouveau mapping si nécessaire
.show table idoc_raw ingestion json mappings
```

## 📊 Métriques à Surveiller

Après publication et configuration :

### Dans l'Eventstream (mode Live)
- **Input events/sec:** Devrait augmenter quand le simulateur envoie des messages
- **Output events/sec:** Devrait correspondre à Input events/sec
- **Errors:** Devrait rester à 0

### Dans KQL Database
```kql
// Taux d'ingestion par minute
idoc_raw
| summarize Count=count() by bin(EventTimestamp, 1m)
| order by EventTimestamp desc

// Latence d'ingestion (si ingestion_time() disponible)
idoc_raw
| extend IngestionLatency = ingestion_time() - EventTimestamp
| summarize avg(IngestionLatency), max(IngestionLatency)
```

## ✅ Checklist de Validation

Après publication et configuration :

- [ ] Eventstream publié (mode Live)
- [ ] Source Event Hub : statut Connected (vert)
- [ ] Destination Eventhouse : statut Connected (vert)
- [ ] Table `idoc_raw` existe dans KQL Database
- [ ] Simulateur envoie des messages sans erreur
- [ ] Messages visibles dans `idoc_raw` table
- [ ] Pas d'erreurs dans les métriques Eventstream

## 🔗 Liens Utiles

- **Fabric Portal:** https://app.fabric.microsoft.com
- **Workspace:** SAP-IDoc-Fabric
- **Eventstream:** SAPIdocIngestAuto
- **KQL Database:** kqldbsapidoc
- **Event Hub Portal:** https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/rg-idoc-fabric-dev/providers/Microsoft.EventHub/namespaces/eh-idoc-flt8076

## 📞 Next Steps

Après validation réussie :
1. ✅ Flux opérationnel Event Hub → Eventstream → KQL Database
2. Créer des vues KQL pour analyses métier
3. Connecter Power BI pour visualisations
4. Documenter le workflow complet
5. Créer des alertes sur erreurs/latence

---

**Date:** 2025-10-23  
**Status:** En cours de publication  
**Prochaine étape:** Tester le flux end-to-end
