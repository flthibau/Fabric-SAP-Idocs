# 3PL Partner API - Plan d'Implémentation

## 🎯 Objectif

Exposer le **3PL Logistics Analytics Data Product** aux partenaires logistiques via:
1. **GraphQL API** (Fabric) - Source de vérité
2. **REST API** (APIM) - Alternative pour partenaires préférant REST
3. **Row-Level Security (RLS)** - Isolation des données par partenaire
4. **OAuth 2.0** - Authentification sécurisée
5. **Demo App** - Application React simulant un partenaire

## 🏗️ Architecture Simplifiée

```
┌──────────────────┐
│ Partner App      │  React/TypeScript Demo
│ (Demo Carrier)   │  
└────────┬─────────┘
         │ HTTPS + OAuth
         ▼
┌──────────────────┐
│ Azure APIM       │  • REST → GraphQL transform
│                  │  • Rate limiting
│                  │  • OAuth validation
└────────┬─────────┘
         │ HTTPS
         ▼
┌──────────────────┐
│ Fabric GraphQL   │  • RLS filtering
│ API Endpoint     │  • partner_access_scope
└────────┬─────────┘
         │ Direct Query
         ▼
┌──────────────────┐
│ Lakehouse Gold   │  Delta Tables with B2B columns
│ Tables           │  
└──────────────────┘
```

## 📊 Partner Data Model

### Colonnes B2B déjà présentes dans les tables Silver/Gold:

```sql
-- idoc_orders_silver/gold
partner_access_scope: STRING  -- Ex: "CUSTOMER-ACME"

-- idoc_shipments_silver/gold
carrier_id: STRING            -- Ex: "CARRIER-FEDEX"
customer_id: STRING
customer_name: STRING
partner_access_scope: STRING  -- Ex: "CARRIER-FEDEX" ou "CUSTOMER-ACME"

-- idoc_warehouse_silver/gold
warehouse_partner_id: STRING  -- Ex: "WAREHOUSE-EAST"
warehouse_partner_name: STRING
partner_access_scope: STRING  -- Ex: "WAREHOUSE-EAST"

-- idoc_invoices_silver/gold
customer_id: STRING
customer_name: STRING
partner_access_scope: STRING  -- Ex: "CUSTOMER-ACME"
```

### 3 Personas de Partenaires (Demo)

| Partner ID | Type | Accès | Use Case |
|-----------|------|-------|----------|
| **CARRIER-FEDEX** | Transporteur | Shipments où `carrier_id='CARRIER-FEDEX'` | Suivi expéditions |
| **WAREHOUSE-EAST** | Entrepôt 3PL | Warehouse où `warehouse_partner_id='WAREHOUSE-EAST'` | Monitoring mouvements |
| **CUSTOMER-ACME** | Client | Orders, Shipments, Invoices où `customer_id='CUSTOMER-ACME'` | Visibilité complète |

## 🔐 Modèle de Sécurité

### OAuth 2.0 Flow (Simplifié pour MVP)

```
1. Partner App → APIM: 
   POST /oauth/token
   Body: { client_id: "fedex-prod", client_secret: "***" }

2. APIM → Azure AD B2C:
   Validate credentials
   
3. APIM → Partner App:
   Return JWT: { partner_id: "CARRIER-FEDEX", tier: "standard" }

4. Partner App → APIM:
   GET /api/v1/shipments
   Header: Authorization: Bearer <JWT>

5. APIM Policy:
   Extract partner_id from JWT
   Add header: X-Partner-Id: CARRIER-FEDEX

6. APIM → Fabric GraphQL:
   Transform REST → GraphQL
   Include X-Partner-Id header

7. Fabric GraphQL:
   Apply RLS: WHERE partner_access_scope = 'CARRIER-FEDEX'

8. Return filtered data
```

### Rate Limiting (APIM Policies)

| Tier | Requests/min | Use Case |
|------|--------------|----------|
| **Free** | 10 | Testing |
| **Standard** | 60 | Production partners |
| **Premium** | 300 | High-volume partners |

## 📡 API Specifications

### GraphQL Schema (Fabric)

