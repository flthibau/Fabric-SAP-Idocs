# 🎓 Microsoft Fabric SAP IDoc Workshop

Welcome to the comprehensive hands-on workshop for building real-time data products with Microsoft Fabric and SAP IDoc integration!

## 🎯 Workshop Overview

This workshop guides you through building a complete **governed, real-time data product** for 3PL (Third-Party Logistics) operations using Microsoft Fabric. You'll learn how to:

- ✅ Ingest SAP IDoc messages in real-time using Azure Event Hubs
- ✅ Process streaming data with Fabric Real-Time Intelligence (Eventhouse)
- ✅ Build medallion architecture (Bronze/Silver/Gold) with Lakehouse
- ✅ Implement Row-Level Security (RLS) with OneLake Security
- ✅ Expose data through GraphQL APIs via Azure API Management
- ✅ Monitor data quality with Microsoft Purview

### Business Scenario

You'll work with a realistic 3PL logistics scenario where a manufacturing company outsources operations to external partners (carriers, warehouses, customers) and needs to expose real-time operational data via API while ensuring **each partner sees only their own data**.

**Partner Types:**
- 🚚 **Carriers**: FedEx, UPS (shipment tracking)
- 🏭 **Warehouse Partners**: WH-EAST, WH-WEST (inventory movements)
- 🏢 **Customers**: ACME Corp, TechCo (order tracking)

**Data Entities:**
- Orders (ORDERS IDoc)
- Shipments (SHPMNT IDoc)
- Deliveries (DESADV IDoc)
- Warehouse Movements (WHSCON IDoc)
- Invoices (INVOIC IDoc)

---

## 📋 Prerequisites and Setup

Before starting this workshop, ensure you have the required prerequisites and complete the environment setup.

### Quick Prerequisites Checklist

- ✅ Azure subscription with Microsoft Fabric enabled
- ✅ Azure AD tenant with permission to create Service Principals
- ✅ Fabric workspace with appropriate permissions (Admin or Member)
- ✅ PowerShell 7+ or Azure CLI installed
- ✅ Python 3.11+ installed
- ✅ Git installed
- ✅ Visual Studio Code (recommended)

📄 **Detailed Requirements**: See [Setup Prerequisites](./setup/prerequisites.md)

### Environment Setup

Complete the environment setup before starting the modules:

1. **Azure Resources Setup** (30 min)
   - Create Resource Group
   - Deploy Azure Event Hubs
   - Configure Azure API Management (optional)

2. **Microsoft Fabric Setup** (45 min)
   - Create Fabric workspace
   - Configure Eventhouse
   - Create Lakehouse

3. **Development Environment** (15 min)
   - Clone repository
   - Install Python dependencies
   - Configure PowerShell modules

📄 **Step-by-Step Guide**: See [Environment Setup](./setup/environment-setup.md)

---

## 📚 Workshop Modules

This workshop is divided into 6 hands-on modules. Each module builds on the previous one, so we recommend completing them in order.

### Module 1: Architecture Overview
**Estimated Time:** 45 minutes  
**Difficulty:** Beginner

Understand the complete architecture and components of the real-time data product.

**Learning Objectives:**
- Understand the end-to-end data flow from SAP to API
- Learn about Microsoft Fabric Real-Time Intelligence
- Explore the medallion architecture pattern
- Review OneLake Security concepts

📄 **Lab Guide**: [Module 1 - Architecture Overview](./labs/module1-architecture.md)

---

### Module 2: Event Hub Setup and IDoc Ingestion
**Estimated Time:** 90 minutes  
**Difficulty:** Intermediate

Set up Azure Event Hubs and configure the SAP IDoc simulator to generate realistic test data.

**Learning Objectives:**
- Deploy and configure Azure Event Hubs
- Understand SAP IDoc message structure
- Run the IDoc simulator to generate test data
- Monitor real-time message ingestion

**Prerequisites:**
- Azure subscription
- Module 1 completed

📄 **Lab Guide**: [Module 2 - Event Hub Setup](./labs/module2-eventhub-setup.md)

