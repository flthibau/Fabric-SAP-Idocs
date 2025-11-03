# 📋 Roadmap Documentation

> **Complete documentation for tracking and managing the SAP IDoc Data Product evolution**

---

## 📚 Documentation Structure

This folder contains all roadmap-related documentation for the SAP IDoc Data Product evolution on Microsoft Fabric.

### Main Documents

| Document | Description | Audience |
|----------|-------------|----------|
| **[COMPLETE_ROADMAP.md](./COMPLETE_ROADMAP.md)** | Comprehensive technical roadmap with all epics, issues, and timelines | Technical Team, Product Owner |
| **[GITHUB_ORGANIZATION_GUIDE.md](./GITHUB_ORGANIZATION_GUIDE.md)** | Guide for using GitHub to track roadmap progress | All Team Members |
| **[RLS_ADVANCED_GUIDE.md](./RLS_ADVANCED_GUIDE.md)** | OneLake Security RLS implementation and debugging guide | Security Team, Developers |

---

## 🎯 Quick Start

### For Product Owners / Managers

1. Read [COMPLETE_ROADMAP.md](./COMPLETE_ROADMAP.md) for full roadmap overview
2. Review the 4 phases and their timelines
3. Track progress via [GitHub Projects](https://github.com/flthibau/Fabric-SAP-Idocs/projects)
4. Monitor metrics in the roadmap document

### For Developers

1. Review [COMPLETE_ROADMAP.md](./COMPLETE_ROADMAP.md) to understand current phase
2. Check [GitHub Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues) for assigned tasks
3. Follow [GITHUB_ORGANIZATION_GUIDE.md](./GITHUB_ORGANIZATION_GUIDE.md) for workflow
4. Refer to technical guides (e.g., RLS_ADVANCED_GUIDE.md) for implementation details

### For Contributors

1. Read [GITHUB_ORGANIZATION_GUIDE.md](./GITHUB_ORGANIZATION_GUIDE.md)
2. Use issue templates in `.github/ISSUE_TEMPLATE/`
3. Follow the contribution workflow
4. Link PRs to issues

---

## 🗺️ Roadmap Overview

### Current Status: Phase 1 - Security & Governance

```
Phase 1: Security & Governance (Q4 2024 - Q1 2025)
├── Epic 1: OneLake Security RLS Enhancement ⚠️ In Progress (Debugging)
└── Epic 2: Data Model Documentation 🟡 Planned

Phase 2: Modern API Layer (Q1 2025 - Q2 2025)
├── Epic 3: Complete REST APIs 🔴 Not Started
└── Epic 4: API Materialization in Purview 🔴 Not Started

Phase 3: Operational Intelligence (Q2 2025 - Q3 2025)
└── Epic 5: RTI Operational Agent 🔴 Not Started

Phase 4: Data Governance & Contracts (Q3 2025 - Q4 2025)
└── Epic 6: Data Contracts in Purview 🔴 Not Started
```

---

## 🎯 Key Initiatives

### 1. OneLake Security RLS (Priority: Critical)

**Current Challenge**: RLS roles created but filtering not working correctly

**Status**: Workspace currently open for debugging

**Key Files**:
- [RLS_ADVANCED_GUIDE.md](./RLS_ADVANCED_GUIDE.md) - Debugging guide
- [ONELAKE_RLS_CONFIGURATION_GUIDE.md](../../fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md) - Current config

**Next Steps**:
1. Debug OneLake RLS filtering issue
2. Validate with all 3 partners (FedEx, Warehouse, ACME)
3. Performance testing
4. Documentation update

---

### 2. Data Model Documentation (Priority: High)

**Objective**: Complete documentation of all data entities

**Deliverables**:
- Entity documentation (5 Gold tables)
- ERD diagrams
- Business glossary
- Developer guide

**Structure**:
```
docs/data-model/
├── README.md
├── entities/
│   ├── gold_orders_daily_summary.md
│   ├── gold_shipments_in_transit.md
│   └── ...
├── diagrams/
└── business-glossary.md
```

---

### 3. Complete REST APIs (Priority: High)

**Objective**: Add REST APIs alongside existing GraphQL

**Scope**:
- CRUD operations (Read-only initially)
- OpenAPI/Swagger documentation
- Rate limiting and authentication
- Integration with APIM

**Technical Options**:
- Azure Functions + APIM
- Fabric Data API (when available)
- Custom API on Azure Container Apps

---

### 4. RTI Operational Agent (Priority: Medium)

**Objective**: Implement AI-powered operational intelligence

**Use Cases**:
1. Shipment delay detection and alerts
2. Warehouse productivity monitoring
3. Revenue anomaly detection

**Components**:
- Real-Time Intelligence (Eventhouse)
- KQL queries for pattern detection
- Logic Apps for notifications
- Operational dashboards

---

### 5. Purview Integration (Priority: High)

**Objectives**:
- Register APIs in Purview catalog
- Materialize API access metadata
- Implement data contracts
- Quality monitoring dashboards

**Benefits**:
- Centralized data governance
- API discoverability
- Quality assurance
- Compliance tracking

---

## 📊 Progress Tracking

### GitHub Resources

- **Issues**: [All Roadmap Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues?q=is%3Aissue+label%3Aroadmap)
- **Projects**: [Roadmap Project Board](https://github.com/flthibau/Fabric-SAP-Idocs/projects)
- **Milestones**: [Phase Milestones](https://github.com/flthibau/Fabric-SAP-Idocs/milestones)

### Creating Issues

Use the provided PowerShell script:

```powershell
cd scripts
.\create-github-issues.ps1 -GitHubToken "YOUR_TOKEN" -Repository "Fabric-SAP-Idocs"
```

Or manually using templates in `.github/ISSUE_TEMPLATE/`

---

## 🏗️ Architecture Evolution

### Current Architecture

```
SAP ERP → Event Hubs → Eventhouse → Lakehouse
                                         ↓
                                    OneLake Security (⚠️ Debugging)
                                         ↓
                                    GraphQL API
                                         ↓
                                    Azure APIM
                                         ↓
                                    Partner Apps
```

### Target Architecture (End of Roadmap)

```
SAP ERP → Event Hubs → Eventhouse ←─ RTI Agent
                            ↓
                       Lakehouse (Bronze/Silver/Gold)
                            ↓
                    ✅ OneLake Security (RLS)
                            ↓
                    ┌───────┴────────┐
              GraphQL API      REST API
                    └───────┬────────┘
                       Azure APIM
                            ↓
                    ┌───────┴────────┐
              Partner Apps      Purview
                                (Catalog + Contracts)
```

---

## 📈 Success Metrics

### Technical KPIs

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| RLS Filtering Accuracy | 100% | 0% (disabled) | → |
| API Response Time (p95) | < 100ms | < 200ms | 🟡 |
| Data Quality Score | > 99% | ~95% | 🟡 |
| API Availability | 99.9% | 99.5% | 🟡 |
| Documentation Coverage | 100% | ~60% | 🟡 |

### Business KPIs

- **Partner Adoption**: Target 10+ active partners
- **API Call Volume**: Target 1M+ calls/month
- **Time to Onboard**: Target < 1 day
- **Security Incidents**: Target 0

---

## 🔗 Related Documentation

### Technical Guides

- [OneLake RLS Configuration](../../fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md)
- [GraphQL API Setup](../../fabric/GRAPHQL_API_SETUP.md)
- [GraphQL Deployment Guide](../../fabric/GRAPHQL_DEPLOYMENT_GUIDE.md)

### Governance

- [Purview Data Quality Setup](../../governance/PURVIEW_DATA_QUALITY_SETUP.md)
- [Data Product Architecture](../../governance/DATA-PRODUCT-ARCHITECTURE-ANALYSIS.md)
- [Business Glossary](../../governance/BUSINESS-GLOSSARY.md)

### API Documentation

- [GraphQL Queries Reference](../../api/GRAPHQL_QUERIES_REFERENCE.md)
- [APIM Configuration](../../api/APIM_CONFIGURATION.md)
- [Partner API Implementation Plan](../../api/PARTNER_API_IMPLEMENTATION_PLAN.md)

---

## 📅 Timeline

| Phase | Start | End | Duration | Status |
|-------|-------|-----|----------|--------|
| **Phase 1**: Security & Governance | Nov 2024 | Jan 2025 | 3 months | 🟡 In Progress |
| **Phase 2**: Modern API Layer | Jan 2025 | Apr 2025 | 3 months | ⚪ Planned |
| **Phase 3**: Operational Intelligence | Apr 2025 | Jul 2025 | 3 months | ⚪ Planned |
| **Phase 4**: Data Contracts | Jul 2025 | Oct 2025 | 3 months | ⚪ Planned |

---

## 🤝 Contributing

### Issue Creation

1. Choose appropriate template (Epic, Technical Task, Documentation)
2. Fill all required fields
3. Add labels and milestone
4. Link to parent Epic
5. Submit and track in Project

### Pull Requests

1. Create feature branch: `feature/epic-X-issue-Y`
2. Implement changes
3. Update documentation
4. Create PR to `develop`
5. Get review and approval
6. Merge and delete branch

---

## 📞 Contact

**Product Owner**: Florent Thibault  
**Repository**: [github.com/flthibau/Fabric-SAP-Idocs](https://github.com/flthibau/Fabric-SAP-Idocs)

**Questions?** Create an issue with label `question`

---

**Last Updated**: November 3, 2024  
**Next Review**: December 1, 2024