```graphql
type Query {
  # Shipments (carrier view)
  shipments(
    status: ShipmentStatus
    dateFrom: String
    dateTo: String
    limit: Int = 50
  ): [Shipment!]!
  
  shipment(shipmentNumber: String!): Shipment
  
  # Orders (customer view)
  orders(
    status: OrderStatus
    dateFrom: String
    dateTo: String
    limit: Int = 50
  ): [Order!]!
  
  # Warehouse (warehouse partner view)
  warehouseMovements(
    movementType: String
    dateFrom: String
    limit: Int = 50
  ): [WarehouseMovement!]!
  
  # Invoices (customer view)
  invoices(
    period: String
    status: String
    limit: Int = 50
  ): [Invoice!]!
  
  # KPIs (all partners)
  kpis(metric: String!, period: String!): [KPI!]!
}

type Shipment {
  shipmentNumber: String!
  shipmentDate: String!
  carrierCode: String!
  carrierName: String!
  trackingNumber: String
  status: String!
  destinationCity: String
  estimatedDelivery: String
  actualDelivery: String
  transitTimeHours: Float
}

type Order {
  orderNumber: String!
  orderDate: String!
  customerName: String!
  totalAmount: Float!
  currency: String!
  status: String!
  slaStatus: String!
}

type WarehouseMovement {
  movementId: String!
  movementDate: String!
  warehouseName: String!
  movementType: String!
  quantity: Float!
  processingTimeMinutes: Float
}

type Invoice {
  invoiceNumber: String!
  invoiceDate: String!
  customerName: String!
  totalAmount: Float!
  currency: String!
  agingBucket: String!
}

type KPI {
  metric: String!
  value: Float!
  period: String!
}

enum ShipmentStatus {
  PENDING_PICKUP
  IN_TRANSIT
  DELIVERED
}

enum OrderStatus {
  PENDING
  CONFIRMED
  SHIPPED
  DELIVERED
}
```

### REST API Endpoints (APIM)

```
# Shipments (carrier access)
GET /api/v1/shipments
  ?status=IN_TRANSIT
  &dateFrom=2025-10-01
  &dateTo=2025-10-31
  &limit=50

GET /api/v1/shipments/{shipmentNumber}

# Orders (customer access)
GET /api/v1/orders
  ?status=CONFIRMED
  &dateFrom=2025-10-01
  &limit=50

# Warehouse (warehouse partner access)
GET /api/v1/warehouse/movements
  ?movementType=GR
  &dateFrom=2025-10-29
  &limit=50

# Invoices (customer access)
GET /api/v1/invoices
  ?period=2025-10
  &status=OVERDUE

# KPIs (all partners)
GET /api/v1/kpis/ON_TIME_DELIVERY_RATE
  ?period=2025-10
```

## 🚀 Plan d'Implémentation (3 Phases)

### Phase 1: Fabric GraphQL API (Jours 1-2)

**Objectif**: Créer l'API GraphQL dans Fabric avec RLS

#### Étape 1.1: Créer API GraphQL dans Fabric
```powershell
# Via Fabric Portal (manuel)
# 1. Ouvrir Lakehouse
# 2. Créer GraphQL Endpoint
# 3. Sélectionner tables Gold (orders, shipments, warehouse, invoices)
# 4. Auto-générer schéma de base
```

#### Étape 1.2: Personnaliser le schéma
- Simplifier les types exposés
- Ajouter filtres par date, status
- Implémenter pagination

#### Étape 1.3: Configurer RLS
```sql
-- Fabric: Créer fonction de sécurité
CREATE FUNCTION fn_PartnerFilter(@partnerId STRING)
RETURNS TABLE
AS
RETURN
SELECT *
FROM idoc_shipments_gold
WHERE partner_access_scope = @partnerId
```

#### Étape 1.4: Tester avec Postman
```graphql
# Query test
query {
  shipments(status: "IN_TRANSIT", limit: 10) {
    shipmentNumber
    carrierName
    status
  }
}

# Headers:
# X-Partner-Id: CARRIER-FEDEX
```

**Livrable Phase 1**:
- ✅ GraphQL endpoint fonctionnel
- ✅ RLS filtering actif
- ✅ Documentation schéma
- ✅ Collection Postman

---

### Phase 2: Azure APIM (Jours 3-5)

**Objectif**: Déployer APIM avec policies OAuth + REST transformation

#### Étape 2.1: Déployer APIM via Bicep
```bash
# Exécuter script automatisé
.\api\scripts\deploy-apim.ps1 `
  -ResourceGroup "rg-3pl-partner-api" `
  -Location "westeurope" `
  -ApimName "apim-3pl-partner"
