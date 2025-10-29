# Data Quality Rules - 3PL Real-Time Analytics

**Data Product:** 3PL Real-Time Analytics  
**Owner:** Data Quality Team  
**Last Updated:** 2025-10-27  
**Review Cycle:** Monthly

---

## 1. Data Quality Framework

### 1.1 Quality Dimensions

| Dimension | Definition | Target | Priority |
|-----------|------------|--------|----------|
| **Completeness** | All required fields populated | 100% | Critical |
| **Accuracy** | Data values match reality | 99% | Critical |
| **Consistency** | Data is consistent across systems | 100% | High |
| **Timeliness** | Data available within SLA | 95% (<5min) | High |
| **Uniqueness** | No duplicate records | 100% | Critical |
| **Validity** | Data conforms to business rules | 99% | High |

---

## 2. Bronze Layer Quality Rules

### 2.1 idoc_raw Table

#### Rule BRZ-001: Message Structure Completeness
**Dimension:** Completeness  
**Description:** Every IDoc message must have control and data segments  
**Validation:**
```kql
idoc_raw
| where isnull(control) or isnull(data)
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Alert data engineering team  
**Business Impact:** Cannot process messages without structure

---

#### Rule BRZ-002: Message Type Validity
**Dimension:** Validity  
**Description:** Message type must be in allowed list  
**Validation:**
```kql
idoc_raw
| where message_type !in ('ORDERS', 'SHPMNT', 'DESADV', 'WHSCON', 'INVOIC')
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Quarantine message, investigate source  
**Business Impact:** Unknown message types cannot be processed

---

#### Rule BRZ-003: IDoc Number Uniqueness
**Dimension:** Uniqueness  
**Description:** Each IDoc number must be unique  
**Validation:**
```kql
idoc_raw
| summarize count() by idoc_number
| where count_ > 1
| summarize duplicate_count = count()
```
**Target:** 0 duplicates  
**Action on Failure:** Deduplicate, keep first occurrence  
**Business Impact:** Duplicate processing causes data inflation

---

#### Rule BRZ-004: Ingestion Timeliness
**Dimension:** Timeliness  
**Description:** Messages ingested within 30 seconds of Event Hub receipt  
**Validation:**
```kql
idoc_raw
| extend latency_seconds = datetime_diff('second', ingestion_time(), todatetime(timestamp))
| where latency_seconds > 30
| summarize late_count = count(), max_latency = max(latency_seconds)
```
**Target:** <5% late messages  
**Action on Failure:** Investigate Eventstream lag  
**Business Impact:** Real-time SLA degradation

---

## 3. Silver Layer Quality Rules

### 3.1 idoc_orders_silver Table

#### Rule SLV-ORD-001: Order Number Mandatory
**Dimension:** Completeness  
**Description:** Every order must have an order number  
**Validation:**
```kql
idoc_orders_silver
| where isempty(order_number) or isnull(order_number)
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Reject record, alert business team  
**Business Impact:** Cannot track or reference orders

---

#### Rule SLV-ORD-002: Customer ID Mandatory
**Dimension:** Completeness  
**Description:** Every order must reference a customer  
**Validation:**
```kql
idoc_orders_silver
| where isempty(customer_id) or isnull(customer_id)
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Reject record  
**Business Impact:** Cannot attribute revenue or fulfill orders

---

#### Rule SLV-ORD-003: Date Consistency
**Dimension:** Consistency  
**Description:** Requested delivery date must be after order date  
**Validation:**
```kql
idoc_orders_silver
| where requested_delivery_date <= order_date
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Correct data, alert business  
**Business Impact:** Illogical business logic

---

#### Rule SLV-ORD-004: Amount Validity
**Dimension:** Validity  
**Description:** Total amount must be positive  
**Validation:**
```kql
idoc_orders_silver
| where total_amount <= 0
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Quarantine order, manual review  
**Business Impact:** Financial reporting errors

---

