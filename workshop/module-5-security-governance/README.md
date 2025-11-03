# Module 5: Security & Governance

> **Implementing RLS and data governance with Purview**

⏱️ **Duration**: 90 minutes | 🎯 **Level**: Advanced | 📋 **Prerequisites**: Modules 1-4 completed

---

## 📖 Module Overview

Implement enterprise-grade security with OneLake Row-Level Security (RLS) and establish data governance using Microsoft Purview.

### Learning Objectives

- ✅ Understand OneLake Security architecture
- ✅ Implement Row-Level Security (RLS) policies
- ✅ Configure Azure AD integration and Service Principals
- ✅ Register data products in Microsoft Purview
- ✅ Implement data quality rules and monitoring
- ✅ Track data lineage

---

## 📚 OneLake Security Architecture

```
┌─────────────────────────────────────────────────────┐
│     OneLake Security Layer (Storage-Level RLS)      │
│                                                     │
│  Single RLS definition enforced across:            │
│  ✓ Real-Time Intelligence (KQL)                    │
│  ✓ Data Engineering (Spark)                        │
│  ✓ Data Warehouse (SQL)                            │
│  ✓ Power BI (Direct Lake)                          │
│  ✓ GraphQL API                                     │
│  ✓ OneLake API                                     │
└─────────────────────────────────────────────────────┘
```

**Key Benefit**: Define security once at the storage layer, enforced everywhere

---

## 🧪 Hands-On Labs

### Lab 1: Create Security Functions

**Create partner security predicate**:

```sql
-- In Fabric Data Warehouse
CREATE FUNCTION dbo.PartnerSecurityPredicate(@partner_id NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN (
    SELECT 1 AS AccessGranted
    WHERE @partner_id = CAST(SESSION_CONTEXT(N'PartnerID') AS NVARCHAR(50))
       OR IS_MEMBER('DataAdmin') = 1  -- Admins see all data
)
GO

-- Create blocking predicate (prevents unauthorized INSERT/UPDATE/DELETE)
CREATE FUNCTION dbo.PartnerBlockingPredicate(@partner_id NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN (
    SELECT 1 AS BlockingGranted
    WHERE @partner_id = CAST(SESSION_CONTEXT(N'PartnerID') AS NVARCHAR(50))
       OR IS_MEMBER('DataAdmin') = 1
)
GO
```

**Verify functions**:

```sql
-- Test filter predicate
SELECT * FROM dbo.PartnerSecurityPredicate('FEDEX')

-- Test with session context
EXEC sp_set_session_context 'PartnerID', 'FEDEX', @read_only = 1
SELECT * FROM gold.shipments  -- Only FEDEX shipments returned
```

---

### Lab 2: Apply Security Policies

**Create security policy on Gold tables**:

```sql
-- Apply to shipments table
CREATE SECURITY POLICY PartnerAccessPolicy
ADD FILTER PREDICATE dbo.PartnerSecurityPredicate(partner_id) ON gold.shipments,
ADD BLOCK PREDICATE dbo.PartnerBlockingPredicate(partner_id) ON gold.shipments
AFTER INSERT,
ADD FILTER PREDICATE dbo.PartnerSecurityPredicate(customer_id) ON gold.orders,
ADD FILTER PREDICATE dbo.PartnerSecurityPredicate(customer_id) ON gold.invoices
WITH (STATE = ON, SCHEMABINDING = ON)
GO

-- Verify policy is active
SELECT * FROM sys.security_policies
WHERE name = 'PartnerAccessPolicy'

-- View predicates
SELECT 
    sp.name AS policy_name,
    o.name AS table_name,
    spp.predicate_definition,
    spp.predicate_type_desc
FROM sys.security_policies sp
JOIN sys.security_predicates spp ON sp.object_id = spp.object_id
JOIN sys.objects o ON spp.target_object_id = o.object_id
WHERE sp.name = 'PartnerAccessPolicy'
```

---

### Lab 3: Configure Service Principals

**Create Service Principals for partners**:

```powershell
# Script: create-partner-apps.ps1

$partners = @(
    @{Name="FedEx"; Id="fedex"; DisplayName="FedEx Carrier Portal"},
    @{Name="WH-EAST"; Id="wh-east"; DisplayName="Warehouse East Application"},
    @{Name="ACME"; Id="acme"; DisplayName="ACME Corp Customer Portal"}
)

foreach ($partner in $partners) {
    # Create Azure AD App Registration
    $app = az ad app create `
        --display-name $partner.DisplayName `
        --sign-in-audience AzureADMyOrg `
        --query appId -o tsv
    
    # Create Service Principal
    $sp = az ad sp create --id $app
    
    # Create client secret
    $secret = az ad app credential reset `
        --id $app `
        --append `
        --display-name "API Access" `
        --years 2 `
        --query password -o tsv
    
    Write-Host "Partner: $($partner.Name)"
    Write-Host "  App ID: $app"
    Write-Host "  Secret: $secret"
    Write-Host "  Partner ID for RLS: $($partner.Id)"
    Write-Host ""
}
```

