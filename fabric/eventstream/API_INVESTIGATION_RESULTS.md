# Analyse : Automatisation Eventstream via API REST

## 🔍 Résumé de l'investigation

**Date** : 23 octobre 2025  
**Objectif** : Automatiser la configuration des sources et destinations Eventstream via l'API Fabric REST

## ❌ Conclusion : IMPOSSIBLE avec l'API actuelle

### Découvertes clés

1. **La définition JSON exportée ne contient PAS les sources/destinations configurées**
   - Export avant configuration : `sources: [], destinations: []`
   - Export après configuration manuelle : `sources: [], destinations: []` (identique!)
   - L'API `getDefinition` retourne le même JSON vide

2. **Les configurations UI ne sont pas stockées dans la définition JSON**
   - Les sources (Event Hub) et destinations (KQL Database) configurées via le portail
   - Ne sont **pas reflétées** dans les fichiers JSON exportables
   - Probablement stockées dans une base de données interne Fabric

3. **Aucune API REST publique disponible**
   - L'API `updateDefinition` ne permet que de modifier les propriétés de base
   - Pas d'endpoint documenté pour gérer sources/destinations
   - La documentation officielle ne couvre pas ces opérations

## 📊 Tests effectués

### Test 1 : Export avant configuration
```bash
fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream"
```

**Résultat** :
```json
{
  "sources": [],
  "destinations": [],
  "streams": [],
  "operators": [],
  "compatibilityLevel": "1.0"
}
```

### Test 2 : Configuration manuelle dans le portail
- ✅ Source Event Hub ajoutée et connectée
- ✅ Destination KQL Database configurée
- ✅ Flux publié et actif

### Test 3 : Export après configuration
```bash
fab export "SAP-IDoc-Fabric.Workspace/SAPIdocIngest.Eventstream" -o configured
```

**Résultat** : **IDENTIQUE au Test 1** ❌
```json
{
  "sources": [],
  "destinations": [],
  "streams": [],
  "operators": [],
  "compatibilityLevel": "1.0"
}
```

### Test 4 : API getDefinition
```bash
fab api "workspaces/{id}/eventstreams/{id}/getDefinition" -X post
```

**Résultat** : Retourne le même JSON vide encodé en Base64

## 🚫 Limitations identifiées

### API Fabric Eventstream

L'API officielle [Items - Eventstream](https://learn.microsoft.com/en-us/rest/api/fabric/eventstream/items) fournit uniquement :