#### Rule SLV-ORD-005: SLA Status Accuracy
**Dimension:** Accuracy  
**Description:** SLA status must match calculated order age  
**Validation:**
```kql
idoc_orders_silver
| extend calculated_sla = case(
    order_age_hours <= 20, "Good",
    order_age_hours <= 24, "At Risk",
    "Breached"
)
| where sla_status != calculated_sla
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Recalculate SLA status  
**Business Impact:** Incorrect performance reporting

---

### 3.2 idoc_shipments_silver Table

#### Rule SLV-SHP-001: Shipment Number Uniqueness
**Dimension:** Uniqueness  
**Description:** Each shipment number must be unique  
**Validation:**
```kql
idoc_shipments_silver
| summarize count() by shipment_number
| where count_ > 1
| summarize duplicate_count = count()
```
**Target:** 0 duplicates  
**Action on Failure:** Deduplicate, alert IT  
**Business Impact:** Double-counting shipments

---

#### Rule SLV-SHP-002: Carrier Code Validity
**Dimension:** Validity  
**Description:** Carrier code must be in master data  
**Validation:**
```kql
let valid_carriers = datatable(carrier_code:string) ["FEDEX", "UPS", "DHL", "USPS", "XPO"];
idoc_shipments_silver
| where carrier_code !in (valid_carriers)
| summarize failed_count = count()
```
**Target:** <1% failures (allows new carriers)  
**Action on Failure:** Alert transportation team to update master data  
**Business Impact:** Cannot track carrier performance

---

#### Rule SLV-SHP-003: In-Transit Logic
**Dimension:** Accuracy  
**Description:** Shipment is in transit only if shipped but not delivered  
**Validation:**
```kql
idoc_shipments_silver
| where is_in_transit == true and (isnull(actual_ship_date) or isnotnull(actual_delivery_date))
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Recalculate is_in_transit flag  
**Business Impact:** Incorrect inventory status

---

#### Rule SLV-SHP-004: Transit Time Reasonableness
**Dimension:** Validity  
**Description:** Transit time must be between 0 and 720 hours (30 days)  
**Validation:**
```kql
idoc_shipments_silver
| where transit_time_hours < 0 or transit_time_hours > 720
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Investigate date calculation logic  
**Business Impact:** Performance metrics unreliable

---

### 3.3 idoc_warehouse_silver Table

#### Rule SLV-WHS-001: Movement Type Validity
**Dimension:** Validity  
**Description:** Movement type must be GR, GI, Transfer, or Count  
**Validation:**
```kql
idoc_warehouse_silver
| where movement_type !in ('GR', 'GI', 'Transfer', 'Count')
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Reject record, alert warehouse  
**Business Impact:** Cannot classify inventory transactions

---

#### Rule SLV-WHS-002: Quantity Positivity
**Dimension:** Validity  
**Description:** Quantity must be positive  
**Validation:**
```kql
idoc_warehouse_silver
| where quantity <= 0
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Correct data, investigate source  
**Business Impact:** Inventory accuracy compromised

---

#### Rule SLV-WHS-003: Location Hierarchy
**Dimension:** Consistency  
**Description:** Location must have zone, aisle, shelf, bin structure  
**Validation:**
```kql
idoc_warehouse_silver
| where isempty(zone) or isempty(aisle) or isempty(shelf) or isempty(bin_location)
| summarize failed_count = count()
```
**Target:** <5% failures (allows flexible locations)  
**Action on Failure:** Alert warehouse to update locations  
**Business Impact:** Cannot optimize warehouse layout

---

#### Rule SLV-WHS-004: Processing Time Reasonableness
**Dimension:** Validity  
**Description:** Processing time must be between 1 and 480 minutes (8 hours)  
**Validation:**
```kql
idoc_warehouse_silver
| where processing_time_minutes < 1 or processing_time_minutes > 480
| summarize failed_count = count()
```
**Target:** <1% failures  
**Action on Failure:** Flag for manual review  
**Business Impact:** Productivity metrics skewed

---

### 3.4 idoc_invoices_silver Table

#### Rule SLV-INV-001: Invoice Number Uniqueness
**Dimension:** Uniqueness  
**Description:** Each invoice number must be unique  
**Validation:**
```kql
idoc_invoices_silver
| summarize count() by invoice_number
| where count_ > 1
| summarize duplicate_count = count()
```
**Target:** 0 duplicates  
**Action on Failure:** Critical alert to finance, investigate double-billing  
**Business Impact:** Financial reporting errors, client disputes

---

#### Rule SLV-INV-002: Amount Calculations
**Dimension:** Accuracy  
**Description:** Total amount must equal subtotal + tax - discount + shipping  
**Validation:**
```kql
idoc_invoices_silver
| extend calculated_total = subtotal_amount + tax_amount - discount_amount + shipping_charges
| where abs(total_amount - calculated_total) > 0.01
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Recalculate totals, alert finance  
**Business Impact:** Revenue mis-statement

