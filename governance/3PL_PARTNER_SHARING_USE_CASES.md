# 3PL Partner Data Sharing - Use Cases & Implementation

## 🎯 Business Context

As a **Third-Party Logistics (3PL)** provider, we need to share operational data with external partners in a secure, governed manner. This document defines the B2B use cases and data sharing requirements.

---

## 👥 Partner Types & Data Access Requirements

### 1. **Logistics Carriers (Transport Partners)**
**Who:** DHL, FedEx, UPS, regional carriers  
**Need:** Real-time visibility into shipments assigned to them

**Required Data:**
- Shipment details (pickup/delivery locations, dates)
- Order references
- Package information (weight, volume, quantity)
- Delivery status updates
- SLA performance metrics

**Data Product View:** `partner_carrier_shipments`

---

### 2. **Warehouse Operators (3PL Partners)**
**Who:** External warehouse facilities  
**Need:** Inventory movements, inbound/outbound operations

**Required Data:**
- Warehouse movement transactions
- Material/SKU information
- Stock levels
- Receiving confirmations
- Productivity metrics

**Data Product View:** `partner_warehouse_operations`

---

### 3. **Customers (Shippers)**
**Who:** Companies using our 3PL services  
**Need:** Track their orders and shipments

**Required Data:**
- Order status (by customer)
- Shipment tracking
- Delivery confirmations
- Invoice summaries
- SLA compliance reports

**Data Product View:** `customer_portal_data`

---

## 📊 Partner Data Products (Gold Layer Extensions)

### ✅ Already Implemented (Current Gold Tables)

**Existing Gold Tables:**
1. `gold_orders_daily_summary` - ⚠️ Needs partner filtering
2. `gold_sla_performance` - ⚠️ Needs partner filtering
3. `gold_shipments_in_transit` - ⚠️ Needs partner filtering
4. `gold_warehouse_productivity_daily` - ⚠️ Needs partner filtering
5. `gold_revenue_recognition_realtime` - ❌ Internal only (not shared)

**Issue:** Current tables contain **ALL data** (multi-tenant), not filtered by partner.

---

## 🔧 Required Enhancements for Partner Sharing

### 1. Add Partner Context to Silver Tables

**Missing Columns in Current Schema:**
- `carrier_id` / `carrier_name` - Which transport partner handles the shipment
- `warehouse_partner_id` - External warehouse operator ID
- `customer_id` - Shipper/customer identifier
- `partner_access_scope` - Data visibility rules

**Action Required:** Enhance IDoc schemas to include partner identifiers.

---

### 2. Create Partner-Specific Gold Views

#### **A. Gold View: `gold_partner_carrier_shipments`**

**Purpose:** Data exposed to carrier partners (DHL, FedEx, etc.)

```sql
CREATE MATERIALIZED LAKE VIEW IF NOT EXISTS gold_partner_carrier_shipments
COMMENT 'Shipment data for external carrier partners - filtered by carrier_id'
PARTITIONED BY (shipment_date, carrier_id)
AS
SELECT 
    shipment_number,
    carrier_id,
    carrier_name,
    order_number,
    -- Exclude sensitive customer data
    -- customer_name → masked as 'Customer-XXX'
    CONCAT('Customer-', SUBSTRING(customer_id, 1, 3)) AS customer_reference,
    
    origin_location,
    destination_location,
    
    planned_ship_date,
    actual_ship_date,
    planned_delivery_date,
    actual_delivery_date,
    
    total_weight_kg,
    total_volume_m3,
    package_count,
    
    shipment_status,
    days_until_planned_delivery,
    days_delayed,
    
    -- SLA metrics
    CASE 
        WHEN actual_delivery_date <= planned_delivery_date THEN 'On-Time'
        ELSE 'Delayed'
    END AS delivery_performance,
    
    CAST(shipment_date AS DATE) AS shipment_date,
    processed_timestamp
    
FROM idoc_shipments_silver
WHERE carrier_id IS NOT NULL  -- Only shipments assigned to carriers
  AND shipment_status IN ('In Transit', 'Delivered', 'Picked Up')
;
```

