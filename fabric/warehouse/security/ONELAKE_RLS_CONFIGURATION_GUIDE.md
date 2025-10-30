# OneLake RLS Configuration Guide - Gold Tables
**Date**: October 29, 2025  
**Workspace**: MngEnvMCAP396311  
**Lakehouse**: Lakehouse3PLAnalytics

## 📋 Prerequisites

✅ **Completed Steps:**
- [x] Service Principals created (3 partners)
- [x] Gold Materialized Lake Views created with RLS columns
- [x] Credentials saved in `api/scripts/partner-apps-credentials.json`

⚠️ **Before Configuring RLS:**
1. Execute notebook `Create_Gold_Materialized_Lake_Views.ipynb` in Fabric Portal
2. Verify Gold tables exist in Lakehouse
3. Confirm RLS columns are populated with data

---

## 🔐 Service Principals Reference

| Partner | App ID | Service Principal Object ID | Role |
|---------|--------|------------------------------|------|
| **FedEx Carrier** | `94a9edcc-7a22-4d89-b001-799e8414711a` | `fa86b10b-792c-495b-af85-bc8a765b44a1` | CarrierFedEx |
| **Warehouse East** | `1de3dcee-f7eb-4701-8cd9-ed65f3792fe0` | `bf7ca9fa-eb65-4261-91f2-08d2b360e919` | WarehouseEast |
| **ACME Customer** | `a3e88682-8bef-4712-9cc5-031d109cefca` | `efae8acd-de55-4c89-96b6-7f031a954ae6` | CustomerAcme |

---

## 🎯 RLS Configuration in Fabric Portal

### Step 1: Navigate to OneLake Security

1. Open: https://msit.powerbi.com/
2. Navigate to Workspace: **MngEnvMCAP396311**
3. Click on **Lakehouse3PLAnalytics**
4. Go to: **Settings** → **Security** → **Row-Level Security**

### Step 2: Create RLS Role - CarrierFedEx

**Purpose**: FedEx carrier accesses only their shipments and SLA data

#### Table 1: gold_shipments_in_transit
```sql
carrier_id = 'CARRIER-FEDEX-GROU'
```

**Configuration:**
- **Role Name**: `CarrierFedEx`
- **Table**: `gold_shipments_in_transit`
- **Filter Expression**: `carrier_id = 'CARRIER-FEDEX-GROU'`
- **Description**: FedEx carrier - shipments in transit tracking

#### Table 2: gold_sla_performance
```sql
carrier_id = 'CARRIER-FEDEX-GROU'
```

**Configuration:**
- **Role Name**: `CarrierFedEx` (same role)
- **Table**: `gold_sla_performance`
- **Filter Expression**: `carrier_id = 'CARRIER-FEDEX-GROU'`
- **Description**: FedEx carrier - SLA performance tracking

#### Assign Service Principal
- **Member Type**: Service Principal
- **Object ID**: `fa86b10b-792c-495b-af85-bc8a765b44a1`
- **Name**: FedEx Carrier Partner API

---

### Step 3: Create RLS Role - WarehousePartner

**Purpose**: Warehouse partner accesses only their warehouse operations

#### Table: gold_warehouse_productivity_daily
```sql
warehouse_partner_id = 'PARTNER_WH003'
```

**Configuration:**
- **Role Name**: `WarehousePartner`
- **Table**: `gold_warehouse_productivity_daily`
- **Filter Expression**: `warehouse_partner_id = 'PARTNER_WH003'`
- **Description**: Warehouse partner - productivity metrics

#### Assign Service Principal
- **Member Type**: Service Principal
- **Object ID**: `bf7ca9fa-eb65-4261-91f2-08d2b360e919`
- **Name**: Warehouse East Partner API

---

### Step 4: Create RLS Role - CustomerAcme

**Purpose**: ACME customer accesses their orders, shipments, invoices, and SLA data

