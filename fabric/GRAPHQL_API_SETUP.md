# Microsoft Fabric GraphQL API Setup Guide

## Vue d'ensemble

Microsoft Fabric permet de créer automatiquement une API GraphQL sur les tables d'un Lakehouse. Cette API GraphQL native sera ensuite exposée via Azure APIM pour ajouter OAuth, rate limiting, et transformation REST.

## Architecture Corrigée

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PARTNER APPLICATION                               │
│                     (React Demo - 3 Personas)                           │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ HTTPS + OAuth 2.0
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         AZURE APIM                                      │
│  ┌──────────────────────┐              ┌──────────────────────┐        │
│  │  REST API Endpoint   │              │  GraphQL Passthrough │        │
│  │  /api/v1/shipments   │              │  /graphql            │        │
│  │  /api/v1/orders      │              │                      │        │
│  └──────────────────────┘              └──────────────────────┘        │
│                                                                         │
│  Policies:                                                              │
│  • OAuth Validation (JWT from Azure AD)                                │
│  • Rate Limiting (tier-based: 10/60/300 req/min)                       │
│  • GraphQL→REST Transformation                                         │
│  • Partner Context Injection (X-Partner-Id header)                     │
└────────────────────────────┬───────────────────────────────────────────┘
                             │ Internal Network / Private Endpoint
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│              MICROSOFT FABRIC - GraphQL API (Auto-Generated)            │
│                                                                         │
│  Endpoint: https://<workspace>.powerbi.com/api/v1/graphql              │
│                                                                         │
│  Features:                                                              │
│  • Auto-generated schema from Lakehouse tables                         │
│  • Built-in filtering, sorting, pagination                             │
│  • Row-Level Security (RLS) via partner_access_scope                   │
│  • Real-time query on Delta tables                                     │
└────────────────────────────┬───────────────────────────────────────────┘
                             │ Direct SQL/Query Engine
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    FABRIC LAKEHOUSE - GOLD TABLES                       │
│                                                                         │
│  Data Product: 3PL Logistics Analytics                                 │
│  Domain: Supply Chain                                                  │
│                                                                         │
│  Tables (with B2B columns):                                            │
│  • idoc_orders_gold           → partner_access_scope                   │
│  • idoc_shipments_gold        → carrier_id, customer_id, partner_*     │
│  • idoc_warehouse_gold        → warehouse_partner_id, partner_*        │
│  • idoc_invoices_gold         → customer_id, partner_access_scope      │
│                                                                         │
│  RLS Policies:                                                          │
│  • CARRIER-FEDEX  → shipments WHERE carrier_id='CARRIER-FEDEX'         │
│  • WAREHOUSE-EAST → movements WHERE warehouse_partner_id='...-EAST'    │
│  • CUSTOMER-ACME  → orders/shipments/invoices WHERE customer_id='...'  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Étape 1 : Activer l'API GraphQL dans Fabric

### 1.1 Prérequis
- Workspace Fabric avec Lakehouse créé
- Tables Gold déjà créées (idoc_orders_gold, idoc_shipments_gold, etc.)
- Colonnes B2B présentes (partner_access_scope, carrier_id, etc.)
- Rôle : Workspace Admin ou Member

### 1.2 Activation de l'API GraphQL

**Option A : Via Fabric Portal (Recommandé)**

1. **Ouvrir le Lakehouse**
   ```
   https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64
   ```

2. **Aller dans Settings → API**
   - Cliquer sur le Lakehouse : `lh_3pl_logistics_gold`
   - Settings (⚙️) → API

3. **Enable GraphQL API**
   - Activer "Enable GraphQL endpoint"
   - Sélectionner les tables à exposer :
     - ☑ idoc_orders_gold
     - ☑ idoc_shipments_gold
     - ☑ idoc_warehouse_gold
     - ☑ idoc_invoices_gold

4. **Configurer les options**
   - **Enable filtering**: ✅ Oui
   - **Enable sorting**: ✅ Oui
   - **Enable pagination**: ✅ Oui (max 1000 records)
   - **Enable mutations**: ❌ Non (read-only pour partners)

5. **Copier l'URL de l'endpoint**
   ```
   https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql
   ```

**Option B : Via Fabric REST API**

