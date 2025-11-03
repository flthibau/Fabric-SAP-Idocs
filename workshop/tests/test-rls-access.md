# RLS Access Testing Guide

This document provides comprehensive test scenarios for validating Row-Level Security (RLS) configuration in the Fabric SAP IDoc Workshop.

---

## 🎯 Testing Objectives

The goal of RLS testing is to ensure:

1. ✅ **Data Isolation**: Each partner sees only their own data
2. ✅ **No Data Leakage**: Partners cannot access other partners' data
3. ✅ **Correct Filtering**: RLS filters are applied correctly across all tables
4. ✅ **Performance**: RLS doesn't significantly degrade query performance
5. ✅ **API Integration**: RLS works correctly through GraphQL API

---

## 📋 Test Scenarios

### Test Scenario 1: FedEx Carrier Access

**Partner:** FedEx (Carrier)  
**Service Principal:** `sp-partner-fedex`  
**RLS Role:** `CARRIER-FEDEX`  
**Expected Access:** Shipments where `carrier_id = 'CARRIER-FEDEX-GROUP'`

#### Test 1.1: Shipment Data Access

**SQL Test:**

```sql
-- Authenticate as FedEx Service Principal
EXECUTE AS USER = 'sp-partner-fedex';

-- Query shipments
SELECT 
    carrier_id,
    carrier_name,
    COUNT(*) as shipment_count
FROM gold_shipments_in_transit
GROUP BY carrier_id, carrier_name;

REVERT;
```

**Expected Result:**

| carrier_id | carrier_name | shipment_count |
|------------|--------------|----------------|
| CARRIER-FEDEX-GROUP | FedEx | 245 |

✅ **Pass Criteria:**
- Only `CARRIER-FEDEX-GROUP` rows returned
- No UPS, DHL, or other carrier data visible
- Row count > 0 (data exists)

❌ **Fail Criteria:**
- Multiple carriers visible
- Zero rows returned
- Error: "Access Denied"

---

#### Test 1.2: SLA Performance Metrics

**SQL Test:**

```sql
EXECUTE AS USER = 'sp-partner-fedex';

SELECT 
    carrier_id,
    COUNT(*) as sla_records,
    AVG(CAST(processing_days as FLOAT)) as avg_processing_days,
    SUM(CASE WHEN sla_compliance = 'Compliant' THEN 1 ELSE 0 END) as compliant_count
FROM gold_sla_performance
GROUP BY carrier_id;

REVERT;
```

**Expected Result:**

| carrier_id | sla_records | avg_processing_days | compliant_count |
|------------|-------------|---------------------|-----------------|
| CARRIER-FEDEX-GROUP | 156 | 2.8 | 142 |

✅ **Pass Criteria:**
- Only FedEx SLA data visible
- Metrics calculated correctly

---

#### Test 1.3: GraphQL API Access

**GraphQL Query:**

```graphql
query FedExShipments {
  gold_shipments_in_transits(first: 100) {
    items {
      carrier_id
      carrier_name
      shipment_number
      tracking_number
      delay_status
    }
  }
}
```

**Authentication:**

```bash
# Get FedEx Service Principal token
TOKEN=$(az account get-access-token \
  --resource https://api.fabric.microsoft.com \
  --query accessToken -o tsv)

# Execute GraphQL query (compact format for curl)
curl -X POST https://<your-graphql-endpoint>/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gold_shipments_in_transits(first:10) { items { carrier_id shipment_number } } }"}'

# Note: The query above is the same as the formatted GraphQL query above,
# but condensed to a single line for use in curl command
```

**Expected Response:**

```json
{
  "data": {
    "gold_shipments_in_transits": {
      "items": [
        {
          "carrier_id": "CARRIER-FEDEX-GROUP",
          "carrier_name": "FedEx",
          "shipment_number": "SHP-2024-001234",
          "tracking_number": "FDX789456123",
          "delay_status": "On Time"
        },
        {
          "carrier_id": "CARRIER-FEDEX-GROUP",
          "carrier_name": "FedEx",
          "shipment_number": "SHP-2024-001235",
          "tracking_number": "FDX789456124",
          "delay_status": "Delayed"
        }
      ]
    }
  }
}
```

