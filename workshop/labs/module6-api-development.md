# Module 6: GraphQL API Development and Testing

**Estimated Time:** 105 minutes  
**Difficulty:** Advanced  
**Prerequisites:** Modules 1-5 completed

## 🎯 Learning Objectives

By the end of this module, you will be able to:

- ✅ Understand GraphQL fundamentals and schema design
- ✅ Write and execute GraphQL queries and mutations
- ✅ Configure OAuth2 authentication for API access
- ✅ Test APIs using Postman and PowerShell
- ✅ Implement REST API alternatives to GraphQL
- ✅ Apply API development best practices
- ✅ Troubleshoot common API issues

## 📋 Prerequisites

Before starting this module, ensure you have:

- ✅ Completed Modules 1-5 (Lakehouse with Gold layer)
- ✅ GraphQL API enabled on your Lakehouse
- ✅ Azure API Management (APIM) deployed (optional for Module 6.5)
- ✅ Service Principals created for partner access
- ✅ Postman installed (or similar API testing tool)
- ✅ PowerShell 7+ or Azure CLI

## 📚 Module Overview

This module covers six key sections:

1. **GraphQL Fundamentals** - Understanding GraphQL concepts
2. **Schema Design Patterns** - Designing effective GraphQL schemas
3. **Query and Mutation Examples** - Practical query development
4. **Authentication and Authorization** - OAuth2 and RLS setup
5. **API Testing with Postman** - Hands-on API testing
6. **REST API Alternatives** - Building REST-style endpoints

---

## 1. GraphQL Fundamentals

### 1.1 What is GraphQL?

GraphQL is a query language for APIs and a runtime for executing those queries. Unlike REST APIs, GraphQL allows clients to request exactly the data they need.

**Key Concepts:**

- **Schema**: Defines available data types and operations
- **Query**: Read-only operations to fetch data
- **Mutation**: Write operations to modify data
- **Subscription**: Real-time data updates (not covered in this module)
- **Type System**: Strong typing for all data structures

**GraphQL vs REST:**

| Feature | GraphQL | REST |
|---------|---------|------|
| **Endpoints** | Single endpoint (`/graphql`) | Multiple endpoints (`/users`, `/orders`) |
| **Data Fetching** | Request specific fields | Fixed response structure |
| **Over-fetching** | No - client controls fields | Yes - server decides response |
| **Under-fetching** | No - single query gets all data | Yes - multiple requests often needed |
| **Versioning** | Schema evolution, no versions | URL versioning (`/v1`, `/v2`) |

### 1.2 GraphQL in Microsoft Fabric

Microsoft Fabric provides a **native GraphQL API** for Lakehouses and Warehouses:

- **Auto-generated schema** from Delta Lake tables
- **Table name pluralization** (e.g., `order` → `orders`)
- **Built-in pagination** with cursor-based navigation
- **Filtering and sorting** capabilities
- **Integration with Row-Level Security (RLS)**

**Architecture:**

```
Partner App
    ↓
Azure APIM (optional)
    ↓
Microsoft Fabric GraphQL API
    ↓
Lakehouse Gold Tables
    ↓
OneLake (Delta Lake)
```

### 1.3 Understanding the 3PL GraphQL Schema

Our 3PL data product exposes five main entity types:

1. **Shipments** - Carrier and customer tracking data
2. **Orders** - Customer order summaries
3. **Warehouse Movements** - Warehouse productivity metrics
4. **SLA Performance** - Carrier on-time delivery metrics
5. **Revenue Recognition** - Financial data

**Example Query Structure:**

```graphql
query {
  gold_shipments_in_transits(first: 10) {
    items {
      shipment_number
      carrier_id
      status
    }
  }
}
```

**Response Structure:**

```json
{
  "data": {
    "gold_shipments_in_transits": {
      "items": [
        {
          "shipment_number": "SHP001",
          "carrier_id": "CARRIER-FEDEX-GROU",
          "status": "IN_TRANSIT"
        }
      ]
    }
  }
}
```

---

## 2. Schema Design Patterns

### 2.1 Fabric Table Naming Convention

⚠️ **CRITICAL**: Fabric GraphQL **automatically pluralizes** table names.

| Lakehouse Table | GraphQL Query Name | Rule |
|----------------|-------------------|------|
| `gold_orders_daily_summary` | `gold_orders_daily_summaries` | `summary` → `summaries` |
| `gold_warehouse_productivity_daily` | `gold_warehouse_productivity_dailies` | `daily` → `dailies` |
| `gold_sla_performance` | `gold_sla_performances` | `performance` → `performances` |
| `gold_shipments_in_transit` | `gold_shipments_in_transits` | `transit` → `transits` |

**Common Mistakes:**

❌ `gold_orders_daily_summary` (singular)  
✅ `gold_orders_daily_summaries` (plural)

### 2.2 Schema Type System

Our 3PL GraphQL schema defines these core types:

**Shipment Type:**

```graphql
type Shipment {
  shipmentNumber: String!         # ! means required
  shipmentDate: DateTime!
  carrierCode: String!
  status: ShipmentStatus!         # Enum type
  estimatedDelivery: DateTime
  actualDelivery: DateTime
  transitTimeHours: Float
}
```

**Enum Types:**

```graphql
enum ShipmentStatus {
  PENDING_PICKUP
  IN_TRANSIT
  OUT_FOR_DELIVERY
  DELIVERED
  EXCEPTION
}
```