**Data Masking:**
- ✅ Customer names masked
- ✅ Internal pricing hidden
- ✅ Only assigned shipments visible

---

#### **B. Gold View: `gold_partner_warehouse_operations`**

**Purpose:** Data exposed to warehouse partners

```sql
CREATE MATERIALIZED LAKE VIEW IF NOT EXISTS gold_partner_warehouse_operations
COMMENT 'Warehouse operations data for external warehouse partners'
PARTITIONED BY (movement_day, warehouse_partner_id)
AS
SELECT 
    warehouse_id,
    warehouse_partner_id,  -- External partner identifier
    
    material_id,
    material_description,
    
    movement_type,
    movement_date,
    CAST(movement_date AS DATE) AS movement_day,
    
    quantity,
    unit_of_measure,
    
    from_location,
    to_location,
    
    -- Exclude internal cost data
    -- movement_cost → not exposed
    
    operator_id,  -- Warehouse staff
    processing_time_minutes,
    
    sap_system,
    processed_timestamp
    
FROM idoc_warehouse_silver
WHERE warehouse_partner_id IS NOT NULL  -- Only partner warehouses
;
```

---

#### **C. Gold View: `gold_customer_portal_orders`**

**Purpose:** Customer self-service portal data

```sql
CREATE MATERIALIZED LAKE VIEW IF NOT EXISTS gold_customer_portal_orders
COMMENT 'Order and shipment data for customer portal access'
PARTITIONED BY (order_date, customer_id)
AS
SELECT 
    o.order_number,
    o.customer_id,
    o.customer_name,
    
    o.order_date,
    o.requested_delivery_date,
    o.order_status,
    o.order_value,
    
    -- Shipment tracking
    s.shipment_number,
    s.carrier_name,
    s.tracking_number,
    s.shipment_status,
    s.actual_ship_date,
    s.actual_delivery_date,
    
    -- SLA compliance
    o.sla_status,
    CASE 
        WHEN s.actual_delivery_date IS NOT NULL 
             AND s.actual_delivery_date <= o.requested_delivery_date 
        THEN 'On-Time'
        WHEN s.actual_delivery_date IS NOT NULL 
             AND s.actual_delivery_date > o.requested_delivery_date 
        THEN 'Delayed'
        ELSE 'Pending'
    END AS delivery_status,
    
    -- Exclude internal operations data
    -- warehouse_id, operator_id → not exposed to customers
    
    o.sap_system,
    o.processed_timestamp
    
FROM idoc_orders_silver o
LEFT JOIN idoc_shipments_silver s 
    ON o.order_number = s.order_number
WHERE o.customer_id IS NOT NULL
;
```

---

## 🔐 Data Governance & Access Control

### Row-Level Security (RLS) Requirements

**Implementation Options:**

1. **Fabric Lakehouse RLS** (if available in preview)
2. **GraphQL API with authentication** (recommended)
3. **Azure Synapse Serverless SQL** with RLS policies
4. **Power BI RLS** for reporting

**RLS Rules:**

```sql
-- Example: Carrier can only see their shipments
CREATE SECURITY POLICY carrier_access
ADD FILTER PREDICATE dbo.fn_carrier_access(carrier_id)
ON gold_partner_carrier_shipments;

-- Function checks authenticated user's carrier_id
CREATE FUNCTION fn_carrier_access(@carrier_id VARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_carrier_access_result
WHERE @carrier_id = USER_NAME();  -- Or from JWT token
```

---

## 📡 Data Sharing Mechanisms

### Option 1: **GraphQL API** (Recommended)
- ✅ Real-time access
- ✅ Fine-grained field-level security
- ✅ Authentication via Azure AD B2C
- ✅ Rate limiting per partner

**Architecture:**
```
Partner App → Azure API Management → GraphQL API → Fabric Lakehouse (Gold Views)
```