```powershell
# Script PowerShell pour activer GraphQL API
$workspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"
$lakehouseId = "<lakehouse-id>"
$token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token

$body = @{
    enableGraphQL = $true
    tables = @(
        @{ name = "idoc_orders_gold"; enabled = $true },
        @{ name = "idoc_shipments_gold"; enabled = $true },
        @{ name = "idoc_warehouse_gold"; enabled = $true },
        @{ name = "idoc_invoices_gold"; enabled = $true }
    )
    settings = @{
        enableFiltering = $true
        enableSorting = $true
        enablePagination = $true
        maxPageSize = 1000
        enableMutations = $false
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/lakehouses/$lakehouseId/graphql" `
    -Method PUT `
    -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $body
```

### 1.3 Vérifier l'API GraphQL

**Tester avec curl :**
```bash
curl -X POST https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql \
  -H "Authorization: Bearer <fabric-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ __schema { types { name } } }"
  }'
```

**Résultat attendu :**
```json
{
  "data": {
    "__schema": {
      "types": [
        { "name": "idoc_orders_gold" },
        { "name": "idoc_shipments_gold" },
        { "name": "idoc_warehouse_gold" },
        { "name": "idoc_invoices_gold" },
        { "name": "Query" },
        { "name": "String" },
        { "name": "Int" },
        ...
      ]
    }
  }
}
```

## Étape 2 : Configurer Row-Level Security (RLS)

### 2.1 Créer les rôles RLS dans Fabric

**Via Fabric Portal :**

1. **Ouvrir le Lakehouse → Security → Row-Level Security**

2. **Créer 3 rôles RLS :**

**Rôle : CARRIER-FEDEX**
```sql
-- Appliquer sur : idoc_shipments_gold
[carrier_id] = "CARRIER-FEDEX"
```

**Rôle : WAREHOUSE-EAST**
```sql
-- Appliquer sur : idoc_warehouse_gold
[warehouse_partner_id] = "WAREHOUSE-EAST"
```

**Rôle : CUSTOMER-ACME**
```sql
-- Appliquer sur : idoc_orders_gold
[partner_access_scope] LIKE "%CUSTOMER-ACME%"

-- Appliquer sur : idoc_shipments_gold
[customer_id] = "CUSTOMER-ACME"

-- Appliquer sur : idoc_invoices_gold
[customer_id] = "CUSTOMER-ACME"
```

### 2.2 Lier RLS à Azure AD Claims

**Option : Dynamic RLS avec USERPRINCIPALNAME()**

Créer une fonction RLS dynamique :

```sql
-- Fonction : GetPartnerIdFromUser()
CREATE FUNCTION GetPartnerIdFromUser()
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @UserEmail VARCHAR(255) = USERPRINCIPALNAME()
    DECLARE @PartnerId VARCHAR(50)
    
    -- Mapping Azure AD Service Principal → Partner ID
    SET @PartnerId = CASE
        WHEN @UserEmail LIKE '%fedex-prod%' THEN 'CARRIER-FEDEX'
        WHEN @UserEmail LIKE '%warehouse-east%' THEN 'WAREHOUSE-EAST'
        WHEN @UserEmail LIKE '%acme-customer%' THEN 'CUSTOMER-ACME'
        ELSE NULL
    END
    
    RETURN @PartnerId
END
```

**Rôle dynamique :**
```sql
-- Appliquer sur toutes les tables
[partner_access_scope] LIKE '%' + dbo.GetPartnerIdFromUser() + '%'
```

## Étape 3 : Introspection du Schema GraphQL

### 3.1 Récupérer le schema auto-généré

```graphql
query IntrospectionQuery {
  __schema {
    types {
      name
      kind
      fields {
        name
        type {
          name
          kind
          ofType {
            name
            kind
          }
        }
      }
    }
  }
}
```

### 3.2 Schema attendu (exemple pour idoc_shipments_gold)