#### Table 1: gold_orders_daily_summary
```sql
partner_access_scope = 'CUSTOMER'
```

**Configuration:**
- **Role Name**: `CustomerAcme`
- **Table**: `gold_orders_daily_summary`
- **Filter Expression**: `partner_access_scope = 'CUSTOMER'`
- **Description**: ACME Corp - daily order summary

#### Table 2: gold_shipments_in_transit
```sql
partner_access_scope = 'CUSTOMER'
```

**Configuration:**
- **Role Name**: `CustomerAcme` (same role)
- **Table**: `gold_shipments_in_transit`
- **Filter Expression**: `partner_access_scope = 'CUSTOMER'`
- **Description**: ACME Corp - shipments tracking

#### Table 3: gold_revenue_recognition_realtime
```sql
partner_access_scope = 'CUSTOMER'
```

**Configuration:**
- **Role Name**: `CustomerAcme` (same role)
- **Table**: `gold_revenue_recognition_realtime`
- **Filter Expression**: `partner_access_scope = 'CUSTOMER'`
- **Description**: ACME Corp - invoices and revenue

#### Table 4: gold_sla_performance
```sql
partner_access_scope = 'CUSTOMER'
```

**Configuration:**
- **Role Name**: `CustomerAcme` (same role)
- **Table**: `gold_sla_performance`
- **Filter Expression**: `partner_access_scope = 'CUSTOMER'`
- **Description**: ACME Corp - SLA performance

#### Assign Service Principal
- **Member Type**: Service Principal
- **Object ID**: `efae8acd-de55-4c89-96b6-7f031a954ae6`
- **Name**: ACME Corp Customer API

---

## 📊 RLS Configuration Summary

| Role | Tables | Filter Column | Filter Value | Service Principal ID |
|------|--------|---------------|--------------|----------------------|
| **CarrierFedEx** | gold_shipments_in_transit<br>gold_sla_performance | `carrier_id` | `CARRIER-FEDEX-GROU` | `fa86b10b...` |
| **WarehousePartner** | gold_warehouse_productivity_daily | `warehouse_partner_id` | `PARTNER_WH003` | `bf7ca9fa...` |
| **CustomerAcme** | gold_orders_daily_summary<br>gold_shipments_in_transit<br>gold_revenue_recognition_realtime<br>gold_sla_performance | `partner_access_scope` | `CUSTOMER` | `efae8acd...` |

---

## 🔄 RLS Propagation

Once configured, RLS automatically applies to ALL consuming services:

- ✅ **GraphQL API** (automatic filtering)
- ✅ **SQL Analytics Endpoint** (automatic filtering)
- ✅ **Power BI Direct Lake** (automatic filtering)
- ✅ **Notebooks** (automatic filtering)
- ✅ **Pipelines** (automatic filtering)

**No additional configuration needed** in GraphQL API or other services!

---

## 🧪 Testing RLS Configuration

### Test 1: Verify RLS in SQL Analytics Endpoint

Connect to Lakehouse SQL Endpoint with Service Principal credentials:

```powershell
# Get FedEx token
$tenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
$clientId = "94a9edcc-7a22-4d89-b001-799e8414711a"
$clientSecret = "YOUR_FEDEX_SECRET_HERE"

$body = @{
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://analysis.windows.net/powerbi/api/.default"
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$token = $tokenResponse.access_token

# Query with FedEx credentials (should only see CARRIER-FEDEX data)
$sqlQuery = "SELECT DISTINCT carrier_id FROM gold_shipments_in_transit"
# Execute query with $token...
```

**Expected Result**: Only rows with `carrier_id = 'CARRIER-FEDEX'`

### Test 2: Verify RLS in GraphQL API

```powershell
# Test script location
cd api/scripts

# Test FedEx Carrier
.\test-graphql-rls.ps1 -Partner "FedEx"

# Test Warehouse East
.\test-graphql-rls.ps1 -Partner "WarehouseEast"

# Test ACME Customer
.\test-graphql-rls.ps1 -Partner "ACME"
```

