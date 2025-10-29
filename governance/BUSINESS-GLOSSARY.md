# 3PL Business Glossary - Standardized Terminology

**Data Product:** 3PL Real-Time Analytics  
**Domain:** Supply Chain & Logistics  
**Last Updated:** 2025-10-27  
**Glossary Owner:** Data Governance Team

---

## Business Entities

### Order

**Term:** Order  
**Definition:** A customer's request for goods or services to be fulfilled by the 3PL provider  
**Synonyms:** Purchase Order, PO, Sales Order  
**Business Owner:** Order Fulfillment Manager  
**Technical Owner:** Orders Silver Table (`idoc_orders_silver`)  
**Related Terms:** Customer, Order Line, Shipment  
**Business Rules:**
- Must have unique order number
- Must reference valid customer
- Cannot be deleted after shipment
- SLA timer starts at order creation

**Example Usage:** "Order #12345 was created on 2025-10-24 with SLA target of 24 hours for shipment"

---

### Shipment

**Term:** Shipment  
**Definition:** The physical movement of goods from origin warehouse to customer destination  
**Synonyms:** Delivery, Consignment, Transport  
**Business Owner:** Transportation Manager  
**Technical Owner:** Shipments Silver Table (`idoc_shipments_silver`)  
**Related Terms:** Order, Carrier, Tracking Number  
**Business Rules:**
- Must reference one or more orders
- Tracking number must be unique
- Cannot modify after delivery confirmation
- Must have valid carrier assignment

**Example Usage:** "Shipment #SHP-001 is in transit with carrier FedEx, estimated delivery tomorrow"

---

### Warehouse Movement

**Term:** Warehouse Movement  
**Definition:** Any transaction that changes inventory location or status within warehouse operations  
**Synonyms:** Inventory Transaction, Material Movement, Stock Transaction  
**Business Owner:** Warehouse Operations Manager  
**Technical Owner:** Warehouse Silver Table (`idoc_warehouse_silver`)  
**Related Terms:** Warehouse, Location, Operator, Material  
**Business Rules:**
- Must have valid movement type (GR, GI, Transfer, Count)
- Must specify warehouse and location
- Requires operator assignment
- Cannot be reversed after 24 hours

**Example Usage:** "Warehouse movement #WM-5678 recorded goods receipt of 100 units to location A-12-03"

---

### Invoice

**Term:** Invoice  
**Definition:** Financial billing document requesting payment for 3PL services rendered  
**Synonyms:** Bill, Charge, Billing Document  
**Business Owner:** Finance Manager  
**Technical Owner:** Invoices Silver Table (`idoc_invoices_silver`)  
**Related Terms:** Customer, Payment, Aging Bucket  
**Business Rules:**
- Must reference delivered order/shipment
- Immutable after 30 days (SOX compliance)
- Payment terms: Net 30 days
- Must include tax calculation

**Example Usage:** "Invoice #INV-2024-001 for $5,000 is 15 days overdue (aging bucket: 1-30 days)"

---

## Business Processes

### Order Fulfillment

**Term:** Order Fulfillment  
**Definition:** Complete process from order receipt to delivery confirmation  
**Process Steps:**
1. Order Receipt & Validation
2. Order Confirmation
3. Warehouse Picking & Packing
4. Shipment Creation
5. Transportation
6. Delivery Confirmation

**KPIs:**
- Order Processing Time (target: <24h)
- Order Accuracy (target: 99.5%)
- Customer Satisfaction (target: 4.5/5)

**Owner:** COO  
**Related Systems:** SAP ERP, WMS, TMS

---

### Order-to-Cash

**Term:** Order-to-Cash (O2C)  
**Definition:** End-to-end business process from order placement to payment collection  
**Process Steps:**
1. Order Entry
2. Order Fulfillment
3. Shipping & Delivery
4. Invoice Generation
5. Payment Collection

**KPIs:**
- Cycle Time (target: <45 days)
- Days Sales Outstanding / DSO (target: <35 days)
- Cash Collection Rate (target: >95%)

**Owner:** CFO  
**Related Terms:** Order, Invoice, Payment

---

## Key Performance Indicators (KPIs)

### SLA Compliance %

**Term:** SLA Compliance Percentage  
**Definition:** Percentage of orders shipped within service level agreement timeframe  
**Formula:** (Orders shipped within SLA / Total orders) × 100  
**Unit:** Percentage (%)  
**Target:** ≥95%  
**Measurement Frequency:** Daily  
**Business Meaning:** Measures operational efficiency in meeting client commitments  
**Owner:** Order Fulfillment Manager  
**Data Source:** `sla_performance` materialized view