**Grant Fabric workspace access**:

```powershell
# Grant Service Principal access to Fabric workspace
$workspaceId = "<workspace-id>"
$servicePrincipalId = "<sp-object-id>"

# Using Fabric REST API
$body = @{
    identifier = $servicePrincipalId
    principalType = "ServicePrincipal"
    workspaceRole = "Viewer"  # Read-only access
} | ConvertTo-Json

Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/users" `
    -Headers @{Authorization = "Bearer $accessToken"} `
    -Body $body `
    -ContentType "application/json"
```

---

### Lab 4: Test RLS with Different Identities

**Test script**:

```sql
-- Scenario 1: FedEx user - should only see FedEx shipments
EXEC sp_set_session_context 'PartnerID', 'FEDEX', @read_only = 1
GO

SELECT carrier_id, COUNT(*) as shipment_count
FROM gold.shipments
GROUP BY carrier_id
-- Result: Only carrier_id = 'FEDEX' rows

GO

-- Scenario 2: ACME customer - should only see ACME orders
EXEC sp_set_session_context 'PartnerID', 'ACME', @read_only = 1
GO

SELECT customer_id, COUNT(*) as order_count
FROM gold.orders
GROUP BY customer_id
-- Result: Only customer_id = 'ACME' rows

GO

-- Scenario 3: Admin user - sees all data
EXEC sp_set_session_context 'PartnerID', NULL
GO

-- Member of DataAdmin role
SELECT carrier_id, COUNT(*) as shipment_count
FROM gold.shipments
GROUP BY carrier_id
-- Result: All carriers visible
```

---

### Lab 5: Register Data Product in Purview

**Data product registration**:

```json
{
  "dataProduct": {
    "name": "SAP-3PL-Logistics-Real-Time-Product",
    "displayName": "SAP 3PL Logistics Operations",
    "description": "Real-time logistics and shipment data from SAP IDoc integration",
    "version": "1.0.0",
    "domain": "Logistics & Supply Chain",
    "owner": {
      "type": "User",
      "email": "data-product-owner@company.com",
      "displayName": "Data Product Team"
    },
    "steward": {
      "type": "Group",
      "email": "data-stewards@company.com"
    },
    "sla": {
      "availability": 99.9,
      "latency": {
        "value": 5,
        "unit": "minutes"
      },
      "dataFreshness": {
        "value": 1,
        "unit": "minutes"
      }
    },
    "assets": [
      {
        "type": "Table",
        "qualifiedName": "fabric://workspace/lakehouse_3pl/gold_shipments",
        "role": "source"
      },
      {
        "type": "API",
        "qualifiedName": "apim://sap-3pl-api/graphql",
        "role": "interface"
      }
    ],
    "classification": {
      "confidentiality": "Internal",
      "compliance": ["GDPR", "SOC2"],
      "sensitivity": "Medium"
    },
    "tags": ["SAP", "Logistics", "3PL", "Real-time", "IDoc"],
    "businessGlossary": {
      "terms": [
        "Shipment",
        "Carrier",
        "3PL Operations",
        "On-Time Delivery"
      ]
    }
  }
}
```

**Register using Purview API**:

```python
import requests
import json

def register_data_product(product_definition, access_token):
    """Register data product in Microsoft Purview"""
    
    purview_endpoint = "https://<purview-account>.purview.azure.com"
    url = f"{purview_endpoint}/catalog/api/atlas/v2/entity"
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    # Transform to Atlas entity format
    entity = {
        "entity": {
            "typeName": "DataProduct",
            "attributes": product_definition["dataProduct"],
            "relationshipAttributes": {
                "assets": product_definition["dataProduct"]["assets"]
            }
        }
    }
    
    response = requests.post(url, headers=headers, json=entity)
    
    if response.status_code == 200:
        print("Data product registered successfully")
        return response.json()
    else:
        print(f"Error: {response.status_code} - {response.text}")
        return None

# Register the product
with open('data-product-definition.json', 'r') as f:
    product_def = json.load(f)

register_data_product(product_def, access_token)
```

---

### Lab 6: Implement Data Quality Rules

**Quality dimensions**:

```python
# data_quality_rules.py

