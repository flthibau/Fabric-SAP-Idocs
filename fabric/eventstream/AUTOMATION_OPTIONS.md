# Options d'automatisation pour Eventstream Fabric

## 🎯 Objectif
Automatiser la configuration de l'Eventstream `SAPIdocIngest` avec :
- **Source** : Azure Event Hub (`eh-idoc-flt8076.servicebus.windows.net/idoc-events`)
- **Destination** : KQL Database (`kqldbsapidoc`)

---

## ✅ Option 1: API REST Fabric (Recommandée)

### Principe
Utiliser l'API `POST /workspaces/{workspaceId}/eventstreams/{eventstreamId}/updateDefinition` pour mettre à jour la définition JSON de l'Eventstream.

### Avantages
- ✅ **100% automatisable** via script
- ✅ Utilise l'API officielle Fabric REST
- ✅ Peut être intégré dans CI/CD pipelines
- ✅ Versionnable avec Git (définition en JSON)

### Limitations
- ⚠️ **Schéma JSON non documenté** : Fabric ne publie pas le schéma complet pour sources/destinations
- ⚠️ **Complexité** : Requiert de l'ingénierie inverse pour trouver le format exact
- ⚠️ **Risque de breaking changes** : Le schéma peut évoluer sans préavis

### Implémentation

#### 1. Exporter un Eventstream configuré manuellement
```powershell
# Configurer manuellement un Eventstream dans le portail
# Puis exporter pour analyser le format JSON

fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -o ".\fabric\eventstream" -f
```

#### 2. Analyser la structure JSON
```bash
# Fichiers exportés :
# - eventstream.json          # Sources, destinations, operators
# - eventstreamProperties.json # Retention, throughput
# - .platform                  # Metadata
```

#### 3. Créer la définition programmati quement
Le script `configure-eventstream.ps1` encode les 3 fichiers en Base64 et appelle l'API :

```powershell
POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/eventstreams/{eventstreamId}/updateDefinition

{
  "definition": {
    "parts": [
      {
        "path": "eventstream.json",
        "payload": "<base64>",
        "payloadType": "InlineBase64"
      },
      {
        "path": "eventstreamProperties.json",
        "payload": "<base64>",
        "payloadType": "InlineBase64"
      },
      {
        "path": ".platform",
        "payload": "<base64>",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
```

#### 4. Exécuter le script
```powershell
.\fabric\eventstream\configure-eventstream.ps1
```

### ⚠️ Prérequis
1. Configurer **manuellement** un Eventstream template avec Event Hub → KQL DB
2. L'exporter avec `fab export` pour capturer le schéma JSON exact
3. Adapter le script avec les valeurs correctes

