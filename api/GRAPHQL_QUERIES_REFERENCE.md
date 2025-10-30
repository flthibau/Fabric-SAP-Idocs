# GraphQL Queries Reference - 3PL Partner APIs

## Overview

This document provides tested and validated GraphQL queries for all Partner APIs. All queries have been tested against the Fabric GraphQL API and work correctly.

> **Last Updated**: 2025-10-30  
> **Fabric GraphQL API**: `2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f`  
> **Workspace**: `ad53e547-23dc-46b0-ab5f-2acbaf0eec64`

## ⚠️ CRITICAL: Table Name Convention

Fabric GraphQL **automatically pluralizes** all table names. You must use the plural form in queries.

| Lakehouse Table Name | GraphQL Query Name | Rule |
|---------------------|-------------------|------|
| `gold_orders_daily_summary` | `gold_orders_daily_summaries` | summary → summaries |
| `gold_warehouse_productivity_daily` | `gold_warehouse_productivity_dailies` | daily → dailies |
| `gold_sla_performance` | `gold_sla_performances` | performance → performances |
| `gold_revenue_recognition_realtime` | `gold_revenue_recognition_realtimes` | realtime → realtimes |
| `gold_shipments_in_transit` | `gold_shipments_in_transits` | transit → transits |

## API Endpoints

All APIs use **POST** method with GraphQL query in request body.

```bash
# Base URL
https://apim-3pl-flt.azure-api.net

# Endpoints
POST /graphql                  # Any GraphQL query
POST /shipments                # Shipments data
POST /orders                   # Orders metrics
POST /warehouse-productivity   # Warehouse KPIs
POST /sla-performance         # Carrier SLA metrics
POST /revenue                 # Revenue recognition data
```

## Request Format

All requests must include:

```http
POST https://apim-3pl-flt.azure-api.net/{endpoint}
Authorization: Bearer <SP_TOKEN>
Content-Type: application/json

{
  "query": "query { ... }"
}
```

## 1. Shipments Queries

### Basic Shipments Query

```graphql
query {
  gold_shipments_in_transits(first: 10) {
    items {
      shipment_number
      carrier_id
      status
      origin
      destination
    }
  }
}
```

### Complete Shipments Query (All Fields)

```graphql
query {
  gold_shipments_in_transits(first: 100) {
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
    }
  }
}
```

### Shipments with Filtering

```graphql
query {
  gold_shipments_in_transits(
    first: 50
    filter: { carrier_id: { eq: "CARRIER-FEDEX-GROU" } }
  ) {
    items {
      shipment_number
      carrier_id
      status
      estimated_delivery_date
    }
  }
}
```

**APIM Usage**:

```bash
POST https://apim-3pl-flt.azure-api.net/shipments
Authorization: Bearer <FEDEX_SP_TOKEN>
Content-Type: application/json

{
  "query": "query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id status } } }"
}
```

## 2. Orders Queries

### Basic Orders Query

```graphql
query {
  gold_orders_daily_summaries(first: 30) {
    items {
      order_date
      total_orders
      total_revenue
    }
  }
}
```

### Complete Orders Query (All Fields)

```graphql
query {
  gold_orders_daily_summaries(first: 100) {
    items {
      order_date
      total_orders
      total_lines
      total_revenue
      avg_order_value
      partner_access_scope
    }
  }
}
```

### Orders with Date Range

```graphql
query {
  gold_orders_daily_summaries(
    first: 90
    filter: { 
      order_date: { 
        ge: "2025-01-01",
        le: "2025-03-31"
      } 
    }
  ) {
    items {
      order_date
      total_orders
      total_revenue
      avg_order_value
    }
  }
}
```

**APIM Usage**:

```bash
POST https://apim-3pl-flt.azure-api.net/orders
Authorization: Bearer <ACME_SP_TOKEN>
Content-Type: application/json

{
  "query": "query { gold_orders_daily_summaries(first: 30) { items { order_date total_orders total_revenue } } }"
}
```

## 3. Warehouse Productivity Queries

### Basic Warehouse Query

```graphql
query {
  gold_warehouse_productivity_dailies(first: 10) {
    items {
      warehouse_id
      productivity_date
      total_shipments
      avg_processing_time
    }
  }
}
```

### Complete Warehouse Query (All Fields)

```graphql
query {
  gold_warehouse_productivity_dailies(first: 100) {
    items {
      warehouse_id
      productivity_date
      total_shipments
      avg_processing_time
      fulfillment_rate
      warehouse_partner_id
      warehouse_partner_name
      partner_access_scope
    }
  }
}
```

### Warehouse Filtered by Partner

```graphql
query {
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

**APIM Usage**:

```bash
POST https://apim-3pl-flt.azure-api.net/warehouse-productivity
Authorization: Bearer <WAREHOUSE_SP_TOKEN>
Content-Type: application/json

{
  "query": "query { gold_warehouse_productivity_dailies(first: 30) { items { warehouse_id productivity_date total_shipments avg_processing_time } } }"
}
```

## 4. SLA Performance Queries

### Basic SLA Query

```graphql
query {
  gold_sla_performances(first: 10) {
    items {
      carrier_id
      ontime_shipments
      late_shipments
      ontime_percentage
    }
  }
}
```

### Complete SLA Query (All Fields)

```graphql
query {
  gold_sla_performances(first: 100) {
    items {
      carrier_id
      ontime_shipments
      late_shipments
      total_shipments
      ontime_percentage
      avg_delay_hours
    }
  }
}
```

### SLA Filtered by Carrier

```graphql
query {
  gold_sla_performances(
    first: 20
    filter: { carrier_id: { eq: "CARRIER-FEDEX-GROU" } }
  ) {
    items {
      carrier_id
      ontime_shipments
      late_shipments
      ontime_percentage
    }
  }
}
```

**APIM Usage**:

```bash
POST https://apim-3pl-flt.azure-api.net/sla-performance
Authorization: Bearer <FEDEX_SP_TOKEN>
Content-Type: application/json

