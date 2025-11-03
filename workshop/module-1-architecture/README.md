# Module 1: Architecture Overview

> **Understanding the SAP IDoc to Microsoft Fabric data flow**

⏱️ **Duration**: 60 minutes  
🎯 **Level**: Beginner  
📋 **Prerequisites**: None

---

## 📖 Module Overview

This module introduces the architectural foundations for integrating SAP IDoc messages with Microsoft Fabric. You'll learn about SAP IDocs, understand the components of Microsoft Fabric, and explore the end-to-end data flow for building a real-time data product.

### Learning Objectives

By the end of this module, you will be able to:

- ✅ Explain what SAP IDocs are and their structure
- ✅ Identify the key Microsoft Fabric components used in the solution
- ✅ Describe the end-to-end data flow from SAP to API
- ✅ Understand the medallion architecture pattern (Bronze/Silver/Gold)
- ✅ Recognize the security and governance layers
- ✅ Explain the 3PL logistics business scenario

---

## 📚 Lesson Content

### 1. Introduction to SAP IDocs

#### What is an IDoc?

**IDoc (Intermediate Document)** is SAP's standard data container used for electronic data interchange (EDI) between SAP systems and external systems.

**Key Characteristics**:
- **Standardized Format**: Predefined structure for different business processes
- **Asynchronous**: Messages can be queued and processed independently
- **Versioned**: Different versions support different SAP releases
- **Bidirectional**: Can be inbound (to SAP) or outbound (from SAP)

#### IDoc Structure

```
┌─────────────────────────────────────┐
│         Control Record              │  ← Header information
│  - IDoc Number                      │
│  - Message Type                     │
│  - Partner Information              │
│  - Direction                        │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│         Data Records                │  ← Business data segments
│  - Segment 1 (Header)               │
│  - Segment 2 (Items)                │
│  - Segment 3 (Partners)             │
│  - Segment N...                     │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│         Status Records              │  ← Processing status
│  - Status Code                      │
│  - Timestamp                        │
│  - Error Messages                   │
└─────────────────────────────────────┘
```

#### Common IDoc Types in 3PL Logistics

| IDoc Type | Description | Business Process |
|-----------|-------------|------------------|
| **ORDERS** | Purchase Order | Order creation from customers |
| **SHPMNT** | Shipment | Shipment notifications |
| **DESADV** | Despatch Advice | Delivery notifications |
| **WHSCON** | Warehouse Confirmation | Warehouse inventory movements |
| **INVOIC** | Invoice | Billing and invoicing |

#### Sample IDoc Message (JSON representation)

```json
{
  "idoc_number": "0000000123456789",
  "idoc_type": "SHPMNT01",
  "message_type": "SHPMNT",
  "direction": "OUTBOUND",
  "partner": {
    "partner_number": "FEDEX",
    "partner_type": "CARRIER",
    "partner_function": "SP"
  },
  "control": {
    "created_date": "2025-01-15",
    "created_time": "14:30:00",
    "status": "03"
  },
  "data": {
    "header": {
      "shipment_id": "SHIP-2025-001234",
      "shipment_number": "SHP001234",
      "ship_date": "2025-01-16",
      "delivery_date": "2025-01-18"
    },
    "items": [
      {
        "item_number": "000010",
        "material": "MAT-12345",
        "quantity": 100,
        "weight": 50.5,
        "weight_unit": "KG"
      }
    ],
    "addresses": {
      "origin": {
        "name": "Warehouse East",
        "city": "New York",
        "country": "US"
      },
      "destination": {
        "name": "ACME Corporation",
        "city": "Chicago",
        "country": "US"
      }
    }
  }
}
```

---

### 2. Microsoft Fabric Components

#### What is Microsoft Fabric?

**Microsoft Fabric** is an all-in-one analytics solution for enterprises that covers everything from data movement to data science, Real-Time Analytics, and business intelligence.

#### Key Components Used in This Solution

##### 1. **Real-Time Intelligence (Eventhouse)**

```
┌────────────────────────────────────────┐
│      Eventhouse (KQL Database)         │
│                                        │
│  • Sub-second data ingestion          │
│  • Streaming transformations          │
│  • KQL query engine                   │
│  • Real-time analytics                │
│  • Hot/cold data tiers                │
└────────────────────────────────────────┘
```

**Use Cases**:
- Real-time operational dashboards
- Streaming analytics
- Anomaly detection
- Live data exploration

##### 2. **Eventstream**

