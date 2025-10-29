# Configuration Eventstream - Script CLI Fabric

## ✅ Étapes complétées

### 1. Installation du CLI Fabric
```powershell
python -m pip install ms-fabric-cli
fab --version  # 0.1.10
```

### 2. Authentification
```powershell
fab auth login
# Sélection: Interactive with a web browser
```

### 3. Création du Workspace
```powershell
# Liste des capacités disponibles
fab api capacities

# Création du workspace
fab mkdir "SAP-IDoc-Fabric.Workspace" -P "capacityName=small4newfeatures,description=Workspace for SAP IDoc ingestion and analysis"
```

**Résultat** : ✅ Workspace `SAP-IDoc-Fabric` créé avec succès

### 4. Création de l'Eventstream
```powershell
# Création de l'Eventstream
fab mkdir "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -P "description=Eventstream for SAP IDoc ingestion from Azure Event Hub"
```

**Résultat** : ✅ Eventstream `SAPIdocIngest` créé avec succès

### 5. Vérification
```powershell
fab ls "SAP-IDoc-Fabric.Workspace"
# Output: SAPIdocIngest.Eventstream
```

---

## 🚧 Configuration manuelle requise

Le CLI Fabric ne supporte pas encore la configuration complète des sources et destinations via la ligne de commande.

### Prochaines étapes dans le portail Fabric

1. **Ouvrir Fabric**
   ```
   https://app.fabric.microsoft.com
   ```

2. **Naviguer vers le workspace**
   - Workspace: `SAP-IDoc-Fabric`
   - Item: `SAPIdocIngest` (Eventstream)

3. **Configurer la source Event Hub**
   
   a. Cliquer sur **"Add source"** dans le canvas
   
   b. Sélectionner **"Azure Event Hubs"**
   
   c. Configurer la connexion:
   ```
   Connection name: conn-eventhub-idoc
   Authentication: Organizational account (Entra ID)
   
   Event Hub namespace: eh-idoc-flt8076.servicebus.windows.net
   Event Hub: idoc-events
   Consumer group: fabric-consumer
   
   Data format: JSON
   ```
   
   d. Tester la connexion
   
   e. Cliquer sur **"Create source"**

4. **Créer la KQL Database (destination)**
   
   a. Dans le canvas, cliquer sur **"Add destination"**
   
   b. Sélectionner **"KQL Database"**
   
   c. Créer ou sélectionner: `kqldb-sap-idoc`
   
   d. Table: `idoc_raw`
   
   e. Mapping de colonnes:
   ```
   idoc_type     → string
   message_type  → string
   sap_system    → string
   timestamp     → datetime
   control       → dynamic
   data          → dynamic
   ```
   
   f. Activer l'ingestion

5. **Publier l'Eventstream**
   - Cliquer sur **"Publish"**

---

## 🧪 Tester l'ingestion

Une fois l'Eventstream configuré et publié:

1. **Envoyer des messages de test**
   ```powershell
   cd simulator
   python main.py
   ```

2. **Vérifier dans Fabric**
   - Ouvrir l'Eventstream
   - Onglet **"Data preview"** → doit afficher les messages

3. **Requêter la KQL Database**
   ```kql
   idoc_raw
   | take 10
   | order by timestamp desc
   ```

---

## 📊 Commandes CLI Fabric utiles

### Lister les items du workspace
```powershell
fab ls "SAP-IDoc-Fabric.Workspace"
```

### Créer une KQL Database (via CLI)
```powershell
fab mkdir "SAP-IDoc-Fabric.Workspace/kqldb_sap_idoc.KQLDatabase" -P "description=KQL Database for SAP IDoc analysis"
```

### Créer un Lakehouse
```powershell
fab mkdir "SAP-IDoc-Fabric.Workspace/lh_sap_idoc.Lakehouse" -P "description=Lakehouse for long-term SAP IDoc storage"
```

### Voir les détails d'un item
```powershell
fab desc "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream"
```

### Supprimer un item
```powershell
fab rm "SAP-IDoc-Fabric.Workspace/ItemName.Type"
```

---

## 📚 Resources

- [Fabric CLI Documentation](https://microsoft.github.io/fabric-cli/)
- [Eventstream Setup Guide](./EVENTSTREAM_SETUP.md)
- [KQL Queries Collection](../README_KQL_QUERIES.md)
- [Quick Start Guide](../../FABRIC_QUICKSTART.md)

---

## ✅ Statut actuel

| Étape | Statut | Notes |
|-------|--------|-------|
| CLI Fabric installé | ✅ | Version 0.1.10 |
| Authentification | ✅ | Login interactif OK |
| Workspace créé | ✅ | SAP-IDoc-Fabric |
| Eventstream créé | ✅ | SAPIdocIngest |
| Source Event Hub configurée | ⏳ | Manuelle dans portail |
| Destination KQL DB configurée | ⏳ | Manuelle dans portail |
| Tests d'ingestion | ⏳ | Après config source |

---

**Date de création** : 2025-10-23  
**Dernière mise à jour** : 2025-10-23
