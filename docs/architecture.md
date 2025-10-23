# Architecture Documentation

## SAP IDoc to Microsoft Fabric Data Product - 3PL Business Case

**Version:** 1.0.0  
**Last Updated:** October 23, 2025  
**Status:** Design Phase

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Component Architecture](#component-architecture)
4. [Data Flow](#data-flow)
5. [Integration Patterns](#integration-patterns)
6. [Security Architecture](#security-architecture)
7. [Scalability & Performance](#scalability--performance)
8. [Disaster Recovery](#disaster-recovery)
9. [Technology Decisions](#technology-decisions)
10. [Deployment Architecture](#deployment-architecture)

---

## Executive Summary

This document describes the end-to-end architecture for ingesting SAP IDoc messages from 3PL (Third-Party Logistics) operations into Microsoft Fabric, transforming them into a governed data product, and exposing them through modern API patterns (GraphQL and REST) managed by Azure API Management and cataloged in Microsoft Purview.

### Key Architectural Principles

- **Event-Driven Architecture**: Real-time processing using Fabric Eventstream
- **API-First Design**: GraphQL as the primary data access pattern
- **Data Product Thinking**: Treating data as a product with clear ownership and SLAs
- **Governance by Design**: Microsoft Purview integration from the start
- **Cloud-Native**: Leveraging Azure PaaS services for scalability and reliability
- **Separation of Concerns**: Clear boundaries between ingestion, processing, and consumption

---

## Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SAP Source System                              │
│                        (Simulated for POC)                               │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ IDoc Messages
                               │ (DESADV, SHPMNT, INVOICE, etc.)
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        IDoc Simulator (Python)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │ IDoc Generator│  │ Schema Validator│  │Event Publisher│                │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ JSON/XML over HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Azure Event Hubs                                   │
│                    (Fabric Eventstream Source)                           │
│  • Partitioned for throughput                                            │
│  • Retention: 7 days                                                     │
│  • Consumer Groups: fabric-ingest, monitoring                            │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Microsoft Fabric Eventstream                          │
│  ┌─────────────────────────────────────────────────────┐                │
│  │  Stream Processing                                  │                │
│  │  • Data validation                                  │                │
│  │  • Schema enforcement                               │                │
│  │  • Enrichment with reference data                   │                │
│  │  • Error handling & DLQ routing                     │                │
│  └─────────────────────────────────────────────────────┘                │
└───────────────┬──────────────────────┬──────────────────────────────────┘
                │                      │
                │ Valid Messages       │ Invalid Messages
                ▼                      ▼
┌───────────────────────────┐  ┌──────────────────────┐
│   Fabric Lakehouse        │  │   Dead Letter Queue  │
│   (Bronze Layer)          │  │   (Error Analysis)   │
│   • Raw IDoc data         │  └──────────────────────┘
│   • Delta Lake format     │
│   • Partitioned by date   │
└──────────┬────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Data Transformation Layer                             │
│                    (Fabric Data Engineering - Spark)                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │
│  │  Silver Layer    │  │   Gold Layer     │  │  Aggregations    │      │
│  │  • Cleansed      │  │   • Business     │  │  • KPIs          │      │
│  │  • Normalized    │  │     dimensions   │  │  • Metrics       │      │
│  │  • Deduped       │  │   • Facts        │  │  • Rollups       │      │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘      │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Fabric SQL Warehouse                                  │
│  • Optimized for analytics queries                                       │
│  • Star schema design                                                    │
│  • Materialized views for common queries                                │
│  • Row-level security                                                    │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    GraphQL API Layer                                     │
│                    (Azure Container Apps / Functions)                    │
│  ┌─────────────────────────────────────────────────────┐                │
│  │  GraphQL Server                                     │                │
│  │  ├── Schema Definition (SDL)                        │                │
│  │  ├── Resolvers (Query, Mutation, Subscription)      │                │
│  │  ├── Data Loaders (Batching & Caching)             │                │
│  │  ├── Authentication & Authorization                 │                │
│  │  └── Error Handling & Logging                       │                │
│  └─────────────────────────────────────────────────────┘                │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Azure API Management                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │
│  │  GraphQL Gateway │  │  REST Transform  │  │  Developer Portal│      │
│  │  • Rate limiting │  │  • GraphQL→REST  │  │  • API Docs      │      │
│  │  • Caching       │  │  • OpenAPI spec  │  │  • Try it out    │      │
│  │  • Monitoring    │  │  • Versioning    │  │  • API keys      │      │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘      │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          API Consumers                                   │
│  • Web Applications    • Mobile Apps    • Partner Integrations           │
│  • Analytics Tools     • Power BI       • Custom Applications            │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                  Cross-Cutting Concerns (Governance)                     │
│                                                                           │
│  ┌──────────────────────────────────────────────────────┐               │
│  │            Microsoft Purview                         │               │
│  │  ├── Data Catalog                                    │               │
│  │  │   • Data product registration                     │               │
│  │  │   • Business glossary                             │               │
│  │  │   • Technical metadata                            │               │
│  │  ├── Data Quality                                    │               │
│  │  │   • Quality rules & validation                    │               │
│  │  │   • Profiling & monitoring                        │               │
│  │  │   • Anomaly detection                             │               │
│  │  ├── Data Lineage                                    │               │
│  │  │   • End-to-end traceability                       │               │
│  │  │   • Impact analysis                               │               │
│  │  ├── API Catalog                                     │               │
│  │  │   • API registration                              │               │
│  │  │   • Schema versioning                             │               │
│  │  └── Classification & Sensitivity                    │               │
│  │      • PII detection                                 │               │
│  │      • Compliance labeling                           │               │
│  └──────────────────────────────────────────────────────┘               │
│                                                                           │
│  ┌──────────────────────────────────────────────────────┐               │
│  │            Monitoring & Observability                │               │
│  │  • Azure Monitor / Application Insights              │               │
│  │  • Fabric Monitoring                                 │               │
│  │  • Custom Metrics & Dashboards                       │               │
│  └──────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. IDoc Simulator

**Purpose**: Simulate SAP system generating IDoc messages for testing and development.

**Technology**: Python 3.11+

**Key Components**:

```
simulator/
├── idoc_generator.py          # Main generator logic
├── idoc_schemas/
│   ├── desadv_schema.py       # Delivery notification
│   ├── shpmnt_schema.py       # Shipment
│   ├── invoice_schema.py      # Invoice
│   ├── orders_schema.py       # Purchase order
│   └── whscon_schema.py       # Warehouse confirmation
├── eventstream_publisher.py   # Event Hub publisher
├── config/
│   ├── config.yaml            # Configuration
│   └── scenarios.yaml         # Business scenarios
└── tests/
    └── test_generator.py
```

**Responsibilities**:
- Generate realistic IDoc messages based on 3PL scenarios
- Validate against SAP IDoc schemas
- Publish to Azure Event Hubs
- Support configurable message rates and volumes
- Simulate error conditions for testing

**Configuration Parameters**:
```yaml
event_hub:
  connection_string: ${EVENT_HUB_CONNECTION_STRING}
  event_hub_name: "sap-idocs"
  
generation:
  message_rate: 100  # messages per minute
  idoc_types:
    - DESADV
    - SHPMNT
    - INVOICE
  
scenarios:
  - name: "normal_operations"
    probability: 0.85
  - name: "delayed_shipment"
    probability: 0.10
  - name: "cancelled_order"
    probability: 0.05
```

### 2. Fabric Eventstream

**Purpose**: Real-time ingestion and initial processing of IDoc messages.

**Configuration**:

```json
{
  "name": "sap-idoc-ingest",
  "source": {
    "type": "EventHub",
    "connectionString": "${EVENT_HUB_CONNECTION_STRING}",
    "consumerGroup": "fabric-ingest",
    "eventHubName": "sap-idocs"
  },
  "transformations": [
    {
      "name": "ValidateSchema",
      "type": "SchemaValidation",
      "schemaRegistry": "purview-schema-registry",
      "onError": "SendToDLQ"
    },
    {
      "name": "EnrichWithMetadata",
      "type": "Derived",
      "fields": [
        "ingestion_timestamp",
        "processing_date",
        "source_system"
      ]
    },
    {
      "name": "RoutingLogic",
      "type": "Filter",
      "conditions": [
        {
          "when": "idoc_type == 'DESADV'",
          "route": "deliveries"
        },
        {
          "when": "idoc_type == 'SHPMNT'",
          "route": "shipments"
        }
      ]
    }
  ],
  "destinations": [
    {
      "name": "lakehouse-bronze",
      "type": "Lakehouse",
      "workspace": "SAP-3PL-Workspace",
      "lakehouse": "sap-idoc-lakehouse",
      "table": "bronze_idocs"
    },
    {
      "name": "dead-letter-queue",
      "type": "EventHub",
      "eventHubName": "sap-idocs-dlq"
    }
  ]
}
```

**Features**:
- Schema validation against registered schemas
- Automatic partitioning by IDoc type and date
- Error handling with dead-letter queue
- Metadata enrichment
- Monitoring and alerting

### 3. Data Transformation Layer (Lakehouse)

**Purpose**: Multi-layered data processing following medallion architecture.

**Architecture Pattern**: Medallion (Bronze → Silver → Gold)

#### Bronze Layer (Raw Data)
```sql
-- Table: bronze_idocs
CREATE TABLE bronze_idocs (
    idoc_number STRING,
    idoc_type STRING,
    message_type STRING,
    direction STRING,
    partner_number STRING,
    raw_payload STRING,  -- Full IDoc XML/JSON
    ingestion_timestamp TIMESTAMP,
    processing_date DATE,
    source_system STRING,
    file_name STRING
)
USING DELTA
PARTITIONED BY (processing_date, idoc_type)
LOCATION 'Files/bronze/idocs';
```

#### Silver Layer (Cleansed & Normalized)
```sql
-- Table: silver_shipments
CREATE TABLE silver_shipments (
    shipment_id STRING PRIMARY KEY,
    shipment_number STRING,
    delivery_number STRING,
    customer_id STRING,
    customer_name STRING,
    ship_date DATE,
    delivery_date DATE,
    origin_location STRING,
    destination_location STRING,
    carrier STRING,
    tracking_number STRING,
    total_weight DECIMAL(18,2),
    total_volume DECIMAL(18,2),
    status STRING,
    created_timestamp TIMESTAMP,
    modified_timestamp TIMESTAMP,
    source_idoc_number STRING,
    data_quality_score DECIMAL(3,2)
)
USING DELTA
PARTITIONED BY (ship_date);

-- Table: silver_deliveries
CREATE TABLE silver_deliveries (
    delivery_id STRING PRIMARY KEY,
    delivery_number STRING,
    shipment_id STRING,
    order_number STRING,
    customer_id STRING,
    planned_delivery_date DATE,
    actual_delivery_date DATE,
    delivery_status STRING,
    delivery_location STRING,
    recipient_name STRING,
    items_count INT,
    total_quantity DECIMAL(18,2),
    created_timestamp TIMESTAMP,
    modified_timestamp TIMESTAMP,
    source_idoc_number STRING
)
USING DELTA
PARTITIONED BY (planned_delivery_date);
```

#### Gold Layer (Business Dimensions & Facts)
```sql
-- Dimension: dim_customer
CREATE TABLE dim_customer (
    customer_key INT PRIMARY KEY,
    customer_id STRING,
    customer_name STRING,
    customer_type STRING,
    country STRING,
    region STRING,
    account_manager STRING,
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN
)
USING DELTA;

-- Dimension: dim_location
CREATE TABLE dim_location (
    location_key INT PRIMARY KEY,
    location_id STRING,
    location_name STRING,
    address STRING,
    city STRING,
    state STRING,
    country STRING,
    postal_code STRING,
    location_type STRING  -- warehouse, customer_site, distribution_center
)
USING DELTA;

-- Fact: fact_shipment
CREATE TABLE fact_shipment (
    shipment_key BIGINT PRIMARY KEY,
    shipment_id STRING,
    customer_key INT,
    origin_location_key INT,
    destination_location_key INT,
    ship_date_key INT,
    delivery_date_key INT,
    carrier_key INT,
    shipment_status_key INT,
    total_weight DECIMAL(18,2),
    total_volume DECIMAL(18,2),
    total_items INT,
    total_value DECIMAL(18,2),
    on_time_delivery_flag BOOLEAN,
    delivery_delay_days INT,
    created_timestamp TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (origin_location_key) REFERENCES dim_location(location_key),
    FOREIGN KEY (destination_location_key) REFERENCES dim_location(location_key)
)
USING DELTA
PARTITIONED BY (ship_date_key);
```

**Transformation Pipelines**:

```python
# Example: Bronze to Silver transformation
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from delta.tables import DeltaTable

def transform_bronze_to_silver_shipments(spark):
    """
    Transform raw IDoc messages to structured shipment data
    """
    # Read from bronze
    bronze_df = spark.read.table("bronze_idocs") \
        .filter(col("idoc_type") == "SHPMNT") \
        .filter(col("processing_date") == current_date())
    
    # Parse JSON payload
    shipment_df = bronze_df \
        .withColumn("parsed", from_json(col("raw_payload"), shipment_schema)) \
        .select(
            col("parsed.header.shipment_id").alias("shipment_id"),
            col("parsed.header.shipment_number").alias("shipment_number"),
            col("parsed.customer.customer_id").alias("customer_id"),
            col("parsed.customer.customer_name").alias("customer_name"),
            col("parsed.dates.ship_date").cast("date").alias("ship_date"),
            col("parsed.dates.delivery_date").cast("date").alias("delivery_date"),
            # ... more fields
            col("idoc_number").alias("source_idoc_number"),
            current_timestamp().alias("created_timestamp")
        )
    
    # Data quality checks
    shipment_df = shipment_df \
        .withColumn("data_quality_score", calculate_quality_score(
            col("shipment_id"),
            col("customer_id"),
            col("ship_date")
        ))
    
    # Upsert to silver table (SCD Type 1)
    silver_table = DeltaTable.forName(spark, "silver_shipments")
    
    silver_table.alias("target") \
        .merge(
            shipment_df.alias("source"),
            "target.shipment_id = source.shipment_id"
        ) \
        .whenMatchedUpdateAll() \
        .whenNotMatchedInsertAll() \
        .execute()
```

### 4. GraphQL API Layer

**Purpose**: Provide a unified, flexible API for data product consumption.

**Technology**: 
- **Option 1**: .NET 8 + Hot Chocolate
- **Option 2**: Node.js + Apollo Server

**Schema Design**:

```graphql
# Type Definitions
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
  country: String
  region: String
  shipments(
    startDate: Date
    endDate: Date
    status: ShipmentStatus
    limit: Int = 10
    offset: Int = 0
  ): [Shipment!]!
}

type Location {
  id: ID!
  locationId: String!
  name: String!
  address: String
  city: String
  state: String
  country: String!
  locationType: LocationType!
}

type ShipmentItem {
  id: ID!
  itemNumber: String!
  description: String
  quantity: Float!
  weight: Float
  volume: Float
  value: Float
}

enum ShipmentStatus {
  CREATED
  IN_TRANSIT
  OUT_FOR_DELIVERY
  DELIVERED
  DELAYED
  CANCELLED
}

enum CustomerType {
  RETAIL
  WHOLESALE
  DISTRIBUTOR
  END_CUSTOMER
}

enum LocationType {
  WAREHOUSE
  DISTRIBUTION_CENTER
  CUSTOMER_SITE
  PORT
  AIRPORT
}

# Query Root
type Query {
  # Shipment queries
  shipment(id: ID!): Shipment
  shipments(
    filters: ShipmentFilters
    pagination: PaginationInput
    sorting: SortingInput
  ): ShipmentConnection!
  
  # Customer queries
  customer(id: ID!): Customer
  customers(
    filters: CustomerFilters
    pagination: PaginationInput
  ): CustomerConnection!
  
  # Analytics queries
  shipmentMetrics(
    startDate: Date!
    endDate: Date!
    groupBy: MetricGroupBy
  ): [ShipmentMetric!]!
  
  onTimeDeliveryRate(
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

# Mutation Root
type Mutation {
  # Typically read-only for data product, but can include:
  requestDataRefresh(entityType: String!): RefreshStatus!
}

# Subscription Root (optional - for real-time updates)
type Subscription {
  shipmentUpdated(customerId: String): Shipment!
  newShipment(customerId: String): Shipment!
}

# Input Types
input ShipmentFilters {
  customerIds: [String!]
  startDate: Date
  endDate: Date
  statuses: [ShipmentStatus!]
  originCountries: [String!]
  destinationCountries: [String!]
  onTimeDelivery: Boolean
}

input PaginationInput {
  limit: Int = 20
  offset: Int = 0
}

input SortingInput {
  field: String!
  direction: SortDirection!
}

enum SortDirection {
  ASC
  DESC
}

# Connection Types (for pagination)
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

# Custom Scalars
scalar Date
scalar DateTime
```

**Resolver Implementation** (.NET example):

```csharp
public class ShipmentQueries
{
    public async Task<Shipment?> GetShipmentAsync(
        [ID] string id,
        [Service] IShipmentRepository repository,
        CancellationToken cancellationToken)
    {
        return await repository.GetByIdAsync(id, cancellationToken);
    }

    [UsePaging]
    [UseFiltering]
    [UseSorting]
    public IQueryable<Shipment> GetShipments(
        [Service] IShipmentRepository repository)
    {
        return repository.GetQueryable();
    }

    public async Task<IEnumerable<ShipmentMetric>> GetShipmentMetricsAsync(
        DateTime startDate,
        DateTime endDate,
        MetricGroupBy? groupBy,
        [Service] IMetricsService metricsService,
        CancellationToken cancellationToken)
    {
        return await metricsService.GetShipmentMetricsAsync(
            startDate, 
            endDate, 
            groupBy ?? MetricGroupBy.Day,
            cancellationToken);
    }
}

// Data Loader for N+1 prevention
public class CustomerByIdDataLoader : BatchDataLoader<string, Customer>
{
    private readonly ICustomerRepository _repository;

    public CustomerByIdDataLoader(
        ICustomerRepository repository,
        IBatchScheduler batchScheduler)
        : base(batchScheduler)
    {
        _repository = repository;
    }

    protected override async Task<IReadOnlyDictionary<string, Customer>> LoadBatchAsync(
        IReadOnlyList<string> keys,
        CancellationToken cancellationToken)
    {
        var customers = await _repository.GetByIdsAsync(keys, cancellationToken);
        return customers.ToDictionary(c => c.Id);
    }
}
```

### 5. Azure API Management

**Purpose**: Enterprise API gateway for governance, security, and transformation.

**Configuration**:

```xml
<!-- GraphQL Passthrough Policy -->
<policies>
    <inbound>
        <base />
        <!-- Authentication -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
            <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
            <audiences>
                <audience>api://sap-3pl-data-product</audience>
            </audiences>
            <required-claims>
                <claim name="roles" match="any">
                    <value>DataConsumer</value>
                    <value>DataAnalyst</value>
                </claim>
            </required-claims>
        </validate-jwt>
        
        <!-- Rate Limiting -->
        <rate-limit-by-key calls="1000" renewal-period="60" 
                           counter-key="@(context.Request.Headers.GetValueOrDefault("Authorization"))" />
        
        <!-- Caching for specific queries -->
        <cache-lookup-value key="@(context.Request.Body.As<string>(preserveContent: true))" 
                           variable-name="cachedResponse" />
        <choose>
            <when condition="@(context.Variables.ContainsKey("cachedResponse"))">
                <return-response>
                    <set-status code="200" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>@((string)context.Variables["cachedResponse"])</set-body>
                </return-response>
            </when>
        </choose>
        
        <!-- Logging -->
        <set-variable name="requestId" value="@(Guid.NewGuid().ToString())" />
        <log-to-eventhub logger-id="api-logger">
            @{
                return new {
                    RequestId = (string)context.Variables["requestId"],
                    Timestamp = DateTime.UtcNow,
                    Method = context.Request.Method,
                    Url = context.Request.Url.ToString(),
                    ClientIP = context.Request.IpAddress
                }.ToString();
            }
        </log-to-eventhub>
    </inbound>
    
    <backend>
        <base />
    </backend>
    
    <outbound>
        <base />
        <!-- Cache successful responses -->
        <choose>
            <when condition="@(context.Response.StatusCode == 200)">
                <cache-store-value key="@(context.Request.Body.As<string>(preserveContent: true))" 
                                  value="@(context.Response.Body.As<string>(preserveContent: true))" 
                                  duration="300" />
            </when>
        </choose>
        
        <!-- Add custom headers -->
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
                    Error = context.LastError.Message,
                    StackTrace = context.LastError.Source
                }.ToString();
            }
        </log-to-eventhub>
    </on-error>
</policies>
```

**GraphQL to REST Transformation**:

```xml
<!-- Example: GET /api/shipments/{id} -> GraphQL query -->
<policies>
    <inbound>
        <base />
        <set-variable name="shipmentId" value="@(context.Request.MatchedParameters["id"])" />
        <set-body>@{
            return new JObject(
                new JProperty("query", $@"
                    query GetShipment($id: ID!) {{
                        shipment(id: $id) {{
                            id
                            shipmentNumber
                            customer {{ id name }}
                            shipDate
                            estimatedDeliveryDate
                            status
                            origin {{ name city country }}
                            destination {{ name city country }}
                            trackingNumber
                        }}
                    }}
                "),
                new JProperty("variables", new JObject(
                    new JProperty("id", context.Variables["shipmentId"])
                ))
            ).ToString();
        }</set-body>
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <rewrite-uri template="/graphql" />
    </inbound>
</policies>
```

### 6. Microsoft Purview Integration

**Purpose**: Comprehensive data governance and catalog.

**Data Product Registration**:

```json
{
  "dataProduct": {
    "name": "SAP-3PL-Logistics-Operations",
    "displayName": "SAP 3PL Logistics Operations Data Product",
    "description": "Real-time logistics and shipment data from SAP IDoc integration",
    "version": "1.0.0",
    "domain": "Logistics",
    "owner": {
      "type": "User",
      "email": "data-product-owner@company.com"
    },
    "steward": {
      "type": "Group",
      "email": "data-stewards@company.com"
    },
    "sla": {
      "availability": 99.9,
      "latency": {
        "value": 5,
        "unit": "minutes"
      },
      "dataFreshness": {
        "value": 1,
        "unit": "minutes"
      }
    },
    "assets": [
      {
        "type": "Table",
        "qualifiedName": "fabric://workspace/lakehouse/silver_shipments",
        "role": "source"
      },
      {
        "type": "API",
        "qualifiedName": "apim://sap-3pl-api/graphql",
        "role": "interface"
      },
      {
        "type": "API",
        "qualifiedName": "apim://sap-3pl-api/rest/shipments",
        "role": "interface"
      }
    ],
    "classification": {
      "confidentiality": "Internal",
      "compliance": ["GDPR", "SOC2"]
    },
    "tags": ["SAP", "Logistics", "3PL", "Real-time", "IDoc"]
  }
}
```

**Data Quality Rules**:

```json
{
  "qualityRules": [
    {
      "name": "ShipmentCompleteness",
      "description": "Ensure all required shipment fields are populated",
      "scope": "silver_shipments",
      "type": "Completeness",
      "rules": [
        {
          "field": "shipment_id",
          "condition": "IS NOT NULL",
          "threshold": 100
        },
        {
          "field": "customer_id",
          "condition": "IS NOT NULL",
          "threshold": 100
        },
        {
          "field": "ship_date",
          "condition": "IS NOT NULL",
          "threshold": 99.5
        }
      ],
      "actions": [
        {
          "type": "Alert",
          "threshold": 95,
          "recipients": ["data-quality-team@company.com"]
        }
      ]
    },
    {
      "name": "ShipmentAccuracy",
      "description": "Validate data accuracy against business rules",
      "scope": "silver_shipments",
      "type": "Accuracy",
      "rules": [
        {
          "field": "ship_date",
          "condition": "ship_date <= actual_delivery_date",
          "threshold": 99
        },
        {
          "field": "total_weight",
          "condition": "total_weight > 0",
          "threshold": 100
        }
      ]
    },
    {
      "name": "ShipmentTimeliness",
      "description": "Monitor data freshness",
      "scope": "silver_shipments",
      "type": "Timeliness",
      "rules": [
        {
          "field": "created_timestamp",
          "condition": "DATEDIFF(minute, created_timestamp, CURRENT_TIMESTAMP) <= 5",
          "threshold": 95
        }
      ]
    }
  ]
}
```

---

## Data Flow

### End-to-End Data Flow Sequence

```
1. IDoc Generation
   └─> Simulator generates SHPMNT IDoc
   └─> Validates against schema
   └─> Publishes to Event Hub

2. Real-time Ingestion
   └─> Event Hub receives message
   └─> Eventstream picks up message
   └─> Schema validation
   └─> Enrichment with metadata
   └─> Routes to Lakehouse (Bronze)

3. Data Transformation
   └─> Spark job reads Bronze table
   └─> Parses IDoc payload
   └─> Applies business logic
   └─> Data quality checks
   └─> Writes to Silver table
   └─> Aggregates to Gold layer

4. API Exposure
   └─> GraphQL resolver queries SQL Warehouse
   └─> Data loader batches requests
   └─> Response formatted per schema
   └─> Cached in APIM

5. Governance
   └─> Lineage tracked in Purview
   └─> Quality metrics collected
   └─> Catalog updated
   └─> Alerts triggered if threshold breached
```

---

## Integration Patterns

### Pattern 1: Event-Driven Ingestion
- **Pattern**: Publisher-Subscriber
- **Technology**: Azure Event Hubs + Fabric Eventstream
- **Benefits**: Decoupling, scalability, fault tolerance

### Pattern 2: Medallion Architecture
- **Pattern**: Bronze → Silver → Gold
- **Technology**: Delta Lake
- **Benefits**: Data quality, auditability, performance optimization

### Pattern 3: API Gateway
- **Pattern**: Backend for Frontend (BFF)
- **Technology**: Azure APIM
- **Benefits**: Centralized security, transformation, monitoring

### Pattern 4: GraphQL Federation (Future)
- **Pattern**: Federated GraphQL
- **Technology**: Apollo Federation
- **Benefits**: Composition of multiple data products

---

## Security Architecture

### Authentication & Authorization

```
┌──────────────┐
│   Consumer   │
└──────┬───────┘
       │ 1. Request with JWT
       ▼
┌──────────────────┐
│      APIM        │
│ ┌──────────────┐ │
│ │ Validate JWT │ │ 2. Validate token with Entra ID
│ └──────────────┘ │
└──────┬───────────┘
       │ 3. Token valid, check claims
       ▼
┌──────────────────┐
│  GraphQL API     │
│ ┌──────────────┐ │
│ │ Authorize    │ │ 4. Check role-based permissions
│ └──────────────┘ │
└──────┬───────────┘
       │ 5. Authorized, execute query
       ▼
┌──────────────────┐
│  SQL Warehouse   │
│ ┌──────────────┐ │
│ │ Row-Level    │ │ 6. Apply RLS based on user context
│ │ Security     │ │
│ └──────────────┘ │
└──────────────────┘
```

### Security Layers

1. **Network Security**
   - Private endpoints for Fabric workspace
   - VNet integration for API hosting
   - NSG rules for traffic filtering

2. **Identity & Access**
   - Azure AD / Entra ID authentication
   - OAuth 2.0 / OIDC
   - Role-based access control (RBAC)

3. **Data Security**
   - Encryption at rest (Azure Storage)
   - Encryption in transit (TLS 1.2+)
   - Row-level security in SQL Warehouse
   - Column-level encryption for PII

4. **API Security**
   - JWT validation
   - API key management
   - Rate limiting
   - IP whitelisting (optional)

5. **Monitoring & Audit**
   - All API calls logged
   - Azure Monitor alerts
   - Purview audit logs

---

## Scalability & Performance

### Scalability Targets

| Component | Target Throughput | Scaling Strategy |
|-----------|------------------|------------------|
| Event Hubs | 10,000 msg/sec | Partition count |
| Eventstream | 5,000 msg/sec | Auto-scale |
| Spark Jobs | 100 GB/hour | Cluster size |
| GraphQL API | 10,000 req/sec | Horizontal scaling |
| APIM | 50,000 req/min | Premium tier |

### Performance Optimization

1. **Lakehouse Optimization**
   ```sql
   -- Optimize Delta tables
   OPTIMIZE silver_shipments
   ZORDER BY (customer_id, ship_date);
   
   -- Vacuum old versions
   VACUUM silver_shipments RETAIN 168 HOURS;
   ```

2. **Caching Strategy**
   - APIM: Cache common queries (5 min TTL)
   - GraphQL: DataLoader for batching
   - SQL: Materialized views for aggregations

3. **Query Optimization**
   - Indexed columns for common filters
   - Partition pruning
   - Query result limiting

---

## Disaster Recovery

### Backup Strategy
- **Lakehouse**: Delta Lake time travel (7 days)
- **Event Hubs**: 7-day retention
- **Databases**: Daily automated backups

### Recovery Objectives
- **RTO** (Recovery Time Objective): 4 hours
- **RPO** (Recovery Point Objective): 1 hour

### DR Runbook
1. Detect failure via monitoring
2. Assess impact and data loss
3. Restore from backup or replay events
4. Validate data integrity
5. Resume normal operations

---

## Technology Decisions

### Why Microsoft Fabric?
- Unified platform for analytics
- Built-in governance with Purview integration
- Seamless scaling
- Cost-effective for lakehouse workloads

### Why GraphQL?
- Flexible querying reduces over-fetching
- Strong typing and schema introspection
- Better developer experience
- Supports real-time subscriptions

### Why Delta Lake?
- ACID transactions
- Time travel capabilities
- Schema evolution
- Optimized query performance

### Why Azure APIM?
- Enterprise-grade API management
- Built-in developer portal
- Advanced policies and transformations
- Integration with Azure services

---

## Deployment Architecture

### Environments

```
Development → Test → UAT → Production
    ↓          ↓      ↓         ↓
 [Dev Fabric] → [Test Fabric] → [UAT Fabric] → [Prod Fabric]
 [Dev APIM]   → [Test APIM]   → [UAT APIM]   → [Prod APIM]
```

### Infrastructure as Code

**Technology**: Azure Bicep or Terraform

```bicep
// Example: Fabric Workspace deployment
resource fabricWorkspace 'Microsoft.Fabric/workspaces@2023-11-01' = {
  name: 'sap-3pl-${environment}'
  location: location
  properties: {
    displayName: 'SAP 3PL Logistics ${environment}'
    description: 'SAP IDoc to Fabric data product'
  }
}

resource lakehouse 'Microsoft.Fabric/workspaces/lakehouses@2023-11-01' = {
  parent: fabricWorkspace
  name: 'sap-idoc-lakehouse'
  properties: {
    displayName: 'SAP IDoc Lakehouse'
  }
}
```

### CI/CD Pipeline

```yaml
# Azure DevOps / GitHub Actions
stages:
  - stage: Build
    jobs:
      - job: BuildSimulator
        steps:
          - task: UsePythonVersion@0
          - script: pip install -r requirements.txt
          - script: pytest tests/
      
      - job: BuildAPI
        steps:
          - task: UseDotNet@2
          - script: dotnet build
          - script: dotnet test
  
  - stage: DeployDev
    dependsOn: Build
    jobs:
      - deployment: DeployFabric
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  # Deploy Fabric artifacts
      
      - deployment: DeployAPI
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  # Deploy GraphQL API
  
  - stage: DeployProd
    dependsOn: DeployDev
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      # Production deployment with approvals
```

---

## Conclusion

This architecture provides a robust, scalable, and governed solution for transforming SAP IDoc data into a modern data product. By leveraging Microsoft Fabric, GraphQL, and Purview, the solution ensures:

- ✅ Real-time data availability
- ✅ Flexible API consumption
- ✅ Comprehensive data governance
- ✅ Enterprise-grade security
- ✅ Scalability for growth

---

**Document Control**
- **Author**: Architecture Team
- **Reviewers**: [List reviewers]
- **Approval Date**: [Date]
- **Next Review**: [Date]