```
┌────────────────────────────────────────┐
│           Eventstream                  │
│                                        │
│  • No-code stream processing          │
│  • Multiple sources/destinations      │
│  • Data transformation                │
│  • Error handling & routing           │
└────────────────────────────────────────┘
```

**Features**:
- Visual stream design
- Built-in transformations
- Schema validation
- Dead-letter queue support

##### 3. **Lakehouse (OneLake)**

```
┌────────────────────────────────────────┐
│          Lakehouse Storage             │
│                                        │
│  Gold Layer (Business-Ready)          │
│  • Materialized lake views            │
│  • Star schema (dimensions & facts)   │
│  • Built from mirrored Silver data    │
│                                        │
│  • Delta Lake format (ACID)           │
│  • Unified storage                    │
│  • Multi-engine access                │
└────────────────────────────────────────┘
```

**Medallion Architecture**:
- **Bronze**: Raw IDoc data ingested into Eventhouse
- **Silver**: Cleansed, normalized data in Eventhouse (via KQL update policies)
- **Gold**: Business-ready aggregations and views in Lakehouse (via materialized lake views)

##### 4. **Materialized Lake Views**

```
┌────────────────────────────────────────┐
│     Materialized Lake Views            │
│                                        │
│  • Create Gold layer transformations  │
│  • Query mirrored Silver Delta tables │
│  • Incremental refresh                │
│  • Dimensional modeling (star schema) │
└────────────────────────────────────────┘
```

##### 5. **Data Warehouse**

```
┌────────────────────────────────────────┐
│          SQL Warehouse                 │
│                                        │
│  • T-SQL query interface              │
│  • Materialized views                 │
│  • Row-Level Security (RLS)           │
│  • GraphQL API endpoint               │
└────────────────────────────────────────┘
```

##### 6. **OneLake Security**

```
┌────────────────────────────────────────┐
│        OneLake Security Layer          │
│                                        │
│  Centralized RLS across:              │
│  ✓ Real-Time Intelligence (KQL)       │
│  ✓ Data Engineering (Spark)           │
│  ✓ Data Warehouse (SQL)               │
│  ✓ Power BI (Direct Lake)             │
│  ✓ GraphQL API                        │
│  ✓ OneLake API                        │
└────────────────────────────────────────┘
```

---

### 3. End-to-End Architecture

#### Complete Data Flow

```
┌──────────────────┐
│   SAP System     │  1. Generate IDoc
│   (Simulated)    │
└────────┬─────────┘
         │
         ↓ IDoc Message (JSON/XML)
┌──────────────────────────────────────────┐
│      Azure Event Hub                     │  2. Ingest Events
│      (idoc-events)                       │
└────────┬─────────────────────────────────┘
         │
         ↓ Real-time Stream
┌──────────────────────────────────────────┐
│   Fabric Eventstream                     │  3. Stream Processing
│   • Schema validation                    │
│   • Enrichment                           │
│   • Error routing                        │
└────────┬─────────────────────────────────┘
         │
         ├─────────────────┐
         ↓                 ↓
┌─────────────────┐  ┌───────────┐
│   Eventhouse    │  │    DLQ    │
│   (Bronze)      │  │  (Errors) │
└────────┬────────┘  └───────────┘
         │
         ↓ KQL Update Policies (Real-Time)
┌─────────────────┐
│   Eventhouse    │  4. Real-Time Transformation
│   (Silver)      │     to Silver Layer
└────────┬────────┘
         │
         ↓ Auto-Mirror to OneLake
┌─────────────────┐
│   Lakehouse     │  5. Mirrored Bronze/Silver
│   (Delta Tables)│     (Auto-synced)
└────────┬────────┘
         │
         ↓ Materialized Lake Views
┌─────────────────┐
│   Lakehouse     │  6. Gold Layer
│   (Gold Layer)  │     Business Views
└────────┬────────┘
         │
         ↓ OneLake Security (RLS)
┌─────────────────┐
│  Data Warehouse │  7. Query Interface
│  + GraphQL API  │
└────────┬────────┘
         │
         ↓ OAuth2 + APIM
┌─────────────────┐
│  Azure APIM     │  8. API Gateway
│  • GraphQL      │
│  • REST APIs    │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│ Partner Apps    │  9. Consumption
│ • FedEx Portal  │
│ • WH-EAST App   │
│ • ACME Customer │
└─────────────────┘

Cross-Cutting Concerns:
┌─────────────────────────────────────────┐
│    Microsoft Purview                    │  Governance
│    • Data catalog                       │
│    • Quality monitoring                 │
│    • Lineage tracking                   │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│    Azure Monitor                        │  Monitoring
│    • Application Insights               │
│    • Log Analytics                      │
│    • Alerts & Dashboards                │
└─────────────────────────────────────────┘
```