---

### On-Time Delivery %

**Term:** On-Time Delivery Rate  
**Definition:** Percentage of shipments delivered by promised delivery date  
**Formula:** (Shipments delivered on time / Total shipments) × 100  
**Unit:** Percentage (%)  
**Target:** ≥92%  
**Measurement Frequency:** Daily  
**Business Meaning:** Measures transportation reliability and customer experience  
**Owner:** Transportation Manager  
**Data Source:** `idoc_shipments_silver` table

---

### Warehouse Productivity

**Term:** Warehouse Productivity  
**Definition:** Number of warehouse movements processed per labor hour  
**Formula:** Total movements / Total labor hours  
**Unit:** Transactions per Hour (Txn/Hr)  
**Target:** ≥45 txn/hr  
**Measurement Frequency:** Shift-based  
**Business Meaning:** Measures operational efficiency of warehouse staff  
**Owner:** Warehouse Operations Manager  
**Data Source:** `warehouse_productivity` materialized view

---

### Days Sales Outstanding (DSO)

**Term:** Days Sales Outstanding  
**Definition:** Average number of days to collect payment after invoice date  
**Formula:** (Accounts Receivable / Total Credit Sales) × Number of Days  
**Unit:** Days  
**Target:** <35 days  
**Measurement Frequency:** Monthly  
**Business Meaning:** Measures cash flow efficiency and credit risk  
**Owner:** Finance Manager  
**Data Source:** `revenue_realtime` materialized view

---

## Data Quality Dimensions

### Completeness

**Term:** Data Completeness  
**Definition:** Extent to which all required data elements are populated  
**Measurement:** % of records with no missing critical fields  
**Target:** 100% for mandatory fields  
**Critical Fields:** Order number, customer, dates, amounts  
**Owner:** Data Quality Team

---

### Accuracy

**Term:** Data Accuracy  
**Definition:** Degree to which data values match the real-world entities they represent  
**Measurement:** % of records passing validation rules  
**Target:** ≥99%  
**Validation Rules:** Valid status codes, positive amounts, valid date ranges  
**Owner:** Data Quality Team

---

### Timeliness

**Term:** Data Timeliness  
**Definition:** Delay between real-world event occurrence and data availability  
**Measurement:** Latency from SAP event to Gold layer  
**Target:** <5 minutes (P95)  
**Business Impact:** Real-time decision making capability  
**Owner:** Platform Engineering

---

## Technical Terms

### IDoc (Intermediate Document)

**Term:** IDoc  
**Definition:** SAP's proprietary data exchange format for asynchronous communication  
**Message Types:** ORDERS05, SHPMNT05, DESADV01, WHSCON01, INVOIC02  
**Structure:** Control record + Data segments  
**Transport:** Azure Event Hubs (JSON format)  
**Owner:** IT Integration Team

---

### Medallion Architecture

**Term:** Medallion Architecture  
**Definition:** Data lakehouse design pattern with Bronze (raw), Silver (cleansed), Gold (aggregated) layers  
**Purpose:** Progressive data refinement from raw to business-ready  
**Implementation:** Fabric Eventhouse with KQL  
**Layers:**
- Bronze: `idoc_raw` (raw IDocs)
- Silver: Cleansed business entities (4 tables)
- Gold: Pre-aggregated KPIs (5 materialized views)

**Owner:** Data Engineering Team

---

### Materialized View

**Term:** Materialized View  
**Definition:** Pre-computed query result stored as physical table for fast access  
**Purpose:** Optimize query performance for dashboards and APIs  
**Refresh:** Real-time (continuous aggregation)  
**Use Case:** Serve <100ms API responses from Gold layer  
**Owner:** Data Engineering Team

---

### Update Policy

**Term:** Update Policy  
**Definition:** Automated data transformation rule triggered on data ingestion  
**Purpose:** Real-time Bronze → Silver transformation  
**Implementation:** KQL functions applied automatically  
**Latency:** <3 seconds  
**Owner:** Data Engineering Team

---

## Status Codes

### Order Status

**Values:**
- `Pending`: Order received, awaiting confirmation
- `Confirmed`: Order validated and accepted
- `Processing`: Warehouse picking in progress
- `Shipped`: Order dispatched to customer
- `Delivered`: Customer received goods
- `Cancelled`: Order cancelled before shipment

**Business Rules:**
- Cannot cancel after shipment
- Can only move forward in status lifecycle
- Delivered status requires proof of delivery

---

### SLA Status

