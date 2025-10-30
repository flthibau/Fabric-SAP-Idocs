# Microsoft Purview - Data Quality Setup Guide

## 📋 Overview

This guide explains how to implement **Data Quality governance** for the **3PL Logistics Analytics Data Product** in Microsoft Purview.

### What's Included

- ✅ **16 Critical Data Quality Rules** (Bronze + Silver layers)
- ✅ **6 Quality Dimensions** (Completeness, Accuracy, Consistency, Timeliness, Uniqueness, Validity)
- ✅ **Automated KQL Validation** (Eventhouse-based)
- ✅ **Real-time Monitoring Dashboard** (KQL functions)
- ✅ **Alert System** (Critical failures detection)
- ✅ **Executive KPIs** (Quality score, health status)

---

## 🎯 Data Quality Framework

### Quality Dimensions

| Dimension | Definition | Target | Example Rules |
|-----------|-----------|--------|---------------|
| **Completeness** | All required fields populated | 100% | Order number mandatory, Customer ID mandatory |
| **Accuracy** | Data values match reality | 99% | Invoice calculation correctness |
| **Consistency** | Data consistent across systems | 100% | Bronze-to-Silver reconciliation |
| **Timeliness** | Data available within SLA | 95% (<5min) | Ingestion latency |
| **Uniqueness** | No duplicate records | 100% | IDoc number, Invoice number uniqueness |
| **Validity** | Data conforms to business rules | 99% | Message type validity, Amount positivity |

### Rules by Layer

#### Bronze Layer (4 rules)
- **BRZ-001**: Message Structure Completeness
- **BRZ-002**: Message Type Validity
- **BRZ-003**: IDoc Number Uniqueness
- **BRZ-004**: Ingestion Timeliness

#### Silver Layer - Orders (4 rules)
- **SLV-ORD-001**: Order Number Mandatory
- **SLV-ORD-002**: Customer ID Mandatory
- **SLV-ORD-003**: Date Consistency
- **SLV-ORD-004**: Amount Validity

#### Silver Layer - Shipments (3 rules)
- **SLV-SHP-001**: Shipment Number Uniqueness
- **SLV-SHP-002**: Carrier Code Validity
- **SLV-SHP-003**: Transit Time Reasonableness

#### Silver Layer - Warehouse (2 rules)
- **SLV-WHS-001**: Movement Type Validity
- **SLV-WHS-002**: Quantity Positivity

#### Silver Layer - Invoices (2 rules)
- **SLV-INV-001**: Invoice Number Uniqueness
- **SLV-INV-002**: Amount Calculations

#### Cross-Layer (1 rule)
- **XLR-001**: Bronze to Silver Reconciliation

---

## 🚀 Implementation Steps

### Step 1: Create Data Quality Rules in Purview

```powershell
# Navigate to governance/purview
cd c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\governance\purview

# Run the creation script
python create_data_quality_rules.py
```

**What This Does:**
- Creates metadata for all 16 DQ rules
- Generates `data_quality_rules_created.json` with full rule definitions
- Generates `data_quality_validation.kql` for automated execution
- Links rules to Data Product ID `a4f24a45-3443-4f87-a46b-1d4b0b00dce4`

**Output Files:**
- `data_quality_rules_created.json` - Rule catalog (JSON)
- `data_quality_validation.kql` - Validation queries (KQL)

### Step 2: Deploy Monitoring Dashboard to Eventhouse

```kql
// Execute in Microsoft Fabric Eventhouse

// 1. Load all monitoring functions
// Copy contents of data_quality_monitoring_dashboard.kql
// Execute in your Eventhouse KQL Database

// 2. Test each function
OverallQualityScore()
QualityScorecardByDimension()
FailedRulesDetails()
DataQualityAlerts()
TableLevelQualityMetrics()
QualityKPIs()
```

**Functions Created:**
- `OverallQualityScore()` - Overall quality score and health status
- `QualityScorecardByDimension()` - Score breakdown by dimension
- `QualityTrend()` - Historical trend (7 days)
- `FailedRulesDetails()` - List of all failures with remediation actions
- `DataQualityAlerts()` - Critical alerts requiring immediate attention
- `TableLevelQualityMetrics()` - Per-table quality metrics
- `QualityKPIs()` - Executive dashboard KPIs

### Step 3: Link Data Quality to Purview Data Product (Manual)

> **Note**: As of Purview API `2025-09-15-preview`, Data Quality rules cannot be automatically linked via API. Manual linking required.

1. **Open Purview Portal**
   ```
   https://web.purview.azure.com/resource/stpurview/datagovernance/dataProducts/a4f24a45-3443-4f87-a46b-1d4b0b00dce4
   ```

2. **Navigate to Data Product**
   - Go to **Data Governance** → **Data Products**
   - Select **3PL Logistics Analytics**