| Opération | Fonctionnalité | Gère sources/destinations ? |
|-----------|----------------|----------------------------|
| Create Eventstream | Créer un Eventstream vide | ❌ Non |
| Delete Eventstream | Supprimer un Eventstream | ❌ N/A |
| Get Eventstream | Récupérer les propriétés | ❌ Non |
| Get Eventstream Definition | Récupérer la définition JSON | ❌ Non (JSON vide) |
| List Eventstreams | Lister les Eventstreams | ❌ Non |
| Update Eventstream | Modifier les propriétés | ❌ Non |
| Update Eventstream Definition | Mettre à jour la définition | ❌ Non (pas d'effet) |

### Fabric CLI

La commande `fab` ne fournit pas de sous-commandes pour :
- Ajouter des sources à un Eventstream
- Configurer des destinations
- Créer des connexions Event Hub
- Mapper vers des KQL Databases

## 💡 Pourquoi cette limitation ?

### Hypothèse 1 : Architecture en couches
L'Eventstream semble avoir **deux couches** :
1. **Définition statique** (JSON exportable) : Propriétés de base, metadata
2. **Configuration runtime** (non-exportable) : Sources, destinations, connexions

La couche 2 est probablement gérée par :
- Des services backend internes Fabric
- Une base de données relationnelle
- Des APIs privées non documentées

### Hypothèse 2 : Sécurité
Les connexions Event Hub et KQL Database contiennent :
- Credentials (clés d'accès, tokens)
- Informations sensibles
- Paramètres réseau

Microsoft ne les expose probablement **pas** dans les définitions exportables pour des raisons de sécurité.

### Hypothèse 3 : Produit en évolution
Eventstream est une fonctionnalité relativement récente de Fabric. L'automatisation complète via API n'est peut-être pas encore disponible.

## ✅ Solutions alternatives

### Option 1 : Configuration manuelle (RECOMMANDÉ pour l'instant)
**Temps** : 15 minutes  
**Automatisable** : ❌ Non  
**Effort** : Faible

✅ **Avantages** :
- Interface guidée
- Validation en temps réel
- Data preview immédiat
- Pas de risque d'erreur

❌ **Inconvénients** :
- Pas de versioning
- Répétitif pour plusieurs environnements
- Pas scriptable

### Option 2 : Terraform/Bicep (À investiguer)
**Statut** : Non testé

Vérifier si les providers Terraform/Bicep pour Fabric supportent :
- `azurerm_fabric_eventstream_source`
- `azurerm_fabric_eventstream_destination`

**Note** : Peu probable qu'ils existent étant donné l'absence d'API REST publique.

### Option 3 : Power Automate / Logic Apps
**Statut** : Possible mais complexe

Utiliser des connecteurs Fabric dans Power Automate :
- Nécessite d'investiguer les connecteurs disponibles
- Probablement limité aux mêmes APIs que le CLI

### Option 4 : Attendre les futures APIs
**Statut** : Long terme

Microsoft ajoute régulièrement de nouvelles fonctionnalités à Fabric. Les APIs pour configurer sources/destinations pourraient être ajoutées dans une future mise à jour.

## 📝 Recommandations

### Court terme (POC/Demo)
➡️ **Configuration manuelle via le portail Fabric**
- Utiliser le guide : `MANUAL_CONFIGURATION_GUIDE.md`
- Temps : 15-20 minutes
- Documenter les étapes pour répétabilité

### Moyen terme (Production)
➡️ **Automatiser uniquement les parties supportées**
- Création Workspace : ✅ Automatisable (`fab mkdir`)
- Création Eventstream (vide) : ✅ Automatisable (`fab mkdir`)
- Création KQL Database : ✅ Automatisable (`fab mkdir`)
- Configuration sources/destinations : ❌ Manuel

### Long terme (Scale)
➡️ **Infrastructure as Code partielle**
- Script les ressources Azure (Event Hub, Resource Group)
- Script les ressources Fabric de base (Workspace, Eventstream, DB)
- **Document manuel** pour la configuration UI Eventstream
- Veiller aux annonces Microsoft pour nouvelles APIs

## 🔗 Ressources

### Documentation officielle
- [Fabric REST API - Eventstream](https://learn.microsoft.com/en-us/rest/api/fabric/eventstream/items)
- [Fabric CLI](https://microsoft.github.io/fabric-cli/)
- [Add Event Hub Source (UI)](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-source-azure-event-hubs)
- [Add KQL Database Destination (UI)](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-kql-database)

### Fichiers du projet
- Guide manuel : `fabric/eventstream/MANUAL_CONFIGURATION_GUIDE.md`
- Informations connexion : `fabric/eventstream/CONNECTION_INFO.md`
- Options comparées : `fabric/eventstream/AUTOMATION_OPTIONS.md`

## 🎯 Prochaine étape recommandée

Étant donné l'impossibilité d'automatiser via API REST, je recommande de :

1. **Valider que la configuration manuelle fonctionne** (Étape 6 du plan)
   - Tester le flux end-to-end
   - Lancer le simulateur Python
   - Vérifier les données dans KQL Database

2. **Documenter le processus manuel** pour répétabilité
   - Captures d'écran
   - Checklist de validation
   - Procédure pour d'autres environnements

3. **Créer un script d'infrastructure partielle**
   - Automatiser Event Hub + Resource Group (Azure)
   - Automatiser Workspace + Eventstream vide + KQL DB (Fabric)
   - Fournir un guide manuel pour le "dernier kilomètre"

**Voulez-vous que je vous aide à valider le flux end-to-end maintenant ?**