---

#### Rule SLV-INV-003: Aging Bucket Consistency
**Dimension:** Consistency  
**Description:** Aging bucket must match days overdue  
**Validation:**
```kql
idoc_invoices_silver
| extend calculated_bucket = case(
    days_overdue <= 0, "Current",
    days_overdue <= 30, "1-30",
    days_overdue <= 60, "31-60",
    days_overdue <= 90, "61-90",
    "90+"
)
| where aging_bucket != calculated_bucket
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Recalculate aging buckets  
**Business Impact:** Cash flow management impaired

---

#### Rule SLV-INV-004: Payment Efficiency Range
**Dimension:** Validity  
**Description:** Payment efficiency must be between 0 and 200%  
**Validation:**
```kql
idoc_invoices_silver
| where payment_efficiency < 0 or payment_efficiency > 200
| summarize failed_count = count()
```
**Target:** 0 failures  
**Action on Failure:** Investigate calculation logic  
**Business Impact:** Performance metrics unreliable

---

## 4. Gold Layer Quality Rules

### 4.1 Materialized Views

#### Rule GLD-001: View Freshness
**Dimension:** Timeliness  
**Description:** Materialized views must refresh within 5 minutes  
**Validation:**
```kql
.show materialized-views
| extend age_minutes = datetime_diff('minute', now(), MaterializedTo)
| where age_minutes > 5
| summarize stale_views = count()
```
**Target:** 0 stale views  
**Action on Failure:** Alert platform engineering, investigate backlog  
**Business Impact:** API serves outdated data

---

#### Rule GLD-002: Data Completeness
**Dimension:** Completeness  
**Description:** Gold views must have data for current day  
**Validation:**
```kql
union
    (orders_daily_summary | where order_date == startofday(now()) | summarize has_orders = count() > 0),
    (sla_performance | where performance_date == startofday(now()) | summarize has_sla = count() > 0)
