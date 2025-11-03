# Module 5: OneLake Security and Row-Level Security (RLS)

**Estimated Time:** 90 minutes  
**Difficulty:** Advanced  
**Prerequisites:** Modules 1-4 completed, Azure AD permissions to create Service Principals

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

- ✅ Understand OneLake Security and Row-Level Security (RLS) concepts
- ✅ Create Azure AD Service Principals for partner applications
- ✅ Configure RLS policies in Microsoft Fabric
- ✅ Implement partner-specific data filtering
- ✅ Test and validate RLS access controls
- ✅ Troubleshoot common RLS issues
- ✅ Apply security best practices

---

## 📋 Module Overview

In this hands-on lab, you'll implement **enterprise-grade Row-Level Security (RLS)** to ensure that each partner in your 3PL logistics system can only access their own data. You'll learn how OneLake Security provides a **single security definition** that works across all 6 Fabric engines (KQL, Spark, SQL, Power BI, GraphQL, and OneLake API).

### Business Scenario

Your 3PL logistics platform serves multiple external partners:
- 🚚 **Carriers** (FedEx, UPS) - Should only see shipments they're delivering
- 🏭 **Warehouse Partners** - Should only see inventory movements in their facilities
- 🏢 **Customers** (ACME Corp, TechCo) - Should only see their own orders, shipments, and invoices

**Security Challenge:** How do you expose real-time operational data through APIs while ensuring complete data isolation between partners?

**Solution:** OneLake Security with Row-Level Security (RLS)

---

## 🏗️ OneLake Security Architecture

### What is OneLake Security?

OneLake Security is Microsoft Fabric's **storage-layer security** that enforces Row-Level Security at the data lake level. This means:

1. **Single Definition**: Define RLS once, enforce everywhere
2. **Multi-Engine Support**: Works across KQL, Spark, SQL, Power BI, GraphQL, OneLake API
3. **Performance**: No query overhead - filtering happens at storage layer
4. **Scalability**: Supports thousands of partners and millions of rows

### RLS Architecture Diagram

```
Partner Application (JWT with partner_id claim)
         ↓
Azure API Management (OAuth2 validation)
         ↓
Service Principal Authentication
         ↓
OneLake Security RLS Filter (at storage layer)
         ↓
Filtered Data (Partner-specific view)
         ↓
GraphQL API / Power BI / KQL Query
```

### Key Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **Service Principal** | Non-human identity for applications | `sp-partner-fedex` |
| **RLS Role** | Named security role with filter predicate | `CARRIER-FEDEX` |
| **Filter Predicate** | DAX expression to filter rows | `[carrier_id] = 'CARRIER-FEDEX'` |
| **Role Member** | Service Principal assigned to RLS role | FedEx app → CARRIER-FEDEX role |
| **Access Scope** | Column defining data ownership | `partner_access_scope` |

---

## 📚 Section 1: OneLake Security Overview

### How OneLake Security Works

OneLake Security uses **role-based filtering** at the storage layer:

1. **Service Principal authenticates** to Fabric
2. **Fabric identifies RLS roles** assigned to that Service Principal
3. **Filter predicates are applied** automatically to all queries
4. **Only matching rows are returned** - no code changes needed

### RLS Filter Examples

#### Partner-Scoped Filter
```dax
[partner_access_scope] = 'CUSTOMER-ACME'
```
This filter ensures ACME Corp only sees rows where `partner_access_scope = 'CUSTOMER-ACME'`.

#### Carrier-Scoped Filter
```dax
[carrier_id] = 'CARRIER-FEDEX'
```
FedEx only sees shipments where they are the carrier.

#### Warehouse-Scoped Filter
```dax
[warehouse_partner_id] = 'PARTNER_WH003'
```
Warehouse East only sees movements in their facility.

### Multi-Level Security

OneLake Security supports **hierarchical access**:

```
Organization Level → Department Level → User Level
```

For this workshop, we'll focus on **Partner Level** security (most common use case).

---

## 📚 Section 2: Service Principal Setup

### What is a Service Principal?

A **Service Principal** is an identity for applications (not humans) to authenticate with Azure AD and access resources.