3. **Add Data Quality Documentation**
   - Click **Edit** on Data Product
   - In **Description** or **Custom Properties**, add:
     ```
     Data Quality Framework: 16 rules across 6 dimensions
     - Completeness: 100% target
     - Accuracy: 99% target
     - Uniqueness: 100% target (critical for invoices)
     - Validation: Automated KQL queries in Eventhouse
     - Monitoring: Real-time dashboard via QualityKPIs() function
     - Alerting: Critical failures trigger immediate alerts
     
     Validation Script: data_quality_validation.kql
     Dashboard: data_quality_monitoring_dashboard.kql
     ```

4. **Link to Eventhouse Assets**
   - Under **Assets**, add links to:
     - `idoc_raw` (Bronze)
     - `idoc_orders_silver` (Silver)
     - `idoc_shipments_silver` (Silver)
     - `idoc_warehouse_silver` (Silver)
     - `idoc_invoices_silver` (Silver)

### Step 4: Configure Automated Validation

**Option A: Scheduled Query in Eventhouse**

```kql
// Create a function to log quality results
.create-or-alter function with (folder = "DataQuality") 
LogQualityResults() {
    let results = OverallQualityScore()
    | extend check_time = now();
    
    // Store in a tracking table (create table first)
    results
    | project check_time, quality_score, health_status, total_rules, passed, failed, critical_failures
}

// Create the tracking table
.create table DataQualityHistory (
    check_time: datetime,
    quality_score: real,
    health_status: string,
    total_rules: int,
    passed: int,
    failed: int,
    critical_failures: int
)

// Execute every hour (configure via Azure Data Factory or Logic Apps)
LogQualityResults()
```

**Option B: Azure Logic Apps (Recommended)**

1. Create Logic App in Azure Portal
2. Configure **Recurrence Trigger** (every 1 hour)
3. Add **Kusto Query Action**:
   - Cluster: Your Eventhouse URI
   - Database: Your KQL Database
   - Query: `DataQualityAlerts()`
4. Add **Condition**:
   - If `critical_failures > 0`
   - Then: **Send Email** or **Post to Teams**

**Option C: Power Automate (Low-code)**

1. Create Flow in Power Automate
2. Trigger: **Recurrence** (every 1 hour)
3. Action: **Run KQL Query** (Eventhouse connector)
4. Condition: If quality_score < 95
5. Action: Send notification to Teams channel

### Step 5: Create Power BI Dashboard (Optional)

**Quick Start:**

1. **Open Power BI Desktop**
2. **Get Data** → **Azure Data Explorer (Kusto)**
3. **Connect to Eventhouse**
   - Cluster: `https://your-eventhouse.region.kusto.windows.net`
   - Database: Your KQL database name
4. **Import Functions**:
   ```
   OverallQualityScore
   QualityScorecardByDimension
   TableLevelQualityMetrics
   DataQualityAlerts
   ```
5. **Create Visualizations**:
   - **Card**: Quality Score (from `OverallQualityScore`)
   - **Gauge**: Health Status (Green/Yellow/Red)
   - **Bar Chart**: Quality by Dimension (from `QualityScorecardByDimension`)
   - **Line Chart**: Quality Trend (from `QualityTrend`)
   - **Table**: Failed Rules (from `FailedRulesDetails`)
   - **Table**: Critical Alerts (from `DataQualityAlerts`)
6. **Configure Auto-Refresh** (every 15 minutes)
7. **Publish to Power BI Service**

---

## 📊 Using the Data Quality Dashboard

### Real-time Quality Check

```kql
// Get current quality score
OverallQualityScore()
```

**Expected Output:**
```
timestamp                  | quality_score | health_status | total_rules | passed | failed | critical_failures
2025-01-20T10:30:00.000Z  | 99.50         | Healthy       | 16          | 16     | 0      | 0
```

### Check for Critical Issues

```kql
// Get all critical alerts
DataQualityAlerts()
```

**If Issues Exist:**
```
timestamp                  | alert_level | rule       | message                                    | affected_table        | failed_count
2025-01-20T10:30:00.000Z  | Critical    | SLV-INV-001| CRITICAL: 2 duplicate invoice numbers...   | idoc_invoices_silver  | 2
```

### View Failed Rules with Remediation

```kql
// Get details of all failures
FailedRulesDetails()
```

**Output:**
```
timestamp | rule       | description              | dimension  | priority | table_name           | failed_count | recommended_action
...       | SLV-INV-001| Invoice Number Uniqueness| Uniqueness | Critical | idoc_invoices_silver | 2            | Critical alert to finance - investigate double-billing
```

### Executive Summary

```kql
// Get KPIs for leadership
QualityKPIs()
```

**Output:**
```
timestamp | kpi_data_quality_score | kpi_total_messages_processed | kpi_critical_issues_count | kpi_health_status
...       | 99.50                  | 125000                      | 0                         | Healthy
```