✅ **Pass Criteria:**
- All returned items have `carrier_id = "CARRIER-FEDEX-GROUP"`
- No 401 or 403 errors
- Response time < 2 seconds

---

### Test Scenario 2: Warehouse Partner Access

**Partner:** Warehouse East  
**Service Principal:** `sp-partner-warehouse-east`  
**RLS Role:** `WAREHOUSE-EAST`  
**Expected Access:** Warehouse data where `warehouse_partner_id = 'PARTNER_WH003'`

#### Test 2.1: Warehouse Productivity Data

**SQL Test:**

```sql
EXECUTE AS USER = 'sp-partner-warehouse-east';

SELECT 
    warehouse_partner_id,
    warehouse_partner_name,
    warehouse_id,
    COUNT(*) as daily_records,
    SUM(total_movements) as total_movements,
    AVG(CAST(movements_per_hour as FLOAT)) as avg_movements_per_hour
FROM gold_warehouse_productivity_daily
GROUP BY warehouse_partner_id, warehouse_partner_name, warehouse_id;

REVERT;
```

**Expected Result:**

| warehouse_partner_id | warehouse_partner_name | warehouse_id | daily_records | total_movements | avg_movements_per_hour |
|----------------------|------------------------|--------------|---------------|-----------------|------------------------|
| PARTNER_WH003 | Warehouse East | WH-EAST-001 | 156 | 45,678 | 285.5 |

✅ **Pass Criteria:**
- Only `PARTNER_WH003` data visible
- No other warehouse partner data
- Aggregations calculated correctly

---

#### Test 2.2: No Access to Other Tables

**SQL Test (Should Return Empty):**

```sql
EXECUTE AS USER = 'sp-partner-warehouse-east';

-- Warehouse partner should NOT see shipment data
SELECT COUNT(*) as should_be_zero
FROM gold_shipments_in_transit;

-- Warehouse partner should NOT see order data
SELECT COUNT(*) as should_be_zero
FROM gold_orders_daily_summary;

REVERT;
```

**Expected Result:**

| should_be_zero |
|----------------|
| 0 |

✅ **Pass Criteria:**
- Both queries return 0 rows
- Or queries fail with "Access Denied" (depending on RLS config)

---

#### Test 2.3: GraphQL API Warehouse Query

**GraphQL Query:**

```graphql
query WarehouseProductivity {
  gold_warehouse_productivity_dailies(first: 50) {
    items {
      warehouse_partner_id
      warehouse_partner_name
      warehouse_id
      movement_day
      total_movements
      performance_status
    }
  }
}
```

**Expected Response:**

```json
{
  "data": {
    "gold_warehouse_productivity_dailies": {
      "items": [
        {
          "warehouse_partner_id": "PARTNER_WH003",
          "warehouse_partner_name": "Warehouse East",
          "warehouse_id": "WH-EAST-001",
          "movement_day": "2024-11-01",
          "total_movements": 1234,
          "performance_status": "Above Target"
        }
      ]
    }
  }
}
```

✅ **Pass Criteria:**
- All items have `warehouse_partner_id = "PARTNER_WH003"`
- No other warehouse data visible

---

### Test Scenario 3: Customer Access (ACME Corp)

**Partner:** ACME Corp (Customer)  
**Service Principal:** `sp-partner-acme`  
**RLS Role:** `CUSTOMER-ACME`  
**Expected Access:** Multi-table access where `partner_access_scope = 'CUSTOMER'`

#### Test 3.1: Order Data Access

**SQL Test:**

```sql
EXECUTE AS USER = 'sp-partner-acme';

SELECT 
    partner_access_scope,
    customer_id,
    customer_name,
    COUNT(DISTINCT order_day) as days_with_orders,
    SUM(total_orders) as total_orders,
    SUM(total_revenue) as total_revenue
FROM gold_orders_daily_summary
GROUP BY partner_access_scope, customer_id, customer_name;

REVERT;
```