```

**Ressources créées**:
- APIM instance (Developer SKU)
- Custom domain (optionnel)
- Azure AD B2C tenant (OAuth)
- 3 App Registrations (FEDEX, WAREHOUSE-EAST, CUSTOMER-ACME)

#### Étape 2.2: Configurer GraphQL Passthrough
```xml
<!-- Policy: Forwarding GraphQL -->
<policies>
    <inbound>
        <!-- Validate OAuth token -->
        <validate-jwt header-name="Authorization">
            <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
            <required-claims>
                <claim name="partner_id" match="any" />
            </required-claims>
        </validate-jwt>
        
        <!-- Extract partner_id from JWT -->
        <set-header name="X-Partner-Id" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","")
                .AsJwt().Claims.GetValueOrDefault("partner_id", ""))</value>
        </set-header>
        
        <!-- Rate limiting -->
        <rate-limit-by-key calls="60" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault("X-Partner-Id"))" />
    </inbound>
    
    <backend>
        <forward-request />
    </backend>
    
    <outbound>
        <set-header name="X-RateLimit-Remaining" exists-action="override">
            <value>@(context.Variables.GetValueOrDefault<string>("rate-limit-remaining"))</value>
        </set-header>
    </outbound>
</policies>
```

#### Étape 2.3: REST → GraphQL Transformation
```xml
<!-- Policy: Transform GET /api/v1/shipments → GraphQL -->
<policies>
    <inbound>
        <set-variable name="status" value="@(context.Request.Url.Query.GetValueOrDefault("status", ""))" />
        <set-variable name="limit" value="@(context.Request.Url.Query.GetValueOrDefault("limit", "50"))" />
        
        <set-body>@{
            var query = $@"
                query {{
                    shipments(status: ""{context.Variables["status"]}"", limit: {context.Variables["limit"]}) {{
                        shipmentNumber
                        shipmentDate
                        carrierName
                        status
                        trackingNumber
                        destinationCity
                        estimatedDelivery
                    }}
                }}
            ";
            return JsonConvert.SerializeObject(new { query });
        }</set-body>
        
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        
        <rewrite-uri template="/graphql" />
    </inbound>
</policies>
```

#### Étape 2.4: Créer Partner Apps dans Azure AD
```powershell
# Script automatisé
.\api\scripts\create-partner-apps.ps1

# Crée 3 App Registrations:
# 1. fedex-prod (client_id, secret) → partner_id: CARRIER-FEDEX
# 2. warehouse-east-prod → partner_id: WAREHOUSE-EAST
# 3. acme-customer-prod → partner_id: CUSTOMER-ACME
```

**Livrable Phase 2**:
- ✅ APIM déployé
- ✅ GraphQL passthrough configuré
- ✅ REST transformations actives
- ✅ OAuth 2.0 fonctionnel
- ✅ Rate limiting configuré
- ✅ 3 partner apps créées

---

### Phase 3: Partner Demo App (Jours 6-8)

**Objectif**: Application React démontrant les 3 personas

#### Étape 3.1: Bootstrap React App
```bash
# Créer app avec Vite
cd api
npm create vite@latest partner-demo-app -- --template react-ts

