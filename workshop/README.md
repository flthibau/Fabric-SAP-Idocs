# 🎓 Workshop: SAP IDoc Integration with Microsoft Fabric

> **Comprehensive upskilling materials for building real-time data products with Microsoft Fabric and SAP**

[![Microsoft Fabric](https://img.shields.io/badge/Microsoft%20Fabric-0078D4?style=flat&logo=microsoft&logoColor=white)](https://fabric.microsoft.com)
[![Real-Time Intelligence](https://img.shields.io/badge/Real--Time%20Intelligence-00BCF2?style=flat&logo=microsoft&logoColor=white)](https://learn.microsoft.com/fabric/real-time-intelligence/)
[![Microsoft Purview](https://img.shields.io/badge/Microsoft%20Purview-50E6FF?style=flat&logo=microsoft&logoColor=black)](https://purview.microsoft.com)

---

## 📖 Workshop Overview

This workshop provides hands-on training for developers and data engineers learning to integrate SAP systems with Microsoft Fabric. You'll build a complete real-time data product from SAP IDoc ingestion through API exposure, implementing enterprise-grade security and governance.

### 🎯 Learning Objectives

By completing this workshop, you will be able to:

- ✅ Understand the end-to-end architecture for SAP IDoc integration with Fabric
- ✅ Configure Azure Event Hub for real-time IDoc ingestion
- ✅ Build streaming analytics with Eventhouse and KQL
- ✅ Implement medallion architecture (Bronze/Silver/Gold) in OneLake
- ✅ Configure Row-Level Security and data governance with Purview
- ✅ Develop GraphQL and REST APIs for data access
- ✅ Set up monitoring and operational dashboards

### 👥 Target Audience

- **Data Engineers** learning Microsoft Fabric
- **SAP Developers** integrating with cloud platforms
- **Solution Architects** designing data products
- **DevOps Engineers** implementing data pipelines

### ⏱️ Duration

**Total Time**: 8-10 hours
- Self-paced with 7 modules
- Each module: 60-90 minutes
- Includes hands-on labs and exercises

---

## 🗂️ Workshop Modules

### [Module 1: Architecture Overview](./module-1-architecture/README.md)
**Duration**: 60 minutes

Understanding the SAP IDoc to Fabric data flow and architectural patterns.

**Topics Covered**:
- SAP IDoc fundamentals and message structure
- Microsoft Fabric components and capabilities
- End-to-end data flow architecture
- Integration patterns and best practices
- Business scenario: 3PL Logistics use case

**Hands-on Lab**:
- Review architecture diagrams
- Explore sample IDoc messages
- Understand data flow sequence

---

### [Module 2: Event Hub Integration](./module-2-event-hub/README.md)
**Duration**: 90 minutes

Setting up and configuring Azure Event Hub for IDoc ingestion.

**Topics Covered**:
- Azure Event Hubs concepts and architecture
- Event Hub namespace and configuration
- IDoc simulator setup and usage
- Event publishing patterns
- Error handling and dead-letter queues

**Hands-on Lab**:
- Deploy Azure Event Hub using Bicep
- Configure IDoc simulator
- Generate and publish test IDoc messages
- Monitor Event Hub metrics
- Troubleshoot ingestion issues

**Prerequisites**:
- Azure subscription with Event Hubs enabled
- Python 3.11+ installed
- Azure CLI installed

---

### [Module 3: Real-Time Intelligence](./module-3-real-time-intelligence/README.md)
**Duration**: 90 minutes

Working with Eventhouse and KQL queries for real-time analytics.

**Topics Covered**:
- Microsoft Fabric Real-Time Intelligence overview
- Eventhouse (KQL Database) concepts
- Eventstream configuration and data ingestion
- KQL query fundamentals
- Real-time dashboards and visualizations

**Hands-on Lab**:
- Create Fabric Eventhouse
- Configure Eventstream with Event Hub source
- Write KQL queries for data exploration
- Build real-time analytics queries
- Create KQL dashboards

**Prerequisites**:
- Microsoft Fabric workspace
- Module 2 completed (Event Hub configured)
- Basic SQL knowledge helpful

---

### [Module 4: Data Lakehouse](./module-4-data-lakehouse/README.md)
**Duration**: 120 minutes

Building Bronze/Silver/Gold layers in OneLake with Delta Lake.

**Topics Covered**:
- Medallion architecture pattern
- Fabric Lakehouse and OneLake concepts
- Delta Lake and ACID transactions
- PySpark transformations
- Data quality and validation

**Hands-on Lab**:
- Create Fabric Lakehouse
- Build Bronze layer (raw IDoc ingestion)
- Implement Silver layer transformations
- Create Gold layer business views
- Configure OneLake shortcuts
- Optimize Delta tables

**Prerequisites**:
- Microsoft Fabric workspace
- Module 3 completed (Eventhouse with data)
- Python/PySpark knowledge

---

### [Module 5: Security & Governance](./module-5-security-governance/README.md)
**Duration**: 90 minutes

Implementing RLS and data governance with Purview.

**Topics Covered**:
- OneLake Security architecture
- Row-Level Security (RLS) implementation
- Azure AD integration and Service Principals
- Microsoft Purview Unified Catalog
- Data quality rules and monitoring
- Data lineage tracking

**Hands-on Lab**:
- Create security functions and policies
- Configure RLS in Fabric Warehouse
- Set up Service Principals for partner access
- Register data product in Purview
- Implement data quality rules
- Test RLS with different user contexts

**Prerequisites**:
- Microsoft Fabric workspace
- Module 4 completed (Lakehouse with Gold layer)
- Azure AD admin permissions
- Purview account (optional but recommended)

---

### [Module 6: API Development](./module-6-api-development/README.md)
**Duration**: 120 minutes

Creating GraphQL and REST APIs for data access.

**Topics Covered**:
- Fabric GraphQL API fundamentals
- GraphQL schema design
- API Management (APIM) setup
- OAuth2 authentication and authorization
- REST API auto-generation from GraphQL
- API policies and transformations

**Hands-on Lab**:
- Enable GraphQL on Fabric Lakehouse
- Design and deploy GraphQL schema
- Configure Azure APIM
- Implement OAuth2 authentication
- Test GraphQL queries
- Generate REST APIs
- Create API documentation

**Prerequisites**:
- Microsoft Fabric workspace
- Module 5 completed (RLS configured)
- Azure APIM instance
- Postman or similar API testing tool

---

### [Module 7: Monitoring & Operations](./module-7-monitoring-operations/README.md)
**Duration**: 90 minutes

Setting up monitoring and operational dashboards.

**Topics Covered**:
- Azure Monitor and Application Insights
- Fabric monitoring capabilities
- KQL queries for operational metrics
- Alerting and notifications
- Performance optimization
- Troubleshooting patterns

**Hands-on Lab**:
- Configure Azure Monitor
- Create operational dashboards
- Set up alert rules
- Monitor API performance
- Optimize query performance
- Create runbooks for common issues

**Prerequisites**:
- All previous modules completed
- Azure Monitor access
- Power BI Desktop (optional)

---

## 🚀 Getting Started

### Prerequisites

Before starting the workshop, ensure you have:

#### **Required**:
- ✅ Azure subscription with Microsoft Fabric enabled
- ✅ Microsoft Fabric workspace with appropriate permissions
- ✅ Azure CLI installed ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- ✅ Git installed
- ✅ Code editor (VS Code recommended)

#### **Recommended**:
- ✅ Python 3.11+ ([Download](https://www.python.org/downloads/))
- ✅ PowerShell 7+ ([Download](https://github.com/PowerShell/PowerShell))
- ✅ Postman or similar API testing tool
- ✅ Power BI Desktop ([Download](https://powerbi.microsoft.com/desktop/))
- ✅ Azure subscription with Purview (for governance module)

### Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/flthibau/Fabric-SAP-Idocs.git
   cd Fabric-SAP-Idocs
   ```

2. **Set Up Azure Resources**
   
   Follow the [Azure Setup Guide](./setup/azure-setup.md) to deploy required resources.

3. **Configure Environment**
   
   Copy and configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your Azure credentials
   ```

4. **Install Dependencies**
   
   Python dependencies:
   ```bash
   cd simulator
   pip install -r requirements.txt
   ```

5. **Verify Setup**
   
   Run the verification script:
   ```bash
   python scripts/verify-setup.py
   ```

---

## 📚 Workshop Resources

### Sample Data and Scenarios

The workshop uses a **3PL (Third-Party Logistics)** business scenario:
- **Partners**: Carriers (FedEx), Warehouses (WH-EAST), Customers (ACME Corp)
- **Data Entities**: Orders, Shipments, Deliveries, Warehouse Movements, Invoices
- **Security Model**: Each partner sees only their authorized data

### Sample Code

All modules include:
- ✅ Complete working code samples
- ✅ Configuration templates
- ✅ PowerShell/Python scripts
- ✅ SQL/KQL query examples
- ✅ GraphQL schema definitions

### Documentation Links

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)
- [Azure Event Hubs](https://learn.microsoft.com/azure/event-hubs/)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [Microsoft Purview](https://learn.microsoft.com/purview/)
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)

---

## 🎯 Learning Path

### Recommended Order

For best results, complete modules in sequence:

```
Start → Module 1 → Module 2 → Module 3 → Module 4 → Module 5 → Module 6 → Module 7 → Complete
```

### Alternative Paths

**Data Engineers**: Focus on Modules 1, 2, 3, 4, 7
**API Developers**: Focus on Modules 1, 5, 6, 7
**Architects**: Complete all modules
**SAP Developers**: Focus on Modules 1, 2, 4, 6

---

## 🆘 Troubleshooting

### Common Issues

Each module includes a troubleshooting section. For general issues:

1. **Azure Authentication Issues**
   - Verify Azure CLI login: `az login`
   - Check subscription: `az account show`
   - Ensure correct permissions

2. **Fabric Workspace Access**
   - Verify workspace membership
   - Check role assignments (Admin/Member)
   - Ensure Fabric capacity is running

3. **Event Hub Connection**
   - Verify connection string
   - Check firewall rules
   - Validate namespace exists

4. **Python Environment**
   - Use virtual environment
   - Install dependencies: `pip install -r requirements.txt`
   - Check Python version: `python --version`

### Getting Help

- 📖 [Troubleshooting Guide](./troubleshooting/README.md)
- 🐛 [Report Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
- 💬 [Discussions](https://github.com/flthibau/Fabric-SAP-Idocs/discussions)

---

## 📊 Workshop Completion

### Certification

Upon completing all modules and labs, you will have:

- ✅ Built a complete real-time data product
- ✅ Implemented enterprise-grade security
- ✅ Created production-ready APIs
- ✅ Configured monitoring and governance
- ✅ Hands-on experience with Microsoft Fabric

### Next Steps

After completing the workshop:

1. **Explore Advanced Topics**
   - [Advanced RLS Patterns](../docs/roadmap/RLS_ADVANCED_GUIDE.md)
   - [Performance Optimization](./advanced/performance-optimization.md)
   - [Multi-Region Deployment](./advanced/multi-region.md)

2. **Build Your Own Project**
   - Use this repository as a template
   - Adapt to your SAP integration needs
   - Contribute improvements back

3. **Join the Community**
   - Share your learnings
   - Help others
   - Contribute to documentation

---

## 🤝 Contributing

We welcome contributions to improve these workshop materials!

### How to Contribute

1. Fork the repository
2. Create a feature branch
3. Make your improvements
4. Submit a pull request

### Contribution Areas

- 📝 Fix typos or improve clarity
- 🔧 Add new labs or exercises
- 🐛 Report bugs or issues
- 💡 Suggest new modules or topics
- 🌍 Translate to other languages

---

## 📄 License

This workshop is provided as-is for educational purposes.

---

## 👥 Authors & Acknowledgments

**Created by**: Florent Thibault (Microsoft - Data & AI Specialist)

**Contributors**: 
- [List of contributors]

**Special Thanks**:
- Microsoft Fabric Team
- Azure API Management Team
- Microsoft Purview Team
- Community contributors

---

## 📞 Support

For questions or support:

- 📧 Email: [Your contact]
- 💼 LinkedIn: [Your LinkedIn]
- 🐛 Issues: [GitHub Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)

---

**🌟 Ready to start? Begin with [Module 1: Architecture Overview](./module-1-architecture/README.md)**
