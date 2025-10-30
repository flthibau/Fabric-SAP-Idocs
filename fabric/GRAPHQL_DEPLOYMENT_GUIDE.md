# Déploiement API GraphQL Fabric via Extension VS Code

Ce guide explique comment déployer l'API GraphQL native de Fabric en utilisant l'extension Microsoft Fabric pour VS Code.

## Prérequis

✅ Extension **Microsoft Fabric** installée (`fabric.vscode-fabric`)  
✅ Connexion à Azure/Fabric configurée  
✅ Workspace Fabric : `ad53e547-23dc-46b0-ab5f-2acbaf0eec64`  
✅ Lakehouse : `lh_3pl_logistics_gold`  
✅ Tables Gold avec colonnes B2B (partner_access_scope)

## Méthode 1 : Déploiement via Extension VS Code (Recommandé)

### Étape 1 : Ouvrir la Vue Fabric

1. **Ouvrir la sidebar Fabric** :
   - Cliquer sur l'icône Fabric dans la sidebar gauche
   - Ou : `Ctrl+Shift+P` → `Fabric: Focus on Fabric View`

2. **Se connecter au Workspace** :
   - Cliquer sur "Sign in to Fabric"
   - Sélectionner le workspace : `MngEnvMCAP396311`

### Étape 2 : Créer l'API GraphQL

1. **Créer un nouvel item** :
   - Clic droit sur le workspace → `Create New Item`
   - Sélectionner type : **GraphQL API**

2. **Configurer l'API** :
   ```
   Nom: 3PL Partner API
   Description: API GraphQL pour partenaires 3PL (Carriers, Warehouses, Customers)
   ```

3. **Sélectionner la source de données** :
   - Type : **Lakehouse**
   - Lakehouse : `lh_3pl_logistics_gold`

4. **Sélectionner les tables** :
   - ☑ `idoc_orders_gold`
   - ☑ `idoc_shipments_gold`
   - ☑ `idoc_warehouse_gold`
   - ☑ `idoc_invoices_gold`

5. **Configurer les options** :
   ```
   ✓ Enable filtering
   ✓ Enable sorting
   ✓ Enable pagination (max 1000 records)
   ✗ Enable mutations (read-only pour partners)
   ```

6. **Sécurité** :
   ```
   ✓ Enable Row-Level Security
   ✗ Allow anonymous access
   Authentication: Azure AD
   ```

7. **Déployer** :
   - Cliquer sur `Create`
   - Attendre la création (30-60 secondes)

### Étape 3 : Récupérer l'Endpoint

Après création, l'endpoint GraphQL sera disponible :

```
https://api.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/<api-id>/graphql
```

Copier cet endpoint pour le configurer dans APIM.

## Méthode 2 : Déploiement Manuel via Fabric Portal

Si l'extension ne fonctionne pas, utiliser le portail :

### Étape 1 : Créer l'API dans Fabric Portal

1. Ouvrir : https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64

2. Cliquer sur `+ New` → `GraphQL API`

3. Configuration identique à la Méthode 1

### Étape 2 : Configuration avancée

Dans les settings de l'API GraphQL :

```json
{
  "schema": {
    "autoGenerate": true,
    "source": "lakehouse",
    "tables": [
      "idoc_orders_gold",
      "idoc_shipments_gold", 
      "idoc_warehouse_gold",
      "idoc_invoices_gold"
    ]
  },
  "capabilities": {
    "filtering": true,
    "sorting": true,
    "pagination": true,
    "mutations": false,
    "maxPageSize": 1000
  },
  "security": {
    "rowLevelSecurity": true,
    "allowAnonymous": false,
    "authMethods": ["AzureAD"]
  }
}
```

## Méthode 3 : Déploiement via Git Integration (CI/CD)

Pour automatiser complètement via Git :

### Étape 1 : Activer Git Integration

1. Dans Fabric Portal → Workspace Settings
2. Git integration → Connect to repository
3. Sélectionner Azure DevOps ou GitHub
4. Configurer la branche : `main`

### Étape 2 : Structure du Repository

```
Fabric-SAP-Idocs/
├── fabric/
│   └── .fabric/
│       ├── graphql-api-definition.json    ← Définition de l'API
│       └── workspace.json                 ← Config workspace
```

### Étape 3 : Commit et Push

```bash
git add fabric/.fabric/graphql-api-definition.json
git commit -m "feat: Add GraphQL API definition for 3PL partners"
git push origin main
```

### Étape 4 : Synchronisation Fabric