quality_rules = {
    "completeness": [
        {
            "name": "ShipmentIDRequired",
            "table": "gold.shipments",
            "column": "shipment_id",
            "rule": "IS NOT NULL",
            "threshold": 100.0,
            "severity": "Critical"
        },
        {
            "name": "CarrierIDRequired",
            "table": "gold.shipments",
            "column": "carrier_id",
            "rule": "IS NOT NULL",
            "threshold": 99.5,
            "severity": "High"
        }
    ],
    "accuracy": [
        {
            "name": "ValidShipDate",
            "table": "gold.shipments",
            "rule": "ship_date <= delivery_date",
            "threshold": 99.0,
            "severity": "Medium"
        },
        {
            "name": "PositiveWeight",
            "table": "gold.shipments",
            "rule": "total_weight > 0",
            "threshold": 100.0,
            "severity": "High"
        }
    ],
    "timeliness": [
        {
            "name": "DataFreshness",
            "table": "gold.shipments",
            "rule": "DATEDIFF(minute, created_timestamp, GETDATE()) <= 5",
            "threshold": 95.0,
            "severity": "High"
        }
    ],
    "consistency": [
        {
            "name": "CustomerReference",
            "rule": "All customer_id in shipments exist in dim_customer",
            "threshold": 100.0,
            "severity": "Critical"
        }
    ]
}
```

**KQL queries for quality monitoring**:

```kql
// Data quality dashboard queries

// Completeness: Missing required fields
gold_shipments
| summarize 
    TotalRows = count(),
    MissingShipmentID = countif(isempty(shipment_id)),
    MissingCarrier = countif(isempty(carrier_id)),
    MissingCustomer = countif(isempty(customer_id))
| extend 
    ShipmentIDCompleteness = 100.0 * (1 - todouble(MissingShipmentID) / TotalRows),
    CarrierCompleteness = 100.0 * (1 - todouble(MissingCarrier) / TotalRows),
    CustomerCompleteness = 100.0 * (1 - todouble(MissingCustomer) / TotalRows)

// Accuracy: Date validation
gold_shipments
| extend 
    IsValidDate = ship_date <= delivery_date,
    IsValidWeight = total_weight > 0
| summarize 
    TotalRows = count(),
    InvalidDates = countif(not(IsValidDate)),
    InvalidWeights = countif(not(IsValidWeight))
| extend 
    DateAccuracy = 100.0 * (1 - todouble(InvalidDates) / TotalRows),
    WeightAccuracy = 100.0 * (1 - todouble(InvalidWeights) / TotalRows)

// Timeliness: Data freshness
gold_shipments
| extend AgeMinutes = datetime_diff('minute', now(), created_timestamp)
| summarize 
    TotalRows = count(),
    Fresh = countif(AgeMinutes <= 5),
    Stale = countif(AgeMinutes > 5)
| extend FreshnessScore = 100.0 * todouble(Fresh) / TotalRows
```

**Deploy quality monitoring**:

```python
def create_quality_alerts(purview_client):
    """Create data quality alerts in Purview"""
    
    for dimension, rules in quality_rules.items():
        for rule in rules:
            alert_config = {
                "name": rule["name"],
                "table": rule["table"],
                "rule": rule["rule"],
                "threshold": rule["threshold"],
                "severity": rule["severity"],
                "notification": {
                    "email": ["data-quality-team@company.com"],
                    "webhook": "https://company.com/webhooks/quality-alert"
                }
            }
            
            purview_client.create_quality_rule(alert_config)
            print(f"Created quality rule: {rule['name']}")
```

---

## 📋 Security Best Practices

**RLS Implementation**:
- ✅ Apply at storage layer (OneLake)
- ✅ Use Service Principal ObjectId for identity
- ✅ Implement blocking predicates for data modification
- ✅ Test with multiple identities
- ✅ Document security model

**Service Principals**:
- ✅ One SP per partner/application
- ✅ Rotate secrets regularly
- ✅ Use Key Vault for secret storage
- ✅ Grant minimum required permissions
- ✅ Monitor SP usage with audit logs

**Data Governance**:
- ✅ Register all data assets in Purview
- ✅ Classify sensitive data (PII, confidential)
- ✅ Implement data quality monitoring
- ✅ Track data lineage end-to-end
- ✅ Define and enforce data contracts

---

## ✅ Module Completion

**Summary**: Implemented enterprise security with RLS and established governance with Purview

**Next**: [Module 6: API Development](../module-6-api-development/README.md) - Create GraphQL and REST APIs

---

**[← Module 4](../module-4-data-lakehouse/README.md)** | **[Home](../README.md)** | **[Module 6 →](../module-6-api-development/README.md)**
