# API Documentation

## SAP 3PL Logistics Operations Data Product API

**Version:** 1.0.0  
**Last Updated:** October 23, 2025  
**Base URL:** `https://api.company.com/sap-3pl`

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [GraphQL API](#graphql-api)
4. [REST API](#rest-api)
5. [Data Models](#data-models)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [Code Examples](#code-examples)
9. [Changelog](#changelog)

---

## Overview

The SAP 3PL Logistics Operations API provides access to real-time logistics data from SAP IDoc integration. The API supports both **GraphQL** and **REST** endpoints, allowing flexible data consumption based on your needs.

### Key Features

- ✅ **Real-time Data**: Data refreshed within 5 minutes of IDoc ingestion
- ✅ **Flexible Querying**: GraphQL allows you to request exactly the data you need
- ✅ **REST Compatibility**: Traditional REST endpoints for common use cases
- ✅ **Pagination**: Efficient handling of large datasets
- ✅ **Filtering & Sorting**: Powerful query capabilities
- ✅ **Type Safety**: Strong typing with GraphQL schema
- ✅ **Comprehensive Documentation**: Interactive API playground

### API Endpoints

| Type | Endpoint | Description |
|------|----------|-------------|
| GraphQL | `POST /graphql` | Main GraphQL endpoint |
| GraphQL Playground | `GET /graphql` | Interactive GraphQL explorer |
| REST | `GET /api/v1/shipments` | List shipments |
| REST | `GET /api/v1/shipments/{id}` | Get shipment by ID |
| REST | `GET /api/v1/customers` | List customers |
| REST | `GET /api/v1/customers/{id}` | Get customer by ID |
| REST | `GET /api/v1/deliveries` | List deliveries |
| REST | `GET /api/v1/metrics` | Get shipment metrics |

---

## Authentication

### OAuth 2.0 / Azure AD

All API requests require authentication using **Azure Active Directory (Entra ID)** with OAuth 2.0.

#### Step 1: Obtain Access Token

```bash
curl -X POST https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id={client-id}" \
  -d "scope=api://sap-3pl-data-product/.default" \
  -d "client_secret={client-secret}" \
  -d "grant_type=client_credentials"
```

**Response:**

```json
{
  "token_type": "Bearer",
  "expires_in": 3600,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Step 2: Use Access Token

Include the access token in the `Authorization` header:

```bash
Authorization: Bearer {access_token}
```

### Required Scopes

| Scope | Permission | Description |
|-------|------------|-------------|
| `Shipments.Read` | Read shipments | View shipment data |
| `Customers.Read` | Read customers | View customer data |
| `Deliveries.Read` | Read deliveries | View delivery data |
| `Metrics.Read` | Read metrics | View analytics and metrics |
| `DataProduct.Admin` | Full access | Administrative access |

### API Keys (Alternative)

For development and testing, you can use API keys:

```bash
X-API-Key: your-api-key-here
```

> **Note:** API keys are less secure than OAuth 2.0 and should only be used in non-production environments.

---

## GraphQL API

### Endpoint

```
POST https://api.company.com/sap-3pl/graphql
Content-Type: application/json
Authorization: Bearer {access_token}
```

### GraphQL Playground

Access the interactive GraphQL playground at:

```
https://api.company.com/sap-3pl/graphql
```

### Schema

#### Core Types

```graphql
type Shipment {
  id: ID!
  shipmentNumber: String!
  deliveryNumber: String
  customer: Customer!
  shipDate: Date!
  estimatedDeliveryDate: Date!
  actualDeliveryDate: Date
  status: ShipmentStatus!
  origin: Location!
  destination: Location!
  carrier: Carrier!
  trackingNumber: String
  items: [ShipmentItem!]!
  totalWeight: Float
  totalVolume: Float
  totalValue: Float
  currency: String
  onTimeDelivery: Boolean
  deliveryDelayDays: Int
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Customer {
  id: ID!
  customerId: String!
  name: String!
  type: CustomerType!
  contactEmail: String
  contactPhone: String
  country: String
  region: String
  accountManager: String
  shipments(
    startDate: Date
    endDate: Date
    status: ShipmentStatus
    limit: Int = 10
    offset: Int = 0
  ): [Shipment!]!
  totalShipments: Int!
  onTimeDeliveryRate: Float
}

type Location {
  id: ID!
  locationId: String!
  name: String!
  address: String
  city: String
  state: String
  country: String!
  postalCode: String
  latitude: Float
  longitude: Float
  locationType: LocationType!
  timeZone: String
}

type Carrier {
  id: ID!
  carrierId: String!
  name: String!
  code: String
  serviceLevel: String
  contactEmail: String
  contactPhone: String
}

type ShipmentItem {
  id: ID!
  itemNumber: String!
  materialNumber: String
  description: String
  quantity: Float!
  quantityUnit: String
  weight: Float
  weightUnit: String
  volume: Float
  volumeUnit: String
  value: Float
  currency: String
}

type ShipmentMetric {
  date: Date!
  totalShipments: Int!
  deliveredShipments: Int!
  inTransitShipments: Int!
  delayedShipments: Int!
  onTimeDeliveryRate: Float!
  averageDeliveryTime: Float
  totalWeight: Float
  totalValue: Float
}

enum ShipmentStatus {
  CREATED
  PLANNED
  IN_TRANSIT
  OUT_FOR_DELIVERY
  DELIVERED
  DELAYED
  CANCELLED
  EXCEPTION
}

enum CustomerType {
  RETAIL
  WHOLESALE
  DISTRIBUTOR
  END_CUSTOMER
  PARTNER
}

enum LocationType {
  WAREHOUSE
  DISTRIBUTION_CENTER
  CUSTOMER_SITE
  PORT
  AIRPORT
  CROSS_DOCK
}

scalar Date
scalar DateTime
```

#### Queries

```graphql
type Query {
  # Single entity queries
  shipment(id: ID!): Shipment
  customer(id: ID!): Customer
  location(id: ID!): Location
  carrier(id: ID!): Carrier
  
  # List queries with filtering and pagination
  shipments(
    filters: ShipmentFilters
    pagination: PaginationInput
    sorting: SortingInput
  ): ShipmentConnection!
  
  customers(
    filters: CustomerFilters
    pagination: PaginationInput
    sorting: SortingInput
  ): CustomerConnection!
  
  deliveries(
    filters: DeliveryFilters
    pagination: PaginationInput
    sorting: SortingInput
  ): DeliveryConnection!
  
  # Analytics queries
  shipmentMetrics(
    startDate: Date!
    endDate: Date!
    groupBy: MetricGroupBy = DAY
    filters: ShipmentFilters
  ): [ShipmentMetric!]!
  
  onTimeDeliveryRate(
    startDate: Date!
    endDate: Date!
    customerId: String
    carrierId: String
  ): Float!
  
  averageDeliveryTime(
    startDate: Date!
    endDate: Date!
    customerId: String
  ): Float!
  
  # Search
  search(
    query: String!
    types: [SearchableType!]
    limit: Int = 20
  ): [SearchResult!]!
}

# Input types
input ShipmentFilters {
  customerIds: [String!]
  shipmentNumbers: [String!]
  startDate: Date
  endDate: Date
  statuses: [ShipmentStatus!]
  originCountries: [String!]
  destinationCountries: [String!]
  carrierIds: [String!]
  onTimeDelivery: Boolean
  minValue: Float
  maxValue: Float
}

input CustomerFilters {
  customerIds: [String!]
  types: [CustomerType!]
  countries: [String!]
  regions: [String!]
  searchTerm: String
}

input DeliveryFilters {
  deliveryNumbers: [String!]
  customerIds: [String!]
  startDate: Date
  endDate: Date
  statuses: [DeliveryStatus!]
}

input PaginationInput {
  limit: Int = 20
  offset: Int = 0
  cursor: String
}

input SortingInput {
  field: String!
  direction: SortDirection!
}

enum SortDirection {
  ASC
  DESC
}

enum MetricGroupBy {
  DAY
  WEEK
  MONTH
  QUARTER
  YEAR
}

# Connection types for pagination
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

### Example Queries

#### 1. Get a Single Shipment

```graphql
query GetShipment {
  shipment(id: "SHP-2025-001234") {
    id
    shipmentNumber
    shipDate
    estimatedDeliveryDate
    status
    customer {
      name
      customerId
    }
    origin {
      name
      city
      country
    }
    destination {
      name
      city
      country
    }
    carrier {
      name
      code
    }
    trackingNumber
    totalWeight
    totalValue
    currency
  }
}
```

**Response:**

```json
{
  "data": {
    "shipment": {
      "id": "SHP-2025-001234",
      "shipmentNumber": "8000001234",
      "shipDate": "2025-10-20",
      "estimatedDeliveryDate": "2025-10-23",
      "status": "IN_TRANSIT",
      "customer": {
        "name": "ACME Corporation",
        "customerId": "CUST-0001"
      },
      "origin": {
        "name": "Hamburg Distribution Center",
        "city": "Hamburg",
        "country": "Germany"
      },
      "destination": {
        "name": "ACME Retail Store #42",
        "city": "Paris",
        "country": "France"
      },
      "carrier": {
        "name": "DHL Express",
        "code": "DHL"
      },
      "trackingNumber": "JD0123456789",
      "totalWeight": 125.5,
      "totalValue": 15750.00,
      "currency": "EUR"
    }
  }
}
```

#### 2. List Shipments with Filters

```graphql
query ListShipments {
  shipments(
    filters: {
      startDate: "2025-10-01"
      endDate: "2025-10-23"
      statuses: [IN_TRANSIT, DELIVERED]
      customerIds: ["CUST-0001"]
    }
    pagination: {
      limit: 10
      offset: 0
    }
    sorting: {
      field: "shipDate"
      direction: DESC
    }
  ) {
    totalCount
    pageInfo {
      hasNextPage
      hasPreviousPage
    }
    edges {
      node {
        id
        shipmentNumber
        shipDate
        status
        customer {
          name
        }
        destination {
          city
          country
        }
        onTimeDelivery
      }
      cursor
    }
  }
}
```

#### 3. Get Customer with Shipments

```graphql
query GetCustomerWithShipments {
  customer(id: "CUST-0001") {
    id
    name
    customerId
    type
    country
    totalShipments
    onTimeDeliveryRate
    shipments(
      startDate: "2025-10-01"
      endDate: "2025-10-23"
      status: DELIVERED
      limit: 5
    ) {
      shipmentNumber
      shipDate
      actualDeliveryDate
      onTimeDelivery
      deliveryDelayDays
    }
  }
}
```

#### 4. Get Shipment Metrics

```graphql
query GetShipmentMetrics {
  shipmentMetrics(
    startDate: "2025-10-01"
    endDate: "2025-10-23"
    groupBy: DAY
    filters: {
      customerIds: ["CUST-0001", "CUST-0002"]
    }
  ) {
    date
    totalShipments
    deliveredShipments
    inTransitShipments
    delayedShipments
    onTimeDeliveryRate
    averageDeliveryTime
    totalValue
  }
}
```

#### 5. Search Across Entities

```graphql
query SearchLogistics {
  search(
    query: "Hamburg"
    types: [SHIPMENT, LOCATION, CUSTOMER]
    limit: 10
  ) {
    ... on Shipment {
      __typename
      id
      shipmentNumber
      status
    }
    ... on Location {
      __typename
      id
      name
      city
      country
    }
    ... on Customer {
      __typename
      id
      name
      country
    }
  }
}
```

### GraphQL Best Practices

1. **Request Only What You Need**
   ```graphql
   # ✅ Good - Request specific fields
   query {
     shipment(id: "123") {
       id
       shipmentNumber
       status
     }
   }
   
   # ❌ Bad - Don't use wildcard queries
   ```

2. **Use Fragments for Reusability**
   ```graphql
   fragment ShipmentBasics on Shipment {
     id
     shipmentNumber
     shipDate
     status
   }
   
   query {
     shipment(id: "123") {
       ...ShipmentBasics
       customer { name }
     }
   }
   ```

3. **Leverage Pagination**
   ```graphql
   query {
     shipments(pagination: { limit: 50, offset: 0 }) {
       edges { node { id } }
       pageInfo { hasNextPage }
     }
   }
   ```

---

## REST API

### Base URL

```
https://api.company.com/sap-3pl/api/v1
```

### Shipments

#### List Shipments

```http
GET /api/v1/shipments
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customerId` | string | No | Filter by customer ID |
| `startDate` | date | No | Filter by start date (YYYY-MM-DD) |
| `endDate` | date | No | Filter by end date (YYYY-MM-DD) |
| `status` | enum | No | Filter by status (comma-separated) |
| `country` | string | No | Filter by destination country |
| `limit` | integer | No | Number of results (default: 20, max: 100) |
| `offset` | integer | No | Pagination offset (default: 0) |
| `sort` | string | No | Sort field and direction (e.g., `shipDate:desc`) |

**Example Request:**

```bash
curl -X GET "https://api.company.com/sap-3pl/api/v1/shipments?customerId=CUST-0001&startDate=2025-10-01&endDate=2025-10-23&status=IN_TRANSIT,DELIVERED&limit=10&offset=0&sort=shipDate:desc" \
  -H "Authorization: Bearer {access_token}" \
  -H "Accept: application/json"
```

**Response:**

```json
{
  "data": [
    {
      "id": "SHP-2025-001234",
      "shipmentNumber": "8000001234",
      "deliveryNumber": "80001234",
      "customer": {
        "id": "CUST-0001",
        "name": "ACME Corporation"
      },
      "shipDate": "2025-10-20",
      "estimatedDeliveryDate": "2025-10-23",
      "actualDeliveryDate": null,
      "status": "IN_TRANSIT",
      "origin": {
        "name": "Hamburg Distribution Center",
        "city": "Hamburg",
        "country": "Germany"
      },
      "destination": {
        "name": "ACME Retail Store #42",
        "city": "Paris",
        "country": "France"
      },
      "carrier": {
        "name": "DHL Express",
        "code": "DHL"
      },
      "trackingNumber": "JD0123456789",
      "totalWeight": 125.5,
      "totalVolume": 2.8,
      "totalValue": 15750.00,
      "currency": "EUR",
      "onTimeDelivery": null,
      "deliveryDelayDays": null,
      "createdAt": "2025-10-20T08:30:00Z",
      "updatedAt": "2025-10-22T14:25:00Z"
    }
  ],
  "pagination": {
    "totalCount": 157,
    "limit": 10,
    "offset": 0,
    "hasNext": true,
    "hasPrevious": false
  },
  "_links": {
    "self": "/api/v1/shipments?limit=10&offset=0",
    "next": "/api/v1/shipments?limit=10&offset=10",
    "first": "/api/v1/shipments?limit=10&offset=0",
    "last": "/api/v1/shipments?limit=10&offset=150"
  }
}
```

#### Get Shipment by ID

```http
GET /api/v1/shipments/{id}
```

**Example Request:**

```bash
curl -X GET "https://api.company.com/sap-3pl/api/v1/shipments/SHP-2025-001234" \
  -H "Authorization: Bearer {access_token}" \
  -H "Accept: application/json"
```

**Response:**

```json
{
  "data": {
    "id": "SHP-2025-001234",
    "shipmentNumber": "8000001234",
    "customer": {
      "id": "CUST-0001",
      "name": "ACME Corporation",
      "customerId": "1000123"
    },
    "shipDate": "2025-10-20",
    "estimatedDeliveryDate": "2025-10-23",
    "status": "IN_TRANSIT",
    "origin": {
      "id": "LOC-001",
      "name": "Hamburg Distribution Center",
      "city": "Hamburg",
      "country": "Germany"
    },
    "destination": {
      "id": "LOC-042",
      "name": "ACME Retail Store #42",
      "address": "123 Rue de Rivoli",
      "city": "Paris",
      "country": "France",
      "postalCode": "75001"
    },
    "carrier": {
      "id": "CAR-001",
      "name": "DHL Express",
      "code": "DHL",
      "serviceLevel": "EXPRESS"
    },
    "trackingNumber": "JD0123456789",
    "items": [
      {
        "id": "ITM-001",
        "itemNumber": "000010",
        "materialNumber": "MAT-12345",
        "description": "Widget Pro 3000",
        "quantity": 50,
        "quantityUnit": "EA",
        "weight": 75.5,
        "weightUnit": "KG",
        "volume": 1.8,
        "volumeUnit": "CBM",
        "value": 12500.00,
        "currency": "EUR"
      },
      {
        "id": "ITM-002",
        "itemNumber": "000020",
        "materialNumber": "MAT-67890",
        "description": "Gadget Ultra",
        "quantity": 25,
        "quantityUnit": "EA",
        "weight": 50.0,
        "weightUnit": "KG",
        "volume": 1.0,
        "volumeUnit": "CBM",
        "value": 3250.00,
        "currency": "EUR"
      }
    ],
    "totalWeight": 125.5,
    "totalVolume": 2.8,
    "totalValue": 15750.00,
    "currency": "EUR",
    "createdAt": "2025-10-20T08:30:00Z",
    "updatedAt": "2025-10-22T14:25:00Z"
  },
  "_links": {
    "self": "/api/v1/shipments/SHP-2025-001234",
    "customer": "/api/v1/customers/CUST-0001",
    "delivery": "/api/v1/deliveries?shipmentId=SHP-2025-001234"
  }
}
```

### Customers

#### List Customers

```http
GET /api/v1/customers
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | enum | No | Filter by customer type |
| `country` | string | No | Filter by country |
| `search` | string | No | Search by name or ID |
| `limit` | integer | No | Number of results (default: 20) |
| `offset` | integer | No | Pagination offset (default: 0) |

#### Get Customer by ID

```http
GET /api/v1/customers/{id}
```

### Deliveries

#### List Deliveries

```http
GET /api/v1/deliveries
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customerId` | string | No | Filter by customer ID |
| `shipmentId` | string | No | Filter by shipment ID |
| `startDate` | date | No | Filter by start date |
| `endDate` | date | No | Filter by end date |
| `status` | enum | No | Filter by delivery status |
| `limit` | integer | No | Number of results (default: 20) |
| `offset` | integer | No | Pagination offset (default: 0) |

### Metrics

#### Get Shipment Metrics

```http
GET /api/v1/metrics/shipments
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `startDate` | date | Yes | Start date (YYYY-MM-DD) |
| `endDate` | date | Yes | End date (YYYY-MM-DD) |
| `groupBy` | enum | No | Group by period (day, week, month) |
| `customerId` | string | No | Filter by customer ID |
| `carrierId` | string | No | Filter by carrier ID |

**Example Request:**

```bash
curl -X GET "https://api.company.com/sap-3pl/api/v1/metrics/shipments?startDate=2025-10-01&endDate=2025-10-23&groupBy=day&customerId=CUST-0001" \
  -H "Authorization: Bearer {access_token}" \
  -H "Accept: application/json"
```

**Response:**

```json
{
  "data": [
    {
      "date": "2025-10-01",
      "totalShipments": 45,
      "deliveredShipments": 42,
      "inTransitShipments": 3,
      "delayedShipments": 2,
      "onTimeDeliveryRate": 95.24,
      "averageDeliveryTime": 2.8,
      "totalWeight": 5675.5,
      "totalValue": 785000.00,
      "currency": "EUR"
    },
    {
      "date": "2025-10-02",
      "totalShipments": 52,
      "deliveredShipments": 48,
      "inTransitShipments": 4,
      "delayedShipments": 1,
      "onTimeDeliveryRate": 97.92,
      "averageDeliveryTime": 2.5,
      "totalWeight": 6234.0,
      "totalValue": 892000.00,
      "currency": "EUR"
    }
  ],
  "summary": {
    "totalShipments": 1247,
    "averageOnTimeDeliveryRate": 96.42,
    "averageDeliveryTime": 2.7
  }
}
```

#### Get On-Time Delivery Rate

```http
GET /api/v1/metrics/on-time-delivery-rate
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `startDate` | date | Yes | Start date |
| `endDate` | date | Yes | End date |
| `customerId` | string | No | Filter by customer |
| `carrierId` | string | No | Filter by carrier |

---

## Data Models

### Shipment Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique shipment identifier |
| `shipmentNumber` | string | SAP shipment number |
| `deliveryNumber` | string | SAP delivery number |
| `customer` | Customer | Customer object |
| `shipDate` | date | Actual ship date |
| `estimatedDeliveryDate` | date | Planned delivery date |
| `actualDeliveryDate` | date | Actual delivery date (null if not delivered) |
| `status` | ShipmentStatus | Current shipment status |
| `origin` | Location | Origin location |
| `destination` | Location | Destination location |
| `carrier` | Carrier | Carrier information |
| `trackingNumber` | string | Carrier tracking number |
| `items` | ShipmentItem[] | Array of shipment items |
| `totalWeight` | float | Total weight |
| `totalVolume` | float | Total volume |
| `totalValue` | float | Total monetary value |
| `currency` | string | Currency code (ISO 4217) |
| `onTimeDelivery` | boolean | Whether delivered on time (null if not delivered) |
| `deliveryDelayDays` | integer | Number of days delayed (null if on time or not delivered) |
| `createdAt` | datetime | Record creation timestamp |
| `updatedAt` | datetime | Last update timestamp |

### ShipmentStatus Enum

| Value | Description |
|-------|-------------|
| `CREATED` | Shipment created in system |
| `PLANNED` | Shipment planned but not yet shipped |
| `IN_TRANSIT` | Shipment in transit |
| `OUT_FOR_DELIVERY` | Out for final delivery |
| `DELIVERED` | Successfully delivered |
| `DELAYED` | Shipment delayed |
| `CANCELLED` | Shipment cancelled |
| `EXCEPTION` | Exception occurred |

---

## Error Handling

### Error Response Format

```json
{
  "errors": [
    {
      "code": "VALIDATION_ERROR",
      "message": "Invalid date format for startDate parameter",
      "field": "startDate",
      "details": {
        "expected": "YYYY-MM-DD",
        "received": "10/01/2025"
      }
    }
  ],
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-10-23T10:30:00Z"
}
```

### HTTP Status Codes

| Code | Description | When Used |
|------|-------------|-----------|
| 200 | OK | Successful request |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily unavailable |

### Common Error Codes

| Code | Description |
|------|-------------|
| `AUTHENTICATION_FAILED` | Authentication token invalid or expired |
| `AUTHORIZATION_FAILED` | Insufficient permissions for this operation |
| `VALIDATION_ERROR` | Input validation failed |
| `RESOURCE_NOT_FOUND` | Requested resource not found |
| `RATE_LIMIT_EXCEEDED` | API rate limit exceeded |
| `INTERNAL_ERROR` | Internal server error |
| `SERVICE_UNAVAILABLE` | Service temporarily unavailable |

---

## Rate Limiting

### Limits

| Tier | Requests per Minute | Requests per Hour | Burst |
|------|---------------------|-------------------|-------|
| Standard | 1,000 | 50,000 | 100 |
| Premium | 5,000 | 250,000 | 500 |
| Enterprise | Custom | Custom | Custom |

### Rate Limit Headers

Every API response includes rate limit information:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1698067200
```

### Rate Limit Exceeded Response

```json
{
  "errors": [
    {
      "code": "RATE_LIMIT_EXCEEDED",
      "message": "API rate limit exceeded. Please retry after 60 seconds.",
      "retryAfter": 60
    }
  ],
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-10-23T10:30:00Z"
}
```

---

## Code Examples

### Python

```python
import requests
from datetime import datetime, timedelta

# Configuration
BASE_URL = "https://api.company.com/sap-3pl"
ACCESS_TOKEN = "your-access-token"

headers = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json"
}

# GraphQL Query
def get_shipment_graphql(shipment_id):
    query = """
    query GetShipment($id: ID!) {
        shipment(id: $id) {
            id
            shipmentNumber
            status
            customer {
                name
                customerId
            }
            origin {
                city
                country
            }
            destination {
                city
                country
            }
            trackingNumber
        }
    }
    """
    
    response = requests.post(
        f"{BASE_URL}/graphql",
        headers=headers,
        json={
            "query": query,
            "variables": {"id": shipment_id}
        }
    )
    
    return response.json()

# REST API
def get_shipments_rest(customer_id, start_date, end_date):
    params = {
        "customerId": customer_id,
        "startDate": start_date.strftime("%Y-%m-%d"),
        "endDate": end_date.strftime("%Y-%m-%d"),
        "limit": 50,
        "offset": 0
    }
    
    response = requests.get(
        f"{BASE_URL}/api/v1/shipments",
        headers=headers,
        params=params
    )
    
    return response.json()

# Get metrics
def get_metrics(start_date, end_date):
    params = {
        "startDate": start_date.strftime("%Y-%m-%d"),
        "endDate": end_date.strftime("%Y-%m-%d"),
        "groupBy": "day"
    }
    
    response = requests.get(
        f"{BASE_URL}/api/v1/metrics/shipments",
        headers=headers,
        params=params
    )
    
    return response.json()

# Usage
if __name__ == "__main__":
    # Get single shipment via GraphQL
    shipment = get_shipment_graphql("SHP-2025-001234")
    print(f"Shipment: {shipment}")
    
    # Get shipments via REST
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)
    shipments = get_shipments_rest("CUST-0001", start_date, end_date)
    print(f"Found {shipments['pagination']['totalCount']} shipments")
    
    # Get metrics
    metrics = get_metrics(start_date, end_date)
    print(f"Metrics: {metrics}")
```

### JavaScript/TypeScript

```typescript
import axios from 'axios';

const BASE_URL = 'https://api.company.com/sap-3pl';
const ACCESS_TOKEN = 'your-access-token';

const api = axios.create({
  baseURL: BASE_URL,
  headers: {
    'Authorization': `Bearer ${ACCESS_TOKEN}`,
    'Content-Type': 'application/json'
  }
});

// GraphQL Query
interface Shipment {
  id: string;
  shipmentNumber: string;
  status: string;
  customer: {
    name: string;
    customerId: string;
  };
  trackingNumber: string;
}

async function getShipmentGraphQL(id: string): Promise<Shipment> {
  const query = `
    query GetShipment($id: ID!) {
      shipment(id: $id) {
        id
        shipmentNumber
        status
        customer {
          name
          customerId
        }
        trackingNumber
      }
    }
  `;

  const response = await api.post('/graphql', {
    query,
    variables: { id }
  });

  return response.data.data.shipment;
}

// REST API
async function getShipments(customerId: string, startDate: Date, endDate: Date) {
  const response = await api.get('/api/v1/shipments', {
    params: {
      customerId,
      startDate: startDate.toISOString().split('T')[0],
      endDate: endDate.toISOString().split('T')[0],
      limit: 50
    }
  });

  return response.data;
}

// Usage
(async () => {
  try {
    const shipment = await getShipmentGraphQL('SHP-2025-001234');
    console.log('Shipment:', shipment);

    const endDate = new Date();
    const startDate = new Date(endDate.getTime() - 30 * 24 * 60 * 60 * 1000);
    const shipments = await getShipments('CUST-0001', startDate, endDate);
    console.log(`Found ${shipments.pagination.totalCount} shipments`);
  } catch (error) {
    console.error('API Error:', error);
  }
})();
```

### C#

```csharp
using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

public class SapDataProductClient
{
    private readonly HttpClient _httpClient;
    private const string BaseUrl = "https://api.company.com/sap-3pl";

    public SapDataProductClient(string accessToken)
    {
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(BaseUrl)
        };
        _httpClient.DefaultRequestHeaders.Authorization = 
            new AuthenticationHeaderValue("Bearer", accessToken);
    }

    // GraphQL Query
    public async Task<Shipment> GetShipmentAsync(string id)
    {
        var query = @"
            query GetShipment($id: ID!) {
                shipment(id: $id) {
                    id
                    shipmentNumber
                    status
                    customer {
                        name
                        customerId
                    }
                    trackingNumber
                }
            }
        ";

        var request = new
        {
            query = query,
            variables = new { id = id }
        };

        var content = new StringContent(
            JsonSerializer.Serialize(request),
            Encoding.UTF8,
            "application/json"
        );

        var response = await _httpClient.PostAsync("/graphql", content);
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadAsStringAsync();
        var data = JsonSerializer.Deserialize<GraphQLResponse<ShipmentData>>(result);
        
        return data.Data.Shipment;
    }

    // REST API
    public async Task<ShipmentListResponse> GetShipmentsAsync(
        string customerId, 
        DateTime startDate, 
        DateTime endDate)
    {
        var url = $"/api/v1/shipments?customerId={customerId}" +
                  $"&startDate={startDate:yyyy-MM-dd}" +
                  $"&endDate={endDate:yyyy-MM-dd}" +
                  $"&limit=50";

        var response = await _httpClient.GetAsync(url);
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<ShipmentListResponse>(content);
    }
}

// Usage
var client = new SapDataProductClient("your-access-token");
var shipment = await client.GetShipmentAsync("SHP-2025-001234");
Console.WriteLine($"Shipment: {shipment.ShipmentNumber}");
```

---

## Changelog

### Version 1.0.0 (2025-10-23)

- Initial API release
- GraphQL endpoint with full schema
- REST API endpoints for shipments, customers, deliveries, and metrics
- OAuth 2.0 authentication
- Rate limiting implementation
- Comprehensive error handling

### Upcoming Features

- **v1.1.0** (Q1 2026)
  - WebSocket support for real-time updates
  - GraphQL subscriptions
  - Enhanced search capabilities
  - Additional analytics endpoints

- **v1.2.0** (Q2 2026)
  - Batch operations support
  - Export functionality (CSV, Excel)
  - Custom report generation
  - Webhook notifications

---

## Support & Resources

- **API Status**: https://status.api.company.com
- **Developer Portal**: https://developer.company.com/sap-3pl
- **Support Email**: api-support@company.com
- **Documentation**: https://docs.api.company.com/sap-3pl
- **Community Forum**: https://community.company.com/api

---

**Last Updated:** October 23, 2025  
**API Version:** 1.0.0  
**Document Version:** 1.0.0