1. Dans Fabric Portal → Workspace
2. Cliquer sur `Source Control` → `Update from Git`
3. Fabric déploie automatiquement l'API GraphQL

## Configuration Row-Level Security (RLS)

Après déploiement de l'API GraphQL, configurer RLS :

### Méthode : Via Lakehouse SQL Analytics Endpoint

1. **Ouvrir SQL Analytics Endpoint** :
   - Lakehouse → SQL Analytics Endpoint → Security

2. **Créer les rôles RLS** :

#### Rôle 1 : CARRIER-FEDEX
```sql
-- Appliquer sur idoc_shipments_gold
CREATE ROLE [CARRIER-FEDEX]

-- DAX Filter (dans Fabric, utiliser l'interface)
[carrier_id] = "CARRIER-FEDEX"
```

#### Rôle 2 : WAREHOUSE-EAST
```sql
-- Appliquer sur idoc_warehouse_gold
CREATE ROLE [WAREHOUSE-EAST]

-- DAX Filter
[warehouse_partner_id] = "WAREHOUSE-EAST"
```

#### Rôle 3 : CUSTOMER-ACME
```sql
-- Appliquer sur idoc_orders_gold, idoc_shipments_gold, idoc_invoices_gold
CREATE ROLE [CUSTOMER-ACME]

-- DAX Filter (sur toutes les tables)
[partner_access_scope] = "CUSTOMER-ACME"
```

### Lier RLS aux Service Principals

1. Créer les Service Principals Azure AD (via `create-partner-apps.ps1`)
2. Dans Fabric → Lakehouse → Security → Manage Roles
3. Pour chaque rôle, ajouter le Service Principal correspondant :
   - CARRIER-FEDEX → `fedex-prod` (client_id: ...)
   - WAREHOUSE-EAST → `warehouse-east-prod` (client_id: ...)
   - CUSTOMER-ACME → `acme-customer-prod` (client_id: ...)

## Test de l'API GraphQL

### Test 1 : Introspection du Schema

```bash
curl -X POST https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphqlapis/<api-id>/graphql \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ __schema { types { name } } }"
  }'
```

### Test 2 : Query avec Filtre

```bash
curl -X POST <graphql-endpoint> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ idoc_shipments_gold(filter: { status: { eq: \"IN_TRANSIT\" } }, first: 5) { shipment_number carrier_id customer_name status } }"
  }'
```

### Test 3 : Vérifier RLS

Avec un token du Service Principal `fedex-prod`, la query ci-dessus ne doit retourner que les shipments où `carrier_id = 'CARRIER-FEDEX'`.

## Troubleshooting

### Erreur : "GraphQL API not available"

**Cause** : GraphQL API est en Preview et pas disponible dans tous les tenants.

**Solution** : Utiliser SQL Endpoint à la place :
- Endpoint : Lakehouse → SQL Analytics Endpoint
- APIM fera des requêtes SQL au lieu de GraphQL
- RLS fonctionne identiquement

### Erreur : "Permission denied"

**Cause** : RLS non configuré ou Service Principal pas dans le rôle.

**Solution** :
1. Vérifier que RLS est activé sur les tables
2. Vérifier que le Service Principal est membre du rôle RLS
3. Vérifier que le token contient le bon `partner_id` claim

### Erreur : "Table not found"

**Cause** : Tables Gold pas créées ou pas accessibles.

**Solution** :
1. Exécuter le notebook `Create_Gold_Materialized_Lake_Views`
2. Vérifier que les tables existent : `SHOW TABLES`
3. Vérifier les permissions sur le Lakehouse

## Prochaines Étapes

Après déploiement réussi de l'API GraphQL :

1. ✅ **Copier l'endpoint GraphQL** → Utiliser dans APIM
2. ⏸️ **Mettre à jour deploy-apim.ps1** avec l'endpoint réel
3. ⏸️ **Créer les Partner App Registrations** (Azure AD)
4. ⏸️ **Configurer RLS** avec les Service Principals
5. ⏸️ **Déployer APIM** avec les policies
6. ⏸️ **Tester end-to-end** Partner App → APIM → Fabric GraphQL

## Ressources

- [Microsoft Fabric GraphQL API Documentation](https://learn.microsoft.com/fabric/data-engineering/graphql-api)
- [Fabric VS Code Extension](https://marketplace.visualstudio.com/items?itemName=fabric.vscode-fabric)
- [Row-Level Security in Fabric](https://learn.microsoft.com/fabric/security/service-admin-row-level-security)