```graphql
type idoc_shipments_gold {
  shipment_number: String!
  shipment_date: DateTime!
  carrier_id: String
  carrier_code: String
  carrier_name: String
  customer_id: String
  customer_name: String
  tracking_number: String
  status: String
  origin_city: String
  destination_city: String
  estimated_delivery: DateTime
  actual_delivery: DateTime
  transit_time_hours: Float
  total_weight: Float
  weight_uom: String
  package_count: Int
  incoterms: String
  partner_access_scope: String
}

type Query {
  idoc_shipments_gold(
    filter: idoc_shipments_gold_filter
    orderBy: [idoc_shipments_gold_orderBy]
    first: Int
    after: String
  ): [idoc_shipments_gold!]!
}

input idoc_shipments_gold_filter {
  shipment_number: StringFilter
  carrier_id: StringFilter
  status: StringFilter
  shipment_date: DateTimeFilter
  AND: [idoc_shipments_gold_filter]
  OR: [idoc_shipments_gold_filter]
}

input StringFilter {
  eq: String
  ne: String
  in: [String]
  contains: String
  startsWith: String
}

input DateTimeFilter {
  eq: DateTime
  gt: DateTime
  gte: DateTime
  lt: DateTime
  lte: DateTime
}

enum idoc_shipments_gold_orderBy {
  shipment_date_ASC
  shipment_date_DESC
  carrier_name_ASC
  carrier_name_DESC
}
```

## Étape 4 : Tester l'API GraphQL avec RLS

### 4.1 Test avec token Azure AD (Service Principal CARRIER-FEDEX)

```bash
# Obtenir un token pour le Service Principal FedEx
TOKEN=$(curl -X POST https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token \
  -d grant_type=client_credentials \
  -d client_id=<fedex-client-id> \
  -d client_secret=<fedex-secret> \
  -d scope=https://analysis.windows.net/powerbi/api/.default \
  | jq -r .access_token)

# Query GraphQL (RLS appliqué automatiquement)
curl -X POST https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ idoc_shipments_gold(filter: { status: { eq: \"IN_TRANSIT\" } }, first: 10) { shipment_number carrier_id customer_name status } }"
  }'
```

**Résultat (RLS actif) :**
```json
{
  "data": {
    "idoc_shipments_gold": [
      {
        "shipment_number": "SHP-2025-001234",
        "carrier_id": "CARRIER-FEDEX",
        "customer_name": "ACME Corp",
        "status": "IN_TRANSIT"
      },
      {
        "shipment_number": "SHP-2025-001235",
        "carrier_id": "CARRIER-FEDEX",
        "customer_name": "GlobalTech Inc",
        "status": "IN_TRANSIT"
      }
    ]
  }
}
```

**Important** : Seules les shipments avec `carrier_id = 'CARRIER-FEDEX'` sont retournées grâce au RLS !

## Étape 5 : Exposer l'API Fabric via APIM

### 5.1 Mettre à jour le script deploy-apim.ps1

**Modification nécessaire :**

```powershell
# Backend pointe vers l'API GraphQL de Fabric (pas un endpoint custom)
$fabricGraphQLEndpoint = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/graphql"

# Créer le backend
az apim api create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "fabric-graphql-api" `
    --path "/graphql" `
    --display-name "Fabric GraphQL API" `
    --service-url $fabricGraphQLEndpoint `
    --protocols https `
    --subscription-required true
```

### 5.2 Policy pour transmettre le token Fabric

**Nouvelle policy : fabric-auth-passthrough.xml**

```xml
<policies>
    <inbound>
        <!-- Valider le JWT du partner (Azure AD) -->
        <validate-jwt header-name="Authorization">
            <openid-config url="https://login.microsoftonline.com/{tenant-id}/.well-known/openid-configuration" />
            <audiences>
                <audience>{{apim-client-id}}</audience>
            </audiences>
        </validate-jwt>
        
        <!-- Extraire partner_id pour logging -->
        <set-variable name="partner-id" value="@{
            var jwt = context.Request.Headers.GetValueOrDefault("Authorization", "").Replace("Bearer ", "").AsJwt();
            return jwt.Claims.GetValueOrDefault("partner_id", "");
        }" />
        
        <!-- Obtenir un token Fabric pour le Service Principal du partner -->
        <!-- Option 1: Utiliser le token du partner directement si configuré pour Fabric -->
        <!-- Option 2: Échanger le token via On-Behalf-Of flow -->
        
        <!-- Pour simplifier : Utiliser un Managed Identity de l'APIM avec les bons rôles RLS -->
        <authentication-managed-identity resource="https://analysis.windows.net/powerbi/api" />
        
        <!-- Le RLS sera appliqué côté Fabric basé sur le Service Principal appelant -->
    </inbound>
    
    <backend>
        <base />
    </backend>
    
    <outbound>
        <base />
    </outbound>
