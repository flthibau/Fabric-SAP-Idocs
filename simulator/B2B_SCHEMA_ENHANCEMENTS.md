# B2B Schema Enhancements - Implementation Summary

**Date:** 2025-01-27  
**Status:** ✅ Complete - All IDoc schemas and master data generators enhanced

---

## Overview

All IDoc schemas and master data generators have been enhanced to support **B2B (Business-to-Business) partner sharing** for 3PL logistics operations. The enhancements enable Row-Level Security (RLS) filtering for external partners including carriers, warehouse operators, and customers.

---

## Partner Types & Access Patterns

### 1. Carriers (DHL, FedEx, UPS, etc.)
**Access Requirements:**
- View only shipments assigned to them
- Track deliveries they are responsible for
- See customer delivery addresses (but NOT customer company names for privacy)

**RLS Filter:**
```sql
WHERE carrier_id = USER_CLAIM('carrier_id')
```

### 2. Warehouse Operators (External 3PL Partners)
**Access Requirements:**
- View only operations at their partner warehouse
- Track inventory movements they handle
- See productivity metrics (but NOT cost data)

**RLS Filter:**
```sql
WHERE warehouse_partner_id = USER_CLAIM('warehouse_partner_id')
```

### 3. Customers (Shippers)
**Access Requirements:**
- View only their own orders and shipments
- Track order status and delivery progress
- Access their invoices

**RLS Filter:**
```sql
WHERE customer_id = USER_CLAIM('customer_id')
```

---

## Schema Changes by IDoc Type

### 1. SHPMNT (Shipment Tracking) ✅

**File:** `simulator/src/idoc_schemas/shpmnt_schema.py`

**New Fields Added:**
```python
# E1SHP00 - Shipment header
{
    # ... existing fields ...
    
    # B2B Partner Fields
    "carrier_id": "CARRIER-DHL",           # Carrier identifier
    "carrier_name": "DHL Express",          # Carrier company name
    "customer_id": "CUST-001",              # Customer identifier
    "customer_name": "Acme Manufacturing Co", # Customer company name
    "partner_access_scope": "CARRIER_CUSTOMER" # RLS policy scope
}
```

**Use Cases:**
- Carrier portal: Filter by `carrier_id` to show only their shipments
- Customer portal: Filter by `customer_id` to show order tracking
- Data masking: Hide `customer_name` from carrier views for privacy

---

### 2. ORDERS (Purchase/Sales Orders) ✅

**File:** `simulator/src/idoc_schemas/orders_schema.py`

**New Fields Added:**
```python
# E1EDK01 - Document header
{
    # ... existing fields ...
    
    # B2B Partner Fields
    "customer_id": "CUST-001",              # Customer identifier
    "customer_name": "Acme Manufacturing Co", # Customer company name
    "partner_access_scope": "CUSTOMER"       # RLS policy scope
}
```

**Use Cases:**
- Customer self-service portal: View only their orders
- Order status tracking per customer
- Customer-specific analytics dashboards

---

### 3. WHSCON (Warehouse Confirmations) ✅

**File:** `simulator/src/idoc_schemas/whscon_schema.py`

**New Fields Added:**
```python
# E1WHC00 - Confirmation header
{
    # ... existing fields ...
    
    # B2B Partner Fields
    "warehouse_partner_id": "PARTNER-WH003",      # External warehouse partner ID
    "warehouse_partner_name": "LogiTech Warehousing", # Partner company name
    "partner_access_scope": "WAREHOUSE_PARTNER"   # RLS policy scope
}
```

**Use Cases:**
- Partner warehouse dashboard: Show only their facility operations
- Partner productivity metrics (excluding cost data)
- Multi-tenant warehouse operations tracking

---

### 4. DESADV (Dispatch Advice / ASN) ✅

**File:** `simulator/src/idoc_schemas/desadv_schema.py`

**New Fields Added:**
```python
# E1EDK01 - Document header
{
    # ... existing fields ...
    
    # B2B Partner Fields
    "carrier_id": "CARRIER-FEDEX",          # Carrier identifier
    "carrier_name": "FedEx Ground",          # Carrier company name
    "customer_id": "CUST-002",              # Customer identifier
    "customer_name": "Global Retail Inc",    # Customer company name
    "partner_access_scope": "CARRIER_CUSTOMER" # RLS policy scope
}
```

**Use Cases:**
- Advance shipping notices for carriers
- Customer delivery notifications
- Cross-docking coordination with carriers

---

### 5. INVOICE (Billing Documents) ✅

**File:** `simulator/src/idoc_schemas/invoice_schema.py`

