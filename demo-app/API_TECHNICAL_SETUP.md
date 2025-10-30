# API Technical Setup - Real-Time Data Product with OneLake Security

## Architecture Overview

This demo implements a **governed Real-Time Data Product** powered by **Microsoft Fabric Real-Time Intelligence** and secured by **OneLake Security** (centralized Row-Level Security). The data product exposes SAP supply chain data to external partners via a secure GraphQL API, registered and monitored through **Microsoft Purview Unified Catalog**.

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Source System** | SAP ERP | Order management, shipment notifications |
| **Integration** | SAP IDocs → Azure Event Hubs | Real-time event streaming (<1 second) |
| **Real-Time Engine** | **Microsoft Fabric Real-Time Intelligence** | Sub-second streaming analytics via Eventhouse (KQL) |
| **Data Platform** | Microsoft Fabric Lakehouse | Delta tables with OneLake storage |
| **Security Layer** | **OneLake Security (RLS)** | Centralized Row-Level Security enforced at storage layer |
| **Data Governance** | Microsoft Purview Unified Catalog | Data product registry, lineage, quality monitoring |
| **API Layer** | Azure API Management (APIM) | API gateway with OAuth2, CORS, throttling |
| **Query Interface** | GraphQL (Fabric native) | Flexible, partner-specific queries (RLS auto-applied) |
| **Authentication** | Azure AD Service Principals | OAuth2 Client Credentials flow |
| **Authorization** | OneLake Row-Level Security | Identity-aware data filtering (all engines) |

### Data Product Characteristics

This is not just an API - it's a **governed data product** with:

- **Cataloging**: Registered in Purview with metadata, ownership, and SLA commitments
- **Lineage**: Full traceability from SAP IDocs to API responses
- **Quality Monitoring**: Automated checks for data freshness, completeness, and schema compliance
- **Access Governance**: Partner permissions managed centrally via OneLake Security
- **Versioning**: GraphQL schema evolution tracked with breaking change detection
- **Real-Time**: <3 second latency from SAP event to API availability (Fabric Real-Time Intelligence)
- **Unified Security**: OneLake RLS enforced across all Fabric engines (KQL, Spark, SQL, GraphQL, Power BI)

---

## Demo Application Screenshot

![Partner API Demo Application](screenshot.png)

*Screenshot showing the complete demo interface with:*
- **Top Section**: Three Service Principal authentication cards (FedEx Carrier, Warehouse Partner, ACME Customer)
- **Middle Section**: Real-time statistics (Shipments, Orders, Warehouse Data, SLA Records)
- **Bottom Section**: Four data tabs (Shipments, Orders, Warehouse, SLA Performance)
- **Connection Status**: Green banner showing "Connected: FedEx Carrier API"
- **Data Table**: Shipments in Transit with columns for Shipment #, Carrier, Origin, Destination, Status

*Notice: When connected as FedEx, only shipments assigned to FedEx carriers are visible due to Row-Level Security filtering.*

---

## Authentication & Security Flow

### 1. Service Principal Setup

Three Azure AD Service Principals created to represent external partners:

```yaml
FedEx (Carrier):
  App ID: 94a9edcc-7a22-4d89-b001-799e8414711a
  Object ID: fa86b10b-792c-495b-af85-bc8a765b44a1
  Secret: YOUR_FEDEX_SECRET_HERE
  Role: Fabric Contributor (scoped to specific workspace)

Warehouse Partner:
  App ID: 1de3dcee-f7eb-4701-8cd9-ed65f3792fe0
  Object ID: bf7ca9fa-eb65-4261-91f2-08d2b360e919
  Secret: YOUR_WAREHOUSE_SECRET_HERE
  Role: Fabric Contributor

ACME Corp (Customer):
  App ID: a3e88682-8bef-4712-9cc5-031d109cefca
  Object ID: efae8acd-de55-4c89-96b6-7f031a954ae6
  Secret: YOUR_ACME_SECRET_HERE
  Role: Fabric Contributor
```

### 2. OAuth2 Token Acquisition

