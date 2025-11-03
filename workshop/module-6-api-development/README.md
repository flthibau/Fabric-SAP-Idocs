# Module 6: API Development

> **Creating GraphQL and REST APIs for data access**

⏱️ **Duration**: 120 minutes | 🎯 **Level**: Advanced | 📋 **Prerequisites**: Modules 1-5 completed

---

## 📖 Module Overview

Build modern APIs using Fabric GraphQL and Azure API Management to expose the data product to partner applications with proper authentication and governance.

### Learning Objectives

- ✅ Enable and configure Fabric GraphQL API
- ✅ Design GraphQL schema for partner data access
- ✅ Configure Azure API Management (APIM)
- ✅ Implement OAuth2 authentication
- ✅ Generate REST APIs from GraphQL
- ✅ Test and document APIs

---

## 📚 API Architecture

```
Partner App → APIM (OAuth2) → GraphQL API → Lakehouse (RLS) → Data
```

---

## 🧪 Hands-On Labs

### Lab 1: Enable Fabric GraphQL API

**Enable GraphQL on Lakehouse**:

```powershell
# Using Fabric PowerShell
Connect-Fabric

# Enable GraphQL API
Enable-FabricGraphQLAPI `
    -WorkspaceId "<workspace-id>" `
    -LakehouseId "<lakehouse-id>" `
    -Endpoint "partner-logistics-api"

# Verify endpoint
Get-FabricGraphQLEndpoint -WorkspaceId "<workspace-id>"
```

**API Endpoint**: `https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql`

---

### Lab 2: Design GraphQL Schema

**Schema for partner data access**:

```graphql
# partner-api.graphql

# Types
type Shipment {
  id: ID!
  shipmentNumber: String!
  shipDate: Date!
  deliveryDate: Date
  status: ShipmentStatus!
  carrier: Carrier!
  customer: Customer!
  origin: Location!
  destination: Location!
  totalWeight: Float
  totalValue: Float
  onTimeDelivery: Boolean
  items: [ShipmentItem!]!
  createdAt: DateTime!
}

type Carrier {
  id: ID!
  carrierId: String!
  name: String!
  shipments(limit: Int = 10): [Shipment!]!
}

type Customer {
  id: ID!
  customerId: String!
  name: String!
  orders: [Order!]!
  shipments: [Shipment!]!
}

type Order {
  id: ID!
  orderNumber: String!
  orderDate: Date!
  customer: Customer!
  totalValue: Float!
  status: OrderStatus!
  items: [OrderItem!]!
}

enum ShipmentStatus {
  CREATED
  IN_TRANSIT
  DELIVERED
  DELAYED
}

enum OrderStatus {
  PENDING
  CONFIRMED
  SHIPPED
  DELIVERED
}

# Queries
type Query {
  # Shipment queries
  shipment(id: ID!): Shipment
  shipments(
    filters: ShipmentFilters
    limit: Int = 20
    offset: Int = 0
  ): ShipmentConnection!
  
  # Order queries
  order(id: ID!): Order
  orders(
    filters: OrderFilters
    limit: Int = 20
    offset: Int = 0
  ): OrderConnection!
  
  # Metrics
  shipmentMetrics(
    startDate: Date!
    endDate: Date!
  ): ShipmentMetrics!
}

input ShipmentFilters {
  startDate: Date
  endDate: Date
  status: ShipmentStatus
  carrierId: String
  customerId: String
}

type ShipmentConnection {
  edges: [ShipmentEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type ShipmentEdge {
  node: Shipment!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
}

type ShipmentMetrics {
  totalShipments: Int!
  onTimeDeliveryRate: Float!
  avgDeliveryDays: Float!
  totalWeight: Float!
}

scalar Date
scalar DateTime
```

**Deploy schema**:

```powershell
# Deploy GraphQL schema to Fabric
Deploy-FabricGraphQLSchema `
    -WorkspaceId "<workspace-id>" `
    -SchemaFile "partner-api.graphql"
```

---

### Lab 3: Configure Azure API Management

**Deploy APIM**:

```bicep
// apim.bicep
resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: 'apim-3pl-logistics'
  location: resourceGroup().location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@company.com'
    publisherName: 'Company IT'
  }
}