| summarize all_current = min1(has_orders, has_sla)
```
**Target:** all_current = true  
**Action on Failure:** Investigate source data availability  
**Business Impact:** Dashboards show incomplete picture

---

## 5. Cross-Layer Validation

### Rule XLR-001: Bronze to Silver Reconciliation
**Dimension:** Consistency  
**Description:** Silver row count must match Bronze (accounting for deduplication)  
**Validation:**
```kql
let bronze_orders = idoc_raw | where message_type == 'ORDERS' | summarize count();
let silver_orders = idoc_orders_silver | summarize count();
print variance_pct = (todouble(silver_orders) - todouble(bronze_orders)) / todouble(bronze_orders) * 100
| where abs(variance_pct) > 5
```
**Target:** <5% variance  
**Action on Failure:** Investigate update policy failures  
**Business Impact:** Data loss in transformation

---

### Rule XLR-002: Silver to Gold Reconciliation
**Dimension:** Consistency  
**Description:** Gold aggregates must match Silver detail  
**Validation:**
```kql
let silver_total = idoc_orders_silver | summarize sum(total_amount);
let gold_total = orders_daily_summary | summarize sum(total_order_value);
print variance_pct = (todouble(gold_total) - todouble(silver_total)) / todouble(silver_total) * 100
| where abs(variance_pct) > 0.1
```
**Target:** <0.1% variance  
**Action on Failure:** Investigate materialized view refresh  
**Business Impact:** Incorrect KPI reporting

---

## 6. Monitoring & Alerting

### 6.1 Quality Dashboard

**KQL Query for Quality Dashboard:**
```kql
let quality_checks = datatable(rule:string, dimension:string, target:real, actual:real, status:string)
[
    "BRZ-001", "Completeness", 0, 0, "Pass",
    "BRZ-002", "Validity", 0, 0, "Pass",
    "SLV-ORD-001", "Completeness", 0, 0, "Pass",
    // ... all rules
];
quality_checks
| extend health = case(
    actual <= target, "Healthy",
    actual <= target * 1.1, "Warning",
    "Critical"
)
| summarize 
    healthy = countif(health == "Healthy"),
    warnings = countif(health == "Warning"),
    critical = countif(health == "Critical")
    by dimension
```

### 6.2 Alert Thresholds

| Severity | Condition | Action | Recipients |
|----------|-----------|--------|------------|
| **Critical** | Any uniqueness violation | Immediate alert | Data Engineering + Business Owner |
| **High** | >5% completeness failures | Alert within 15 min | Data Quality Team |
| **Medium** | Timeliness SLA breach | Alert within 1 hour | Platform Engineering |
| **Low** | Validity warnings | Daily digest | Data Stewards |

---

## 7. Remediation Procedures

### 7.1 Completeness Failures
1. Identify missing fields
2. Check if data exists in Bronze
3. If Bronze has data: Fix extraction function
4. If Bronze missing: Contact SAP integration team
5. Backfill corrected data

### 7.2 Uniqueness Violations
1. Identify duplicate records
2. Determine root cause (duplicate sends vs processing)
3. Keep first occurrence by ingestion timestamp
4. Delete duplicates
5. Prevent recurrence (idempotency checks)

### 7.3 Timeliness Issues
1. Check Eventstream lag
2. Check Eventhouse ingestion queue
3. Check update policy execution time
4. Scale resources if needed
5. Monitor recovery

---

## 8. Data Quality Ownership

| Layer | Primary Owner | Backup Owner | Escalation |
|-------|---------------|--------------|------------|
| **Bronze** | Data Engineering | Platform Engineering | VP Engineering |
| **Silver** | Data Quality Team | Business Domain Owners | Director of Analytics |
| **Gold** | Data Quality Team | BI Team | Director of Analytics |
| **Cross-Layer** | Data Governance Team | Data Engineering | CDO |

---

## 9. Quality Metrics

### 9.1 KPIs

| Metric | Formula | Target | Frequency |
|--------|---------|--------|-----------|
| **Data Quality Score** | (Passed rules / Total rules) × 100 | ≥99% | Daily |
| **Critical Failures** | Count of critical severity failures | 0 | Real-time |
| **Mean Time to Detect (MTTD)** | Avg time from failure to alert | <15 min | Weekly |
| **Mean Time to Resolve (MTTR)** | Avg time from alert to fix | <2 hours | Weekly |

---

## 10. Continuous Improvement

### 10.1 Rule Review Process

**Monthly Review:**
- Analyze rule violation trends
- Identify new data quality risks
- Propose new rules or update thresholds
- Deprecate obsolete rules

**Quarterly Deep Dive:**
- Review rule effectiveness (false positives/negatives)
- Benchmark against industry standards
- Update remediation procedures
- Train stakeholders on new rules

---

**Document Status:** Active  
**Version:** 1.0  
**Next Review:** 2025-11-27