Partners obtain access tokens via OAuth2 Client Credentials flow:

```powershell
# PowerShell example (get-token.ps1)
$clientId = "94a9edcc-7a22-4d89-b001-799e8414711a"  # FedEx
$clientSecret = "YOUR_FEDEX_SECRET_HERE"
$tenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
$scope = "https://analysis.windows.net/powerbi/api/.default"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = $scope
}

$response = Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Body $body

$token = $response.access_token  # Valid for 3599 seconds (1 hour)
```

### 3. API Call with Token

```javascript
// JavaScript example
const token = "eyJ0eXAiOiJKV1QiLCJhbGci..."; // From OAuth2 flow

fetch('https://apim-3pl-flt.azure-api.net/graphql', {
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        query: `
            query {
                gold_shipments_in_transits(first: 50) {
                    items {
                        shipment_number
                        carrier_id
                        customer_name
                        origin_location
                        destination_location
                        partner_access_scope
                    }
                }
            }
        `
    })
}).then(response => response.json())
  .then(data => console.log(data));
```

---

## Azure API Management Configuration

### APIM Instance Details

```yaml
Resource Group: rg-3pl-partner-api
APIM Name: apim-3pl-flt
Gateway URL: https://apim-3pl-flt.azure-api.net
Tier: Developer (upgradable to Standard/Premium)
Region: East US
```

### API Configuration

```yaml
API Name: graphql-partner-api
Path: /graphql
Backend: fabric-graphql-backend
Protocol: HTTPS only
Subscription: Not required (OAuth2 provides security)
```

### Critical: CORS Policy Configuration

**Problem Solved**: Browser-based applications (JavaScript) require CORS headers to make cross-origin requests. Without CORS, browsers block API calls with error: `"Failed to fetch"`.

**CORS Policy** (`cors-policy.xml`):

```xml
<policies>
    <inbound>
        <base />
        
        <!-- CORS for browser access -->
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>http://localhost:8000</origin>
                <origin>http://127.0.0.1:8000</origin>
                <origin>http://localhost:3000</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>PUT</method>
                <method>DELETE</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
            <expose-headers>
                <header>*</header>
            </expose-headers>
        </cors>
        
        <!-- Set the backend to Fabric GraphQL -->
        <set-backend-service backend-id="fabric-graphql-backend" />
        
        <!-- Ensure Content-Type is application/json -->
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        
        <!-- CRITICAL: Authorization header passthrough -->
        <!-- The OAuth2 Bearer token is forwarded to Fabric -->
        <!-- Fabric reads the token to determine partner identity for RLS -->
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Key Points**:
- **`allow-credentials="true"`**: Allows cookies and authorization headers
- **`<allowed-origins>`**: Whitelist of allowed domains (add production URLs before deployment)
- **Authorization Passthrough**: APIM forwards the token to Fabric without modification
- **GraphQL Backend**: `fabric-graphql-backend` points to Fabric workspace GraphQL endpoint

### How to Apply CORS Policy

**Option 1: Azure Portal** (Recommended for this demo):

1. Navigate to: Azure Portal → API Management → APIs → `graphql-partner-api`
2. Select "Design" tab → "All operations"
3. Click "Inbound processing" → "Code editor" (`</>` icon)
4. Paste the entire `cors-policy.xml` content
5. Click "Save"

**Option 2: Azure CLI** (Requires appropriate permissions):

```powershell
az rest --method PUT `
  --uri "/subscriptions/{subscription-id}/resourceGroups/rg-3pl-partner-api/providers/Microsoft.ApiManagement/service/apim-3pl-flt/apis/graphql-partner-api/policies/policy?api-version=2021-08-01" `
  --body "@cors-policy.xml"