// GraphQL API
resource graphqlApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apim
  name: 'partner-logistics-api'
  properties: {
    displayName: 'Partner Logistics GraphQL API'
    path: 'graphql'
    protocols: ['https']
    subscriptionRequired: true
    type: 'graphql'
    format: 'graphql-link'
    value: 'https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphql'
  }
}
```

**APIM Policies**:

```xml
<!-- inbound policy -->
<policies>
  <inbound>
    <base />
    
    <!-- CORS -->
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>https://fedex-portal.company.com</origin>
        <origin>https://acme-customer.company.com</origin>
      </allowed-origins>
      <allowed-methods>
        <method>POST</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
    
    <!-- OAuth2 Validation -->
    <validate-jwt header-name="Authorization" 
                  failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
      <audiences>
        <audience>api://partner-logistics-api</audience>
      </audiences>
      <required-claims>
        <claim name="roles" match="any">
          <value>PartnerAccess</value>
        </claim>
      </required-claims>
    </validate-jwt>
    
    <!-- Extract partner ID from JWT claims -->
    <set-variable name="partnerId" 
                  value="@(context.Request.Headers.GetValueOrDefault("Authorization","")
                          .AsJwt()?.Claims?.GetValueOrDefault("partner_id", ""))" />
    
    <!-- Set session context for RLS -->
    <set-header name="X-Partner-ID" exists-action="override">
      <value>@((string)context.Variables["partnerId"])</value>
    </set-header>
    
    <!-- Rate limiting by partner -->
    <rate-limit-by-key calls="1000" 
                       renewal-period="60" 
                       counter-key="@((string)context.Variables["partnerId"])" />
    
    <!-- Logging -->
    <set-variable name="requestId" value="@(Guid.NewGuid().ToString())" />
    <log-to-eventhub logger-id="api-logger">
      @{
        return new {
          RequestId = (string)context.Variables["requestId"],
          PartnerId = (string)context.Variables["partnerId"],
          Timestamp = DateTime.UtcNow,
          Method = context.Request.Method,
          Url = context.Request.Url.ToString()
        }.ToString();
      }
    </log-to-eventhub>
    
  </inbound>
  
  <backend>
    <base />
  </backend>
  
  <outbound>
    <base />
    <set-header name="X-Request-Id" exists-action="override">
      <value>@((string)context.Variables["requestId"])</value>
    </set-header>
  </outbound>
  
  <on-error>
    <base />
    <log-to-eventhub logger-id="api-logger">
      @{
        return new {
          RequestId = (string)context.Variables["requestId"],
          Error = context.LastError.Message
        }.ToString();
      }
    </log-to-eventhub>
  </on-error>
</policies>
```

---

### Lab 4: Implement OAuth2 Authentication

**Register API in Azure AD**:

```powershell
# Create API application
$apiApp = az ad app create `
    --display-name "Partner Logistics API" `
    --identifier-uris "api://partner-logistics-api" `
    --app-roles '[{
        "allowedMemberTypes": ["Application"],
        "description": "Partner access to logistics data",
        "displayName": "PartnerAccess",
        "id": "' + (New-Guid) + '",
        "isEnabled": true,
        "value": "PartnerAccess"
    }]'

# Create Service Principal
az ad sp create --id $apiApp.appId
```

**Grant partner apps access**:

```powershell
# Assign role to partner Service Principal
az ad app permission grant `
    --id $partnerAppId `
    --api $apiAppId `
    --scope "PartnerAccess"
```

**Get access token (partner app)**:

```powershell
# get-token.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ServicePrincipal  # fedex, acme, wh-east
)

$config = @{
    fedex = @{
        ClientId = "<fedex-app-id>"
        ClientSecret = "<fedex-secret>"
        PartnerId = "FEDEX"
    }
    acme = @{
        ClientId = "<acme-app-id>"
        ClientSecret = "<acme-secret>"
        PartnerId = "ACME"
    }
}