#### Data Flow Sequence

| Step | Component | Action | Latency |
|------|-----------|--------|---------|
| 1 | SAP System (Simulated) | Generate IDoc message | - |
| 2 | Azure Event Hub | Receive and buffer message | < 1 sec |
| 3 | Fabric Eventstream | Validate, enrich, route | < 1 sec |
| 4 | Eventhouse Bronze | Real-time ingestion to Bronze layer | < 1 sec |
| 5 | Eventhouse Silver | KQL update policy transforms to Silver | < 1 sec |
| 6 | Lakehouse (Mirror) | Auto-mirror Bronze/Silver as Delta tables | < 5 sec |
| 7 | Lakehouse Gold | Materialized lake views create Gold layer | 1-5 min |
| 8 | GraphQL API | Query data from Gold layer | < 100 ms |
| 9 | APIM | Route to consumer | < 50 ms |

**Total End-to-End Latency**: 
- **Real-time path (Eventhouse Bronze/Silver)**: < 5 seconds
- **Analytics path (Lakehouse Gold)**: 1-5 minutes for materialized view refresh

---

### 4. Business Scenario: 3PL Logistics

#### The Challenge

A manufacturing company outsources logistics to external partners and needs to:

- **Share operational data** with carriers, warehouses, and customers
- **Ensure data security** - each partner sees only their data
- **Provide real-time access** - < 5 minutes latency
- **Support multiple access patterns** - GraphQL and REST APIs
- **Maintain data quality** - governance and monitoring

#### Partner Types

```
┌─────────────────────────────────────────────────────┐
│                   Partners                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  🚚 CARRIERS           🏭 WAREHOUSES    👔 CUSTOMERS│
│  • FedEx              • WH-EAST         • ACME Corp │
│  • UPS                • WH-WEST         • Widget Co │
│  • DHL                • WH-CENTRAL      • Global Inc│
│                                                     │
│  Access to:           Access to:        Access to:  │
│  - Shipments          - Inventory       - Orders    │
│  - Tracking           - Movements       - Shipments │
│                       - Receiving       - Invoices  │
└─────────────────────────────────────────────────────┘
```

#### Data Entities

| Entity | Description | Partner Access |
|--------|-------------|----------------|
| **Orders** | Customer purchase orders | Customers, Warehouses |
| **Shipments** | Shipment records | Carriers, Customers, Warehouses |
| **Deliveries** | Delivery confirmations | Carriers, Customers |
| **Warehouse Movements** | Inventory movements | Warehouses |
| **Invoices** | Billing documents | Customers |

#### Security Model

**Row-Level Security (RLS)** ensures each partner sees only authorized data:

```sql
-- Example RLS Rule
CREATE FUNCTION dbo.PartnerSecurityPredicate(@partner_id NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN (
    SELECT 1 AS AccessGranted
    WHERE @partner_id = CAST(SESSION_CONTEXT(N'PartnerID') AS NVARCHAR(50))
)

-- Apply to tables
CREATE SECURITY POLICY PartnerAccessPolicy
ADD FILTER PREDICATE dbo.PartnerSecurityPredicate(partner_id)
ON gold.shipments,
   gold.orders,
   gold.invoices
WITH (STATE = ON);
```

**Result**: FedEx queries only return FedEx shipments, ACME only sees ACME orders, etc.

---

### 5. Integration Patterns

#### Pattern 1: Event-Driven Ingestion

```
Publish-Subscribe Pattern
━━━━━━━━━━━━━━━━━━━━━
SAP → Event Hub → Multiple Consumers
      (1 to Many)
      
Benefits:
✓ Decoupling
✓ Scalability
✓ Fault tolerance
```

#### Pattern 2: Medallion Architecture

```
Bronze → Silver → Gold
━━━━━━━━━━━━━━━━━━━━
Raw → Cleansed → Business Views

Benefits:
✓ Data quality
✓ Auditability
✓ Performance optimization
```

#### Pattern 3: API Gateway