```

---

## Microsoft Fabric Data Architecture

### Real-Time Intelligence & OneLake Security

This architecture leverages two key Fabric capabilities:

**1. Microsoft Fabric Real-Time Intelligence**

Enables sub-second streaming analytics from SAP to API:

- **Eventhouse (KQL Database)**: Purpose-built for real-time event streaming
- **Sub-second ingestion**: Event Hubs → Eventhouse in <1 second
- **KQL queries**: Ad-hoc real-time analytics on streaming data
- **Continuous mirroring**: Automatic sync to Lakehouse (OneLake)
- **No data movement**: Eventhouse and Lakehouse share OneLake storage
- **Real-time dashboards**: Monitor SAP events as they arrive

**2. OneLake Security (Centralized RLS)**

Enforces Row-Level Security at the **storage layer** for ALL Fabric engines:

- **Single Security Model**: RLS defined once in OneLake, enforced everywhere
- **Multi-Engine Support**: Same security across:
  - **Real-Time Intelligence** (KQL queries on Eventhouse)
  - **Data Engineering** (Spark notebooks, Data Factory pipelines)
  - **Data Warehouse** (SQL analytics engine, T-SQL queries)
  - **Power BI** (Direct Lake semantic models, reports)
  - **GraphQL API** (Partner API queries - THIS DEMO)
  - **OneLake API** (Direct file access via REST)

- **Identity-Aware**: Azure AD token → Service Principal → RLS context
- **Storage-Level Enforcement**: Security at Delta table level (impossible to bypass)
- **No Application Code**: Filtering logic in OneLake, not in GraphQL/API layer
- **Consistent Experience**: Partners see same filtered data in all tools

### Data Flow: SAP → Real-Time Intelligence → OneLake Security → API

```
SAP ERP
│
├─ IDoc ORDERS (Order creation/updates)
├─ IDoc SHPMNT (Shipment notifications)
├─ IDoc DESADV (Advanced shipping notices)
├─ IDoc WHSCON (Warehouse confirmations)
└─ IDoc INVOIC (Invoices)
    ↓ <1 second latency
┌─────────────────────────────────────────────────────────────────┐
│              Azure Event Hubs (eh-idoc-flt8076)                  │
│                  Topic: idoc-events (4 partitions)               │
│                  Real-time throughput: 1000+ events/sec          │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ Streaming ingestion
┌─────────────────────────────────────────────────────────────────┐
│         MICROSOFT FABRIC REAL-TIME INTELLIGENCE                  │
│                                                                  │
│  Eventhouse (KQL Database - Real-Time Analytics)                │
│  - Bronze Layer: idoc_raw_events (streaming ingestion)          │
│  - KQL queries for real-time monitoring                         │
│  - Sub-second query performance                                 │
│  - Continuous mirroring to OneLake (no data movement)           │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ Automatic sync via OneLake
┌─────────────────────────────────────────────────────────────────┐
│         MICROSOFT FABRIC LAKEHOUSE (OneLake Storage)             │
│                                                                  │
│  ═══════════════════════════════════════════════════════════   │
│  ONELAKE SECURITY LAYER - CENTRALIZED RLS                       │
│  ═══════════════════════════════════════════════════════════   │
│  Security enforced at STORAGE LAYER for ALL engines:            │
│    ✓ Real-Time Intelligence (Eventhouse KQL)                    │
│    ✓ Data Engineering (Spark, Pipelines)                        │
│    ✓ Data Warehouse (SQL analytics)                             │
│    ✓ Power BI (Direct Lake, semantic models)                    │
│    ✓ GraphQL API (Partner access - THIS DEMO)                   │
│    ✓ OneLake API (Direct file access)                           │
│                                                                  │
│  RLS Rules: partner_access_scope column filtering               │
│    - "CARRIER_CUSTOMER" → FedEx Service Principal               │
│    - "WAREHOUSE_PARTNER" → WH003 Service Principal              │
│    - "CUSTOMER" → ACME Service Principal                        │
│  ═══════════════════════════════════════════════════════════   │
│                                                                  │
│  Silver Layer: Cleaned & Enriched (partner metadata)            │
│  - idoc_orders_silver (partner_access_scope)                    │
│  - idoc_shipments_silver (carrier_id, customer_id)              │
│  - idoc_warehouse_silver (warehouse_partner_id)                 │
│                                                                  │
│  Gold Layer: Business Views (OneLake RLS auto-applied)          │
│  - gold_shipments_in_transits                                   │
│  - gold_orders_daily_summaries                                  │
│  - gold_warehouse_productivity_dailies                          │
│  - gold_sla_performances                                        │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ GraphQL API auto-generated from Delta tables
                         │ (OneLake RLS automatically enforced)