**Connection Pattern (Pagination):**

```graphql
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
  startCursor: String
  endCursor: String
}
```

### 2.3 Design Patterns for Business Scenarios

**Pattern 1: Partner-Scoped Queries**

All queries automatically filter by `partner_access_scope` using RLS:

```graphql
query GetMyShipments {
  gold_shipments_in_transits(first: 50) {
    items {
      shipment_number
      carrier_id
      # Only shipments accessible to authenticated partner
    }
  }
}
```

**Pattern 2: Date Range Filtering**

```graphql
query GetOrdersByPeriod {
  gold_orders_daily_summaries(
    first: 90
    filter: {
      order_date: {
        ge: "2025-01-01"    # Greater or equal
        le: "2025-03-31"    # Less or equal
      }
    }
  ) {
    items {
      order_date
      total_orders
      total_revenue
    }
  }
}
```

**Pattern 3: Multi-Field Filtering with AND/OR**

```graphql
query GetFilteredShipments {
  gold_shipments_in_transits(
    first: 100
    filter: {
      and: [
        { carrier_id: { eq: "CARRIER-FEDEX-GROU" } }
        { status: { eq: "IN_TRANSIT" } }
      ]
    }
  ) {
    items {
      shipment_number
      status
    }
  }
}
```

---

## 3. Query and Mutation Examples

### 3.1 Basic Queries

**Example 1: Get Recent Shipments**

```graphql
query GetRecentShipments {
  gold_shipments_in_transits(first: 20) {
    items {
      shipment_number
      carrier_id
      customer_name
      origin
      destination
      status
      estimated_delivery_date
    }
  }
}
```

**Example 2: Get Daily Order Metrics**

```graphql
query GetDailyOrders {
  gold_orders_daily_summaries(first: 30) {
    items {
      order_date
      total_orders
      total_lines
      total_revenue
      avg_order_value
    }
  }
}
```

**Example 3: Get Warehouse Productivity**

```graphql
query GetWarehouseMetrics {
  gold_warehouse_productivity_dailies(
    first: 50
    filter: { warehouse_partner_id: { eq: "PARTNER-WH003" } }
  ) {
    items {
      warehouse_id
      productivity_date
      total_shipments
      avg_processing_time
      fulfillment_rate
    }
  }
}
```

### 3.2 Advanced Filtering

**Comparison Operators:**

| Operator | Description | Example |
|----------|-------------|---------|
| `eq` | Equals | `{ carrier_id: { eq: "FEDEX" } }` |
| `ne` | Not equals | `{ status: { ne: "CANCELLED" } }` |
| `gt` | Greater than | `{ total_revenue: { gt: 1000 } }` |
| `ge` | Greater or equal | `{ order_date: { ge: "2025-01-01" } }` |
| `lt` | Less than | `{ avg_processing_time: { lt: 60 } }` |
| `le` | Less or equal | `{ event_date: { le: "2025-12-31" } }` |
| `contains` | Contains string | `{ customer_name: { contains: "ACME" } }` |
| `startsWith` | Starts with | `{ shipment_number: { startsWith: "SHP" } }` |

**Example: Complex Filter**

```graphql
query GetComplexFilter {
  gold_shipments_in_transits(
    first: 100
    filter: {
      and: [
        {
          or: [
            { carrier_id: { eq: "CARRIER-FEDEX-GROU" } }
            { carrier_id: { eq: "CARRIER-UPS" } }
          ]
        }
        { status: { ne: "CANCELLED" } }
        { ship_date: { ge: "2025-01-01" } }
      ]
    }
  ) {
    items {
      shipment_number
      carrier_id
      status
    }
  }
}
```

### 3.3 Pagination

**Cursor-Based Pagination:**