**Expected Result:**

| partner_access_scope | customer_id | customer_name | days_with_orders | total_orders | total_revenue |
|----------------------|-------------|---------------|------------------|--------------|---------------|
| CUSTOMER | CUST-12345 | ACME Corp | 45 | 1,234 | 5,678,900.00 |

✅ **Pass Criteria:**
- Only `partner_access_scope = 'CUSTOMER'` data visible
- Customer-specific metrics shown

---

#### Test 3.2: Shipment Tracking Access

**SQL Test:**

```sql
EXECUTE AS USER = 'sp-partner-acme';

SELECT 
    partner_access_scope,
    carrier_id,
    COUNT(*) as shipment_count,
    SUM(CASE WHEN delay_status = 'On Time' THEN 1 ELSE 0 END) as on_time_count,
    SUM(CASE WHEN delay_status = 'Delayed' THEN 1 ELSE 0 END) as delayed_count
FROM gold_shipments_in_transit
WHERE partner_access_scope IS NOT NULL
GROUP BY partner_access_scope, carrier_id;

REVERT;
```

**Expected Result:**

| partner_access_scope | carrier_id | shipment_count | on_time_count | delayed_count |
|----------------------|------------|----------------|---------------|---------------|
| CUSTOMER | CARRIER-FEDEX-GROUP | 145 | 132 | 13 |
| CUSTOMER | CARRIER-UPS-GROUP | 98 | 91 | 7 |

✅ **Pass Criteria:**
- Only `partner_access_scope = 'CUSTOMER'` rows
- Can see multiple carriers (but only their own shipments)

---

#### Test 3.3: Revenue Recognition Access

**SQL Test:**

```sql
EXECUTE AS USER = 'sp-partner-acme';

SELECT 
    partner_access_scope,
    customer_id,
    SUM(total_revenue) as total_revenue,
    SUM(total_paid) as total_paid,
    SUM(total_due) as total_due,
    COUNT(DISTINCT invoice_number) as invoice_count
FROM gold_revenue_recognition_realtime
GROUP BY partner_access_scope, customer_id;

REVERT;
```

**Expected Result:**

| partner_access_scope | customer_id | total_revenue | total_paid | total_due | invoice_count |
|----------------------|-------------|---------------|------------|-----------|---------------|
| CUSTOMER | CUST-12345 | 5,678,900.00 | 4,500,000.00 | 1,178,900.00 | 234 |

✅ **Pass Criteria:**
- Only CUSTOMER scope financial data visible
- Sensitive financial metrics protected

---

#### Test 3.4: Multi-Table GraphQL Query

**GraphQL Query:**

```graphql
query CustomerDashboard {
  orders: gold_orders_daily_summaries(first: 10) {
    items {
      partner_access_scope
      customer_name
      total_orders
      total_revenue
    }
  }
  
  shipments: gold_shipments_in_transits(first: 10) {
    items {
      partner_access_scope
      customer_name
      shipment_number
      delay_status
    }
  }
  
  revenue: gold_revenue_recognition_realtimes(first: 10) {
    items {
      partner_access_scope
      customer_name
      total_revenue
      total_due
    }
  }
}
```

**Expected Response:**

All 3 sections (orders, shipments, revenue) should return only CUSTOMER scope data.

✅ **Pass Criteria:**
- All items across all 3 queries have `partner_access_scope = "CUSTOMER"`
- No data leakage from other scopes

---

### Test Scenario 4: Negative Tests (Security Validation)

#### Test 4.1: Attempt Cross-Partner Access

**SQL Test:**

```sql
-- Authenticate as FedEx (carrier)
EXECUTE AS USER = 'sp-partner-fedex';

-- Try to access customer order data (should fail or return 0 rows)
SELECT COUNT(*) as should_be_zero
FROM gold_orders_daily_summary;

-- Try to access warehouse data (should fail or return 0 rows)
SELECT COUNT(*) as should_be_zero
FROM gold_warehouse_productivity_daily;

REVERT;
```