**New Fields Added:**
```python
# E1EDK01 - Document header
{
    # ... existing fields ...
    
    # B2B Partner Fields
    "customer_id": "CUST-001",              # Customer identifier
    "customer_name": "Acme Manufacturing Co", # Customer company name
    "partner_access_scope": "CUSTOMER"       # RLS policy scope
}
```

**Use Cases:**
- Customer invoice portal (self-service billing)
- Accounts receivable per customer
- Customer payment tracking

---

## Master Data Generator Enhancements

### Warehouses ✅

**File:** `simulator/src/utils/data_generator.py`

**Changes:**
```python
def _generate_warehouses(self):
    """Generate warehouse master data with partner information"""
    warehouses = [
        {
            "warehouse_id": "WH001",
            "name": "Chicago Distribution Center",
            "city": "Chicago",
            # ... location fields ...
            
            # B2B Partner Fields (warehouses WH003-WH005 are partner-operated)
            "partner_id": "",  # Empty for owned warehouses (WH001, WH002)
            "partner_name": "",
            "is_partner_operated": False
        },
        {
            "warehouse_id": "WH003",
            "name": "Los Angeles Distribution Center",
            "city": "Los Angeles",
            
            # B2B Partner Fields
            "partner_id": "PARTNER-WH003",
            "partner_name": "LogiTech Warehousing",
            "is_partner_operated": True  # External partner
        }
    ]
```

**Partner Warehouse Names:**
- `PARTNER-WH003`: LogiTech Warehousing (Los Angeles)
- `PARTNER-WH004`: Premier Logistics Partners (Dallas)
- `PARTNER-WH005`: Strategic Distribution Inc (Newark)

**Business Model:**
- Warehouses WH001-WH002: Company-owned facilities
- Warehouses WH003-WH005: Partner-operated (external 3PL providers)

---

### Carriers ✅

**File:** `simulator/src/utils/data_generator.py`

**Changes:**
```python
def _generate_carriers(self):
    """Generate carrier master data (B2B partners)"""
    carriers = [
        {
            "carrier_id": "CARRIER-FEDEX-GRO",  # Semantic ID (not numeric)
            "name": "FedEx Ground",
            "scac": "FDEG",
            "service_level": "STANDARD"
        },
        {
            "carrier_id": "CARRIER-DHL-EXPRE",
            "name": "DHL Express",
            "scac": "DHLE",
            "service_level": "EXPRESS"
        }
    ]
```

**Top Carriers (20 total):**
1. FedEx Ground (CARRIER-FEDEX-GRO)
2. UPS (CARRIER-UPS)
3. DHL Express (CARRIER-DHL-EXPRE)
4. USPS Priority (CARRIER-USPS-PRIO)
5. XPO Logistics (CARRIER-XPO-LOGIS)
6. J.B. Hunt, Schneider, Werner, Knight-Swift, etc.

**Key Change:** Carrier IDs now use **semantic identifiers** (e.g., `CARRIER-DHL-EXPRE`) instead of numeric codes (e.g., `CAR001`) for better B2B API readability.

---

### Customers ✅

**File:** `simulator/src/utils/data_generator.py`

**Existing Implementation (No Changes Needed):**
```python
def _generate_customers(self):
    """Generate customer master data"""
    customers = []
    for i in range(self.customer_count):  # Default: 100 customers
        customers.append({
            "customer_id": f"CUST{i+1:06d}",  # CUST000001 - CUST000100
            "name": fake.company(),           # ✅ Already generates company names
            "street": fake.street_address(),
            "city": fake.city(),
            "state": fake.state_abbr(),
            "postal_code": fake.postcode(),
            "country": "US",
            "phone": fake.phone_number(),
            "email": fake.company_email()
        })
```

**Sample Customer Names (Faker-generated):**
- "Acme Manufacturing Co"
- "Global Retail Inc"
- "TechCorp Solutions"
- "Midwest Distributors LLC"

**Status:** ✅ Customer generator already produces company names via `fake.company()` - no changes required.

---

## Partner Access Scope Reference

### Field: `partner_access_scope`

**Purpose:** Defines which partner types can access each record type (used for RLS policies)

**Allowed Values:**

| Value | Description | Applicable IDoc Types |
|-------|-------------|----------------------|
| `CARRIER_CUSTOMER` | Accessible by carriers AND customers | SHPMNT, DESADV |
| `CUSTOMER` | Accessible by customers only | ORDERS, INVOICE |
| `WAREHOUSE_PARTNER` | Accessible by warehouse partners only | WHSCON |

**RLS Policy Examples:**