### 📚 Documentation API
- [Update Eventstream Definition](https://learn.microsoft.com/en-us/rest/api/fabric/eventstream/items/update-eventstream-definition)
- [Get Eventstream Definition](https://learn.microsoft.com/en-us/rest/api/fabric/eventstream/items/get-eventstream-definition)

---

## ✅ Option 2: Fabric CLI Import/Export (Semi-automatique)

### Principe
1. Configurer un Eventstream **template** manuellement dans le portail
2. L'exporter avec `fab export`
3. Modifier les valeurs (workspace, database, etc.) dans les JSON
4. Réimporter avec `fab import`

### Avantages
- ✅ Utilise le CLI Fabric officiel
- ✅ Pas de manipulation d'API REST directe
- ✅ Format JSON validé par Fabric

### Limitations
- ⚠️ Nécessite un template configuré manuellement au préalable
- ⚠️ Modification manuelle des JSON exportés
- ⚠️ Moins scriptable que l'API REST

### Implémentation

#### 1. Créer un template manuellement
Dans le portail Fabric :
1. Créer un Eventstream "Template"
2. Ajouter source Event Hub avec Entra ID auth
3. Ajouter destination KQL Database
4. Publisher

#### 2. Exporter le template
```powershell
fab export "SAP-IDoc-Fabric.Workspace/Template.Eventstream" -o ".\templates" -f
```

#### 3. Modifier les JSON
Éditer `templates/Template.Eventstream/eventstream.json` :
- Remplacer les valeurs Event Hub namespace, hub name, consumer group
- Remplacer le nom de la KQL Database et table

#### 4. Importer dans un nouvel Eventstream
```powershell
# Méthode 1: Créer nouveau
fab mkdir "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream"

# Méthode 2: Importer la définition
fab import "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -i ".\templates\Template.Eventstream" -f
```

### 📚 Documentation
- [Fabric CLI Import](https://microsoft.github.io/fabric-cli/commands/fs/import/)
- [Fabric CLI Export](https://microsoft.github.io/fabric-cli/commands/fs/export/)

---

## ⚠️ Option 3: Configuration manuelle dans le portail

### Principe
Configuration complète via l'interface graphique du portail Fabric.

### Avantages
- ✅ Interface visuelle guidée
- ✅ Validation en temps réel
- ✅ Pas de risque d'erreur de syntaxe JSON
- ✅ Data preview disponible immédiatement

### Limitations
- ❌ **Pas automatisable**
- ❌ Pas de versioning
- ❌ Processus manuel répétitif pour plusieurs environnements

### Étapes

#### 1. Ouvrir l'Eventstream
1. Naviguer vers https://app.fabric.microsoft.com
2. Workspace : `SAP-IDoc-Fabric`
3. Ouvrir `SAPIdocIngest`

#### 2. Ajouter la source Event Hub
1. Mode Edit → `Add source` → `Azure Event Hubs`
2. **Connection settings** :
   - Event Hubs namespace : `eh-idoc-flt8076.servicebus.windows.net`
   - Event Hub : `idoc-events`
3. **Connection credentials** :
   - Connection name : `eh-sap-idoc-connection`
   - Authentication kind : `Shared Access Key` ou **Entra ID** (recommandé)
   - Consumer group : `fabric-consumer`
   - Data format : `JSON`
4. Cliquer `Connect`

#### 3. Ajouter la destination KQL Database
1. Mode Edit → `Add destination` → `Eventhouse`
2. **Ingestion mode** : `Direct ingestion`
3. **Configuration** :
   - Destination name : `KQL-SAP-Analysis`
   - Workspace : `SAP-IDoc-Fabric`
   - Eventhouse : `kqldbsapidoc_auto`
   - Database : `kqldbsapidoc`
4. Cliquer `Save`

#### 4. Connecter le flux
1. Glisser une connexion de `EventHub-SAP-IDocs` vers `KQL-SAP-Analysis`
2. Cliquer `Publish`

#### 5. Configurer la table KQL
1. En mode Live, cliquer `Configure` dans le nœud destination
2. **Get data** :
   - Table : `New table` → `idoc_raw`
   - Data connection name : `es-sap-idoc-connection`
3. **Inspect data** :
   - Format : `JSON`
   - Créer le schéma automatiquement ou manuellement :
     ```kql
     .create table idoc_raw (
         idoc_type: string,
         message_type: string,
         sap_system: string,
         timestamp: datetime,
         control: dynamic,
         data: dynamic,
         raw_payload: string
     )
     ```
4. Cliquer `Finish`

### ⏱️ Temps estimé
15-20 minutes

---

## 🎯 Recommandation

| Critère | Option 1 (API) | Option 2 (Import/Export) | Option 3 (Manuel) |
|---------|----------------|--------------------------|-------------------|
| **Automatisation** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **Facilité** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **CI/CD ready** | ✅ | ⚠️ | ❌ |
| **Documentation** | ⚠️ Limitée | ✅ Complète | ✅ Complète |
| **Maintenance** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |

### Pour un POC / Demo rapide
➡️ **Option 3 (Manuel)** : Configuration en 15 minutes, test immédiat

### Pour un déploiement en production
➡️ **Option 1 (API REST)** après avoir :
1. Configuré un template manuel pour capturer le schéma JSON
2. Extrait le format exact avec `fab export`
3. Testé le script `configure-eventstream.ps1`

### Compromis
➡️ **Option 2 (Import/Export)** : Automatisation partielle avec templates versionnés

---

## 🧪 Test de validation

Après configuration (quelle que soit l'option), tester le flux complet :

```powershell
# 1. Lancer le simulateur
cd simulator
python main.py

# 2. Vérifier dans Fabric
# - Eventstream Data Preview montre les messages
# - KQL Database contient les données

# 3. Requête KQL
idoc_raw
| where timestamp > ago(1h)
| summarize count() by idoc_type
| order by count_ desc
```

---

## 📝 Notes importantes

### Authentification Event Hub
- **Shared Access Key** : Fonctionne immédiatement, mais moins sécurisé
- **Entra ID** (recommandé) : Nécessite d'accorder des permissions :
  ```bash
  # Accorder "Azure Event Hubs Data Receiver" à l'identité Fabric
  az role assignment create \
    --role "Azure Event Hubs Data Receiver" \
    --assignee <fabric-managed-identity> \
    --scope /subscriptions/<sub>/resourceGroups/rg-idoc-fabric-dev/providers/Microsoft.EventHub/namespaces/eh-idoc-flt8076
  ```

### Schéma JSON Eventstream
Le format exact des `sources` et `destinations` dans `eventstream.json` n'est **pas officiellement documenté** par Microsoft. L'approche par ingénierie inverse (export manuel) est donc nécessaire.

### Ressources créées
Les 3 options configurent les mêmes ressources :
- ✅ Source : Azure Event Hub connection
- ✅ Destination : KQL Database avec table `idoc_raw`
- ✅ Flux : EventHub → KQL DB (direct ingestion)
- ✅ Mapping : Schéma JSON → colonnes KQL

---

## 🔗 Liens utiles

- [Fabric CLI Documentation](https://microsoft.github.io/fabric-cli/)
- [Eventstream REST API](https://learn.microsoft.com/en-us/rest/api/fabric/eventstream/items)
- [Add Event Hub Source](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-source-azure-event-hubs)
- [Add KQL Database Destination](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-kql-database)
