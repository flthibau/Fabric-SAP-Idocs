# Medallion Architecture - Eventhouse Design

## Overview

This document defines the **Bronze → Silver → Gold** architecture for SAP IDoc data in the context of **3PL (Third-Party Logistics)** operations.

---

## 🥉 Bronze Layer (Raw Data)

### Purpose
Store raw IDoc messages as received from SAP via Event Hub, with minimal transformation.

### Table
- **`idoc_raw`** ✅ (Already exists)

### Characteristics
- **Data Quality**: Raw, unvalidated
- **Schema**: Flexible (dynamic JSON)
- **Retention**: 90 days
- **Update**: Real-time streaming from Eventstream

### Columns
```kql
idoc_type: string          // IDoc type identifier
message_type: string       // Message type (ORDERS, DESADV, etc.)
sap_system: string         // Source SAP system
timestamp: datetime        // Message timestamp
control: dynamic           // Control segment (JSON)
data: dynamic              // Data segments (JSON)
EventProcessedUtcTime: datetime
PartitionId: string
EventEnqueuedUtcTime: datetime
```

---

## 🥈 Silver Layer (Cleansed & Enriched)

### Purpose
Cleansed, validated, and structured data ready for business analysis.

### Tables to Create

#### 1. `idoc_orders_silver`
**Purpose**: Cleansed purchase orders from ORDERS IDoc type

**Business Fields Extracted**:
- Order number
- Customer ID
- Order date
- Delivery date
- Total amount
- Order status
- Line items (products, quantities, prices)

**Data Quality**:
- Validation: Non-null order numbers
- Deduplication: Latest version per order
- Enrichment: Calculated fields (age, SLA status)

#### 2. `idoc_shipments_silver`
**Purpose**: Shipment tracking from SHPMNT + DESADV IDoc types

**Business Fields**:
- Shipment number
- Tracking number
- Origin/Destination
- Carrier
- Planned vs actual ship date
- Delivery status
- Related order numbers

#### 3. `idoc_warehouse_silver`
**Purpose**: Warehouse operations from WHSCON IDoc type

**Business Fields**:
- Warehouse ID
- Movement type (receipt, picking, shipping)
- Material/SKU
- Quantity
- Location (bin, shelf)
- Operator ID
- Timestamp

#### 4. `idoc_invoices_silver`
**Purpose**: Invoice data from INVOIC IDoc type

**Business Fields**:
- Invoice number
- Customer ID
- Invoice date
- Due date
- Total amount
- Tax amount
- Payment status
- Related order/shipment

---

## 🥇 Gold Layer (Business Analytics)

### Purpose
Pre-aggregated, business-ready metrics for fast API queries and dashboards.

### Materialized Views to Create

#### 1. `orders_daily_summary`
**Metrics**:
- Total orders per day
- Total revenue
- Average order value
- Orders by status (pending, shipped, delivered)
- SLA compliance rate

**Refresh**: Every 5 minutes

#### 2. `shipments_in_transit`
**Metrics**:
- Active shipments count
- Expected delivery today/this week
- Delayed shipments
- Average transit time by carrier/route

**Refresh**: Real-time (continuous)

#### 3. `warehouse_productivity`
**Metrics**:
- Movements per hour by warehouse
- Picking rate (items/hour)
- Error rate (returns, corrections)
- Inventory turns

**Refresh**: Every 15 minutes

#### 4. `revenue_realtime`
**Metrics**:
- Revenue today/this week/this month
- Revenue by customer
- Revenue by product category
- Invoice payment status

**Refresh**: Every 5 minutes

#### 5. `sla_performance`
**Metrics**:
- Order-to-ship SLA (% on-time)
- Ship-to-delivery SLA
- Invoice processing time
- Customer satisfaction score (derived)

**Refresh**: Every 30 minutes

---