┌─────────────────────────────────────────────────────────────────┐
│              Fabric GraphQL Endpoint (Native)                    │
│  - Schema auto-derived from OneLake Delta tables                │
│  - RLS filtering applied BEFORE query execution                 │
│  - Partner identity extracted from Azure AD token               │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ Secured via APIM Gateway
┌─────────────────────────────────────────────────────────────────┐
│              Azure APIM (API Gateway)                            │
│  - Public endpoint: https://apim-3pl-flt.azure-api.net/graphql  │
│  - OAuth2 token validation (Azure AD)                           │
│  - CORS, throttling, monitoring                                 │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ Governed by
┌─────────────────────────────────────────────────────────────────┐
│         Microsoft Purview Unified Catalog                        │
│  - Data Product: "Partner Supply Chain API"                     │
│  - Lineage: SAP → Event Hubs → Eventhouse → Lakehouse → API    │
│  - Quality Metrics: Freshness (<3 sec), Completeness (>98%)     │
│  - Access Policies: OneLake RLS integration                     │
│  - Compliance Tags: PII detected, GDPR compliant                │
└────────────────────────┬────────────────────────────────────────┘
                         ↓ Consumed by Partners
        ┌────────────────┴────────────────┬──────────────────┐
        ↓                                 ↓                  ↓
   FedEx API                         WH003 API          ACME API
   (Carrier TMS)                    (Warehouse WMS)    (Customer ERP)
   Sees: Shipments                  Sees: Warehouse    Sees: Orders
   with carrier_id=FedEx            with warehouse=WH003  with customer=ACME
   (OneLake RLS filter)             (OneLake RLS filter)  (OneLake RLS filter)