```
Backend for Frontend (BFF)
━━━━━━━━━━━━━━━━━━━━━━━━
GraphQL API → APIM → Partners
              (Security, Transformation, Monitoring)

Benefits:
✓ Centralized security
✓ API versioning
✓ Rate limiting
✓ Analytics
```

---

## 🧪 Hands-On Lab

### Lab 1: Explore Sample IDoc Messages

**Objective**: Understand IDoc structure by examining sample messages.

**Instructions**:

1. Navigate to the simulator directory:
   ```bash
   cd /path/to/Fabric-SAP-Idocs/simulator
   ```

2. Review sample IDoc schemas:
   ```bash
   cat sample_data/sample_shipment_idoc.json
   ```

3. Identify key components:
   - Control record fields
   - Header segment
   - Item segments
   - Partner information

4. **Exercise**: Map IDoc fields to business concepts
   - What is the shipment ID?
   - Who is the carrier?
   - What are the origin and destination?

**Solution**: [Lab 1 Solution](./labs/lab1-solution.md)

---

### Lab 2: Architecture Diagram Analysis

**Objective**: Understand component responsibilities in the architecture.

**Instructions**:

1. Review the end-to-end architecture diagram above

2. Answer these questions:
   - Which component handles schema validation?
   - Where is real-time analytics performed?
   - Which layer applies Row-Level Security?
   - What happens to invalid messages?

3. **Exercise**: Trace a shipment IDoc from SAP to API
   - List each component it passes through
   - Identify transformation points
   - Note security checkpoints

**Solution**: [Lab 2 Solution](./labs/lab2-solution.md)

---

### Lab 3: Business Scenario Mapping

**Objective**: Map technical components to business requirements.

**Instructions**:

1. Review the 3PL business scenario

2. **Exercise**: For each requirement, identify the technical solution

   | Requirement | Technical Solution |
   |-------------|-------------------|
   | Real-time data access | ? |
   | Partner data isolation | ? |
   | API flexibility | ? |
   | Data quality monitoring | ? |
   | Audit trail | ? |

3. Discuss why each technology was chosen

**Solution**: [Lab 3 Solution](./labs/lab3-solution.md)

---

## 📋 Knowledge Check

### Quiz

1. **What is an IDoc?**
   - [ ] A database table in SAP
   - [x] A standardized data container for EDI
   - [ ] A SAP programming language
   - [ ] A type of API

2. **Which Fabric component provides sub-second analytics?**
   - [ ] Lakehouse
   - [ ] Data Warehouse
   - [x] Real-Time Intelligence (Eventhouse)
   - [ ] Eventstream

3. **In the medallion architecture, which layer contains raw data?**
   - [x] Bronze
   - [ ] Silver
   - [ ] Gold
   - [ ] Platinum

4. **What does RLS stand for?**
   - [ ] Real-time Loading System
   - [ ] Relational Layer Security
   - [x] Row-Level Security
   - [ ] Remote Login Service

5. **Which Azure service acts as the API gateway?**
   - [ ] Azure Functions
   - [x] Azure API Management
   - [ ] Azure App Service
   - [ ] Azure Front Door

**Answers**: See [Quiz Answers](./labs/quiz-answers.md)

---

## 📚 Additional Resources

### Documentation
- [SAP IDoc Documentation](https://help.sap.com/docs)
- [Microsoft Fabric Overview](https://learn.microsoft.com/fabric/)
- [Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)
- [OneLake Documentation](https://learn.microsoft.com/fabric/onelake/)

### Reference Architecture
- [Main Architecture Document](../../docs/architecture.md)
- [Business Scenario](../../demo-app/BUSINESS_SCENARIO.md)
- [Technical Setup](../../demo-app/API_TECHNICAL_SETUP.md)

### Code Examples
- [IDoc Simulator](../../simulator/)
- [Sample IDocs](../../simulator/sample_data/)

---

## ✅ Module Completion

### Summary

In this module, you learned:

- ✅ SAP IDoc structure and common types
- ✅ Microsoft Fabric components and their roles
- ✅ End-to-end data flow architecture
- ✅ Medallion architecture pattern
- ✅ 3PL logistics business scenario
- ✅ Security and governance layers

### Next Steps

You're now ready to move to **[Module 2: Event Hub Integration](../module-2-event-hub/README.md)** where you'll:
- Deploy Azure Event Hub
- Configure the IDoc simulator
- Generate and publish test messages
- Monitor ingestion metrics

---

**[← Back to Workshop Home](../README.md)** | **[Next: Module 2 →](../module-2-event-hub/README.md)**