## 🔄 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER (Raw)                        │
│                                                               │
│  idoc_raw (streaming from Eventstream)                       │
│  - All IDoc types (ORDERS, DESADV, SHPMNT, INVOIC, WHSCON)  │
│  - Retention: 90 days                                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ Update Policies (automatic transformation)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                   SILVER LAYER (Cleansed)                    │
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │ idoc_orders     │  │ idoc_shipments   │                 │
│  │ _silver         │  │ _silver          │                 │
│  └─────────────────┘  └──────────────────┘                 │
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │ idoc_warehouse  │  │ idoc_invoices    │                 │
│  │ _silver         │  │ _silver          │                 │
│  └─────────────────┘  └──────────────────┘                 │
│                                                               │
│  - Validated, structured                                     │
│  - Business fields extracted                                 │
│  - Retention: 365 days                                       │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ Materialized Views (pre-aggregated)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    GOLD LAYER (Analytics)                    │
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │ orders_daily    │  │ shipments_in     │                 │
│  │ _summary        │  │ _transit         │                 │
│  └─────────────────┘  └──────────────────┘                 │
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │ warehouse_      │  │ revenue_         │                 │
│  │ productivity    │  │ realtime         │                 │
│  └─────────────────┘  └──────────────────┘                 │
│                                                               │
│  ┌─────────────────┐                                        │
│  │ sla_performance │                                        │
│  └─────────────────┘                                        │
│                                                               │
│  - Pre-aggregated metrics                                    │
│  - Fast query response (<100ms)                              │
│  - API-ready                                                 │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ GraphQL API (via Azure Functions)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                  AZURE API MANAGEMENT                        │
│                                                               │
│  - Authentication (API keys, OAuth2)                         │
│  - Rate limiting                                             │
│  - Caching                                                   │
│  - Monitoring                                                │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ Published as Data Product
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              MICROSOFT PURVIEW DATA PRODUCT                  │
│                                                               │
│  - Data lineage (Eventstream → Eventhouse → API)            │
│  - Data catalog                                              │
│  - Governance policies                                       │
│  - Consumer discovery                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Key Performance Indicators (KPIs)

### Operational KPIs (Real-time)
1. **Orders in Process**: Count of orders not yet shipped
2. **Shipments in Transit**: Active shipments
3. **Warehouse Utilization**: % capacity used
4. **Invoice Pending**: Unpaid invoices

### Performance KPIs (Historical trends)
1. **Order Processing Time**: From order to shipment
2. **Delivery Performance**: % on-time deliveries
3. **Warehouse Throughput**: Items processed/hour
4. **Invoice Cycle Time**: From shipment to payment

### Financial KPIs
1. **Daily Revenue**: Total invoiced amount
2. **Outstanding Receivables**: Unpaid invoice value
3. **Average Order Value**: Revenue / order count
4. **Revenue by Customer**: Top customers

---

## 🔧 Implementation Steps

### Phase 1: Silver Layer (Week 1)
1. Create `idoc_orders_silver` table + update policy
2. Create `idoc_shipments_silver` table + update policy
3. Create `idoc_warehouse_silver` table + update policy
4. Create `idoc_invoices_silver` table + update policy
5. Validate data quality

### Phase 2: Gold Layer (Week 1)
1. Create materialized views for daily summaries
2. Create real-time metric views
3. Optimize refresh intervals
4. Test query performance (<100ms target)

### Phase 3: GraphQL API (Week 2)
1. Design GraphQL schema
2. Implement resolvers (KQL queries)
3. Deploy to Azure Functions
4. Add authentication

### Phase 4: APIM + Purview (Week 2)
1. Configure API Management
2. Add policies (throttling, caching)
3. Register in Purview as Data Product
4. Document API for consumers

---

## 📈 Success Metrics

- **Query Performance**: <100ms for Gold layer queries
- **Data Freshness**: <5 seconds from IDoc arrival to Gold layer
- **API Response Time**: <200ms for GraphQL queries
- **Uptime**: 99.9% availability
- **Data Quality**: <0.1% error rate in Silver layer

---

## 🚀 Ready to Build

**Next Steps**:
1. Create Silver layer tables
2. Implement update policies
3. Build Gold layer materialized views
4. Test end-to-end with real IDoc data

Let's start building! 🏗️