```

### Data Governance with Purview Unified Catalog

#### Data Product Registration

The Partner Supply Chain API is registered as a **Data Product** in Purview:

**Metadata**:
- **Name**: Partner Supply Chain API
- **Domain**: Supply Chain & Logistics
- **Owner**: Logistics Operations Team (logistics@company.com)
- **Classification**: Confidential - Partner Data
- **SLA Commitments**:
  - Availability: 99.9% uptime
  - Latency: <500ms P95 response time
  - Freshness: <3 seconds from SAP event to API
  - Data Quality: >98% completeness

#### Automated Data Lineage

Purview automatically tracks data lineage:

1. **Source**: SAP ERP (IDoc generation)
2. **Ingestion**: Azure Event Hubs (idoc-events topic)
3. **Bronze Layer**: Eventhouse (idoc_raw_events table)
4. **Silver Layer**: Lakehouse (idoc_orders_silver, idoc_shipments_silver, etc.)
5. **Gold Layer**: Lakehouse (gold_shipments_in_transits, gold_orders_daily_summaries, etc.)
6. **API Layer**: Fabric GraphQL endpoint
7. **Exposure**: Azure APIM (https://apim-3pl-flt.azure-api.net/graphql)
8. **Consumption**: Partner systems (FedEx TMS, WH003 WMS, ACME ERP)

**Benefits**:
- Impact analysis: Know which partners are affected by schema changes
- Compliance audits: Prove data flow for GDPR, SOC2 certifications
- Root cause analysis: Trace data quality issues back to source

#### Data Quality Monitoring

Purview monitors quality metrics in real-time:

**Freshness**:
- **Metric**: Time delta between SAP event timestamp and API availability
- **Target**: <3 seconds
- **Alert**: Triggered if >10 seconds for 5 consecutive minutes

**Completeness**:
- **Metric**: % of required fields populated in gold tables
- **Target**: >98%
- **Alert**: Triggered if <95% for any 1-hour window

**Schema Compliance**:
- **Metric**: GraphQL schema matches published contract
- **Target**: No breaking changes without version increment
- **Alert**: Triggered on field removal or type change

**Access Audit**:
- **Metric**: Partner API calls logged with identity, query, timestamp
- **Target**: 100% audit coverage
- **Alert**: Triggered on suspicious patterns (rate limiting violations, unauthorized queries)

#### Compliance & Access Governance

**PII Detection**:
- Customer names, addresses flagged automatically
- Redaction policies applied for non-authorized consumers
- GDPR "right to be forgotten" workflows enabled

**Data Residency**:
- Event Hubs, Fabric, APIM all in same Azure region (compliance with EU/US data laws)
- Cross-region replication disabled for partner data

**Access Policies**:
- **FedEx**: Read-only access to shipments where `partner_access_scope = 'CARRIER_CUSTOMER'`
- **WH003**: Read-only access to warehouse data where `partner_access_scope = 'WAREHOUSE_PARTNER'`
- **ACME**: Read-only access to orders/shipments where `partner_access_scope = 'CUSTOMER'`

**Retention Policies**:
- Bronze layer (Eventhouse): 7 days
- Silver/Gold layers (Lakehouse): 2 years
- API audit logs (Azure Monitor): 90 days
- Purview lineage metadata: 5 years

### Row-Level Security Implementation via OneLake

**OneLake Security Model**:

Row-Level Security is enforced at the **OneLake storage layer**, providing unified security across ALL Fabric engines.

**RLS Column**: `partner_access_scope` (string)

**Values**:
- `"CARRIER_CUSTOMER"` → FedEx Service Principal sees records with this scope
- `"WAREHOUSE_PARTNER"` → WH003 Service Principal sees records with this scope
- `"CUSTOMER"` → ACME Service Principal sees records with this scope

**How OneLake RLS Works**:

1. Partner sends API request with Bearer token (Azure AD)
2. APIM forwards token to Fabric GraphQL endpoint
3. Fabric extracts Service Principal identity from token
4. **OneLake Security Layer** applies RLS filter BEFORE query execution
5. Query runs against filtered dataset (partner sees only their data)
6. Results returned through GraphQL → APIM → Partner

**Conceptual Logic** (handled by OneLake, not application code):

```sql
-- OneLake automatically adds this WHERE clause based on token identity
SELECT * FROM gold_shipments_in_transits
WHERE partner_access_scope = GetPartnerScopeFromToken()
```

**Key Benefits of OneLake Security**:

- **Centralized**: RLS defined once in OneLake, enforced everywhere
- **No Bypass**: Even direct Lakehouse/Warehouse queries respect RLS
- **Multi-Engine**: Same security for GraphQL, SQL, Spark, KQL, Power BI
- **No Code**: Filtering at storage layer, not in application logic
- **Identity-Aware**: Azure AD token automatically mapped to RLS context
- **Audit Trail**: All access logged with Service Principal identity
- **Performance**: RLS filter applied at Delta table scan (optimized)

**Why This Matters**:

Traditional approach: Implement filtering in EVERY query, API endpoint, report → error-prone, hard to maintain

OneLake approach: Define security ONCE at storage layer → automatically enforced across all access paths → zero trust, no gaps

---

## GraphQL Query Examples

### Shipments Query (Used by FedEx)

```graphql
query GetMyShipments {
  gold_shipments_in_transits(first: 50) {
    items {
      shipment_number
      carrier_id
      customer_id
      customer_name
      origin_location
      destination_location
      partner_access_scope
    }
  }
}
```

**FedEx Result** (only their shipments):

```json
{
  "data": {
    "gold_shipments_in_transits": {
      "items": [
        {
          "shipment_number": "SHIP123456",
          "carrier_id": "CARRIER-FEDEX-GROU",
          "customer_name": "ACME Corp",
          "origin_location": "Dallas, TX",
          "destination_location": "New York, NY",
          "partner_access_scope": "CARRIER_CUSTOMER"
        }
      ]
    }
  }
}
```

### Orders Query (Used by ACME)

```graphql
query GetMyOrders {
  gold_orders_daily_summaries(first: 50) {
    items {
      customer_id
      customer_name
      total_orders
      partner_access_scope
    }
  }
}
```

**ACME Result** (only their orders):

```json
{
  "data": {
    "gold_orders_daily_summaries": {
      "items": [
        {
          "customer_id": "CUST000042",
          "customer_name": "ACME Corp",
          "total_orders": 15,
          "partner_access_scope": "CUSTOMER"
        }
      ]
    }
  }
}
```

### Warehouse Query (Used by WH003)

```graphql
query GetMyWarehouseData {
  gold_warehouse_productivity_dailies(first: 50) {
    items {
      warehouse_id
      total_movements
      unique_operators
      partner_access_scope
    }
  }
}
```

**WH003 Result** (only their warehouse):

```json
{
  "data": {
    "gold_warehouse_productivity_dailies": {
      "items": [
        {
          "warehouse_id": "WH003",
          "total_movements": 247,
          "unique_operators": 12,
          "partner_access_scope": "WAREHOUSE_PARTNER"
        }
      ]
    }
  }
}
```

### SLA Performance Query (Used by All Partners)

```graphql
query GetSLAPerformance {
  gold_sla_performances(first: 50) {
    items {
      carrier_id
      carrier_name
      order_number
      customer_id
      sla_status
      sla_compliance
      processing_days
      on_time_delivery
      partner_access_scope
    }
  }
}
```

**Results Vary by Partner**:
- **FedEx**: Only SLA records for shipments they transported
- **ACME**: Only SLA records for their orders
- **WH003**: Only SLA records for orders fulfilled in their warehouse

---

## Demo Application Setup

### Prerequisites

1. **Python 3.8+** (for local HTTP server)
2. **PowerShell 5.1+** (for token acquisition script)
3. **Modern browser** (Chrome, Edge, Firefox with CORS support)
4. **Network access** to Azure APIM endpoint

### File Structure

```
demo-app/
├── index.html                    # Main UI (Service Principal cards + tabs)
├── get-token.ps1                 # OAuth2 token acquisition script
├── start-demo.ps1                # Launch local HTTP server
├── cors-policy.xml               # APIM CORS policy configuration
├── BUSINESS_SCENARIO.md          # Business context documentation
├── API_TECHNICAL_SETUP.md        # This file
└── js/
    ├── config.js                 # API endpoint + GraphQL queries
    ├── auth.js                   # Authentication flow
    ├── api.js                    # API calls with error handling
    └── app.js                    # UI logic and data rendering