# Dependencies
cd partner-demo-app
npm install axios @tanstack/react-query react-router-dom
npm install -D tailwindcss postcss autoprefixer
```

#### Étape 3.2: Structure de l'App
```
partner-demo-app/
├── src/
│   ├── App.tsx                    # Main app
│   ├── components/
│   │   ├── Login.tsx              # OAuth login
│   │   ├── Dashboard.tsx          # KPI summary
│   │   ├── ShipmentList.tsx       # Carrier view
│   │   ├── OrderList.tsx          # Customer view
│   │   └── WarehouseMovements.tsx # Warehouse view
│   ├── services/
│   │   └── apiClient.ts           # REST client with auth
│   ├── auth/
│   │   └── AuthContext.tsx        # OAuth flow
│   ├── types/
│   │   └── api.types.ts           # TypeScript types
│   └── config/
│       └── partners.ts            # 3 partner configs
```

#### Étape 3.3: Fonctionnalités par Persona

**CARRIER-FEDEX (Transporteur)**
- Dashboard: "42 expéditions en transit"
- Liste expéditions filtrées par `carrier_id=CARRIER-FEDEX`
- Détail expédition avec tracking
- KPI: Taux livraison à temps

**WAREHOUSE-EAST (Entrepôt)**
- Dashboard: "1,247 mouvements aujourd'hui"
- Liste mouvements filtrés par `warehouse_partner_id=WAREHOUSE-EAST`
- Détail mouvement avec temps traitement
- KPI: Efficacité entrepôt

**CUSTOMER-ACME (Client)**
- Dashboard: "128 commandes actives"
- Liste commandes, expéditions, factures
- Détail commande avec statut SLA
- KPI: Performance globale

#### Étape 3.4: Implémentation OAuth Flow
```typescript
// src/auth/AuthContext.tsx
const login = async (partnerId: string) => {
  const response = await fetch(`${APIM_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: partners[partnerId].clientId,
      client_secret: partners[partnerId].clientSecret,
      grant_type: 'client_credentials'
    })
  });
  
  const { access_token } = await response.json();
  localStorage.setItem('token', access_token);
  setToken(access_token);
};
```

**Livrable Phase 3**:
- ✅ App React fonctionnelle
- ✅ 3 personas implémentées
- ✅ OAuth flow complet
- ✅ UI moderne (TailwindCSS)
- ✅ Gestion erreurs
- ✅ Loading states

---

## 📦 Livrables Finaux

### Code & Scripts

```
api/
├── graphql/
│   ├── schema/
│   │   └── partner-api.graphql          # ✅ Schéma GraphQL
│   ├── resolvers/
│   │   └── rls-functions.kql            # ✅ Fonctions RLS
│   └── postman/
│       └── partner-api-collection.json  # ✅ Tests Postman
│
├── apim/
│   ├── bicep/
│   │   ├── main.bicep                   # ✅ APIM infrastructure
│   │   └── parameters.json              # ✅ Config environnement
│   ├── policies/
│   │   ├── oauth-validation.xml         # ✅ Validation OAuth
│   │   ├── rate-limiting.xml            # ✅ Rate limiting
│   │   └── graphql-to-rest.xml          # ✅ Transformation
│   └── api-definitions/
│       └── openapi-spec.yaml            # ✅ Spec REST API
│
├── partner-demo-app/
│   ├── src/                             # ✅ App React complète
│   ├── package.json
│   └── README.md                        # ✅ Setup guide
│
└── scripts/
    ├── deploy-apim.ps1                  # ✅ Déploiement APIM
    ├── create-partner-apps.ps1          # ✅ Création apps Azure AD
    └── test-e2e.ps1                     # ✅ Tests end-to-end
```

### Documentation

1. **API Reference** (`api/API_REFERENCE.md`)
   - Endpoints GraphQL + REST
   - Authentification OAuth
   - Rate limits
   - Exemples code (curl, JavaScript, Python)

2. **Integration Guide** (`docs/PARTNER_INTEGRATION_GUIDE.md`)
   - Onboarding partenaires
   - Obtention credentials
   - Sample apps
   - Best practices

3. **Architecture Diagram** (`docs/api-architecture.png`)
   - Composants
   - Flux données
   - Sécurité

## 🎬 Scénario de Démo

### Persona: CARRIER-FEDEX

```bash
# 1. Login
POST https://apim-3pl-partner.azure-api.net/oauth/token
Body: {
  "client_id": "fedex-prod-12345",
  "client_secret": "***",
  "grant_type": "client_credentials"
}

Response: {
  "access_token": "eyJ...",
  "partner_id": "CARRIER-FEDEX",
  "tier": "standard"
}

# 2. Get active shipments
GET https://apim-3pl-partner.azure-api.net/api/v1/shipments?status=IN_TRANSIT
Authorization: Bearer eyJ...

Response: [
  {
    "shipmentNumber": "SHIP-20251029-001",
    "carrierName": "FedEx Ground",
    "status": "IN_TRANSIT",
    "trackingNumber": "FEDEX-123456",
    "destinationCity": "Paris",
    "estimatedDelivery": "2025-10-30T14:00:00Z"
  },
  ...
]

# 3. Get KPI
GET https://apim-3pl-partner.azure-api.net/api/v1/kpis/ON_TIME_DELIVERY_RATE?period=2025-10
Authorization: Bearer eyJ...

Response: {
  "metric": "ON_TIME_DELIVERY_RATE",
  "value": 94.8,
  "period": "2025-10"
}
```

## ✅ Critères de Succès

1. ✅ Fabric GraphQL répond avec RLS actif
2. ✅ APIM transforme REST → GraphQL correctement
3. ✅ OAuth 2.0 flow complet
4. ✅ Rate limiting fonctionne (60 req/min)
5. ✅ 3 personas démo fonctionnelles
6. ✅ Latence < 500ms (P95)
7. ✅ Documentation complète
8. ✅ Tests E2E passants

## 📅 Timeline

| Phase | Durée | Début | Fin |
|-------|-------|-------|-----|
| Phase 1: Fabric GraphQL | 2j | J1 | J2 |
| Phase 2: APIM | 3j | J3 | J5 |
| Phase 3: Demo App | 3j | J6 | J8 |
| **Total** | **8 jours** | | |

---

**Prêt à commencer ?** 🚀

Prochaine action suggérée:
1. ✅ Créer le schéma GraphQL dans Fabric
2. ⏸️ Générer les scripts Bicep APIM
3. ⏸️ Bootstrap app React

Que souhaitez-vous démarrer en premier ?
