# Guide de configuration manuelle de l'Eventstream

## 🎯 Objectif
Configurer l'Eventstream `SAPIdocIngest` dans le portail Fabric pour capturer le schéma JSON exact des sources et destinations.

---

## 📋 Informations nécessaires

### Azure Event Hub (Source)
- **Namespace** : `eh-idoc-flt8076.servicebus.windows.net`
- **Event Hub** : `idoc-events`
- **Consumer Group** : `fabric-consumer`
- **Resource Group** : `rg-idoc-fabric-dev`
- **Subscription** : Votre subscription Azure

### Fabric Resources (Destination)
- **Workspace** : `SAP-IDoc-Fabric`
  - ID : `ad53e547-23dc-46b0-ab5f-2acbaf0eec64`
- **Eventstream** : `SAPIdocIngest`
  - ID : `cb23a2a2-ad04-4b46-9616-d76e59a9a665`
- **Eventhouse** : `kqldbsapidoc_auto`
- **KQL Database** : `kqldbsapidoc`

---

## 🚀 Étapes de configuration

### ÉTAPE 1 : Ouvrir le portail Fabric

1. Ouvrir votre navigateur : https://app.fabric.microsoft.com
2. Se connecter avec votre compte Microsoft
3. Cliquer sur l'icône **Workspaces** dans le menu de gauche
4. Sélectionner **SAP-IDoc-Fabric**

### ÉTAPE 2 : Ouvrir l'Eventstream

1. Dans la liste des items, trouver **SAPIdocIngest** (type : Eventstream)
2. Cliquer dessus pour l'ouvrir
3. Vous devriez voir un canvas vide avec le message "Add source"

### ÉTAPE 3 : Activer le mode Edit

1. En haut à droite, cliquer sur **Edit** pour passer en mode édition
2. Le canvas devrait afficher les options d'ajout de source

### ÉTAPE 4 : Ajouter la source Azure Event Hub

#### 4.1 Lancer le wizard
1. Cliquer sur **Add source** dans le ribbon (ou sur la carte "Add source" dans le canvas)
2. Dans le menu déroulant, sélectionner **Azure Event Hubs**
3. Le wizard "Connect" s'ouvre

#### 4.2 Créer une nouvelle connection

1. Sur la page **Connect**, confirmer que **Basic** est sélectionné pour "Feature level"
2. Cliquer sur **New connection**

#### 4.3 Connection settings

Dans la section **Connection settings** :
- **Event Hubs namespace** : `eh-idoc-flt8076.servicebus.windows.net`
- **Event hub** : `idoc-events`

#### 4.4 Connection credentials

**OPTION A - Shared Access Key (Plus simple pour le test)** :