### Option 2: **Power BI Embedded**
- ✅ Pre-built dashboards for partners
- ✅ RLS enforced automatically
- ❌ Less flexible than API

### Option 3: **Azure Data Share** (Batch)
- ✅ Scheduled data exports
- ✅ Delta Lake snapshots
- ❌ Not real-time

### Option 4: **Fabric OneLake Shortcuts** (Advanced)
- ✅ Direct Delta Lake access
- ⚠️ Requires careful governance
- ✅ Best for trusted partners

---

## 🎯 Recommended Implementation Phases

### **Phase 1: Enhance Data Model** ✅ **START HERE**
1. Add partner identifier columns to IDoc schemas
   - `carrier_id` in shipments
   - `warehouse_partner_id` in warehouse movements
   - `customer_id` validation in orders
2. Regenerate Silver tables with new schema
3. Update EventStream to populate partner fields

### **Phase 2: Create Partner Gold Views** 
1. Create `gold_partner_carrier_shipments`
2. Create `gold_partner_warehouse_operations`
3. Create `gold_customer_portal_orders`
4. Document data dictionaries for each partner type

### **Phase 3: Implement Access Control**
1. Set up Azure AD B2C for partner authentication
2. Configure API Management with partner-specific subscriptions
3. Implement RLS or API-level filtering
4. Audit logging for compliance

### **Phase 4: GraphQL API Deployment**
1. Generate GraphQL schema from Gold views
2. Deploy API to Azure Container Apps / App Service
3. Configure authentication & authorization
4. Rate limiting and monitoring

### **Phase 5: Partner Onboarding**
1. API documentation (Swagger/OpenAPI)
2. Sample code (Python, JavaScript, C#)
3. Partner portal for API key management
4. SLA agreements and support

---

## 📋 Data Dictionary for Partners

### Carrier Partner Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `shipment_number` | string | Unique shipment ID | SHP-2025-001234 |
| `carrier_id` | string | Your carrier identifier | CARRIER-DHL |
| `order_number` | string | Reference order | ORD-2025-005678 |
| `customer_reference` | string | Masked customer ID | Customer-ABC |
| `origin_location` | string | Pickup address | Chicago, IL |
| `destination_location` | string | Delivery address | New York, NY |
| `planned_delivery_date` | date | Target delivery | 2025-10-30 |
| `actual_delivery_date` | date | Actual delivery | 2025-10-29 |
| `delivery_performance` | string | On-Time / Delayed | On-Time |

---

## 🔍 Missing Data - Action Items

### **Current Schema Gaps:**

❌ **Missing in `idoc_shipments_silver`:**
- `carrier_id` - Which carrier handles this shipment
- `carrier_name` - Carrier company name
- `tracking_number` - Carrier's tracking number
- `customer_id` - Link to customer

❌ **Missing in `idoc_warehouse_silver`:**
- `warehouse_partner_id` - External warehouse operator
- `material_description` - SKU description

❌ **Missing in `idoc_orders_silver`:**
- `customer_name` - Customer company name

**Solution:** Update IDoc generator schemas to include these fields.

---

## ✅ Next Steps

1. **Review and approve partner data sharing requirements**
2. **Update IDoc schemas** to include partner identifiers
3. **Create partner-specific Gold views** with data masking
4. **Implement authentication** (Azure AD B2C)
5. **Deploy GraphQL API** for real-time access
6. **Update Purview Business Domain** with B2B classification
7. **Create Data Product** with partner access policies

---

## 📞 Questions to Address

1. **Which carriers** should be onboarded first? (DHL, FedEx, UPS?)
2. **Authentication method:** API keys vs OAuth 2.0 vs Azure AD B2C?
3. **Real-time** (GraphQL) or **batch** (daily exports)?
4. **SLA** for partner API availability? (99.9%?)
5. **Rate limits** per partner? (e.g., 1000 req/min)

---

**Document Version:** 1.0  
**Last Updated:** October 28, 2025  
**Owner:** Operations & Supply Chain Team
