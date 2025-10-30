# 🚀 Real-Time SAP IDoc Data Product with Microsoft Fabric

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)
[![Microsoft Fabric](https://img.shields.io/badge/Microsoft%20Fabric-0078D4?style=flat&logo=microsoft&logoColor=white)](https://fabric.microsoft.com)
[![Real-Time Intelligence](https://img.shields.io/badge/Real--Time%20Intelligence-00BCF2?style=flat&logo=microsoft&logoColor=white)](https://learn.microsoft.com/fabric/real-time-intelligence/)
[![Microsoft Purview](https://img.shields.io/badge/Microsoft%20Purview-50E6FF?style=flat&logo=microsoft&logoColor=black)](https://purview.microsoft.com)

> **A complete end-to-end demonstration of a governed, real-time data product for 3PL logistics operations**

## 🎯 What You'll Find Here

This repository contains a **production-ready reference implementation** demonstrating how to build a modern data product on Microsoft Fabric with:

✅ **Real-Time Data Product** with Fabric Real-Time Intelligence (Eventhouse)  
✅ **OneLake Security** - Centralized Row-Level Security across all 6 Fabric engines  
✅ **Microsoft Purview Unified Catalog** - Complete data governance and quality monitoring  
✅ **GraphQL API** via Azure API Management with OAuth2 authentication  
✅ **Live Demo Application** - Visual interface showing partner-specific data filtering  
✅ **SAP IDoc Simulator** - Generate realistic 3PL logistics data

---

## ⚡ Quick Start

### 🎬 See the Demo in Action

```powershell
# 1. Clone the repository
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git
cd Fabric-SAP-Idocs

# 2. Launch the demo application
cd demo-app
.\start-demo.ps1

# 3. Get an access token (example with FedEx carrier)
.\get-token.example.ps1 -ServicePrincipal fedex

# 4. Open http://localhost:8000 and paste the token
```

📖 **Full Setup Guide**: See [`demo-app/QUICKSTART.md`](./demo-app/QUICKSTART.md)

---

## 📋 Business Scenario: 3PL Logistics with Row-Level Security

A manufacturing company outsources logistics to external partners (carriers, warehouses, customers) and needs to **expose real-time operational data via API** while ensuring **each partner sees only their own data**.

### The Challenge
- **3 Partner Types**: Carriers (e.g., FedEx), Warehouse Partners (e.g., WH-EAST), Customers (e.g., ACME Corp)
- **5 Data Entities**: Orders, Shipments, Deliveries, Warehouse Movements, Invoices
- **Security Requirement**: Partners must only see data they're authorized to access

### The Solution
**Real-Time Data Product** powered by:
- 🔥 **Microsoft Fabric Real-Time Intelligence** (Eventhouse) for sub-second streaming
- 🔒 **OneLake Security** for centralized Row-Level Security across 6 engines
- 📊 **Microsoft Purview** for data governance and quality monitoring
- 🌐 **GraphQL API** exposed through Azure API Management

📄 **Complete Business Case**: [`demo-app/BUSINESS_SCENARIO.md`](./demo-app/BUSINESS_SCENARIO.md)

---

## 🏗️ Architecture Overview

```
SAP ERP System
      ↓
Azure Event Hubs (idoc-events)
      ↓
╔══════════════════════════════════════════════════════════╗
║  MICROSOFT FABRIC REAL-TIME INTELLIGENCE                 ║
║  ┌─────────────────────────────────────────────────┐    ║
║  │  Eventhouse (KQL Database)                      │    ║
║  │  - Sub-second ingestion                         │    ║
║  │  - Streaming transformations                    │    ║
║  │  - Real-time analytics                          │    ║
║  └─────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════╝
      ↓
╔══════════════════════════════════════════════════════════╗
║  MICROSOFT FABRIC LAKEHOUSE                              ║
║  ┌─────────────────────────────────────────────────┐    ║
║  │  OneLake Storage (Delta Lake)                   │    ║
║  │  - Bronze: Raw IDocs                            │    ║
║  │  - Silver: Normalized tables                    │    ║
║  │  - Gold: Business views (materialized)          │    ║
║  └─────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════╝
      ↓
╔══════════════════════════════════════════════════════════╗
║  ONELAKE SECURITY LAYER (Centralized RLS)                ║
║  ✓ Real-Time Intelligence (KQL)                          ║
║  ✓ Data Engineering (Spark)                              ║
║  ✓ Data Warehouse (SQL)                                  ║
║  ✓ Power BI (Direct Lake)                                ║
║  ✓ GraphQL API (THIS PROJECT)                            ║
║  ✓ OneLake API                                           ║
╚══════════════════════════════════════════════════════════╝
      ↓
Fabric GraphQL API (partner_logistics_api)
      ↓
Azure API Management (apim-3pl-flt)
   - OAuth2 validation
   - CORS policy
   - Rate limiting
      ↓
╔══════════════════════════════════════════════════════════╗
║  MICROSOFT PURVIEW UNIFIED CATALOG                       ║
║  - Data Product registration                             ║
║  - Data quality monitoring                               ║
║  - Lineage tracking                                      ║
║  - Business glossary                                     ║
╚══════════════════════════════════════════════════════════╝
      ↓
Partner Applications
   - FedEx Carrier Portal
   - Warehouse WH-EAST Dashboard
   - ACME Corp Customer Portal
```

📄 **Technical Architecture**: [`demo-app/API_TECHNICAL_SETUP.md`](./demo-app/API_TECHNICAL_SETUP.md)

---

## 🎯 Project Overview

This project demonstrates how to build a **governed, real-time data product** on Microsoft Fabric with enterprise-grade security and quality controls. It showcases the complete journey from SAP IDoc ingestion to partner API consumption.

---

## 📦 Repository Contents

### 🎬 Demo Application (`/demo-app`)
**Live demonstration of Row-Level Security in action**

- **Visual Interface**: 4-tab application showing partner-specific data filtering
- **OAuth2 Authentication**: Service Principal token acquisition scripts
- **Documentation**: 
  - [`BUSINESS_SCENARIO.md`](./demo-app/BUSINESS_SCENARIO.md) - Professional business case (LinkedIn-ready)
  - [`API_TECHNICAL_SETUP.md`](./demo-app/API_TECHNICAL_SETUP.md) - Complete technical guide
  - [`QUICKSTART.md`](./demo-app/QUICKSTART.md) - Get started in 5 minutes

**Technologies**: HTML5, JavaScript, Python HTTP Server

### 🎲 SAP IDoc Simulator (`/simulator`)
**Generate realistic 3PL logistics data**

- **5 IDoc Types**: ORDERS, SHPMNT, DESADV, WHSCON, INVOIC
- **Configurable Scenarios**: Warehouse count, customer count, carrier count
- **Azure Event Hubs Integration**: Direct ingestion to Fabric Eventstream
- **Documentation**: Complete setup and usage guide

**Technologies**: Python 3.11+, Azure SDK, YAML configuration

```bash
cd simulator
python main.py --count 100  # Generate 100 IDocs
```

### 🏭 Fabric Configuration (`/fabric`)
**Microsoft Fabric workspace setup and data transformations**

- **Eventstream**: Real-Time Intelligence ingestion configuration
- **Data Engineering**: Spark notebooks for Bronze/Silver/Gold layers
- **Warehouse**: SQL schemas and materialized views
- **OneLake Security**: Row-Level Security configuration guides

**Key Files**:
- `warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md` - Complete RLS setup
- `data-engineering/notebooks/gold_layer_orders_summary.py` - Gold layer transformations

### 🌐 API Implementation (`/api`)
**GraphQL and APIM configuration**

- **GraphQL Schema**: Partner-filtered data access (`partner-api.graphql`)
- **APIM Policies**: 
  - CORS configuration
  - OAuth2 validation
  - Rate limiting
  - GraphQL passthrough
- **PowerShell Scripts**: Service Principal setup, APIM deployment, testing

**Endpoints**:
- GraphQL: `https://apim-3pl-flt.azure-api.net/graphql`
- REST (auto-generated): `/rest/shipments`, `/rest/orders`, etc.

### 🛡️ Governance & Quality (`/governance`)
**Microsoft Purview integration**

- **Data Product Registration**: Purview catalog integration
- **Data Quality Rules**: Automated quality monitoring
- **KQL Queries**: Quality validation dashboards
- **Python Scripts**: Quality rule deployment

**Technologies**: Microsoft Purview, KQL, Python

### 🏗️ Infrastructure (`/infrastructure`)
**Infrastructure as Code templates**

- **Bicep Templates**: Azure resource deployment
- **PowerShell Scripts**: APIM setup, Service Principal creation, REST API deployment
- **Configuration Files**: Resource definitions and policies

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Ingestion** | Azure Event Hubs | SAP IDoc streaming |
| **Real-Time Processing** | Fabric Real-Time Intelligence (Eventhouse) | Sub-second analytics |
| **Storage** | OneLake (Delta Lake) | Unified data lake |
| **Transformation** | Fabric Data Engineering (Spark) | ETL pipelines |
| **Analytics** | Fabric Data Warehouse (SQL) | TSQL queries |
| **API** | Fabric GraphQL + Azure APIM | Data product exposure |
| **Security** | OneLake Security + Azure AD | Centralized RLS |
| **Governance** | Microsoft Purview | Data catalog & quality |
| **BI** | Power BI Direct Lake | Real-time dashboards |

---

## 🔒 Security Architecture

### OneLake Security: Single Point of Control

**Storage-Layer Row-Level Security** enforced across **all 6 Fabric engines**:

```sql
-- Example RLS rule applied at OneLake storage layer
CREATE FUNCTION dbo.PartnerSecurityPredicate(@partner_id NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN (
    SELECT 1 AS AccessGranted
    WHERE @partner_id = CAST(SESSION_CONTEXT(N'PartnerID') AS NVARCHAR(50))
)
```

**Benefits**:
✅ **Centralized**: One RLS definition, enforced everywhere  
✅ **Multi-Engine**: Works across KQL, Spark, SQL, Power BI, GraphQL, OneLake API  
✅ **Identity-Aware**: Leverages Azure AD Service Principal claims  
✅ **Impossible to Bypass**: Enforced at storage layer, not application layer

### Authentication Flow

1. **Partner Application** → Acquires OAuth2 token from Azure AD
2. **Token Claims** → Include Service Principal ObjectId
3. **APIM Gateway** → Validates token, extracts claims
4. **GraphQL API** → Sets session context with partner identity
5. **OneLake Security** → Filters data based on RLS rules
6. **Partner Receives** → Only authorized data

📄 **Complete Security Guide**: [`fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md`](./fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md)

---

## 📊 Data Governance with Microsoft Purview

### Unified Catalog Integration

**Data Product Registration**:
- Product Name: `SAP-3PL-Logistics-Real-Time-Product`
- Domain: Logistics & Supply Chain
- Owner: Data Product Team
- SLA: < 5 minutes latency, 99.9% availability

**Data Quality Monitoring** (6 dimensions):
1. **Completeness**: Required fields populated
2. **Accuracy**: Valid reference data
3. **Consistency**: Cross-entity relationships maintained
4. **Timeliness**: Data freshness SLA compliance
5. **Validity**: Format and range validations
6. **Uniqueness**: No duplicate key violations

**Automated Quality Checks**:
```kql
// Example quality check running in Purview
idoc_shipments_gold
| summarize 
    TotalRows = count(),
    MissingCarrier = countif(isempty(carrier_id)),
    FutureDates = countif(ship_date > now())
| extend 
    CompletenessScore = 100.0 * (1 - todouble(MissingCarrier) / TotalRows),
    ValidityScore = 100.0 * (1 - todouble(FutureDates) / TotalRows)
```

📄 **Governance Setup**: [`governance/PURVIEW_DATA_QUALITY_SETUP.md`](./governance/PURVIEW_DATA_QUALITY_SETUP.md)

---

## 📈 Real-Time Intelligence Capabilities

### Eventhouse (KQL Database)

**Sub-Second Streaming Analytics**:
- Ingestion latency: < 1 second
- Query performance: Sub-second for aggregations
- Retention: Configurable (hot/cold tiers)

**Example KQL Queries**:
```kql
// Real-time shipment tracking
idoc_shipments_raw
| where ingestion_time() > ago(5m)
| where carrier_id == "FEDEX"
| summarize 
    ShipmentCount = count(),
    TotalWeight = sum(weight_kg)
  by bin(ship_date, 1h)
| render timechart
```

**Use Cases**:
- Live operational dashboards
- Real-time alerting
- Streaming anomaly detection
- Interactive exploration

---

## 🚀 Getting Started

### Prerequisites

- **Azure Subscription** with Microsoft Fabric enabled
- **Azure AD** tenant with permission to create Service Principals
- **Fabric Workspace** with appropriate permissions
- **PowerShell 7+** or **Azure CLI**
- **Python 3.11+** (for simulator)

### Step-by-Step Setup

#### 1️⃣ Deploy Azure Infrastructure

```powershell
cd infrastructure/bicep

# Deploy Event Hub
az deployment group create \
  --resource-group rg-fabric-sap-idocs \
  --template-file event-hub.bicep

# Deploy APIM (if not existing)
az deployment group create \
  --resource-group rg-fabric-sap-idocs \
  --template-file apim.bicep
```

#### 2️⃣ Create Service Principals

```powershell
cd api/scripts

# Create 3 Service Principals (FedEx, Warehouse, ACME)
.\create-partner-apps.ps1

# Grant Fabric workspace access
.\grant-sp-workspace-access.ps1
```

#### 3️⃣ Configure Microsoft Fabric

**Eventstream**:
1. Create Eventstream: `idoc-ingestion-stream`
2. Source: Azure Event Hubs (`eh-idoc-flt8076/idoc-events`)
3. Destination: Eventhouse `kql-3pl-logistics`

**Lakehouse**:
1. Create Lakehouse: `lakehouse_3pl`
2. Run Bronze/Silver/Gold transformation notebooks
3. Create materialized views

**OneLake Security**:
```sql
-- Run in Fabric Warehouse
-- See fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md
CREATE SECURITY POLICY PartnerAccessPolicy
ADD FILTER PREDICATE dbo.PartnerSecurityPredicate(partner_id)
ON gold.orders, gold.shipments, gold.invoices
WITH (STATE = ON);
```

#### 4️⃣ Deploy GraphQL API

```powershell
cd fabric/scripts

# Enable GraphQL on Lakehouse
.\enable-graphql-api.ps1

# Deploy API definition
.\deploy-graphql-api.ps1
```

#### 5️⃣ Configure APIM

```powershell
cd api/scripts

# Deploy APIM policies (CORS, OAuth, etc.)
.\configure-and-test-apim.ps1

# Test REST API endpoints
.\test-rest-apis.ps1
```

#### 6️⃣ Run the Demo Application

```powershell
cd demo-app

# Copy example file and add your secrets
Copy-Item get-token.example.ps1 get-token.ps1
# Edit get-token.ps1 with real Service Principal secrets

# Start demo server
.\start-demo.ps1

# In another terminal, get a token
.\get-token.ps1 -ServicePrincipal fedex

# Open http://localhost:8000 and paste token
```

#### 7️⃣ (Optional) Setup Purview Governance

```powershell
cd governance/purview

# Register data product in Purview
python create_data_quality_rules.py

# Deploy quality monitoring dashboard
# Upload data_quality_monitoring_dashboard.kql to Purview
```

📄 **Detailed Setup Guides**: See individual README files in each folder

---

## 🧪 Testing the Solution

### End-to-End Flow Test

```powershell
# 1. Generate test IDocs
cd simulator
python main.py --count 50

# 2. Verify Eventstream ingestion
# Check Fabric Eventstream monitoring

# 3. Query Eventhouse (Real-Time Intelligence)
# Run KQL query in Eventhouse portal

# 4. Test GraphQL API
cd ../api/scripts
.\test-graphql-rls.ps1

# 5. Test REST API via APIM
.\test-rest-apis.ps1

# 6. Verify RLS filtering
.\test-fedex-only.ps1  # Should only see FedEx shipments
```

### Data Quality Validation

```kql
// Run in Eventhouse or Purview
idoc_shipments_gold
| extend QualityCheck = case(
    isempty(carrier_id), "Missing Carrier",
    isempty(tracking_number), "Missing Tracking",
    weight_kg <= 0, "Invalid Weight",
    "OK"
)
| summarize count() by QualityCheck
```

---

## 📚 Documentation Index

### Business & Architecture
- 📄 [`demo-app/BUSINESS_SCENARIO.md`](./demo-app/BUSINESS_SCENARIO.md) - **LinkedIn-ready business case**
- 📄 [`demo-app/API_TECHNICAL_SETUP.md`](./demo-app/API_TECHNICAL_SETUP.md) - Technical architecture deep-dive
- 📄 [`PROJECT_STRUCTURE.md`](./PROJECT_STRUCTURE.md) - Repository organization

### Setup Guides
- 📄 [`demo-app/QUICKSTART.md`](./demo-app/QUICKSTART.md) - Get demo running in 5 minutes
- 📄 [`simulator/README.md`](./simulator/README.md) - IDoc simulator setup
- 📄 [`fabric/GRAPHQL_DEPLOYMENT_GUIDE.md`](./fabric/GRAPHQL_DEPLOYMENT_GUIDE.md) - GraphQL API deployment
- 📄 [`fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md`](./fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md) - OneLake Security setup

### API Reference
- 📄 [`api/GRAPHQL_QUERIES_REFERENCE.md`](./api/GRAPHQL_QUERIES_REFERENCE.md) - GraphQL schema and examples
- 📄 [`api/APIM_CONFIGURATION.md`](./api/APIM_CONFIGURATION.md) - APIM policies and configuration

### Governance
- 📄 [`governance/PURVIEW_DATA_QUALITY_SETUP.md`](./governance/PURVIEW_DATA_QUALITY_SETUP.md) - Purview integration
- 📄 [`docs/governance-guide.md`](./docs/governance-guide.md) - Data governance best practices

---

## 🎯 Key Takeaways

### 🔥 Real-Time Intelligence
- **Sub-second latency** from SAP to API using Eventhouse
- **Streaming analytics** with KQL for operational insights
- **Hot path** for live dashboards and alerting

### 🔒 OneLake Security
- **Single RLS definition** enforced across 6 Fabric engines
- **Storage-layer security** impossible to bypass
- **Identity-aware filtering** via Azure AD integration

### 📊 Data Governance
- **Purview Unified Catalog** for data product registration
- **Automated quality monitoring** with 6 quality dimensions
- **Full lineage tracking** from SAP to API

### 🌐 Modern Data Product
- **GraphQL-first API** for flexible data access
- **APIM gateway** for enterprise-grade API management
- **OAuth2 authentication** with Service Principal claims

### 🎬 Production-Ready Demo
- **Live application** showing real RLS filtering
- **Complete documentation** for LinkedIn sharing
- **Infrastructure as Code** for repeatable deployment

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

---

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

## 👥 Author

**Florent Thibault**  
Microsoft - Data & AI Specialist

📧 Contact: [Your Contact Info]  
🔗 LinkedIn: [Your LinkedIn]

---

## 🌟 Acknowledgments

- **Microsoft Fabric Team** - Real-Time Intelligence capabilities
- **Azure APIM Team** - GraphQL support
- **Microsoft Purview Team** - Data governance platform
- **Community Contributors** - Testing and feedback

---

## 📌 Version History

- **v1.0.0** (October 2025)
  - ✅ Complete demo application with RLS
  - ✅ Real-Time Intelligence integration
  - ✅ OneLake Security implementation
  - ✅ Purview Unified Catalog integration
  - ✅ GraphQL API via APIM
  - ✅ SAP IDoc simulator
  - ✅ Comprehensive documentation

---

**⭐ If you find this project useful, please star the repository!**

**🔗 Repository**: https://github.com/flthibau/Fabric-SAP-Idocs