{
  "query": "query { gold_sla_performances(first: 10) { items { carrier_id ontime_shipments late_shipments ontime_percentage } } }"
}
```

## 5. Revenue Recognition Queries

### Basic Revenue Query

```graphql
query {
  gold_revenue_recognition_realtimes(first: 10) {
    items {
      event_date
      total_revenue
      recognized_revenue
    }
  }
}
```

### Complete Revenue Query (All Fields)

```graphql
query {
  gold_revenue_recognition_realtimes(first: 100) {
    items {
      event_date
      total_revenue
      recognized_revenue
      pending_revenue
      recognition_percentage
      partner_access_scope
    }
  }
}
```

### Revenue with Date Filter

```graphql
query {
  gold_revenue_recognition_realtimes(
    first: 60
    filter: { 
      event_date: { 
        ge: "2025-01-01"
      } 
    }
  ) {
    items {
      event_date
      total_revenue
      recognized_revenue
      pending_revenue
      recognition_percentage
    }
  }
}
```

**APIM Usage**:

```bash
POST https://apim-3pl-flt.azure-api.net/revenue
Authorization: Bearer <ACME_SP_TOKEN>
Content-Type: application/json

{
  "query": "query { gold_revenue_recognition_realtimes(first: 30) { items { event_date total_revenue recognized_revenue } } }"
}
```

## Advanced Query Patterns

### Pagination with Cursor

```graphql
query {
  gold_shipments_in_transits(first: 50, after: "cursor_value") {
    items {
      shipment_number
      carrier_id
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

### Multiple Filters (AND)

```graphql
query {
  gold_shipments_in_transits(
    first: 100
    filter: {
      and: [
        { carrier_id: { eq: "CARRIER-FEDEX-GROU" } },
        { status: { eq: "IN_TRANSIT" } }
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

### Multiple Filters (OR)

```graphql
query {
  gold_shipments_in_transits(
    first: 100
    filter: {
      or: [
        { status: { eq: "IN_TRANSIT" } },
        { status: { eq: "DELIVERED" } }
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

### Sorting

```graphql
query {
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

## PowerShell Test Script

```powershell
# Get token for Service Principal
az login --service-principal `
  -u <APP_ID> `
  -p <SECRET> `
  --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4

$token = (az account get-access-token `
  --resource "https://analysis.windows.net/powerbi/api" | ConvertFrom-Json).accessToken

# Test query
$query = @{
  query = "query { gold_shipments_in_transits(first: 10) { items { shipment_number carrier_id } } }"
} | ConvertTo-Json

$response = Invoke-WebRequest `
  -Uri "https://apim-3pl-flt.azure-api.net/shipments" `
  -Method Post `
  -Headers @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
  } `
  -Body $query

# Parse response
$data = ($response.Content | ConvertFrom-Json).data.gold_shipments_in_transits.items
$data | Format-Table
```

## Common GraphQL Operators

### Comparison Operators

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

### Logical Operators

```graphql
# AND
filter: {
  and: [
    { carrier_id: { eq: "FEDEX" } },
    { status: { eq: "IN_TRANSIT" } }
  ]
}

# OR
filter: {
  or: [
    { carrier_id: { eq: "FEDEX" } },
    { carrier_id: { eq: "UPS" } }
  ]
}

# NOT
filter: {
  not: { status: { eq: "CANCELLED" } }
}
```

## Response Format

All GraphQL queries return data in this format:

```json
{
  "data": {
    "gold_shipments_in_transits": {
      "items": [
        {
          "shipment_number": "SHP001",
          "carrier_id": "CARRIER-FEDEX-GROU"
        }
      ],
      "pageInfo": {
        "hasNextPage": true,
        "endCursor": "cursor_value"
      }
    }
  }
}
```

To extract items in PowerShell:

```powershell
$items = (($response.Content | ConvertFrom-Json).data.gold_shipments_in_transits.items)
```

## Error Handling

### GraphQL Errors

```json
{
  "errors": [
    {
      "message": "The field `gold_orders_daily_summary` does not exist on the type `Query`.",
      "locations": [{ "line": 1, "column": 9 }]
    }
  ]
}
```

**Common Error**: Table name not pluralized. Use `gold_orders_daily_summaries` instead.

### HTTP Errors

- **401 Unauthorized**: Token invalid or expired
- **403 Forbidden**: No permissions on GraphQL API or Lakehouse
- **404 Not Found**: API endpoint doesn't exist or not configured
- **500 Internal Server Error**: Invalid GraphQL syntax or backend error

## Testing Checklist

- [ ] Token has correct scope (`https://analysis.windows.net/powerbi/api`)
- [ ] Table name is pluralized (e.g., `summaries` not `summary`)
- [ ] GraphQL syntax is valid (test on Fabric GraphQL endpoint first)
- [ ] Service Principal has Execute permission on GraphQL API
- [ ] Service Principal has Viewer permission on Lakehouse
- [ ] Request uses POST method with JSON body
- [ ] Content-Type header is `application/json`
- [ ] Authorization header format is `Bearer <token>`

---

**Last Updated**: 2025-10-30

**Related Documentation**:
- [APIM Configuration](./APIM_CONFIGURATION.md)
- [RLS Configuration](../governance/RLS_CONFIGURATION_VALUES.md)
- [Service Principal Setup](./SERVICE_PRINCIPALS.md)