---

### Module 3: KQL Queries and Real-Time Analytics
**Estimated Time:** 75 minutes  
**Difficulty:** Intermediate

Learn Kusto Query Language (KQL) to analyze streaming data in Fabric Eventhouse.

**Learning Objectives:**
- Write basic and advanced KQL queries
- Perform time-series analysis
- Create aggregations and summaries
- Build real-time dashboards

**Prerequisites:**
- Modules 1-2 completed
- Data flowing through Event Hub

📄 **Lab Guide**: [Module 3 - KQL Queries](./labs/module3-kql-queries.md)

---

### Module 4: Lakehouse Medallion Architecture
**Estimated Time:** 120 minutes  
**Difficulty:** Advanced

Build the Bronze, Silver, and Gold layers using Fabric Data Engineering.

**Learning Objectives:**
- Create Bronze layer (raw data ingestion)
- Transform to Silver layer (cleaned and normalized)
- Build Gold layer (business views and aggregations)
- Implement data quality checks

**Prerequisites:**
- Modules 1-3 completed
- Familiarity with PySpark or SQL

📄 **Lab Guide**: [Module 4 - Lakehouse Layers](./labs/module4-lakehouse-layers.md)

---

### Module 5: OneLake Security and Row-Level Security
**Estimated Time:** 90 minutes  
**Difficulty:** Advanced

Implement enterprise-grade security with OneLake Row-Level Security (RLS).

**Learning Objectives:**
- Create Azure AD Service Principals
- Configure OneLake Security policies
- Implement RLS across all Fabric engines
- Test partner-specific data filtering

**Prerequisites:**
- Modules 1-4 completed
- Azure AD permissions to create Service Principals

📄 **Lab Guide**: [Module 5 - Security and RLS](./labs/module5-security-rls.md)

---

### Module 6: GraphQL API Development
**Estimated Time:** 105 minutes  
**Difficulty:** Advanced

Expose your data product through GraphQL APIs with Azure API Management.

**Learning Objectives:**
- Enable GraphQL API on Lakehouse
- Configure Azure APIM policies
- Implement OAuth2 authentication
- Test the live demo application

**Prerequisites:**
- All previous modules completed
- Postman or similar API testing tool

📄 **Lab Guide**: [Module 6 - API Development](./labs/module6-api-development.md)

---

## ⏱️ Total Workshop Duration

| Module | Duration | Difficulty | Type |
|--------|----------|------------|------|
| Setup & Prerequisites | 90 min | Beginner | Setup |
| Module 1: Architecture | 45 min | Beginner | Theory |
| Module 2: Event Hub | 90 min | Intermediate | Hands-on |
| Module 3: KQL Queries | 75 min | Intermediate | Hands-on |
| Module 4: Lakehouse | 120 min | Advanced | Hands-on |
| Module 5: Security | 90 min | Advanced | Hands-on |
| Module 6: API Development | 105 min | Advanced | Hands-on |
| **Total** | **~10 hours** | Mixed | Full Day Workshop |

**Recommended Schedule:**
- **Day 1 (Morning)**: Setup + Modules 1-2
- **Day 1 (Afternoon)**: Modules 3-4
- **Day 2 (Morning)**: Module 5
- **Day 2 (Afternoon)**: Module 6 + Wrap-up

---

## 🛠️ Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Event Hub Connection Failed
**Symptoms:** Simulator cannot send messages to Event Hub

**Solutions:**
1. Verify Event Hub connection string in `.env` file
2. Check Event Hub namespace exists in Azure Portal
3. Ensure Event Hub instance `idoc-events` is created
4. Verify network connectivity (firewall rules)

```powershell
# Test Event Hub connectivity
.\scripts\test-eventhub-connection.ps1
```

---

#### Issue: Fabric Workspace Access Denied
**Symptoms:** Cannot access workspace resources

**Solutions:**
1. Verify you have Admin or Member role in workspace
2. Check workspace is in correct Fabric capacity
3. Ensure Fabric trial or paid license is active