1. **Connection name** : `eh-sap-idoc-connection`
2. **Authentication kind** : Sélectionner **Shared Access Key**
3. **Shared Access Key Name** : Récupérer depuis Azure :
   ```powershell
   # Dans un terminal PowerShell
   az eventhubs eventhub authorization-rule keys list `
     --resource-group rg-idoc-fabric-dev `
     --namespace-name eh-idoc-flt8076 `
     --eventhub-name idoc-events `
     --name simulator-send `
     --query primaryKey -o tsv
   ```
4. **Shared Access Key** : Coller la clé récupérée
5. Cliquer sur **Connect** en bas de la page

**OPTION B - Entra ID (Recommandé pour production)** :

1. **Connection name** : `eh-sap-idoc-connection-entra`
2. **Authentication kind** : Sélectionner **Organizational account** ou **Managed Identity**
3. Se connecter avec votre compte Azure
4. Cliquer sur **Connect**

⚠️ **Note** : Si vous utilisez Entra ID, vous devrez peut-être accorder des permissions RBAC sur l'Event Hub.

#### 4.5 Stream details

1. **Consumer group** : `fabric-consumer`
2. **Data format** : Sélectionner **JSON**
3. **Source name** (optionnel) : Garder le nom par défaut ou renommer en `EventHub-SAP-IDocs`
4. Cliquer sur **Next**

#### 4.6 Review + connect

1. Vérifier tous les paramètres
2. Cliquer sur **Add**
3. La source Event Hub est ajoutée au canvas

### ÉTAPE 5 : Ajouter la destination KQL Database

#### 5.1 Lancer le wizard de destination

1. Dans le ribbon, cliquer sur **Add destination**
2. Sélectionner **Eventhouse**

#### 5.2 Configuration de base

1. **Ingestion mode** : Sélectionner **Direct ingestion**
2. **Destination name** : `KQL-SAP-Analysis`
3. **Workspace** : Sélectionner **SAP-IDoc-Fabric** (devrait être présélectionné)
4. **Eventhouse** : Sélectionner **kqldbsapidoc_auto**

⚠️ **Important** : NE PAS cocher "Activate ingestion after adding the data source" pour l'instant

5. Cliquer sur **Save**

#### 5.3 Connecter le flux

1. La destination apparaît sur le canvas
2. Si elle n'est pas automatiquement connectée, glisser une connexion depuis la sortie de `EventHub-SAP-IDocs` vers l'entrée de `KQL-SAP-Analysis`
3. Vérifier que le flux est bien connecté (ligne entre les deux nœuds)

### ÉTAPE 6 : Publier l'Eventstream

1. Dans le ribbon, cliquer sur **Publish**
2. Confirmer la publication
3. Attendre quelques secondes pour que l'Eventstream passe en mode **Live view**

### ÉTAPE 7 : Configurer la table KQL Database

#### 7.1 Ouvrir la configuration de destination

1. En mode **Live view**, dans le nœud destination `KQL-SAP-Analysis`, cliquer sur **Configure**
2. La fenêtre "Get data" de l'Eventhouse s'ouvre

#### 7.2 Créer la table

1. **Select a table** : Sélectionner **New table**
2. **Table name** : `idoc_raw`
3. **Data connection name** : Garder le nom proposé (ex: `es-sap-idoc-connection`)
4. Cliquer sur **Next**

⏱️ Attendre quelques instants pendant que Fabric récupère des données d'exemple depuis l'Event Hub.

#### 7.3 Inspecter et mapper les données

1. Sur l'écran **Inspect the data** :
   - **Format** : Confirmer **JSON**
   - Cliquer sur **Edit columns**

2. Dans **Edit columns** :
   - Fabric devrait détecter automatiquement la structure JSON
   - Si nécessaire, ajuster le mapping :
     - `idoc_type` : string
     - `message_type` : string
     - `sap_system` : string
     - `timestamp` : datetime
     - `control` : dynamic (objet JSON)
     - `data` : dynamic (objet JSON)
   - Cliquer sur **Apply**

3. Cliquer sur **Finish**

#### 7.4 Résumé

1. Sur l'écran **Summary**, vérifier :
   - ✅ Table `idoc_raw` créée
   - ✅ Connection établie entre Eventstream et Eventhouse
   - ✅ Schéma mappé
2. Cliquer sur **Close**

### ÉTAPE 8 : Vérification

#### 8.1 Vérifier le flux en Live view

1. Vous devriez voir :
   - Source `EventHub-SAP-IDocs` en vert
   - Destination `KQL-SAP-Analysis` en vert
   - Connexion entre les deux

#### 8.2 Tester avec des données

1. Ouvrir un terminal PowerShell
2. Lancer le simulateur :
   ```powershell
   cd c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\simulator
   python main.py
   ```
3. Le simulateur devrait envoyer 100 messages IDoc

#### 8.3 Vérifier dans Eventstream Data Preview

1. Dans l'Eventstream, cliquer sur le nœud **EventHub-SAP-IDocs**
2. En bas, onglet **Data preview**
3. Vous devriez voir les messages JSON qui arrivent en temps réel

#### 8.4 Vérifier dans KQL Database

1. Ouvrir le **KQL Queryset** ou **KQL Database** dans Fabric
2. Exécuter la requête :
   ```kql
   idoc_raw
   | take 10
   ```
3. Vous devriez voir les 10 premiers messages IDoc

---

## ✅ Configuration terminée !

Votre Eventstream est maintenant complètement configuré et opérationnel.

**Prochaine étape** : Exporter la configuration pour l'automatisation

```powershell
fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -o ".\fabric\eventstream\configured" -f
```

---

## 🔧 Dépannage

### Problème : "Unable to connect to Event Hub"
- Vérifier que le namespace et event hub existent dans Azure
- Vérifier les permissions si vous utilisez Entra ID
- Essayer avec Shared Access Key pour tester

### Problème : "No data preview available"
- Vérifier que l'Event Hub contient des messages (lancer le simulateur)
- Vérifier que le consumer group `fabric-consumer` existe
- Attendre quelques minutes après la publication

### Problème : "Table creation failed"
- Vérifier que le KQL Database `kqldbsapidoc` existe
- Vérifier les permissions sur l'Eventhouse
- Essayer de créer la table manuellement :
  ```kql
  .create table idoc_raw (
      idoc_type: string,
      message_type: string,
      sap_system: string,
      timestamp: datetime,
      control: dynamic,
      data: dynamic
  )
  ```

---

## 📊 Résultat attendu

Après cette configuration manuelle, vous aurez :
- ✅ Eventstream `SAPIdocIngest` configuré et publié
- ✅ Source Event Hub connectée avec authentification
- ✅ Destination KQL Database avec table `idoc_raw`
- ✅ Flux de données actif : Event Hub → Eventstream → KQL Database
- ✅ **Schéma JSON capturé** pour l'automatisation future

⏱️ **Temps total estimé** : 15-20 minutes