```sql
-- Carrier portal view (shipments only)
CREATE VIEW gold_partner_carrier_shipments AS
SELECT 
    shipment_id,
    order_id,
    carrier_id,
    carrier_name,
    shipment_date,
    delivery_date,
    status,
    tracking_number,
    -- MASK customer names for privacy
    'CONFIDENTIAL' AS customer_name,
    customer_city,
    customer_state
FROM silver_shipments
WHERE carrier_id = USER_CLAIM('carrier_id')
  AND partner_access_scope IN ('CARRIER_CUSTOMER');

-- Customer portal view (orders + shipments)
CREATE VIEW gold_customer_portal_orders AS
SELECT 
    order_id,
    customer_id,
    customer_name,
    order_date,
    delivery_date,
    status,
    total_amount,
    tracking_number
FROM silver_orders o
LEFT JOIN silver_shipments s ON o.order_id = s.order_id
WHERE customer_id = USER_CLAIM('customer_id')
  AND partner_access_scope IN ('CUSTOMER', 'CARRIER_CUSTOMER');

-- Warehouse partner view (operations only)
CREATE VIEW gold_partner_warehouse_operations AS
SELECT 
    confirmation_id,
    warehouse_id,
    warehouse_partner_id,
    warehouse_partner_name,
    operation_type,
    operation_date,
    quantity_handled,
    productivity_score,
    -- EXCLUDE cost/pricing data
    -- cost_per_unit (HIDDEN),
    -- labor_cost (HIDDEN)
FROM silver_warehouse_confirmations
WHERE warehouse_partner_id = USER_CLAIM('warehouse_partner_id')
  AND partner_access_scope = 'WAREHOUSE_PARTNER';
```

---

## Data Regeneration Checklist

To populate the new B2B partner fields with realistic test data:

### ✅ Step 1: Schema Enhancements (COMPLETE)
- [x] Update SHPMNT schema with carrier/customer fields
- [x] Update ORDERS schema with customer fields
- [x] Update WHSCON schema with warehouse partner fields
- [x] Update DESADV schema with carrier/customer fields
- [x] Update INVOICE schema with customer fields

### ✅ Step 2: Master Data Generators (COMPLETE)
- [x] Enhance warehouse generator with partner IDs
- [x] Update carrier generator with semantic IDs
- [x] Verify customer generator produces company names

### ⏸️ Step 3: Regenerate Test Data (PENDING)

**Action Required:**
```powershell
# Navigate to simulator directory
cd simulator

# Regenerate IDocs with enhanced B2B fields
python main.py --count 1000

# Verify new fields are populated
python -c "
import json
with open('output/idoc_sample.json') as f:
    idoc = json.load(f)
    print('Carrier ID:', idoc['data']['E1SHP00']['carrier_id'])
    print('Customer Name:', idoc['data']['E1SHP00']['customer_name'])
    print('Partner Scope:', idoc['data']['E1SHP00']['partner_access_scope'])
"
```

**Expected Output:**
```
Carrier ID: CARRIER-DHL-EXPRE
Customer Name: Acme Manufacturing Co
Partner Scope: CARRIER_CUSTOMER
```

### ⏸️ Step 4: Update Silver Table Schemas (PENDING)

**Tables to Modify:**

1. **`idoc_shipments_silver`** (KQL Table)
```kql
.alter table idoc_shipments_silver (
    -- ... existing columns ...
    carrier_id: string,
    carrier_name: string,
    customer_id: string,
    customer_name: string,
    tracking_number: string,
    partner_access_scope: string
)
```

2. **`idoc_orders_silver`** (KQL Table)
```kql
.alter table idoc_orders_silver (
    -- ... existing columns ...
    customer_id: string,
    customer_name: string,
    partner_access_scope: string
)
```

3. **`idoc_warehouse_silver`** (KQL Table)
```kql
.alter table idoc_warehouse_silver (
    -- ... existing columns ...
    warehouse_partner_id: string,
    warehouse_partner_name: string,
    partner_access_scope: string
)
```

**Action:** Update Eventhouse KQL tables and re-materialize from `idoc_raw` table.

### ⏸️ Step 5: Create Partner-Specific Gold Views (PENDING)

**New Views to Create:**

1. `gold_partner_carrier_shipments` - Carrier-filtered shipments (with data masking)
2. `gold_partner_warehouse_operations` - Warehouse partner operations (cost data excluded)
3. `gold_customer_portal_orders` - Customer self-service data

**Method:** Create new Fabric Notebook `Create_Partner_Gold_Views.ipynb` with SQL definitions from `governance/3PL_PARTNER_SHARING_USE_CASES.md`.

---

## Sample Data Examples

### Shipment Record (After Regeneration)

```json
{
  "idoc_type": "SHPMNT01",
  "message_type": "SHPMNT",
  "data": {
    "E1SHP00": {
      "segnam": "E1SHP00",
      "shipment_id": "SHIP20250127001",
      "carrier_id": "CARRIER-DHL-EXPRE",
      "carrier_name": "DHL Express",
      "customer_id": "CUST000042",
      "customer_name": "Acme Manufacturing Co",
      "partner_access_scope": "CARRIER_CUSTOMER",
      "tracking_number": "1Z999AA10123456784",
      "shipment_date": "20250127",
      "status": "IN_TRANSIT"
    }
  }
}
```