```

### Running the Demo

**Step 1: Get Access Token**

```powershell
cd demo-app
.\get-token.ps1 -ServicePrincipal fedex
# Token automatically copied to clipboard
```

**Step 2: Start Application**

```powershell
.\start-demo.ps1
# Opens browser to http://localhost:8000
```

**Step 3: Connect as Partner**

1. Click "Connect" on desired partner card (FedEx, Warehouse, ACME)
2. Paste token when prompted (Ctrl+V)
3. Application fetches data from GraphQL API
4. View filtered results in tabs (Shipments, Orders, Warehouse, SLA)

**Step 4: Test Different Partners**

```powershell
# Get token for another partner
.\get-token.ps1 -ServicePrincipal warehouse
# OR
.\get-token.ps1 -ServicePrincipal acme

# Reconnect in browser with new token
# Notice different data returned due to RLS filtering
```

---

## Troubleshooting

### Issue: "Failed to fetch" Error in Browser

**Cause**: CORS not configured on APIM

**Solution**:
1. Apply `cors-policy.xml` to APIM API (see CORS section above)
2. Ensure `allow-credentials="true"` is set
3. Add your local dev URLs to `<allowed-origins>`

### Issue: "GraphQL Error: Field does not exist"

**Cause**: Query references fields not in Fabric table schema

**Solution**:
1. Test query directly in PowerShell:

```powershell
$token = Get-Clipboard
$query = 'query { gold_shipments_in_transits(first: 1) { items { shipment_number } } }'
$body = @{ query = $query } | ConvertTo-Json

