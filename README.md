# SAP IDoc to Microsoft Fabric Data Product

## 🎯 Project Overview

This project demonstrates a modern data product architecture for ingesting SAP IDocs (Intermediate Documents) into Microsoft Fabric, focusing on a **3PL (Third-Party Logistics)** business case. The solution provides real-time data ingestion, transformation, and API-based consumption with comprehensive data governance.

## 🏗️ Architecture

```
┌─────────────────┐
│  IDoc Simulator │
│   (3PL Domain)  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│         Microsoft Fabric Eventstream        │
│      (Real-time Data Ingestion)            │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│     Fabric Lakehouse / Data Warehouse       │
│     (Data Storage & Transformation)         │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│           GraphQL Data Product              │
│        (Unified Data Access Layer)          │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│      Azure API Management (APIM)            │
│   - GraphQL Endpoint                        │
│   - REST API (from GraphQL)                 │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│    Microsoft Purview Data Catalog           │
│  - Data Product Definition                  │
│  - Data Quality Rules                       │
│  - API Registration                         │
│  - Lineage & Governance                     │
└─────────────────────────────────────────────┘
```

## 📋 Business Case: 3PL Operations

### SAP IDoc Types Covered
- **DESADV** - Delivery Notification
- **SHPMNT** - Shipment Information
- **INVOICE** - Billing Document
- **ORDERS** - Purchase Order
- **WHSCON** - Warehouse Confirmation

### Use Cases
1. Real-time shipment tracking
2. Inventory movement monitoring
3. Automated billing reconciliation
4. Warehouse operations analytics
5. Customer delivery status reporting

## 🚀 Project Components

### 1. IDoc Simulator
**Location:** `/simulator`

A Python-based simulator that generates realistic SAP IDoc messages for 3PL scenarios.

**Features:**
- Multiple IDoc types (DESADV, SHPMNT, INVOICE, etc.)
- Configurable message frequency and volume
- Support for various 3PL scenarios
- Direct integration with Fabric Eventstream

**Technologies:**
- Python 3.11+
- Azure Event Hubs SDK
- SAP IDoc schema definitions

### 2. Fabric Eventstream Configuration
**Location:** `/fabric/eventstream`

Configuration and setup for real-time data ingestion.

**Features:**
- Event Hub source connection
- Data transformation rules
- Routing to Lakehouse/Warehouse
- Error handling and dead-letter queue

### 3. Data Transformation & Storage
**Location:** `/fabric/data-engineering`

Data pipelines and transformation logic.

**Features:**
- IDoc parsing and normalization
- Business logic implementation
- Dimensional modeling for analytics
- Delta Lake optimization

**Technologies:**
- Fabric Data Engineering (Spark)
- Delta Lake
- SQL Warehouse

### 4. GraphQL Data Product
**Location:** `/api/graphql`

GraphQL API layer providing unified access to the data product.

**Features:**
- Schema-first design
- Efficient query capabilities
- Real-time subscriptions (optional)
- Authentication & authorization

**Technologies:**
- Apollo Server / Hot Chocolate
- .NET 8 / Node.js
- Azure Functions / Container Apps

### 5. API Management Layer
**Location:** `/api/apim`

Azure APIM configuration for API governance and exposure.

**Features:**
- GraphQL endpoint exposure
- GraphQL-to-REST transformation
- Rate limiting and throttling
- API versioning
- Developer portal

**Endpoints:**
- `POST /graphql` - GraphQL endpoint
- `GET /api/shipments` - REST API for shipments
- `GET /api/deliveries` - REST API for deliveries
- `GET /api/invoices` - REST API for invoices

### 6. Data Governance (Purview)
**Location:** `/governance/purview`

Microsoft Purview configuration for comprehensive data governance.

**Features:**
- Data product registration
- Data quality rules definition
- Business glossary integration
- API catalog registration
- Data lineage tracking
- Sensitivity classification

**Data Quality Dimensions:**
- Completeness
- Accuracy
- Consistency
- Timeliness
- Validity

## 📁 Project Structure

