# Microsoft Purview - Governance Setup

This directory contains scripts and configuration for setting up data governance in Microsoft Purview Unified Catalog for the 3PL Logistics Analytics Data Product.

## 📁 Directory Structure

```
governance/purview/
├── README.md                              # This file
├── requirements.txt                       # Python dependencies
│
├── create_demo_domains.py                 # ✅ Create 3 enterprise domains (Finance, HR, Sales)
├── enrich_supply_chain_domain.py          # ✅ Enrich Supply Chain domain with OKRs and Terms
├── create_okrs_domain_with_link.py        # ✅ Create Data Product-specific OKRs
│
├── demo_domains_created.json              # Results from domain creation
├── supply_chain_domain_enrichment.json    # Results from Supply Chain enrichment
├── okrs_domain_level.json                 # Results from Data Product OKR creation
├── data_product_supply_chain.json         # Domain configuration
│
└── archive/                               # Experimental/test scripts (not for production)
    ├── test_*.py                          # API testing scripts
    ├── query_atlas_entities.py            # Atlas API exploration
    └── search_*.py                        # Search experiments
```

## 🎯 What Was Accomplished

### ✅ Final Architecture

```
Microsoft Purview Unified Catalog
├── Finance Domain
│   ├── 3 Objectives (8 Key Results)
│   └── 8 Glossary Terms
│
├── Human Resources Domain
│   ├── 3 Objectives (9 Key Results)
│   └── 9 Glossary Terms
│
├── Sales & Marketing Domain
│   ├── 3 Objectives (9 Key Results)
│   └── 10 Glossary Terms
│
└── Supply Chain Domain ⭐
    ├── 4 Domain-Level Objectives (12 Key Results)
    ├── 12 Domain-Level Glossary Terms
    └── Data Product: 3PL Logistics Analytics
        ├── 3 Objectives (manually linked, 9 Key Results)
        └── 8 Glossary Terms (manually linked)
```

### 📊 Statistics

- **4 Enterprise Domains** created
- **13 Objectives** (9 from demo domains + 4 generic Supply Chain)
- **47 Glossary Terms** (27 from demo domains + 12 generic Supply Chain + 8 Data Product-specific)
- **38 Key Results** tracked
- **1 Data Product** (3PL Logistics Analytics in Supply Chain domain)

## 🚀 How to Use These Scripts

### Prerequisites

```powershell
# Install dependencies
pip install -r requirements.txt

# Authenticate to Azure
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4
```

### 1. Create Demo Enterprise Domains

Creates Finance, Human Resources, and Sales & Marketing domains with full OKRs and Glossary Terms.

```powershell
python create_demo_domains.py
```

**Output:** `demo_domains_created.json`

### 2. Enrich Supply Chain Domain

Adds generic domain-level OKRs and Glossary Terms to the Supply Chain domain (separate from Data Product items).

```powershell
python enrich_supply_chain_domain.py
```

**Output:** `supply_chain_domain_enrichment.json`

### 3. Create Data Product-Specific OKRs

Creates Objectives and Key Results specific to the "3PL Logistics Analytics" Data Product.

```powershell
python create_okrs_domain_with_link.py
```

**Output:** `okrs_domain_level.json`

**⚠️ Important:** After running this script, you must **manually link** the created OKRs and Glossary Terms to the Data Product via the Purview Portal. The API does not support automatic linking.

## 🔗 Manual Linking in Purview Portal

### Why Manual Linking is Required

The Microsoft Purview Unified Catalog API (2025-09-15-preview) does not currently support creating Glossary Terms or Objectives directly at the Data Product level. Items must be created at the Domain level and then manually linked via the portal.

### How to Link OKRs to Data Product

1. Open Purview Portal: https://web.purview.azure.com/resource/stpurview
2. Navigate to: **Unified Catalog** → **Domains** → **Supply Chain** → **Data Products** → **3PL Logistics Analytics**
3. Click on **Objectives** tab
4. Click **+ Add objective**
5. Select the 3 Data Product-specific objectives:
   - Operational Excellence & On-Time Delivery
   - Customer Satisfaction & Service Quality
   - Platform Adoption & Data-Driven Insights
6. Save

### How to Link Glossary Terms to Data Product