```graphql
query GetShipmentsPage1 {
  gold_shipments_in_transits(first: 50) {
    items {
      shipment_number
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

**Get Next Page:**

```graphql
query GetShipmentsPage2 {
  gold_shipments_in_transits(
    first: 50
    after: "cursor_value_from_page1"
  ) {
    items {
      shipment_number
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

### 3.4 Sorting

```graphql
query GetSortedOrders {
  gold_orders_daily_summaries(
    first: 30
    orderBy: { order_date: DESC }
  ) {
    items {
      order_date
      total_orders
      total_revenue
    }
  }
}
```

### 3.5 Mutations (Future Enhancement)

> ⚠️ **Note**: The current implementation is **read-only**. Mutations would require additional backend development.

**Conceptual Mutation Example:**

```graphql
mutation UpdateShipmentStatus {
  updateShipment(
    shipmentNumber: "SHP001"
    status: DELIVERED
    actualDelivery: "2025-10-30T14:30:00Z"
  ) {
    shipment {
      shipmentNumber
      status
      actualDelivery
    }
  }
}
```

---

## 4. Authentication and Authorization

### 4.1 OAuth2 Flow with Service Principals

**Authentication Architecture:**

```
1. Partner App → Azure AD: Request token
2. Azure AD → Partner App: Return JWT token
3. Partner App → APIM: Call API with Bearer token
4. APIM → Fabric GraphQL: Pass token (passthrough)
5. Fabric → OneLake: Apply RLS based on token
6. OneLake → Fabric: Return filtered data
7. Fabric → APIM → Partner: Return response
```

### 4.2 Getting an Access Token

**Using Azure CLI:**

```bash
# Login as Service Principal
az login --service-principal \
  -u <APP_ID> \
  -p <SECRET> \
  --tenant <TENANT_ID>

# Get token for Fabric
TOKEN=$(az account get-access-token \
  --resource "https://analysis.windows.net/powerbi/api" \
  --query accessToken -o tsv)

echo $TOKEN
```

**Using PowerShell:**

```powershell
# Login as Service Principal
az login --service-principal `
  -u 94a9edcc-7a22-4d89-b001-799e8414711a `
  -p <SECRET> `
  --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4

# Get token
$token = (az account get-access-token `
  --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

Write-Host "Token: $($token.Substring(0,20))..."
```

**Token Scope:**

⚠️ **CRITICAL**: Token must use scope `https://analysis.windows.net/powerbi/api`

❌ Wrong: `https://graph.microsoft.com`  
✅ Correct: `https://analysis.windows.net/powerbi/api`

### 4.3 Service Principal Setup

**Our 3PL Partners:**

| Partner | Type | App ID | Object ID (for RLS) |
|---------|------|--------|---------------------|
| FedEx | Carrier | `94a9edcc-7a22-4d89-b001-799e8414711a` | `fa86b10b-792c-495b-af85-bc8a765b44a1` |
| Warehouse | Warehouse | `1de3dcee-f7eb-4701-8cd9-ed65f3792fe0` | `bf7ca9fa-eb65-4261-91f2-08d2b360e919` |
| ACME | Customer | `a3e88682-8bef-4712-9cc5-031d109cefca` | `efae8acd-de55-4c89-96b6-7f031a954ae6` |

**Required Permissions in Fabric:**

1. **Workspace Access**: Viewer role
2. **GraphQL API Permission**: Execute permission
3. **RLS Role Assignment**: Mapped to appropriate partner role

### 4.4 Row-Level Security (RLS)

RLS ensures each partner sees only their data:

**How It Works:**

1. Service Principal authenticates and gets token
2. Token contains Object ID claim
3. Fabric GraphQL extracts Object ID from token
4. OneLake security layer applies RLS filter
5. Only rows matching `partner_access_scope` are returned

**Example RLS Logic:**

```sql
-- Conceptual RLS policy
WHERE partner_access_scope = <Object_ID_from_token>
  OR partner_access_scope LIKE '%' + <Object_ID_from_token> + '%'
```

**Testing RLS:**

```powershell
# Test as FedEx (should see FedEx shipments only)
az login --service-principal -u <FEDEX_APP_ID> -p <SECRET> --tenant <TENANT_ID>
$fedexToken = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Test as ACME (should see customer shipments only)
az login --service-principal -u <ACME_APP_ID> -p <SECRET> --tenant <TENANT_ID>
$acmeToken = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Compare results - should be different
```

---

## 5. API Testing with Postman

### 5.1 Postman Collection Setup

**Step 1: Import the Collection**

1. Download the collection: `workshop/postman/api-collection.json`
2. Open Postman
3. Click **Import** → **Upload Files**
4. Select `api-collection.json`

**Step 2: Configure Environment Variables**

Create a Postman environment with these variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `base_url` | `https://apim-3pl-flt.azure-api.net` | APIM base URL |
| `tenant_id` | `38de1b20-8309-40ba-9584-5d9fcb7203b4` | Azure AD tenant |
| `fedex_app_id` | `94a9edcc-7a22-4d89-b001-799e8414711a` | FedEx SP app ID |
| `fedex_secret` | `<secret>` | FedEx SP secret |
| `token` | (auto-populated) | Bearer token |

**Step 3: Get Token (Pre-request Script)**

Add this to collection-level pre-request script:

```javascript
// This is a placeholder - actual token must be obtained via Azure CLI
// Postman cannot directly authenticate Service Principals
console.log("Use Azure CLI to get token:");
console.log("az login --service-principal -u {{fedex_app_id}} -p {{fedex_secret}} --tenant {{tenant_id}}");
console.log("TOKEN=$(az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' --query accessToken -o tsv)");
```

> ⚠️ **Note**: Postman cannot directly get Azure SP tokens. Use Azure CLI or PowerShell to obtain tokens, then paste into Postman environment variable.

### 5.2 Test Cases in Postman

**Test 1: Get Shipments**

```
POST {{base_url}}/shipments
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "query": "query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id status } } }"
}
```

**Expected Result:** 200 OK with shipments array

**Test 2: Get Orders with Date Filter**

```
POST {{base_url}}/orders
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "query": "query { gold_orders_daily_summaries(first: 30, filter: { order_date: { ge: \"2025-01-01\" } }) { items { order_date total_orders total_revenue } } }"
}
```

**Test 3: Get Warehouse Productivity**

```
POST {{base_url}}/warehouse-productivity
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "query": "query { gold_warehouse_productivity_dailies(first: 20) { items { warehouse_id productivity_date total_shipments } } }"
}
```

**Test 4: Get SLA Performance**

```
POST {{base_url}}/sla-performance
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "query": "query { gold_sla_performances(first: 10) { items { carrier_id ontime_percentage late_shipments } } }"
}
```

### 5.3 Postman Tests Scripts

Add test assertions to validate responses:

```javascript
// Test script for shipments endpoint
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has data", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('data');
});

pm.test("Shipments array exists", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.data.gold_shipments_in_transits).to.have.property('items');
});

pm.test("Shipments count > 0", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.data.gold_shipments_in_transits.items.length).to.be.above(0);
});

pm.test("No GraphQL errors", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.not.have.property('errors');
});
```

### 5.4 PowerShell Testing Alternative

**Complete PowerShell Test Script:**

```powershell
# get-token-and-test.ps1

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('fedex', 'warehouse', 'acme')]
    [string]$Partner
)

# Partner credentials
$partners = @{
    fedex = @{
        AppId = "94a9edcc-7a22-4d89-b001-799e8414711a"
        Name = "FedEx Carrier"
    }
    warehouse = @{
        AppId = "1de3dcee-f7eb-4701-8cd9-ed65f3792fe0"
        Name = "Warehouse Partner"
    }
    acme = @{
        AppId = "a3e88682-8bef-4712-9cc5-031d109cefca"
        Name = "ACME Customer"
    }
}

$partnerInfo = $partners[$Partner]
Write-Host "`nTesting as: $($partnerInfo.Name)" -ForegroundColor Cyan

# Login and get token
az login --service-principal `
  -u $partnerInfo.AppId `
  -p $env:SP_SECRET `
  --tenant "38de1b20-8309-40ba-9584-5d9fcb7203b4"

$token = (az account get-access-token `
  --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Test shipments API
Write-Host "`nTesting Shipments API..." -ForegroundColor Yellow

$query = @{
  query = "query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id customer_name status } } }"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod `
      -Uri "https://apim-3pl-flt.azure-api.net/shipments" `
      -Method Post `
      -Headers @{
          "Authorization" = "Bearer $token"
          "Content-Type" = "application/json"
      } `
      -Body $query
    
    $items = $response.data.gold_shipments_in_transits.items
    Write-Host "✅ SUCCESS: Retrieved $($items.Count) shipments" -ForegroundColor Green
    
    if ($items.Count -gt 0) {
        Write-Host "`nFirst 3 shipments:" -ForegroundColor Cyan
        $items | Select-Object -First 3 | Format-Table
    }
} catch {
    Write-Host "❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
```

**Usage:**

```powershell
# Set secret in environment
$env:SP_SECRET = "<your-secret>"

# Test as FedEx
.\get-token-and-test.ps1 -Partner fedex

# Test as ACME
.\get-token-and-test.ps1 -Partner acme
```

---

## 6. REST API Alternatives

### 6.1 Why REST-Style Endpoints?

While GraphQL is powerful, some scenarios benefit from REST-style APIs:

- **Simpler integration** for partners unfamiliar with GraphQL
- **Fixed response format** for consistent processing
- **OpenAPI/Swagger documentation** compatibility
- **Easier caching** at CDN/proxy layer

### 6.2 REST Endpoints via APIM

Azure APIM allows creating REST-style endpoints that call GraphQL backend:

**Endpoint Design:**

| REST Endpoint | GraphQL Query | Purpose |
|---------------|---------------|---------|
| `POST /shipments` | `gold_shipments_in_transits` | Get shipments |
| `POST /orders` | `gold_orders_daily_summaries` | Get orders |
| `POST /warehouse-productivity` | `gold_warehouse_productivity_dailies` | Get warehouse data |
| `POST /sla-performance` | `gold_sla_performances` | Get SLA metrics |
| `POST /revenue` | `gold_revenue_recognition_realtimes` | Get revenue data |

**Why POST instead of GET?**

- GraphQL queries are sent in request body
- APIM Developer SKU limitations with GET transformations
- Consistent with GraphQL convention

### 6.3 APIM Policy for REST Wrapper

**Simplified REST API Policy:**

```xml
<policies>
    <inbound>
        <base />
        <!-- No transformation - passthrough to GraphQL -->
        <set-backend-service 
            base-url="https://[workspace].graphql.fabric.microsoft.com/v1/workspaces/[workspace-id]/graphqlapis/[api-id]/graphql" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <!-- Optional: Extract items array for simpler response -->
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

### 6.4 Creating REST Endpoints in APIM

**Using Azure CLI:**

```bash
# Create REST-style API that calls GraphQL backend
az apim api create \
  --resource-group rg-3pl-partner-api \
  --service-name apim-3pl-flt \
  --api-id shipments-api \
  --path shipments \
  --display-name "Shipments API" \
  --protocols https \
  --service-url "https://[fabric-graphql-url]"

# Add POST operation
az apim api operation create \
  --resource-group rg-3pl-partner-api \
  --service-name apim-3pl-flt \
  --api-id shipments-api \
  --url-template "/" \
  --method POST \
  --display-name "Get Shipments"
```

### 6.5 REST vs GraphQL Comparison

**REST Example (POST /shipments):**

```bash
curl -X POST https://apim-3pl-flt.azure-api.net/shipments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gold_shipments_in_transits(first: 10) { items { shipment_number } } }"}'
```

**GraphQL Example (POST /graphql):**

```bash
curl -X POST https://apim-3pl-flt.azure-api.net/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gold_shipments_in_transits(first: 10) { items { shipment_number } } }"}'
```

**Result:** Both return the same GraphQL response!

The difference is **conceptual**:
- `/shipments` implies a shipments-only endpoint (REST)
- `/graphql` is explicit about using GraphQL syntax

---

## 7. Best Practices

### 7.1 Query Design Best Practices

✅ **DO:**

- Request only the fields you need
- Use pagination for large datasets
- Apply filters at query level (not in app code)
- Use named queries for clarity
- Handle `pageInfo.hasNextPage` for complete data retrieval

❌ **DON'T:**

- Request all fields when you only need a few
- Fetch all records without pagination
- Filter results in application code
- Use inline queries in production (use named queries)
- Ignore GraphQL errors in responses

**Good Query:**

```graphql
query GetActiveShipments {
  gold_shipments_in_transits(
    first: 50
    filter: { status: { eq: "IN_TRANSIT" } }
  ) {
    items {
      shipment_number
      carrier_id
      estimated_delivery_date
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

**Bad Query:**

```graphql
query {
  gold_shipments_in_transits(first: 10000) {
    items {
      shipment_number
      carrier_id
      customer_id
      customer_name
      origin
      destination
      status
      ship_date
      estimated_delivery_date
      actual_delivery_date
      partner_access_scope
      # ... requesting all fields unnecessarily
    }
  }
}
```

### 7.2 Authentication Best Practices

✅ **DO:**

- Store secrets in Azure Key Vault
- Use short-lived tokens (refresh before expiry)
- Validate token scope before making requests
- Implement token caching in your app
- Use HTTPS for all API calls

❌ **DON'T:**

- Hard-code secrets in source code
- Share Service Principal credentials across teams
- Use expired tokens
- Send tokens in URL query parameters
- Expose tokens in client-side code

**Token Management Pattern:**

```powershell
function Get-FabricToken {
    param([string]$AppId, [string]$Secret)
    
    # Check if cached token is still valid
    if ($script:CachedToken -and $script:TokenExpiry -gt (Get-Date)) {
        return $script:CachedToken
    }
    
    # Get new token
    az login --service-principal -u $AppId -p $Secret --tenant $TenantId
    $tokenResponse = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
    
    # Cache token and expiry
    $script:CachedToken = $tokenResponse.accessToken
    $script:TokenExpiry = [DateTime]::Parse($tokenResponse.expiresOn)
    
    return $script:CachedToken
}
```

### 7.3 Error Handling Best Practices

**Handle GraphQL Errors:**

```javascript
// Node.js example
async function queryFabricAPI(query) {
    const response = await fetch('https://apim-3pl-flt.azure-api.net/graphql', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query })
    });
    
    const result = await response.json();
    
    // Check for GraphQL errors
    if (result.errors) {
        console.error('GraphQL errors:', result.errors);
        throw new Error(`GraphQL error: ${result.errors[0].message}`);
    }
    
    // Check for HTTP errors
    if (!response.ok) {
        throw new Error(`HTTP error ${response.status}: ${response.statusText}`);
    }
    
    return result.data;
}
```

**PowerShell Error Handling:**

```powershell
try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
    
    if ($response.errors) {
        Write-Error "GraphQL errors: $($response.errors | ConvertTo-Json)"
        return
    }
    
    return $response.data
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    
    switch ($statusCode) {
        401 { Write-Error "Unauthorized: Token invalid or expired" }
        403 { Write-Error "Forbidden: Insufficient permissions" }
        404 { Write-Error "Not Found: API endpoint doesn't exist" }
        500 { Write-Error "Server Error: Invalid GraphQL query or backend error" }
        default { Write-Error "Error $statusCode: $_" }
    }
}
```

### 7.4 Performance Best Practices

✅ **DO:**

- Use `first` parameter to limit results
- Implement cursor-based pagination
- Cache frequently accessed data
- Use APIM caching policies (when appropriate)
- Monitor query performance

❌ **DON'T:**

- Fetch thousands of records in a single query
- Make sequential requests that could be combined
- Skip pagination for large datasets
- Ignore slow query warnings

**Efficient Pagination:**

```javascript
async function getAllShipments() {
    let allShipments = [];
    let cursor = null;
    let hasNextPage = true;
    
    while (hasNextPage) {
        const query = `
            query {
                gold_shipments_in_transits(first: 100${cursor ? `, after: "${cursor}"` : ''}) {
                    items { shipment_number carrier_id }
                    pageInfo { hasNextPage endCursor }
                }
            }
        `;
        
        const result = await queryFabricAPI(query);
        const data = result.gold_shipments_in_transits;
        
        allShipments.push(...data.items);
        hasNextPage = data.pageInfo.hasNextPage;
        cursor = data.pageInfo.endCursor;
    }
    
    return allShipments;
}
```

### 7.5 Security Best Practices

✅ **DO:**

- Validate all user inputs
- Use RLS to enforce data access
- Audit API access logs
- Rotate Service Principal secrets regularly
- Implement rate limiting

❌ **DON'T:**

- Trust client-side filtering
- Expose internal Object IDs to users
- Log authentication tokens
- Skip input validation

**Input Validation Example:**

```powershell
function Test-GraphQLQuery {
    param([string]$Query)
    
    # Validate query doesn't contain malicious patterns
    if ($Query -match '(__schema|__type|introspection)') {
        throw "Schema introspection is disabled"
    }
    
    # Limit query complexity
    if (($Query -split "`n").Count -gt 50) {
        throw "Query too complex (max 50 lines)"
    }
    
    return $true
}
```

---

## 8. Troubleshooting

### 8.1 Common Issues and Solutions

#### Issue 1: 401 Unauthorized

**Symptoms:** API returns 401 error

**Possible Causes:**
- Token is expired
- Token has wrong scope
- Service Principal not authenticated

**Solutions:**

```powershell
# Check token expiry
$tokenObj = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json
Write-Host "Token expires at: $($tokenObj.expiresOn)"

# Get fresh token
az login --service-principal -u $appId -p $secret --tenant $tenantId
$newToken = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken
```

#### Issue 2: 403 Forbidden

**Symptoms:** API returns 403 error

**Possible Causes:**
- Service Principal lacks workspace access
- Service Principal lacks GraphQL API permission
- RLS denies access to all data

**Solutions:**

1. Check Workspace access:
   - Open Fabric workspace
   - Go to **Manage access**
   - Verify Service Principal has **Viewer** role (minimum)

2. Check GraphQL API permission:
   - Open Lakehouse
   - Go to GraphQL API settings
   - Verify Service Principal has **Execute** permission

#### Issue 3: 404 Not Found

**Symptoms:** API returns 404 error

**Possible Causes:**
- API endpoint doesn't exist
- Wrong base URL
- APIM not configured correctly

**Solutions:**

```powershell
# Test direct Fabric GraphQL endpoint (bypass APIM)
$fabricUrl = "https://[workspace].graphql.fabric.microsoft.com/v1/workspaces/[workspace-id]/graphqlapis/[api-id]/graphql"

Invoke-RestMethod -Uri $fabricUrl -Method Post `
  -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
  -Body '{"query":"query { gold_shipments_in_transits(first: 1) { items { shipment_number } } }"}'
```

#### Issue 4: GraphQL Errors - Invalid Field

**Symptoms:** Response contains GraphQL error: "field does not exist"

**Cause:** Table name not pluralized

**Solution:**

```graphql
# ❌ Wrong
query {
  gold_orders_daily_summary(first: 10) {
    items { order_date }
  }
}

# ✅ Correct
query {
  gold_orders_daily_summaries(first: 10) {
    items { order_date }
  }
}
```

#### Issue 5: Empty Results (RLS Filtering All Data)

**Symptoms:** Query succeeds but returns 0 items

**Possible Causes:**
- RLS is filtering out all data
- Service Principal Object ID not in RLS roles
- No data matches the filter criteria

**Solutions:**

```powershell
# Verify Object ID
$objectId = az ad sp show --id $appId --query id -o tsv
Write-Host "Service Principal Object ID: $objectId"

# Check if Object ID exists in gold table partner_access_scope column
# (This requires direct database access or Power BI to query)
```

#### Issue 6: Timeout Errors

**Symptoms:** Request times out after 30+ seconds

**Possible Causes:**
- Query too complex
- Fetching too many records
- Lakehouse compute is slow

**Solutions:**

- Reduce `first` parameter (e.g., 100 instead of 10000)
- Add more specific filters
- Use pagination
- Check Fabric capacity utilization

### 8.2 Debugging Tools

**1. Test Direct GraphQL Endpoint:**

```powershell
# Bypass APIM to isolate issues
$fabricUrl = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"

Invoke-RestMethod -Uri $fabricUrl -Method Post `
  -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
  -Body '{"query":"query { __schema { queryType { name } } }"}' # Introspection query
```

**2. Inspect Token Claims:**

```powershell
# Decode JWT token (header.payload.signature)
$token = "eyJ0eXAiOiJKV1..."
$payload = $token.Split('.')[1]

# Add padding if needed
while ($payload.Length % 4 -ne 0) { $payload += "=" }

# Decode Base64
$bytes = [Convert]::FromBase64String($payload)
$jsonPayload = [System.Text.Encoding]::UTF8.GetString($bytes)

# Display claims
$jsonPayload | ConvertFrom-Json | ConvertTo-Json
```

**3. Enable APIM Tracing:**

```powershell
# Add Ocp-Apim-Trace header to request
Invoke-RestMethod -Uri "https://apim-3pl-flt.azure-api.net/graphql" -Method Post `
  -Headers @{
      "Authorization" = "Bearer $token"
      "Content-Type" = "application/json"
      "Ocp-Apim-Trace" = "true"
      "Ocp-Apim-Subscription-Key" = "trace-key" # Get from APIM portal
  } `
  -Body '{"query":"query { gold_shipments_in_transits(first: 1) { items { shipment_number } } }"}'
```

**4. Check APIM Logs:**

- Go to Azure Portal → APIM instance
- **Monitoring** → **Logs**
- Query recent requests:

```kusto
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where Url contains "graphql"
| project TimeGenerated, Method, Url, ResponseCode, ResponseSize
| order by TimeGenerated desc
```

### 8.3 Testing Checklist

Before reporting an issue, verify:

- [ ] Token is valid and not expired
- [ ] Token scope is `https://analysis.windows.net/powerbi/api`
- [ ] Service Principal has Viewer role on workspace
- [ ] Service Principal has Execute permission on GraphQL API
- [ ] Table names are pluralized correctly
- [ ] GraphQL query syntax is valid
- [ ] Request uses POST method
- [ ] Content-Type header is `application/json`
- [ ] Authorization header format is `Bearer <token>`
- [ ] API endpoint URL is correct

---

## 9. Hands-On Exercises

### Exercise 1: Build Your First Query (15 min)

**Objective:** Write and test a basic GraphQL query

**Tasks:**
1. Get a token for FedEx Service Principal
2. Write a query to get the 10 most recent shipments
3. Include these fields: shipment_number, carrier_id, status, estimated_delivery_date
4. Execute the query using PowerShell or Postman
5. Verify you receive shipments data

**Solution:**

```powershell
# Get token
az login --service-principal -u <FEDEX_APP_ID> -p <SECRET> --tenant <TENANT_ID>
$token = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Query
$query = @{
  query = @"
    query GetRecentShipments {
      gold_shipments_in_transits(first: 10) {
        items {
          shipment_number
          carrier_id
          status
          estimated_delivery_date
        }
      }
    }
"@
} | ConvertTo-Json

# Execute
Invoke-RestMethod -Uri "https://apim-3pl-flt.azure-api.net/graphql" `
  -Method Post `
  -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
  -Body $query
```

### Exercise 2: Apply Filters (15 min)

**Objective:** Use filtering to narrow results

**Tasks:**
1. Query shipments where status = "IN_TRANSIT"
2. Add a date filter for ship_date >= "2025-01-01"
3. Sort by estimated_delivery_date (ascending)
4. Return only 20 results

**Solution:**

```graphql
query GetFilteredShipments {
  gold_shipments_in_transits(
    first: 20
    filter: {
      and: [
        { status: { eq: "IN_TRANSIT" } }
        { ship_date: { ge: "2025-01-01" } }
      ]
    }
    orderBy: { estimated_delivery_date: ASC }
  ) {
    items {
      shipment_number
      carrier_id
      ship_date
      estimated_delivery_date
    }
  }
}
```

### Exercise 3: Implement Pagination (20 min)

**Objective:** Retrieve all shipments using pagination

**Tasks:**
1. Write a script that fetches all shipments in batches of 50
2. Use cursor-based pagination
3. Continue until `hasNextPage` is false
4. Print total count of shipments retrieved

**Solution:**

```powershell
$allShipments = @()
$cursor = $null
$hasNextPage = $true

while ($hasNextPage) {
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }
    
    $query = @{
        query = "query { gold_shipments_in_transits(first: 50$afterClause) { items { shipment_number } pageInfo { hasNextPage endCursor } } }"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "https://apim-3pl-flt.azure-api.net/graphql" `
      -Method Post -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
      -Body $query
    
    $data = $response.data.gold_shipments_in_transits
    $allShipments += $data.items
    $hasNextPage = $data.pageInfo.hasNextPage
    $cursor = $data.pageInfo.endCursor
    
    Write-Host "Fetched $($data.items.Count) shipments (Total: $($allShipments.Count))"
}