Invoke-RestMethod -Uri 'https://apim-3pl-flt.azure-api.net/graphql' `
    -Method Post `
    -Headers @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' } `
    -Body $body
```

2. Update `config.js` with correct field names from Fabric schema

### Issue: 401 Unauthorized

**Cause**: Token expired or invalid

**Solution**:
- Tokens expire after 3599 seconds (1 hour)
- Generate new token: `.\get-token.ps1 -ServicePrincipal <partner>`
- Verify Service Principal has Fabric Contributor role on workspace

### Issue: Empty Results Despite Valid Token

**Cause**: No data matches partner's RLS scope

**Solution**:
- Verify `partner_access_scope` column populated in Fabric tables
- Check Service Principal Object ID matches expected scope value
- Query directly in Fabric to confirm data exists

---

## Monitoring & Observability

### APIM Analytics

Monitor API usage in Azure Portal:

- **Requests**: Total calls, success rate, error rate
- **Latency**: P50, P95, P99 response times
- **Authentication**: OAuth2 token validation metrics
- **Partners**: Breakdown by Service Principal (via token claims)

### Fabric Monitoring

Track data pipeline health:

- **Event Hubs**: Incoming IDoc message rate, lag
- **Eventhouse**: Query performance, storage usage
- **Lakehouse**: Table refresh rates, RLS policy hits

### Application Insights (Optional)

Add telemetry to demo app:

```javascript
appInsights.trackEvent({
    name: 'API_Call',
    properties: {
        partner: 'FedEx',
        query: 'gold_shipments_in_transits',
        recordCount: 50
    }
});
```

---

## Security Best Practices

### Production Deployment Checklist

- [ ] **Rotate Service Principal secrets** regularly (90-day cadence)
- [ ] **Enable APIM throttling** to prevent abuse (e.g., 100 requests/minute per partner)
- [ ] **Implement IP whitelisting** in APIM for known partner networks
- [ ] **Enable APIM request logging** to Azure Monitor for audit trail
- [ ] **Use Azure Key Vault** for storing Service Principal secrets (not in code)
- [ ] **Configure APIM policies** for request size limits (prevent DoS)
- [ ] **Enable Fabric audit logs** to track data access patterns
- [ ] **Implement GraphQL query depth limits** (prevent expensive nested queries)
- [ ] **Add rate limiting per Service Principal** in APIM
- [ ] **Use managed identities** where possible instead of Service Principal secrets

### CORS Production Configuration

**Development**:
```xml
<allowed-origins>
  <origin>http://localhost:8000</origin>
</allowed-origins>
```

**Production**:
```xml
<allowed-origins>
  <origin>https://partners.yourcompany.com</origin>
  <origin>https://api.yourcompany.com</origin>
</allowed-origins>
```

**Never Use in Production**:
```xml
<!-- DO NOT USE - Allows any origin -->
<allowed-origins>
  <origin>*</origin>
</allowed-origins>
```

---

## Additional Resources

### Microsoft Documentation

- [Azure API Management Policies](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [Microsoft Fabric GraphQL API](https://learn.microsoft.com/en-us/fabric/data-engineering/graphql-api)
- [Azure AD Service Principals](https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Row-Level Security in Fabric](https://learn.microsoft.com/en-us/fabric/security/service-admin-row-level-security)

### Demo Scripts

- **get-token.ps1**: OAuth2 token acquisition for Service Principals
- **start-demo.ps1**: Local HTTP server launcher
- **config.js**: API configuration and GraphQL queries

### Support Files

- **cors-policy.xml**: Complete APIM policy with CORS + GraphQL passthrough
- **BUSINESS_SCENARIO.md**: Business context for LinkedIn sharing
- **API_TECHNICAL_SETUP.md**: This technical documentation

---

*Last Updated: 2025-01-30*  
*Demo Version: 1.0*