$tenantId = "<tenant-id>"
$scope = "api://partner-logistics-api/.default"

$body = @{
    grant_type = "client_credentials"
    client_id = $config[$ServicePrincipal].ClientId
    client_secret = $config[$ServicePrincipal].ClientSecret
    scope = $scope
    partner_id = $config[$ServicePrincipal].PartnerId
}

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Body $body

Write-Host "Access Token:"
Write-Host $response.access_token
```

---

### Lab 5: Test GraphQL API

**Query shipments (as FedEx)**:

```graphql
query GetFedExShipments {
  shipments(
    filters: { 
      startDate: "2025-01-01"
      endDate: "2025-01-31"
    }
    limit: 10
  ) {
    edges {
      node {
        id
        shipmentNumber
        shipDate
        deliveryDate
        carrier {
          name
        }
        customer {
          name
        }
        totalWeight
        onTimeDelivery
      }
    }
    pageInfo {
      hasNextPage
    }
    totalCount
  }
}
```

**Test with curl**:

```bash
# Get token
TOKEN=$(./get-token.ps1 -ServicePrincipal fedex)

# Query API
curl -X POST \
  https://apim-3pl-logistics.azure-api.net/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { shipments(limit: 5) { edges { node { shipmentNumber carrier { name } } } } }"
  }'
```

**Test with Postman**:
1. Create new POST request
2. URL: `https://apim-3pl-logistics.azure-api.net/graphql`
3. Headers: `Authorization: Bearer <token>`
4. Body (GraphQL): Paste query above
5. Send and verify only partner data returned

---

### Lab 6: Generate REST APIs from GraphQL

**APIM REST transformation**:

```xml
<!-- GET /api/shipments/{id} → GraphQL query -->
<policies>
  <inbound>
    <base />
    <set-variable name="shipmentId" 
                  value="@(context.Request.MatchedParameters["id"])" />
    <set-body>@{
      return new JObject(
        new JProperty("query", 
          "query GetShipment($id: ID!) { shipment(id: $id) { id shipmentNumber shipDate deliveryDate carrier { name } customer { name } totalWeight } }"
        ),
        new JProperty("variables", new JObject(
          new JProperty("id", context.Variables["shipmentId"])
        ))
      ).ToString();
    }</set-body>
    <rewrite-uri template="/graphql" />
  </inbound>
</policies>
```

**Test REST endpoint**:

```bash
# GET shipment by ID
curl -X GET \
  "https://apim-3pl-logistics.azure-api.net/api/shipments/SHIP-001234" \
  -H "Authorization: Bearer $TOKEN"

# GET shipments list
curl -X GET \
  "https://apim-3pl-logistics.azure-api.net/api/shipments?limit=10&startDate=2025-01-01" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📋 API Best Practices

**GraphQL Design**:
- ✅ Use proper type system
- ✅ Implement pagination (connections pattern)
- ✅ Add filtering and sorting
- ✅ Avoid N+1 queries with DataLoaders
- ✅ Version schema appropriately

**APIM Configuration**:
- ✅ Enable CORS for web apps
- ✅ Implement rate limiting per partner
- ✅ Log all requests for audit
- ✅ Cache common queries
- ✅ Monitor API usage

**Security**:
- ✅ Use OAuth2/OIDC
- ✅ Validate JWT tokens
- ✅ Extract identity from claims
- ✅ Apply RLS at data layer
- ✅ Rotate secrets regularly

---

## ✅ Module Completion

**Summary**: Built complete API layer with GraphQL, REST, OAuth2, and APIM

**Next**: [Module 7: Monitoring & Operations](../module-7-monitoring-operations/README.md) - Set up monitoring and dashboards

---

**[← Module 5](../module-5-security-governance/README.md)** | **[Home](../README.md)** | **[Module 7 →](../module-7-monitoring-operations/README.md)**