**Expected Result:**

| should_be_zero |
|----------------|
| 0 |

✅ **Pass Criteria:**
- FedEx cannot see customer or warehouse data
- Queries return 0 rows or access denied error

---

#### Test 4.2: Unauthenticated Access

**GraphQL Test:**

```bash
# Call GraphQL API without authentication
curl -X POST https://<your-graphql-endpoint>/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gold_shipments_in_transits(first:10) { items { carrier_id } } }"}'
```

**Expected Response:**

```json
{
  "errors": [
    {
      "message": "Unauthorized",
      "extensions": {
        "code": "UNAUTHENTICATED"
      }
    }
  ]
}
```

✅ **Pass Criteria:**
- 401 Unauthorized error
- No data returned

---

#### Test 4.3: Token with Wrong Scope

**Test:**

```bash
# Get token for Fabric API (correct)
TOKEN_CORRECT=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)

# Get token for Graph API (wrong scope)
TOKEN_WRONG=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

# Try to query with wrong token
curl -X POST https://<your-graphql-endpoint>/graphql \
  -H "Authorization: Bearer $TOKEN_WRONG" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gold_shipments_in_transits(first:1) { items { carrier_id } } }"}'
```

**Expected Response:**

```json
{
  "errors": [
    {
      "message": "Invalid token audience",
      "extensions": {
        "code": "INVALID_TOKEN"
      }
    }
  ]
}
```

✅ **Pass Criteria:**
- Authentication fails with wrong token scope
- Error message indicates token issue

---

## 🔧 Automated Testing with PowerShell

Use the provided PowerShell script to run all tests automatically:

```powershell
# Navigate to the tests directory
# From the workshop directory:
cd tests

# Or from the repository root:
cd workshop/tests

# Option 1: Run full test suite
.\test-rls-access.ps1

# Option 2: Test specific partner
.\test-rls-access.ps1 -Partner FedEx

# Option 3: Verbose output with detailed results
.\test-rls-access.ps1 -Verbose

# Option 4: Export results to JSON
.\test-rls-access.ps1 -ExportResults -OutputPath ./test-results.json
```

**Test Script Features:**

- ✅ Authenticates as each Service Principal
- ✅ Runs SQL and GraphQL tests
- ✅ Validates expected vs actual results
- ✅ Generates pass/fail report
- ✅ Exports results to JSON for CI/CD integration

---

## 📊 Performance Testing

### Performance Test 1: RLS Query Overhead

**Measure query performance with and without RLS:**

```sql
-- Enable statistics
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Test 1: Admin query (no RLS filter)
SELECT COUNT(*) FROM gold_shipments_in_transit;

-- Test 2: RLS-filtered query (as FedEx)
EXECUTE AS USER = 'sp-partner-fedex';
SELECT COUNT(*) FROM gold_shipments_in_transit;
REVERT;

-- Compare: Logical reads, CPU time, Elapsed time
```

**Acceptable Performance:**

| Metric | Admin Query | RLS Query | Acceptable Overhead |
|--------|-------------|-----------|---------------------|
| Logical Reads | 1,234 | 1,456 | < 20% increase |
| CPU Time (ms) | 45 | 52 | < 20% increase |
| Elapsed Time (ms) | 78 | 89 | < 20% increase |

✅ **Pass Criteria:**
- RLS overhead < 20% for typical queries
- Query plans use indexes efficiently

---

### Performance Test 2: Index Effectiveness

**Check if RLS filter columns are indexed:**

```sql
-- Find indexes on RLS filter columns
SELECT 
    t.name as TableName,
    i.name as IndexName,
    c.name as ColumnName,
    i.type_desc as IndexType
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.tables t ON i.object_id = t.object_id
WHERE c.name IN ('carrier_id', 'warehouse_partner_id', 'partner_access_scope')
    AND t.schema_id = SCHEMA_ID('gold')
ORDER BY t.name, i.name;
```

**Expected Indexes:**