### Test 3: Count Validation

Query to verify filtering works:

```sql
-- As FedEx (should see only CARRIER-FEDEX-GROU)
SELECT carrier_id, COUNT(*) as shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id;

-- Expected: Only 1 row with carrier_id = 'CARRIER-FEDEX-GROU'
```

```sql
-- As Customer (should see only CUSTOMER)
SELECT partner_access_scope, COUNT(*) as order_count
FROM gold_orders_daily_summary
GROUP BY partner_access_scope;

-- Expected: Only 1 row with partner_access_scope = 'CUSTOMER'
```

---

## 🚨 Troubleshooting

### Issue: Service Principal not found
**Solution**: Verify Object ID (not App ID) is used in role assignment

### Issue: RLS not filtering data
**Checks**:
1. Verify notebook was executed and Gold tables recreated
2. Check RLS columns exist in tables: `SELECT TOP 1 * FROM gold_orders_daily_summary`
3. Confirm RLS columns have data (not all NULL)
4. Verify filter expression syntax (single quotes for strings)

### Issue: Access denied errors
**Solution**: 
1. Grant Service Principal **Read** permission on Lakehouse
2. Add Service Principal to appropriate RLS role
3. Wait 5-10 minutes for permissions to propagate

### Issue: No data returned for partner
**Root Cause**: RLS columns not populated in source data

**Solution**: 
```powershell
# Regenerate data with B2B columns
cd simulator
python main.py --count 100

# Wait for mirroring to sync (1-2 minutes)

# Re-execute Gold views notebook in Fabric Portal
```

---

## 📝 Next Steps After RLS Configuration

1. **Replace Silver tables with Gold tables in GraphQL API**
   - Fabric Portal → GraphQL API → Settings
   - Remove: 4 Silver tables
   - Add: 5 Gold tables

2. **Test GraphQL with Service Principals**
   ```powershell
   cd api/scripts
   .\test-graphql-gold-rls.ps1
   ```

3. **Deploy Azure APIM**
   ```powershell
   cd api/scripts
   .\deploy-apim.ps1 `
     -ResourceGroup "rg-3pl-partner-api" `
     -Location "westeurope" `
     -ApimName "apim-3pl-flt"
   ```

4. **Configure APIM Managed Identity**
   - Enable System Managed Identity on APIM
   - Grant Read access to Lakehouse
   - Assign to RLS roles (if using Managed Identity auth)

5. **Create partner subscriptions in APIM**
   - Standard tier for FedEx and Warehouse (60 req/min)
   - Premium tier for ACME (300 req/min)

---

## 📚 Reference Files

- **Service Principal Credentials**: `api/scripts/partner-apps-credentials.json`
- **OneLake RLS Config Template**: `fabric/warehouse/security/onelake-rls-config.json`
- **Gold Views Notebook**: `fabric/lakehouse/Create_Gold_Materialized_Lake_Views.ipynb`
- **GraphQL Test Script**: `api/scripts/test-graphql-simple.ps1`
- **APIM Deployment**: `api/scripts/deploy-apim.ps1`

---

## ✅ Validation Checklist

- [ ] All 3 RLS roles created in Fabric Portal
- [ ] Service Principals assigned to roles (correct Object IDs)
- [ ] RLS tested with SQL queries (correct filtering)
- [ ] GraphQL API returns filtered data per partner
- [ ] No data leakage between partners verified
- [ ] Silver tables removed from GraphQL API
- [ ] Gold tables added to GraphQL API
- [ ] APIM deployed with Managed Identity
- [ ] End-to-end authentication flow tested

---

**Configuration Complete!** 🎉

Your OneLake RLS is now configured for B2B partner data isolation. Each partner can only access their own data through GraphQL API, SQL, Power BI, and all other Fabric services automatically.