Write-Host "`nTotal shipments retrieved: $($allShipments.Count)" -ForegroundColor Green
```

### Exercise 4: Test RLS (20 min)

**Objective:** Verify Row-Level Security is working

**Tasks:**
1. Get token for FedEx Service Principal
2. Query shipments and note the results
3. Get token for ACME Service Principal
4. Query shipments with same query
5. Compare results - they should be different

**Solution:**

```powershell
function Test-PartnerRLS {
    param($AppId, $Secret, $PartnerName)
    
    az login --service-principal -u $AppId -p $Secret --tenant $TenantId
    $token = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken
    
    $query = @{ query = "query { gold_shipments_in_transits(first: 100) { items { shipment_number carrier_id customer_name } } }" } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "https://apim-3pl-flt.azure-api.net/graphql" `
      -Method Post -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
      -Body $query
    
    $items = $response.data.gold_shipments_in_transits.items
    
    Write-Host "`n$PartnerName Results:" -ForegroundColor Cyan
    Write-Host "  Total shipments: $($items.Count)"
    Write-Host "  Unique carriers: $(($items.carrier_id | Select-Object -Unique).Count)"
    Write-Host "  Unique customers: $(($items.customer_name | Select-Object -Unique).Count)"
}

# Test both partners
Test-PartnerRLS -AppId "<FEDEX_APP_ID>" -Secret "<SECRET>" -PartnerName "FedEx"
Test-PartnerRLS -AppId "<ACME_APP_ID>" -Secret "<SECRET>" -PartnerName "ACME"
```

### Exercise 5: Error Handling (15 min)

**Objective:** Implement robust error handling

**Tasks:**
1. Create a function that queries the API
2. Handle HTTP errors (401, 403, 404, 500)
3. Handle GraphQL errors
4. Test with intentional errors (wrong table name, expired token)

**Solution:**

```powershell
function Invoke-FabricGraphQL {
    param(
        [string]$Query,
        [string]$Token,
        [string]$Endpoint = "https://apim-3pl-flt.azure-api.net/graphql"
    )
    
    try {
        $body = @{ query = $Query } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri $Endpoint -Method Post `
          -Headers @{"Authorization" = "Bearer $Token"; "Content-Type" = "application/json"} `
          -Body $body -ErrorAction Stop
        
        # Check for GraphQL errors
        if ($response.errors) {
            Write-Error "GraphQL Error: $($response.errors[0].message)"
            return $null
        }
        
        return $response.data
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        switch ($statusCode) {
            401 { Write-Error "Authentication failed: Token invalid or expired" }
            403 { Write-Error "Access denied: Insufficient permissions" }
            404 { Write-Error "Endpoint not found: Check API URL" }
            500 { Write-Error "Server error: Invalid query syntax or backend issue" }
            default { Write-Error "HTTP $statusCode : $($_.Exception.Message)" }
        }
        
        return $null
    }
}