1. In the same Data Product page, click **Glossary terms** tab
2. Click **+ Add term**
3. Select the 8 Data Product-specific terms:
   - 3PL (Third-Party Logistics)
   - SLA (Service Level Agreement)
   - OTD (On-Time Delivery)
   - EDI (Electronic Data Interchange)
   - IDoc (Intermediate Document)
   - WMS (Warehouse Management System)
   - TMS (Transportation Management System)
   - KPI (Key Performance Indicator)
4. Save

## 🌐 API Configuration

All scripts use the following configuration:

```python
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = "https://stpurview.purview.azure.com"
API_VERSION = "2025-09-15-preview"
```

**Authentication:** Azure DefaultAzureCredential (supports Azure CLI, Managed Identity, etc.)

**Scope:** `https://purview.azure.net/.default`

## 📝 Key API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/datagovernance/catalog/businessdomains` | POST | Create business domains |
| `/datagovernance/catalog/objectives` | POST | Create objectives |
| `/datagovernance/catalog/keyResults` | POST | Create key results |
| `/datagovernance/catalog/terms` | POST | Create glossary terms |

## 🔍 Verifying Results

### Check Domains

```powershell
# List all domains
az rest --method GET --uri "https://stpurview.purview.azure.com/datagovernance/catalog/businessdomains?api-version=2025-09-15-preview"
```

### View in Portal

1. **Domains:** https://web.purview.azure.com/resource/stpurview/datagovernance/domains
2. **Data Product:** https://web.purview.azure.com/resource/stpurview/datagovernance/catalog/dataProducts/{id}

## 📚 Reference Documentation

- **Purview API Limitations:** `archive/test_*.py` (experimental attempts to create items at Data Product level)
- **Business Domain Config:** `data_product_supply_chain.json`
- **Main Architecture:** `../../docs/architecture.md`

## ⚠️ Known Limitations

### API Limitations (as of 2025-09-15-preview)

1. ❌ **Cannot create Terms at Data Product level**
   - **Workaround:** Create at Domain level → Link manually via Portal

2. ❌ **Cannot create Objectives at Data Product level**
   - **Workaround:** Create at Domain level → Link manually via Portal

3. ❌ **Cannot auto-link items during creation**
   - The `dataProduct` field in POST payloads is ignored
   - **Workaround:** Manual linking via Portal

4. ✅ **Can create at Domain level** (fully supported)

### Tested Approaches (All Failed)

See `archive/test_exhaustive_glossary_api.py` for 5 different API approaches tested:
- ❌ Test 1: `dataProduct` only
- ❌ Test 2: `domain` + `dataProduct`
- ❌ Test 3: `domain` only (baseline)
- ❌ Test 4: `dataProductId`
- ❌ Test 5: `parent` field

**Conclusion:** Manual linking via Portal is the only working solution.

## 🎯 Next Steps

### Immediate

- [x] Create 4 enterprise domains
- [x] Enrich with OKRs and Glossary Terms
- [x] Create Data Product-specific items
- [x] Manual linking via Portal (user completed)

### Future Enhancements

- [ ] Link Fabric Lakehouse tables to Data Product (manual via Portal)
- [ ] Set up automated scanning for data assets
- [ ] Configure data lineage tracking
- [ ] Implement Row-Level Security for B2B partner access
- [ ] Create additional Data Products in other domains

## 🆘 Troubleshooting

### Error: "Unauthorized" or "Forbidden"

**Solution:** Ensure you're authenticated with sufficient permissions:
```powershell
az login --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4
az account show  # Verify correct tenant
```

Required Purview roles:
- Data Curator (minimum)
- Data Source Admin (for asset linking)

### Error: "Domain not found"

**Solution:** Verify domain ID in `data_product_supply_chain.json` matches actual domain ID in Purview:
```python
# In Python script
with open("data_product_supply_chain.json") as f:
    data = json.load(f)
    print(f"Domain ID: {data['domainId']}")
```

### Items Not Appearing in Portal

**Solution:** Wait 30-60 seconds for indexing, then refresh the portal page.

## 📧 Support

For questions about this setup:
1. Check `archive/` for experimental code and API tests
2. Review conversation summary in this file
3. Consult Microsoft Purview documentation: https://learn.microsoft.com/en-us/purview/

---

**Last Updated:** 2025-10-29  
**API Version:** 2025-09-15-preview  
**Status:** ✅ Production Ready (with manual linking for Data Product items)