**Why Service Principals for RLS?**
- Each partner application gets its own identity
- Fine-grained access control per partner
- Auditable - you know exactly which partner accessed what data
- Secure - credentials can be rotated without user involvement

### Prerequisites

Before creating Service Principals, ensure you have:

✅ Azure AD tenant with permissions to create App Registrations  
✅ PowerShell 7+ or Azure CLI installed  
✅ Azure subscription linked to Fabric workspace  
✅ Admin or Member role in Fabric workspace

### Creating Service Principals

We'll create **3 Service Principals** for our partner scenarios:

| Partner | Service Principal Name | RLS Role | Access Scope |
|---------|----------------------|----------|--------------|
| FedEx Carrier | `sp-partner-fedex` | `CARRIER-FEDEX` | Shipments where carrier_id = FEDEX |
| Warehouse East | `sp-partner-warehouse-east` | `WAREHOUSE-EAST` | Warehouse movements at WH003 |
| ACME Corp | `sp-partner-acme` | `CUSTOMER-ACME` | Orders, shipments, invoices for ACME |

### Step-by-Step: Create Service Principals with PowerShell

We've provided a PowerShell script to automate Service Principal creation.

**Navigate to the scripts directory:**

```powershell
# From the workshop directory
cd scripts

# Or from the repository root
cd workshop/scripts
```

**Run the configuration script:**

```powershell
.\configure-rls.ps1 -Action CreateServicePrincipals
```

This script will:
1. ✅ Create 3 App Registrations in Azure AD
2. ✅ Generate client secrets for each
3. ✅ Save credentials to `partner-apps-credentials.json`
4. ✅ Display Service Principal details

**Expected Output:**

```
✅ Created Service Principal: sp-partner-fedex
   App ID: 12345678-1234-1234-1234-123456789abc
   Object ID: abcdef12-3456-7890-abcd-ef1234567890

✅ Created Service Principal: sp-partner-warehouse-east
   App ID: 23456789-2345-2345-2345-234567890abc
   Object ID: bcdef123-4567-8901-bcde-f12345678901

✅ Created Service Principal: sp-partner-acme
   App ID: 34567890-3456-3456-3456-345678901abc
   Object ID: cdef1234-5678-9012-cdef-123456789012

✅ Credentials saved to: partner-apps-credentials.json
```

### Manual Service Principal Creation (Azure Portal)