# Test with valid query
$data = Invoke-FabricGraphQL -Query "query { gold_shipments_in_transits(first: 1) { items { shipment_number } } }" -Token $token

# Test with invalid table name
$data = Invoke-FabricGraphQL -Query "query { invalid_table_name(first: 1) { items { field } } }" -Token $token
```

---

## 10. Next Steps and Resources

### 10.1 Congratulations! 🎉

You've completed Module 6 and now have the skills to:

✅ Design and query GraphQL APIs  
✅ Implement OAuth2 authentication  
✅ Test APIs using multiple tools  
✅ Apply security best practices  
✅ Troubleshoot common API issues

### 10.2 Next Steps

1. **Deploy to Production**
   - Upgrade APIM to Standard or Premium SKU
   - Configure rate limiting and throttling
   - Set up Application Insights monitoring
   - Document APIs for partner developers

2. **Enhance APIs**
   - Add response transformation policies
   - Implement caching for read-heavy queries
   - Create developer portal for partners
   - Add webhook notifications for events

3. **Advanced Topics**
   - Implement mutations for write operations
   - Add GraphQL subscriptions for real-time updates
   - Integrate with Power BI Embedded
   - Set up multi-region deployment

### 10.3 Additional Resources

**Microsoft Fabric:**
- [Fabric GraphQL Documentation](https://learn.microsoft.com/fabric/data-engineering/graphql-api)
- [OneLake Security](https://learn.microsoft.com/fabric/onelake/security/overview)
- [Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)

**GraphQL:**
- [GraphQL Official Documentation](https://graphql.org/learn/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [Apollo GraphQL Tutorials](https://www.apollographql.com/tutorials/)

**Azure API Management:**
- [APIM Documentation](https://learn.microsoft.com/azure/api-management/)
- [APIM Policies Reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [APIM Security Best Practices](https://learn.microsoft.com/azure/api-management/api-management-security-controls)

**Authentication:**
- [Azure AD Service Principals](https://learn.microsoft.com/entra/identity-platform/app-objects-and-service-principals)
- [OAuth 2.0 in Azure AD](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-client-creds-grant-flow)

### 10.4 Sample Code Repository

All sample code from this module is available in:

- **GraphQL Queries**: `/workshop/samples/graphql-queries.graphql`
- **Postman Collection**: `/workshop/postman/api-collection.json`
- **PowerShell Scripts**: `/demo-app/test-api.ps1`

### 10.5 Workshop Feedback

We'd love to hear your feedback!

- What worked well?
- What could be improved?
- What topics should we add?

Share your thoughts: [GitHub Discussions](https://github.com/flthibau/Fabric-SAP-Idocs/discussions)

---

## Appendix A: Quick Reference

### GraphQL Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `eq` | `{ status: { eq: "DELIVERED" } }` | Equals |
| `ne` | `{ status: { ne: "CANCELLED" } }` | Not equals |
| `gt` | `{ total_revenue: { gt: 1000 } }` | Greater than |
| `ge` | `{ order_date: { ge: "2025-01-01" } }` | Greater or equal |
| `lt` | `{ delay_hours: { lt: 24 } }` | Less than |
| `le` | `{ event_date: { le: "2025-12-31" } }` | Less or equal |
| `contains` | `{ name: { contains: "ACME" } }` | Contains substring |
| `startsWith` | `{ shipment_number: { startsWith: "SHP" } }` | Starts with |

### HTTP Status Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 200 | OK | Successful request |
| 401 | Unauthorized | Invalid or expired token |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | API endpoint doesn't exist |
| 500 | Server Error | Invalid GraphQL syntax or backend error |

### PowerShell Quick Commands

```powershell
# Get token
$token = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Test API
Invoke-RestMethod -Uri "https://apim-3pl-flt.azure-api.net/graphql" -Method Post `
  -Headers @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"} `
  -Body '{"query":"query { gold_shipments_in_transits(first: 10) { items { shipment_number } } }"}'