---

## 🔔 Alert Configuration

### Critical Alerts (Immediate Action Required)

| Rule | Alert Condition | Action | Notification |
|------|----------------|--------|--------------|
| **BRZ-001** | Any message missing structure | Alert data engineering | Email + Teams |
| **BRZ-003** | Duplicate IDoc numbers > 0 | Deduplicate immediately | Email |
| **SLV-ORD-001** | Orders missing order_number > 0 | Reject records | Email + Teams |
| **SLV-ORD-004** | Invalid amounts > 0 | Quarantine for review | Email + Teams |
| **SLV-INV-001** | Duplicate invoice numbers > 0 | **CRITICAL ALERT** to Finance | Email + Teams + SMS |
| **SLV-INV-002** | Invoice calculation errors > 0 | Recalculate, alert finance | Email + Teams |

### Warning Alerts (Monitor Closely)

| Rule | Alert Condition | Action | Notification |
|------|----------------|--------|--------------|
| **BRZ-004** | Late messages > 5% | Investigate Eventstream lag | Teams |
| **SLV-ORD-003** | Date inconsistencies > 0 | Correct data | Email |
| **SLV-SHP-002** | Unknown carriers > 1% | Update master data | Teams |
| **XLR-001** | Bronze-Silver variance > 5% | Check update policies | Email |

---

## 🛠️ Troubleshooting

### Issue: Quality Score Below 95%

**Investigation Steps:**
```kql
// 1. Check which rules are failing
FailedRulesDetails()

// 2. Check which dimension has issues
QualityScorecardByDimension()

// 3. Check specific table metrics
TableLevelQualityMetrics()
| where table_name == "idoc_invoices_silver"
```

### Issue: Critical Failures Detected

**Remediation Process:**

1. **Run Alert Query**
   ```kql
   DataQualityAlerts()
   ```

2. **Identify Root Cause**
   - Check source data in Bronze layer
   - Verify transformation logic in update policies
   - Review recent configuration changes

3. **Fix Based on Rule**
   - **BRZ-001**: Check Event Hub message format
   - **BRZ-003**: Investigate SAP source for duplicate sends
   - **SLV-INV-001**: Urgent - stop invoice processing, investigate billing system
   - **SLV-INV-002**: Recalculate totals, verify tax/discount logic

4. **Verify Fix**
   ```kql
   // Re-run validation after fix
   OverallQualityScore()
   ```

5. **Document Incident**
   - Record in `DataQualityHistory` table
   - Update runbook if new issue type

### Issue: Rules Not Executing

**Checklist:**
- ✅ KQL functions deployed to Eventhouse?
- ✅ Tables exist (`idoc_raw`, `idoc_*_silver`)?
- ✅ Permissions granted to execute queries?
- ✅ Scheduled job configured (Logic Apps)?
- ✅ Network connectivity to Eventhouse?

---

## 📈 Best Practices

### 1. Monitor Continuously
- Review `OverallQualityScore()` daily
- Check `DataQualityAlerts()` every hour (automated)
- Trend analysis weekly via `QualityTrend()`

### 2. Maintain Thresholds
- **Critical rules**: 0 failures allowed
- **High priority**: <1% failure rate
- **Medium priority**: <5% failure rate

### 3. Update Rules Regularly
- Review rules quarterly
- Add new rules as business evolves
- Retire obsolete rules

### 4. Document Everything
- Log all quality incidents
- Update remediation procedures
- Share insights with stakeholders

### 5. Integrate with CI/CD
- Run quality checks before deployment
- Fail deployments if critical rules fail
- Automate rollback if quality degrades

---

## 📚 Related Documentation

- [DATA-QUALITY-RULES.md](./DATA-QUALITY-RULES.md) - Complete rule definitions
- [governance/purview/README.md](./purview/README.md) - Purview setup guide
- [fabric/warehouse/schema/](../fabric/warehouse/schema/) - Table schemas

---

## 🔗 Quick Links

- **Purview Portal**: https://web.purview.azure.com/resource/stpurview
- **Data Product**: https://web.purview.azure.com/resource/stpurview/datagovernance/dataProducts/a4f24a45-3443-4f87-a46b-1d4b0b00dce4
- **Supply Chain Domain**: https://web.purview.azure.com/resource/stpurview/datagovernance/businessDomains/041de34f-62cf-4c8a-9a17-d1cc823e9538

---

## 📞 Support

**Data Quality Owner**: Data Engineering Team  
**Business Owner**: Supply Chain Analytics Team  
**Technical Contact**: Fabric/Purview Administrator

**Escalation Path:**
1. Data Engineering (quality rule failures)
2. Supply Chain Business Team (data consistency issues)
3. Finance Team (invoice-related critical alerts)

---

**Last Updated**: 2025-01-20  
**Version**: 1.0  
**Status**: Active