```
Fabric+SAP+Idocs/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── api-documentation.md
│   └── governance-guide.md
├── simulator/
│   ├── src/
│   │   ├── idoc_generator.py
│   │   ├── idoc_schemas/
│   │   └── eventstream_publisher.py
│   ├── config/
│   ├── tests/
│   └── requirements.txt
├── fabric/
│   ├── eventstream/
│   │   └── eventstream-config.json
│   ├── data-engineering/
│   │   ├── notebooks/
│   │   └── pipelines/
│   └── warehouse/
│       └── schema/
├── api/
│   ├── graphql/
│   │   ├── schema/
│   │   ├── resolvers/
│   │   └── server.js (or Program.cs)
│   └── apim/
│       ├── policies/
│       └── api-definitions/
├── governance/
│   ├── purview/
│   │   ├── data-product-definition.json
│   │   ├── data-quality-rules.json
│   │   └── catalog-registration.json
│   └── scripts/
└── infrastructure/
    ├── bicep/
    └── terraform/
```

## 🛠️ Technology Stack

### Core Platform
- **Microsoft Fabric** - Unified analytics platform
- **Azure Event Hubs** - Event streaming
- **Azure API Management** - API gateway
- **Microsoft Purview** - Data governance

### Development
- **Python 3.11+** - IDoc simulator
- **.NET 8 / Node.js 20+** - GraphQL API
- **Apache Spark** - Data transformation
- **Delta Lake** - Data storage format

### Infrastructure
- **Azure Bicep / Terraform** - Infrastructure as Code
- **Azure DevOps / GitHub Actions** - CI/CD

## 🚦 Getting Started

### Prerequisites
- Azure Subscription with Fabric enabled
- Microsoft Purview account
- Azure API Management instance
- Python 3.11+
- .NET 8 SDK or Node.js 20+

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Fabric+SAP+Idocs
   ```

2. **Set up the IDoc Simulator**
   ```bash
   cd simulator
   pip install -r requirements.txt
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Azure credentials
   ```

4. **Deploy Fabric resources**
   - Follow instructions in `/fabric/README.md`

5. **Deploy GraphQL API**
   ```bash
   cd api/graphql
   # Follow language-specific setup
   ```

6. **Configure APIM**
   - Import API definitions from `/api/apim`

7. **Set up Purview governance**
   - Follow instructions in `/governance/README.md`

## 📊 Data Product Specifications

### Domain: 3PL Operations

**Data Product Name:** SAP-3PL-Logistics-Operations

**Owner:** Data Product Team

**SLA:**
- **Latency:** < 5 minutes from IDoc generation to API availability
- **Availability:** 99.9%
- **Data Freshness:** Near real-time (< 1 minute)

**Quality Metrics:**
- Completeness: > 99%
- Accuracy: > 99.5%
- Timeliness: 95% within SLA

**Data Entities:**
- Shipments
- Deliveries
- Invoices
- Warehouse Confirmations
- Inventory Movements

## 🔐 Security & Compliance

- **Authentication:** Azure AD / Entra ID
- **Authorization:** Role-based access control (RBAC)
- **Data Encryption:** At rest and in transit
- **Compliance:** GDPR, SOC 2 considerations
- **Audit Logging:** Comprehensive activity logging

## 📈 Monitoring & Observability

- **Fabric Monitoring:** Built-in monitoring for Eventstream and Pipelines
- **APIM Analytics:** API usage and performance metrics
- **Application Insights:** Custom telemetry and logging
- **Purview Insights:** Data quality and governance metrics

## 🧪 Testing Strategy

1. **Unit Tests:** Individual components
2. **Integration Tests:** End-to-end data flow
3. **Performance Tests:** Load and stress testing
4. **Data Quality Tests:** Validation rules
5. **API Contract Tests:** GraphQL schema validation

## 📝 API Documentation

GraphQL schema and API documentation available at:
- GraphQL Playground: `https://<apim-url>/graphql`
- REST API Docs: `https://<apim-url>/docs`
- Developer Portal: `https://<apim-url>/developer`

## 🤝 Contributing

1. Create a feature branch
2. Implement changes with tests
3. Submit pull request
4. Pass code review and CI/CD checks

## 📚 Additional Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [SAP IDoc Documentation](https://help.sap.com/docs/idocs)
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Microsoft Purview](https://learn.microsoft.com/purview/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)

## 📄 License

[Specify your license]

## 👥 Team & Contact

- **Product Owner:** [Name]
- **Technical Lead:** [Name]
- **Data Engineer:** [Name]
- **Support:** [Contact Information]

---

**Version:** 1.0.0  
**Last Updated:** October 23, 2025  
**Status:** In Development