</policies>
```

## Étape 6 : Mapping Schema GraphQL → REST

Le fichier `graphql-to-rest.xml` que j'ai créé reste valide, mais il transforme maintenant les requêtes REST vers le **vrai schema auto-généré de Fabric**.

**Exemple de mapping :**

```
REST: GET /api/v1/shipments?status=IN_TRANSIT&limit=10

↓ Transformation APIM ↓

GraphQL Fabric:
{
  idoc_shipments_gold(
    filter: { status: { eq: "IN_TRANSIT" } }
    first: 10
  ) {
    shipment_number
    shipment_date
    carrier_id
    carrier_name
    customer_id
    customer_name
    tracking_number
    status
    origin_city
    destination_city
    estimated_delivery
    actual_delivery
    transit_time_hours
    total_weight
    weight_uom
    package_count
    incoterms
  }
}
```

## Étape 7 : Synchroniser le Schema

### 7.1 Mettre à jour partner-api.graphql

Le fichier `api/graphql/schema/partner-api.graphql` doit être **synchronisé avec le schema auto-généré de Fabric**.

**Action recommandée :**

1. Faire une introspection du schema Fabric
2. Générer le fichier GraphQL à partir du schema réel
3. Utiliser ce schema comme documentation pour les partners

**Script de synchronisation :**

```powershell
# Récupérer le schema depuis Fabric
$token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token
$introspection = Invoke-RestMethod `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/graphql" `
    -Method POST `
    -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body '{"query":"query IntrospectionQuery { __schema { types { name kind fields { name type { name kind ofType { name kind } } } } } }"}'

# Convertir en SDL (Schema Definition Language)
# ... (logique de conversion) ...

# Sauvegarder
$introspection | ConvertTo-Json -Depth 10 | Out-File "api/graphql/schema/fabric-schema.json"
```

## Résumé des Changements d'Architecture

| Composant | Avant (Incorrect) | Après (Correct) |
|-----------|------------------|-----------------|
| **Source de vérité** | Schema GraphQL custom | Tables Lakehouse Gold |
| **GraphQL Endpoint** | À créer manuellement | Auto-généré par Fabric |
| **Schema GraphQL** | Défini manuellement | Introspection du schema Fabric |
| **RLS** | À implémenter | Natif Fabric (rôles + Azure AD) |
| **APIM Backend** | Endpoint custom | `https://api.fabric.microsoft.com/.../graphql` |
| **Authentication** | OAuth → Custom API | OAuth → Fabric API (Managed Identity) |

## Prochaines Étapes

1. ✅ **Activer GraphQL API dans Fabric Portal** (Étape 1)
2. ✅ **Configurer RLS sur les tables Gold** (Étape 2)
3. ✅ **Tester l'introspection du schema** (Étape 3)
4. ⏸️ **Mettre à jour deploy-apim.ps1** avec l'endpoint Fabric réel
5. ⏸️ **Créer la policy fabric-auth-passthrough.xml**
6. ⏸️ **Synchroniser partner-api.graphql avec le schema Fabric**
7. ⏸️ **Tester end-to-end : Partner App → APIM → Fabric GraphQL → Lakehouse**

## Avantages de l'API GraphQL Native Fabric

✅ **Zero-code** : Pas besoin de développer l'API GraphQL  
✅ **Auto-sync** : Schema toujours synchronisé avec les tables  
✅ **Performance** : Query engine optimisé pour Delta Lake  
✅ **RLS natif** : Sécurité intégrée avec Azure AD  
✅ **Pagination** : Gestion automatique des gros volumes  
✅ **Filtering** : Opérateurs avancés (eq, ne, in, contains, gt, lt, etc.)  
✅ **Monitoring** : Intégré dans Fabric metrics  

## Documentation Microsoft

- [Fabric GraphQL API Overview](https://learn.microsoft.com/fabric/data-engineering/graphql-api)
- [Enable GraphQL on Lakehouse](https://learn.microsoft.com/fabric/data-engineering/lakehouse-graphql-api)
- [Row-Level Security in Fabric](https://learn.microsoft.com/fabric/security/service-admin-row-level-security)
- [Fabric REST API Reference](https://learn.microsoft.com/rest/api/fabric/)