If you prefer the Azure Portal:

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Name: `sp-partner-fedex`
4. Click **Register**
5. Go to **Certificates & secrets** → **New client secret**
6. Description: `FedEx API Access`, Expires: 12 months
7. Copy the **secret value** (you won't see it again!)
8. Note the **Application (client) ID** and **Directory (tenant) ID**

Repeat for the other 2 Service Principals.

### Grant Workspace Access

Service Principals need **Viewer** role in the Fabric workspace to read data.

**Using PowerShell:**

```powershell
.\configure-rls.ps1 -Action GrantWorkspaceAccess -WorkspaceName "your-workspace-name"
```

**Using Fabric Portal:**

1. Open your Fabric workspace
2. Click **Manage access**
3. Click **Add people**
4. Search for the Service Principal name (e.g., `sp-partner-fedex`)
5. Assign role: **Viewer**
6. Click **Add**

Repeat for all 3 Service Principals.

---

## 📚 Section 3: RLS Configuration

Now that we have Service Principals, let's configure RLS roles and filters.

### RLS Tables and Columns

Our Gold layer tables have these RLS columns:

| Table | RLS Column | Purpose |
|-------|------------|---------|
| `gold_orders_daily_summary` | `partner_access_scope` | Customer access |
| `gold_shipments_in_transit` | `carrier_id` | Carrier access |
| `gold_shipments_in_transit` | `partner_access_scope` | Customer access |
| `gold_warehouse_productivity_daily` | `warehouse_partner_id` | Warehouse access |
| `gold_sla_performance` | `carrier_id` | Carrier SLA metrics |
| `gold_revenue_recognition_realtime` | `partner_access_scope` | Customer financials |

### Creating RLS Roles in Fabric

#### Step 1: Open SQL Analytics Endpoint

1. Go to **Fabric Portal**: https://app.fabric.microsoft.com
2. Open your workspace
3. Find your **Lakehouse** (e.g., `lh_3pl_gold`)
4. Click on the **SQL analytics endpoint** (icon: 🔌)
5. In the left pane, click **Security** → **Manage security roles**

#### Step 2: Create Role 1 - CARRIER-FEDEX

This role filters shipment data for FedEx carriers.

**Create the role:**

1. Click **+ New role**
2. **Role name**: `CARRIER-FEDEX`
3. **Description**: `FedEx carrier - shipment access only`

**Add filter predicates:**

1. **Table**: `gold_shipments_in_transit`
2. **Filter expression** (DAX):
   ```dax
   [carrier_id] = "CARRIER-FEDEX-GROUP"
   ```
3. Click **Save**

4. **Table**: `gold_sla_performance`
5. **Filter expression** (DAX):
   ```dax
   [carrier_id] = "CARRIER-FEDEX-GROUP"
   ```
6. Click **Save**

**Add role members:**

1. Click **Manage members**
2. Click **+ Add**
3. Search for `sp-partner-fedex`
4. Select the Service Principal
5. Click **Add**

#### Step 3: Create Role 2 - WAREHOUSE-EAST

This role filters warehouse data for Warehouse East operations.

1. Click **+ New role**
2. **Role name**: `WAREHOUSE-EAST`
3. **Description**: `Warehouse East - facility WH003 access`

**Add filter predicate:**

1. **Table**: `gold_warehouse_productivity_daily`
2. **Filter expression** (DAX):
   ```dax
   [warehouse_partner_id] = "PARTNER_WH003"
   ```
3. Click **Save**

**Add role members:**

1. Click **Manage members**
2. Add Service Principal: `sp-partner-warehouse-east`

#### Step 4: Create Role 3 - CUSTOMER-ACME

This role provides customer access across multiple tables.

1. Click **+ New role**
2. **Role name**: `CUSTOMER-ACME`
3. **Description**: `ACME Corp - customer data access`

**Add filter predicates (multiple tables):**

1. **Table**: `gold_orders_daily_summary`
   ```dax
   [partner_access_scope] = "CUSTOMER"
   ```

2. **Table**: `gold_shipments_in_transit`
   ```dax
   [partner_access_scope] = "CUSTOMER"
   ```

3. **Table**: `gold_revenue_recognition_realtime`
   ```dax
   [partner_access_scope] = "CUSTOMER"
   ```

**Add role members:**

1. Add Service Principal: `sp-partner-acme`

### Verify RLS Configuration

After creating all roles, verify the configuration:

**Expected Roles:**

```
✅ CARRIER-FEDEX
   - Tables: gold_shipments_in_transit, gold_sla_performance
   - Members: sp-partner-fedex

✅ WAREHOUSE-EAST
   - Tables: gold_warehouse_productivity_daily
   - Members: sp-partner-warehouse-east

✅ CUSTOMER-ACME
   - Tables: gold_orders_daily_summary, gold_shipments_in_transit, gold_revenue_recognition_realtime
   - Members: sp-partner-acme
```

---

## 📚 Section 4: Testing Access Controls

Now let's validate that RLS is working correctly.

### Test Approach

We'll test RLS using:
1. **Direct SQL Queries** with `EXECUTE AS USER`
2. **GraphQL API** with Service Principal tokens
3. **KQL Queries** in Eventhouse (if configured)

### Test 1: SQL Query Test (Admin View)

First, let's see the data **without RLS** (as an admin):

```sql
-- Connect to SQL Analytics Endpoint as admin

-- Check total shipments (all carriers)
SELECT carrier_id, COUNT(*) as shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id
ORDER BY shipment_count DESC;
```

**Expected Output (Admin - No RLS):**

```
carrier_id              | shipment_count
------------------------|---------------
CARRIER-FEDEX-GROUP     | 245
CARRIER-UPS-GROUP       | 198
CARRIER-DHL-GROUP       | 176
```

### Test 2: Impersonate FedEx Carrier

Now let's test with RLS as FedEx:

```sql
-- Impersonate the FedEx Service Principal
EXECUTE AS USER = 'sp-partner-fedex';

-- This query should only return FedEx shipments
SELECT carrier_id, COUNT(*) as shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id;

-- Return to admin context
REVERT;
```

**Expected Output (FedEx - With RLS):**

```
carrier_id              | shipment_count
------------------------|---------------
CARRIER-FEDEX-GROUP     | 245
```

✅ **Pass Criteria**: Only FedEx shipments are visible, no UPS or DHL data

### Test 3: Warehouse Partner Test

```sql
EXECUTE AS USER = 'sp-partner-warehouse-east';

SELECT warehouse_partner_id, COUNT(*) as movement_count
FROM gold_warehouse_productivity_daily
GROUP BY warehouse_partner_id;

REVERT;
```

**Expected Output:**

```
warehouse_partner_id | movement_count
---------------------|---------------
PARTNER_WH003        | 156
```

✅ **Pass Criteria**: Only PARTNER_WH003 data visible

### Test 4: Customer Access Test

```sql
EXECUTE AS USER = 'sp-partner-acme';

-- Orders
SELECT partner_access_scope, COUNT(*) as order_count
FROM gold_orders_daily_summary
GROUP BY partner_access_scope;

-- Shipments
SELECT partner_access_scope, COUNT(*) as shipment_count
FROM gold_shipments_in_transit
WHERE partner_access_scope IS NOT NULL
GROUP BY partner_access_scope;

REVERT;
```

**Expected Output:**

```
partner_access_scope | order_count
---------------------|------------
CUSTOMER             | 89

partner_access_scope | shipment_count
---------------------|---------------
CUSTOMER             | 72
```

✅ **Pass Criteria**: Only CUSTOMER scope data visible

### Test 5: GraphQL API Test with PowerShell

Use the provided test script to validate RLS through the GraphQL API:

```powershell
cd /home/runner/work/Fabric-SAP-Idocs/Fabric-SAP-Idocs/workshop/tests

# Run comprehensive RLS tests
.\test-rls-access.ps1 -Verbose
```

See the **Test Access Scenarios** section below for details.

---

## 📚 Section 5: Common Security Patterns

### Pattern 1: Multi-Table Access

Some partners need access to multiple related tables:

```dax
-- Apply same filter to all customer-facing tables
-- Table: gold_orders_daily_summary
[partner_access_scope] = "CUSTOMER"

-- Table: gold_shipments_in_transit
[partner_access_scope] = "CUSTOMER"

-- Table: gold_revenue_recognition_realtime
[partner_access_scope] = "CUSTOMER"
```

### Pattern 2: Multiple Filter Criteria

Combine conditions with AND/OR logic:

```dax
-- Warehouse can see their facility AND shipments for their customers
[warehouse_partner_id] = "PARTNER_WH003" 
| [destination_warehouse_id] = "WH-EAST-001"
```

### Pattern 3: Dynamic Partner Mapping

For advanced scenarios, use lookup tables:

```dax
-- Filter based on user-to-partner mapping table
USERPRINCIPALNAME() IN (
    CALCULATETABLE(
        VALUES(user_partner_mapping[email]),
        user_partner_mapping[partner_id] = "CARRIER-FEDEX"
    )
)
```

### Pattern 4: Admin Override

Allow admin roles to bypass RLS:

```dax
-- Admin users see all data
[partner_access_scope] = "CUSTOMER-ACME"
|| USERPRINCIPALNAME() IN ("admin@contoso.com", "dataops@contoso.com")
```

### Pattern 5: Time-Based Access

Restrict access to recent data only:

```dax
-- Partners only see last 90 days
[carrier_id] = "CARRIER-FEDEX"
&& [shipment_date] >= TODAY() - 90
```

---

## 📚 Section 6: Debugging RLS Issues

### Issue 1: RLS Not Filtering Data

**Symptom:** Service Principal sees all data, not just their scope

**Root Causes:**
1. Service Principal not added to RLS role members
2. RLS role not enabled (STATE = OFF)
3. Filter predicate DAX syntax error
4. Column name mismatch

**Debugging Steps:**

```sql
-- Check if RLS policies exist and are enabled
SELECT 
    sp.name as RoleName,
    sp.is_enabled,
    t.name as TableName,
    spr.filter_predicate
FROM sys.security_policies sp
JOIN sys.security_predicates spr ON sp.object_id = spr.object_id
JOIN sys.tables t ON spr.target_object_id = t.object_id
WHERE sp.is_enabled = 1;
```

```sql
-- Check role membership
SELECT 
    r.name as RoleName,
    m.name as MemberName,
    m.type_desc as MemberType
FROM sys.database_role_members drm
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
WHERE r.name LIKE '%CARRIER%' OR r.name LIKE '%WAREHOUSE%' OR r.name LIKE '%CUSTOMER%';
```

**Solutions:**
1. Verify Service Principal is in role: **Security** → **Manage roles** → Check members
2. Enable RLS policy: `ALTER SECURITY POLICY PolicyName WITH (STATE = ON)`
3. Test filter predicate in standalone query
4. Verify column exists: `SELECT TOP 1 carrier_id FROM table`

### Issue 2: Access Denied Errors

**Symptom:** `403 Forbidden` or `Access Denied` when querying

**Root Causes:**
1. Service Principal lacks workspace permissions
2. Lakehouse/Warehouse permissions not granted
3. Token scope incorrect

**Solutions:**

```powershell
# Verify workspace access
Get-PowerBIWorkspaceUsers -WorkspaceId <workspace-id>

# Grant workspace viewer role
Add-PowerBIWorkspaceUser -WorkspaceId <workspace-id> -UserPrincipalName "sp-name@tenant.onmicrosoft.com" -AccessRight Viewer

# Check token scope
$token = "your-token-here"
$tokenPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token.Split('.')[1]))
$tokenPayload | ConvertFrom-Json | Select-Object -ExpandProperty scp
```

### Issue 3: Performance Degradation

**Symptom:** Queries slow after enabling RLS

**Root Causes:**
1. Missing indexes on RLS filter columns
2. Complex DAX expressions
3. Full table scans

**Solutions:**

```sql
-- Create indexes on RLS columns
CREATE NONCLUSTERED INDEX IX_Shipments_CarrierID
ON gold_shipments_in_transit (carrier_id)
INCLUDE (shipment_number, tracking_number, ship_date);

CREATE NONCLUSTERED INDEX IX_Warehouse_PartnerID
ON gold_warehouse_productivity_daily (warehouse_partner_id)
INCLUDE (movement_day, total_movements);

-- Update statistics
UPDATE STATISTICS gold_shipments_in_transit;
UPDATE STATISTICS gold_warehouse_productivity_daily;
```

### Issue 4: GraphQL API Returns Empty Results

**Symptom:** GraphQL query returns `{ "data": { "items": [] } }`

**Root Causes:**
1. No data matches the RLS filter
2. Service Principal token not properly authenticated
3. Data hasn't been generated for that partner

**Debugging:**

```graphql
# Test query as admin (should return data)
query {
  gold_shipments_in_transits(first: 10) {
    items {
      carrier_id
      shipment_number
    }
  }
}
```

```sql
-- Verify data exists for the partner
SELECT COUNT(*) FROM gold_shipments_in_transit WHERE carrier_id = 'CARRIER-FEDEX-GROUP';
```

**Solutions:**
1. Regenerate test data: Run the IDoc simulator
2. Verify token authentication: Check `Authorization: Bearer <token>` header
3. Check RLS role assignment for the Service Principal

### Issue 5: Data Leakage Between Partners

**Symptom:** Partner A can see Partner B's data

**Root Causes:**
1. Service Principal assigned to multiple roles
2. Missing RLS filter on a table
3. Joins to unfiltered tables

**Security Audit:**

```sql
-- Check if Service Principal has multiple role memberships
SELECT 
    m.name as ServicePrincipal,
    r.name as RoleName
FROM sys.database_role_members drm
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
WHERE m.name LIKE 'sp-partner%'
ORDER BY m.name, r.name;
```

```sql
-- Verify all gold tables have RLS filters
SELECT 
    t.name as TableName,
    ISNULL(COUNT(spr.object_id), 0) as RLS_Filter_Count
FROM sys.tables t
LEFT JOIN sys.security_predicates spr ON t.object_id = spr.target_object_id
WHERE t.schema_id = SCHEMA_ID('gold')
GROUP BY t.name
ORDER BY RLS_Filter_Count, t.name;
```

**Solutions:**
1. Remove Service Principal from incorrect roles
2. Add RLS filters to all customer-facing tables
3. Avoid JOINs to tables without RLS (or add filters)

---

## ✅ Lab Validation Checklist

Use this checklist to validate your RLS implementation:

### Service Principal Setup
- [ ] 3 Service Principals created (FedEx, Warehouse, ACME)
- [ ] Client secrets saved securely
- [ ] Service Principals granted Viewer role in workspace
- [ ] Credentials file `partner-apps-credentials.json` created

### RLS Configuration
- [ ] Role `CARRIER-FEDEX` created with shipment filters
- [ ] Role `WAREHOUSE-EAST` created with warehouse filters
- [ ] Role `CUSTOMER-ACME` created with multi-table filters
- [ ] All roles enabled (STATE = ON)
- [ ] Service Principals assigned to correct roles

### Testing
- [ ] SQL impersonation tests pass (EXECUTE AS USER)
- [ ] FedEx only sees CARRIER-FEDEX-GROUP shipments
- [ ] Warehouse only sees PARTNER_WH003 movements
- [ ] ACME only sees CUSTOMER scope data
- [ ] GraphQL API tests pass with Service Principal tokens
- [ ] No data leakage between partners

### Security Best Practices
- [ ] RLS columns indexed for performance
- [ ] No admin credentials hardcoded
- [ ] Token expiration configured (12 months max)
- [ ] Audit logging enabled
- [ ] Documentation updated

---

## 🎓 Key Takeaways

Congratulations! You've implemented enterprise-grade Row-Level Security. Here's what you learned:

1. **OneLake Security** provides storage-layer RLS that works across all Fabric engines
2. **Service Principals** enable secure, auditable partner application access
3. **RLS Roles** define filter predicates using DAX expressions
4. **Multi-Table Filtering** ensures consistent security across related datasets
5. **Testing is Critical** - always validate RLS with impersonation and real tokens
6. **Performance Matters** - index RLS filter columns for optimal query speed

---

## 📚 Additional Resources

### Microsoft Documentation
- [OneLake Security Overview](https://learn.microsoft.com/fabric/security/onelake-security)
- [Row-Level Security in Fabric](https://learn.microsoft.com/fabric/security/service-admin-row-level-security)
- [Service Principals in Fabric](https://learn.microsoft.com/fabric/admin/service-principal-overview)

### Repository Resources
- [RLS Configuration Guide](/fabric/RLS_CONFIGURATION_GUIDE.md) - Technical implementation details
- [RLS Advanced Guide](/docs/roadmap/RLS_ADVANCED_GUIDE.md) - Multi-level security patterns
- [PowerShell Scripts](/workshop/scripts/) - Automation scripts for RLS setup

### Next Steps
- **Module 6**: [GraphQL API Development](./module6-api-development.md) - Expose your secure data through APIs
- **Bonus**: Integrate with Microsoft Purview for data governance and compliance

---

## 🆘 Getting Help

If you encounter issues:

1. **Check Troubleshooting**: Review Section 6 above
2. **Review Test Results**: Run `.\test-rls-access.ps1 -Verbose`
3. **Validate Configuration**: Use the validation checklist
4. **Community Support**: [GitHub Discussions](https://github.com/flthibau/Fabric-SAP-Idocs/discussions)
5. **Report Issues**: [GitHub Issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)

---

**🎉 Well done!** You've successfully implemented OneLake Security RLS. Your data product is now secure and ready for production deployment.

**Next Module**: [Module 6 - GraphQL API Development →](./module6-api-development.md)