# Decode token claims
$payload = $token.Split('.')[1]
while ($payload.Length % 4 -ne 0) { $payload += "=" }
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
```

---

## Appendix B: GraphQL Schema Reference

See complete schema: `/api/graphql/schema/partner-api.graphql`

**Main Query Types:**

- `gold_shipments_in_transits` - Shipment tracking
- `gold_orders_daily_summaries` - Order metrics
- `gold_warehouse_productivity_dailies` - Warehouse KPIs
- `gold_sla_performances` - Carrier SLA metrics
- `gold_revenue_recognition_realtimes` - Revenue data

**Common Fields:**

```graphql
type Shipment {
  shipment_number: String!
  carrier_id: String!
  customer_name: String!
  status: ShipmentStatus!
  estimated_delivery_date: DateTime
}

enum ShipmentStatus {
  PENDING_PICKUP
  IN_TRANSIT
  OUT_FOR_DELIVERY
  DELIVERED
  EXCEPTION
}
```

---

**Module 6 Complete!** 🎓

You are now ready to build, deploy, and manage GraphQL APIs with Microsoft Fabric!

**Previous Module:** [Module 5 - Security and RLS](./module5-security-rls.md)  
**Workshop Home:** [README](../README.md)

---

**Last Updated:** November 2024  
**Version:** 1.0  
**Author:** Florent Thibault, Microsoft