```powershell
# Verify workspace access
Get-FabricWorkspace -Name "your-workspace-name"
```

---

#### Issue: KQL Query Returns No Data
**Symptoms:** Queries return empty results

**Solutions:**
1. Verify Eventstream is running and configured
2. Check data is flowing: `idoc_raw | count`
3. Verify table name matches (`idoc_raw` vs `idoc_shipments_raw`)
4. Check time range: `| where ingestion_time() > ago(1h)`

```kql
// Diagnostic query
idoc_raw
| summarize count() by bin(ingestion_time(), 1h)
| render timechart
```

---

#### Issue: RLS Not Filtering Data
**Symptoms:** All users see all data regardless of role

**Solutions:**
1. Verify RLS policies are enabled (`STATE = ON`)
2. Check session context is being set correctly
3. Verify Service Principal is assigned to correct role
4. Test with impersonation: `EXECUTE AS USER = 'sp-partner-fedex'`

```sql
-- Check RLS policies
SELECT * FROM sys.security_policies WHERE is_enabled = 1;

-- Test RLS
EXECUTE AS USER = 'sp-partner-fedex';
SELECT COUNT(*) FROM gold.shipments;
REVERT;
```

---

#### Issue: GraphQL API Returns 401 Unauthorized
**Symptoms:** API calls fail with authentication error

**Solutions:**
1. Verify OAuth2 token is valid and not expired
2. Check Service Principal has Fabric workspace access
3. Verify APIM policy is correctly configured
4. Ensure correct audience in token (`https://analysis.windows.net/powerbi/api`)

```powershell
# Get fresh token
.\get-token.ps1 -ServicePrincipal fedex

# Test token validity
Test-FabricToken -Token $token
```

---

#### Issue: Python Simulator Fails to Start
**Symptoms:** Import errors or connection errors

**Solutions:**
1. Verify Python 3.11+ is installed: `python --version`
2. Activate virtual environment: `.\venv\Scripts\activate`
3. Install dependencies: `pip install -r requirements.txt`
4. Check `.env` file exists with correct credentials

```bash
# Reinstall dependencies
pip install --force-reinstall -r requirements.txt

# Test imports
python -c "import azure.eventhub; print('OK')"
```

---

### Getting Help

If you encounter issues not covered here:

1. **Check Logs**: Review error messages in console/terminal
2. **Module Documentation**: Each lab guide has a troubleshooting section
3. **Repository Issues**: Check [GitHub Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
4. **Azure Portal**: Review Activity Log for resource-level errors
5. **Fabric Monitoring**: Check Eventhouse and Lakehouse monitoring

---

## ❓ Frequently Asked Questions (FAQ)

### General Questions

**Q: Do I need a production SAP system for this workshop?**  
A: No! We provide a Python-based IDoc simulator that generates realistic test data. No SAP system required.

**Q: What is the cost of running this workshop?**  
A: Costs vary based on Azure consumption. Estimate ~$50-100 for the full workshop with cleanup afterward. Use Fabric trial capacity when possible.

**Q: Can I run this workshop in a shared Fabric workspace?**  
A: Yes, but be aware that RLS configuration may affect other users. We recommend a dedicated workspace for learning.

**Q: How long does data persist in Eventhouse?**  
A: Default retention is 90 days. You can configure hot/cold cache policies for cost optimization.

---

### Technical Questions

**Q: What's the difference between Eventhouse and Lakehouse?**  
A: 
- **Eventhouse**: Real-time streaming analytics with KQL, sub-second latency
- **Lakehouse**: Batch data storage with Delta Lake, supports Spark and SQL

Both are needed for a complete real-time data product.

**Q: Can I use GraphQL API with Power BI?**  
A: Not directly. Use Direct Lake mode with Lakehouse or connect to Warehouse SQL endpoint instead.

**Q: Do I need to configure APIM for this workshop?**  
A: It's optional for Modules 1-5. APIM is required only for Module 6 (API Development) to implement OAuth2 and CORS policies.

**Q: Can I deploy this to production?**  
A: Yes! This is a production-ready reference implementation. Review security and governance configurations for your requirements.

**Q: What's OneLake Security?**  
A: OneLake Security allows you to define Row-Level Security (RLS) at the storage layer, which is enforced across all 6 Fabric engines (KQL, Spark, SQL, Power BI, GraphQL, OneLake API).

**Q: Can I add more IDoc types?**  
A: Yes! The simulator is extensible. Add new schemas in `simulator/src/idoc_schemas/` following the existing pattern.

---

### Workshop Format Questions

**Q: Can I do this workshop self-paced?**  
A: Absolutely! All modules are designed for self-paced learning with detailed step-by-step instructions.

**Q: Do I need to complete all modules?**  
A: Not necessarily. Modules 1-2 are foundational. Choose additional modules based on your learning goals (analytics → Module 3, security → Module 5, APIs → Module 6).

**Q: Can I use this for team training?**  
A: Yes! This workshop is designed for both individual and team learning. Consider assigning different modules to team members.

**Q: Is there a certification?**  
A: This workshop doesn't provide formal certification, but it covers content relevant to Microsoft Fabric certifications.

---

## 📞 Support and Resources

### Workshop Support

- **Repository Issues**: [Report issues or ask questions](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
- **Discussions**: [Community discussions](https://github.com/flthibau/Fabric-SAP-Idocs/discussions)
- **Documentation**: All modules include detailed guides and troubleshooting

### Microsoft Resources

- **Microsoft Fabric Documentation**: [learn.microsoft.com/fabric](https://learn.microsoft.com/fabric/)
- **Real-Time Intelligence**: [Eventhouse Documentation](https://learn.microsoft.com/fabric/real-time-intelligence/)
- **Fabric Community**: [community.fabric.microsoft.com](https://community.fabric.microsoft.com)
- **Azure Event Hubs**: [Event Hubs Documentation](https://learn.microsoft.com/azure/event-hubs/)

### Learning Resources

- **KQL Tutorial**: [Kusto Query Language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- **GraphQL Guide**: [GraphQL.org](https://graphql.org/learn/)
- **Delta Lake**: [delta.io](https://delta.io/)
- **Medallion Architecture**: [Databricks Medallion](https://www.databricks.com/glossary/medallion-architecture)

### Related Projects

- **Main Repository**: [Fabric-SAP-Idocs](https://github.com/flthibau/Fabric-SAP-Idocs)
- **Demo Application**: [/demo-app](../demo-app/README.md)
- **IDoc Simulator**: [/simulator](../simulator/README.md)
- **Governance Setup**: [/governance](../governance/README.md)

---

## 👥 Author and Contributors

**Florent Thibault**  
Microsoft - Data & AI Specialist

**Workshop Contributors:**
- Community contributors and testers
- Microsoft Fabric team for technical guidance
- Azure APIM team for GraphQL support

---

## 📄 License

This workshop and all associated materials are provided as-is for educational and demonstration purposes.

---

## 🌟 Next Steps

Ready to begin? Here's how to get started:

1. ✅ **Review Prerequisites**: Read [Setup Prerequisites](./setup/prerequisites.md)
2. ✅ **Configure Environment**: Follow [Environment Setup](./setup/environment-setup.md)
3. ✅ **Start Learning**: Begin with [Module 1 - Architecture](./labs/module1-architecture.md)
4. ✅ **Join Community**: Star the repo and join discussions!

**Let's build amazing real-time data products together! 🚀**

---

## 🔄 Workshop Updates

**Last Updated**: November 2024  
**Version**: 1.0  
**Status**: ✅ Production Ready

### Recent Updates
- Initial workshop release with 6 comprehensive modules
- Added troubleshooting guide and FAQ
- Included estimated times and difficulty levels
- Enhanced setup documentation

### Upcoming Enhancements
- Video walkthroughs for each module
- Additional advanced modules (Purview integration, AI analytics)
- Multi-language support
- Pre-configured ARM templates

---

**⭐ If this workshop helps you, please star the repository!**

**🔗 Repository**: https://github.com/flthibau/Fabric-SAP-Idocs