**Values:**
- `Good`: Shipped within 24h of order creation (0-20h elapsed)
- `At Risk`: Approaching SLA limit (20-24h elapsed)
- `Breached`: Exceeded 24h SLA (>24h elapsed)

**Business Rules:**
- SLA clock starts at order creation timestamp
- SLA stops when actual ship date is recorded
- Breached status cannot be reversed

---

### Payment Status

**Values:**
- `Pending`: Invoice sent, payment not yet received
- `Partial`: Partial payment received
- `Paid`: Full payment received
- `Overdue`: Payment past due date
- `Written Off`: Uncollectible debt

**Business Rules:**
- Status auto-updates based on payment transactions
- Overdue if no payment by due_date + grace period (7 days)
- Write-off requires finance approval

---

### Shipment Status

**Values:**
- `Preparing`: Warehouse packing in progress
- `Ready to Ship`: Packed and awaiting carrier pickup
- `In Transit`: With carrier, en route to customer
- `Out for Delivery`: Final mile delivery in progress
- `Delivered`: Successfully delivered to customer
- `Exception`: Delivery issue (damage, refused, etc.)

**Business Rules:**
- In Transit requires tracking number
- Exception status requires reason code
- Delivered requires signature (optional)

---

## Aging Buckets

### Invoice Aging

**Definition:** Classification of invoices by number of days overdue

**Buckets:**
- **Current**: 0 days overdue (within payment terms)
- **1-30 Days**: 1-30 days past due date
- **31-60 Days**: 31-60 days past due date
- **61-90 Days**: 61-90 days past due date
- **90+ Days**: More than 90 days past due date

**Business Impact:**
- Current: Healthy cash flow
- 1-30: Routine follow-up
- 31-60: Escalation to account manager
- 61-90: Collection agency warning
- 90+: Legal action considered

**Owner:** Finance Manager

---

## Business Units & Roles

### 3PL Provider

**Term:** Third-Party Logistics Provider  
**Definition:** Company providing outsourced logistics services (warehousing, transportation, fulfillment)  
**Abbreviation:** 3PL  
**Services Offered:** Order fulfillment, warehouse management, transportation, value-added services  
**Clients:** E-commerce, retail, manufacturing companies

---

### Roles

#### Order Fulfillment Manager
**Responsibilities:**
- Monitor order SLA compliance
- Optimize fulfillment processes
- Resolve order exceptions

**KPI Ownership:** SLA Compliance %, Order Accuracy

---

#### Transportation Manager
**Responsibilities:**
- Manage carrier relationships
- Optimize routing and scheduling
- Track on-time delivery performance

**KPI Ownership:** On-Time Delivery %, Transit Time

---

#### Warehouse Operations Manager
**Responsibilities:**
- Manage warehouse staff and productivity
- Optimize warehouse layout and processes
- Ensure inventory accuracy

**KPI Ownership:** Warehouse Productivity, Inventory Accuracy

---

#### Finance Manager
**Responsibilities:**
- Generate and send invoices
- Monitor accounts receivable
- Manage cash collection

**KPI Ownership:** DSO, Cash Collection Rate

---

## Compliance & Governance

### GDPR (General Data Protection Regulation)

**Term:** GDPR  
**Definition:** EU regulation on data protection and privacy  
**Impact on Data Product:**
- Customer PII (name, address) must support right to erasure
- Data subject access requests within 30 days
- Consent required for data processing

**Compliance Owner:** Legal & Compliance Team

---

### SOX (Sarbanes-Oxley Act)

**Term:** SOX  
**Definition:** US regulation for financial reporting accuracy  
**Impact on Data Product:**
- Invoice data must be immutable after 30 days
- Audit trail required for all financial transactions
- Internal controls for data access

**Compliance Owner:** Finance & Audit Team

---

## Glossary Governance

### Change Management

**Process:**
1. Propose new term or change existing definition
2. Review by domain expert
3. Approval by glossary owner
4. Update glossary document
5. Notify stakeholders

**Approval Required From:**
- Domain Expert (business validation)
- Data Governance Team (consistency check)
- Technical Owner (implementation feasibility)

---

### Review Cycle

**Frequency:** Quarterly  
**Next Review:** 2025-11-27  
**Participants:** All business owners + data governance team

**Review Checklist:**
- ✅ New terms added
- ✅ Deprecated terms marked
- ✅ Definitions still accurate
- ✅ Owners still valid
- ✅ Technical mappings current

---

**Document Version:** 1.0  
**Status:** Active  
**Format:** Markdown  
**Location:** `governance/BUSINESS-GLOSSARY.md`