### Warehouse Confirmation Record

```json
{
  "idoc_type": "WHSCON01",
  "message_type": "WHSCON",
  "data": {
    "E1WHC00": {
      "segnam": "E1WHC00",
      "confirmation_id": "WC20250127001",
      "warehouse_id": "WH003",
      "warehouse_name": "Los Angeles Distribution Center",
      "warehouse_partner_id": "PARTNER-WH003",
      "warehouse_partner_name": "LogiTech Warehousing",
      "partner_access_scope": "WAREHOUSE_PARTNER",
      "operation_type": "GOODS_RECEIPT",
      "operation_date": "20250127",
      "quantity": 500
    }
  }
}
```

### Customer Order Record

```json
{
  "idoc_type": "ORDERS05",
  "message_type": "ORDERS",
  "data": {
    "E1EDK01": {
      "segnam": "E1EDK01",
      "order_id": "ORD20250127001",
      "customer_id": "CUST000015",
      "customer_name": "Global Retail Inc",
      "partner_access_scope": "CUSTOMER",
      "order_date": "20250127",
      "total_value": 25430.50,
      "currency": "USD"
    }
  }
}
```

---

## Security & Privacy Considerations

### Data Masking Requirements

| Partner Type | Masked Fields | Visible Fields |
|--------------|---------------|----------------|
| **Carriers** | customer_name, pricing, internal_notes | shipment_id, delivery_address, tracking, SLA metrics |
| **Warehouse Partners** | cost_per_unit, labor_cost, customer_names | warehouse operations, productivity, inventory movements |
| **Customers** | internal_operations, carrier_costs, other_customers | their orders, shipments, invoices, delivery status |

### Authentication & Authorization

**Recommended Stack:**
- **Identity Provider:** Azure AD B2C (external partner accounts)
- **API Gateway:** Azure API Management (rate limiting, OAuth validation)
- **RLS Enforcement:** GraphQL API + Fabric Lakehouse Dynamic Security (if available)
- **Audit Logging:** All partner access logged to Azure Monitor

**Partner Credentials Example:**
```json
{
  "sub": "carrier-dhl-user@dhl.com",
  "oid": "550e8400-e29b-41d4-a716-446655440000",
  "carrier_id": "CARRIER-DHL-EXPRE",
  "partner_type": "CARRIER",
  "scopes": ["shipments.read", "tracking.update"]
}
```

---

## Next Steps

### Immediate (This Sprint)
1. ✅ **Schema Enhancements** - Complete (all 5 IDoc types updated)
2. ✅ **Master Data Generators** - Complete (warehouses, carriers, customers)
3. ⏸️ **Regenerate Test Data** - Run `simulator/main.py --count 1000`
4. ⏸️ **Verify Field Population** - Inspect output JSON for new partner fields

### Short-Term (Next Sprint)
5. ⏸️ **Update Silver Table Schemas** - Add partner columns to KQL tables
6. ⏸️ **Re-materialize Silver Tables** - Re-process `idoc_raw` with new schema
7. ⏸️ **Create Partner Gold Views** - Implement 3 new MLVs with RLS filtering
8. ⏸️ **Update Business Domain** - Change classification to "Partner Shared" in Purview

### Medium-Term (Month 2)
9. ⏸️ **Implement GraphQL API** - Deploy partner-facing API with OAuth
10. ⏸️ **Configure Azure AD B2C** - External partner authentication
11. ⏸️ **Deploy API Management** - Rate limiting and API key management
12. ⏸️ **Create Partner Documentation** - API docs, SDKs, sample code

### Long-Term (Month 3+)
13. ⏸️ **Partner Onboarding** - Invite carriers, warehouse partners, customers
14. ⏸️ **SLA Monitoring Dashboards** - Real-time partner performance metrics
15. ⏸️ **Cost Allocation** - Chargeback per warehouse partner facility
16. ⏸️ **Expand Data Sharing** - Power BI Embedded, Azure Data Share

---

## Reference Documents

- **B2B Use Cases:** `governance/3PL_PARTNER_SHARING_USE_CASES.md`
- **Business Domain Config:** `governance/purview/business_domain_config.json`
- **Purview API Guide:** `governance/purview/PURVIEW_API_GUIDE.md`
- **Architecture:** `docs/architecture.md`

---

**Last Updated:** 2025-01-27  
**Author:** GitHub Copilot  
**Status:** Schema enhancements complete - Ready for data regeneration
