# Guide de test pour automatisation Eventstream

## 🎯 Objectif
Déterminer le meilleur moyen d'automatiser la configuration de l'Eventstream.

## 📋 Plan de test

### Étape 1: Configuration manuelle (baseline)
⏱️ **Temps estimé** : 15 minutes

1. Ouvrir https://app.fabric.microsoft.com
2. Workspace : `SAP-IDoc-Fabric`
3. Ouvrir `SAPIdocIngest`
4. Mode Edit
5. Add source → Azure Event Hubs
   - Namespace : `eh-idoc-flt8076.servicebus.windows.net`
   - Event Hub : `idoc-events`
   - Consumer group : `fabric-consumer`
   - Auth : Entra ID (si possible) ou Shared Access Key
   - Data format : JSON
6. Add destination → Eventhouse
   - Mode : Direct ingestion
   - Eventhouse : `kqldbsapidoc_auto`
   - Database : `kqldbsapidoc`
   - Table : `idoc_raw` (nouvelle)
7. Publish
8. Configure destination → Créer table avec schéma JSON

### Étape 2: Export pour analyse
```powershell
fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -o ".\fabric\eventstream\configured" -f
```

### Étape 3: Analyse du JSON
Comparer les fichiers :
- `configured/SAPIdocIngest.Eventstream/eventstream.json` (avec sources/destinations)
- `SAPIdocIngest.Eventstream/eventstream.json` (vide, exporté avant)

Objectif : **Capturer le format exact des objets sources et destinations**

### Étape 4: Test du script d'automatisation
Adapter `configure-eventstream.ps1` avec les vrais schémas JSON, puis :
```powershell
.\fabric\eventstream\configure-eventstream.ps1
```

### Étape 5: Validation
1. Lancer le simulateur :
   ```powershell
   cd simulator
   python main.py
   ```

2. Vérifier dans Fabric :
   - Eventstream Data Preview montre les messages
   - KQL Database contient les données

3. Requête KQL :
   ```kql
   idoc_raw
   | where timestamp > ago(1h)
   | summarize count() by idoc_type
   ```

## 📊 Résultats attendus

| Méthode | Temps | Automatisable | Succès |
|---------|-------|---------------|--------|
| Manuelle | 15 min | ❌ | ✅ |
| API REST | 5 min | ✅ | 🧪 À tester |
| Import/Export | 10 min | ⚠️ Partiel | 🧪 À tester |

## 🎯 Décision finale
À prendre après l'étape 3 (analyse du JSON exporté)

## 📝 Notes
- IDs à récupérer :
  - Workspace : `ad53e547-23dc-46b0-ab5f-2acbaf0eec64`
  - Eventstream : `cb23a2a2-ad04-4b46-9616-d76e59a9a665`
  - Event Hub namespace : `eh-idoc-flt8076.servicebus.windows.net`
  - Event Hub : `idoc-events`
  - Consumer group : `fabric-consumer`
  - KQL Database : `kqldbsapidoc`