| TableName | ColumnName | IndexType |
|-----------|------------|-----------|
| gold_shipments_in_transit | carrier_id | NONCLUSTERED |
| gold_warehouse_productivity_daily | warehouse_partner_id | NONCLUSTERED |
| gold_orders_daily_summary | partner_access_scope | NONCLUSTERED |

✅ **Pass Criteria:**
- All RLS filter columns have indexes
- Execution plans show index seeks (not scans)

---

## ✅ Test Summary Checklist

Use this checklist to track test completion:

### FedEx Carrier Tests
- [ ] Test 1.1: Shipment data filtered correctly
- [ ] Test 1.2: SLA metrics show only FedEx
- [ ] Test 1.3: GraphQL API returns FedEx data only
- [ ] Test 4.1: Cannot access customer or warehouse data

### Warehouse Partner Tests
- [ ] Test 2.1: Warehouse productivity data filtered
- [ ] Test 2.2: No access to shipment or order tables
- [ ] Test 2.3: GraphQL API returns warehouse data only

### Customer Tests
- [ ] Test 3.1: Order data filtered to CUSTOMER scope
- [ ] Test 3.2: Shipment tracking filtered correctly
- [ ] Test 3.3: Revenue data shows only customer financials
- [ ] Test 3.4: Multi-table GraphQL query works correctly

### Security Tests
- [ ] Test 4.1: Cross-partner access blocked
- [ ] Test 4.2: Unauthenticated requests rejected
- [ ] Test 4.3: Invalid tokens rejected

### Performance Tests
- [ ] RLS query overhead < 20%
- [ ] Indexes exist on all RLS filter columns
- [ ] Execution plans optimized

---

## 🐛 Troubleshooting Failed Tests

### Test Fails: "Zero rows returned"

**Possible Causes:**
1. No test data generated for that partner
2. RLS filter too restrictive
3. Table names mismatch

**Solutions:**
```sql
-- Check if data exists (as admin)
SELECT carrier_id, COUNT(*) FROM gold_shipments_in_transit GROUP BY carrier_id;

-- Verify RLS filter matches data values
SELECT DISTINCT carrier_id FROM gold_shipments_in_transit;
-- Should include 'CARRIER-FEDEX-GROUP'

-- Re-run IDoc simulator to generate test data
```

---

### Test Fails: "Access Denied"

**Possible Causes:**
1. Service Principal not granted workspace access
2. Service Principal not added to RLS role
3. Wrong authentication scope

**Solutions:**
1. Grant Viewer role in Fabric workspace
2. Add SP to RLS role in Security settings
3. Verify token: `az account get-access-token --resource https://api.fabric.microsoft.com`

---

### Test Fails: "See all data (no filtering)"

**Possible Causes:**
1. RLS role not enabled
2. Filter predicate incorrect
3. Service Principal has Admin role (bypasses RLS)

**Solutions:**
```sql
-- Check RLS policy is enabled
SELECT name, is_enabled FROM sys.security_policies;

-- Verify filter predicate
SELECT 
    p.name as PolicyName,
    pr.filter_predicate
FROM sys.security_policies p
JOIN sys.security_predicates pr ON p.object_id = pr.object_id;

-- Ensure Service Principal is not Admin
```

---

## 📚 Additional Resources

- **Module 5 Lab Guide**: [module5-security-rls.md](../labs/module5-security-rls.md)
- **RLS Configuration Guide**: [/fabric/RLS_CONFIGURATION_GUIDE.md](/fabric/RLS_CONFIGURATION_GUIDE.md)
- **PowerShell Test Script**: [/workshop/scripts/configure-rls.ps1](../scripts/configure-rls.ps1)
- **Microsoft Docs**: [Row-Level Security in Fabric](https://learn.microsoft.com/fabric/security/service-admin-row-level-security)

---

**✅ All tests passing?** Congratulations! Your RLS implementation is secure and ready for production use.

**❌ Tests failing?** Review the troubleshooting guide above or check Module 5 Section 6 for detailed debugging steps.
