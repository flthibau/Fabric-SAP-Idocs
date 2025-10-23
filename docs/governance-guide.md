# Data Governance Guide

## SAP 3PL Logistics Operations Data Product

**Version:** 1.0.0  
**Last Updated:** October 23, 2025  
**Owner:** Data Governance Team

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Data Product Definition](#data-product-definition)
3. [Microsoft Purview Setup](#microsoft-purview-setup)
4. [Data Catalog Management](#data-catalog-management)
5. [Data Quality Framework](#data-quality-framework)
6. [Data Lineage](#data-lineage)
7. [Data Classification](#data-classification)
8. [API Governance](#api-governance)
9. [Access Control](#access-control)
10. [Compliance & Privacy](#compliance--privacy)
11. [Monitoring & Reporting](#monitoring--reporting)
12. [Governance Workflows](#governance-workflows)

---

## Executive Summary

This document outlines the comprehensive data governance framework for the SAP 3PL Logistics Operations Data Product. It establishes standards, policies, and procedures to ensure data quality, security, compliance, and proper utilization across the organization.

### Governance Objectives

1. ✅ **Data Quality**: Ensure high-quality, accurate, and consistent data
2. ✅ **Data Discovery**: Enable easy discovery and understanding of data assets
3. ✅ **Compliance**: Maintain compliance with GDPR, SOC 2, and industry regulations
4. ✅ **Security**: Protect sensitive data and control access appropriately
5. ✅ **Lineage**: Track data from source to consumption
6. ✅ **Accountability**: Clear ownership and responsibility for data assets
7. ✅ **Transparency**: Provide visibility into data operations and quality

### Governance Stakeholders

| Role | Responsibility | Contact |
|------|----------------|---------|
| **Data Product Owner** | Overall product ownership and strategy | product-owner@company.com |
| **Data Steward** | Day-to-day data quality and governance | data-steward@company.com |
| **Data Architect** | Technical architecture and design | data-architect@company.com |
| **Privacy Officer** | Data privacy and compliance | privacy@company.com |
| **Security Officer** | Data security and access control | security@company.com |
| **Business Owner** | Business requirements and validation | business-owner@company.com |

---

## Data Product Definition

### Data Product Overview

**Name**: SAP-3PL-Logistics-Operations  
**Version**: 1.0.0  
**Domain**: Logistics & Supply Chain  
**Status**: Production

**Description**:  
A real-time data product providing comprehensive logistics and shipment information derived from SAP IDoc integration, serving analytics, reporting, and operational needs across the organization.

### Data Product Specification

```json
{
  "dataProduct": {
    "metadata": {
      "id": "dp-sap-3pl-logistics-001",
      "name": "SAP-3PL-Logistics-Operations",
      "displayName": "SAP 3PL Logistics Operations",
      "version": "1.0.0",
      "status": "Production",
      "createdDate": "2025-10-01",
      "lastModifiedDate": "2025-10-23"
    },
    "business": {
      "domain": "Logistics",
      "subDomain": "Third-Party Logistics",
      "businessPurpose": "Provide real-time visibility into logistics operations including shipments, deliveries, and inventory movements",
      "businessValue": "Enables data-driven decision making for logistics optimization, customer service, and operational efficiency",
      "useCases": [
        "Shipment tracking and monitoring",
        "On-time delivery analytics",
        "Customer service inquiries",
        "Logistics performance reporting",
        "Predictive delivery analysis"
      ]
    },
    "ownership": {
      "productOwner": {
        "name": "John Smith",
        "email": "john.smith@company.com",
        "department": "Logistics"
      },
      "dataSteward": {
        "name": "Jane Doe",
        "email": "jane.doe@company.com",
        "department": "Data Governance"
      },
      "technicalOwner": {
        "name": "Bob Johnson",
        "email": "bob.johnson@company.com",
        "department": "Data Engineering"
      }
    },
    "sla": {
      "availability": {
        "target": 99.9,
        "measurement": "monthly uptime percentage"
      },
      "latency": {
        "value": 5,
        "unit": "minutes",
        "description": "Maximum time from IDoc arrival to API availability"
      },
      "freshness": {
        "value": 1,
        "unit": "minutes",
        "description": "Maximum data age in the API"
      },
      "completeness": {
        "target": 99.5,
        "measurement": "percentage of required fields populated"
      },
      "accuracy": {
        "target": 99.9,
        "measurement": "percentage of records passing validation rules"
      }
    },
    "dataAssets": [
      {
        "name": "bronze_idocs",
        "type": "Table",
        "layer": "Bronze",
        "description": "Raw IDoc messages from SAP",
        "location": "fabric://sap-3pl-workspace/lakehouse/bronze_idocs",
        "format": "Delta Lake",
        "retention": "90 days"
      },
      {
        "name": "silver_shipments",
        "type": "Table",
        "layer": "Silver",
        "description": "Cleansed and normalized shipment data",
        "location": "fabric://sap-3pl-workspace/lakehouse/silver_shipments",
        "format": "Delta Lake",
        "retention": "2 years"
      },
      {
        "name": "gold_fact_shipment",
        "type": "Table",
        "layer": "Gold",
        "description": "Dimensional shipment fact table",
        "location": "fabric://sap-3pl-workspace/warehouse/fact_shipment",
        "format": "SQL Warehouse",
        "retention": "7 years"
      }
    ],
    "interfaces": [
      {
        "name": "GraphQL API",
        "type": "API",
        "endpoint": "https://api.company.com/sap-3pl/graphql",
        "protocol": "GraphQL over HTTPS",
        "authentication": "OAuth 2.0 / Azure AD"
      },
      {
        "name": "REST API",
        "type": "API",
        "endpoint": "https://api.company.com/sap-3pl/api/v1",
        "protocol": "REST over HTTPS",
        "authentication": "OAuth 2.0 / Azure AD"
      }
    ],
    "consumers": [
      {
        "name": "Logistics Dashboard",
        "type": "Application",
        "team": "Logistics Operations"
      },
      {
        "name": "Customer Service Portal",
        "type": "Application",
        "team": "Customer Success"
      },
      {
        "name": "Power BI Reports",
        "type": "Analytics",
        "team": "Business Intelligence"
      }
    ],
    "tags": [
      "SAP",
      "Logistics",
      "3PL",
      "Real-time",
      "IDoc",
      "Shipments",
      "Supply Chain"
    ]
  }
}
```

---

## Microsoft Purview Setup

### Prerequisites

1. **Purview Account**: Microsoft Purview account provisioned
2. **Permissions**: Data Curator role or higher
3. **Collections**: Appropriate collection structure created
4. **Connections**: Fabric workspace and APIM registered as data sources

### Collection Structure

```
Root Collection
└── Logistics
    └── SAP-3PL-Operations
        ├── Data Sources
        │   ├── Fabric Lakehouse
        │   └── Fabric SQL Warehouse
        ├── APIs
        │   ├── GraphQL API
        │   └── REST API
        └── Reports & Dashboards
```

### Registering Data Sources

#### 1. Register Fabric Workspace

```bash
# Using Azure CLI
az purview account add-root-collection-admin \
  --account-name <purview-account-name> \
  --resource-group <resource-group> \
  --object-id <user-object-id>

# Register Fabric as a data source
az rest --method put \
  --url "https://<purview-account-name>.purview.azure.com/scan/datasources/fabric-sap-3pl?api-version=2022-07-01-preview" \
  --body '{
    "kind": "Fabric",
    "properties": {
      "endpoint": "https://fabric.microsoft.com/<workspace-id>",
      "collection": {
        "referenceName": "SAP-3PL-Operations"
      }
    }
  }'
```

#### 2. Configure Scanning

**Scan Configuration for Lakehouse:**

```json
{
  "name": "sap-3pl-lakehouse-scan",
  "properties": {
    "scanRulesetName": "FabricLakehouse",
    "scanRulesetType": "System",
    "scanLevel": "Full",
    "recurrence": {
      "frequency": "Daily",
      "interval": 1,
      "startTime": "2025-10-24T02:00:00Z"
    },
    "scope": {
      "includePrefix": ["bronze_*", "silver_*", "gold_*"]
    }
  }
}
```

#### 3. Register APIs in Purview

**GraphQL API Registration:**

```json
{
  "name": "SAP-3PL-GraphQL-API",
  "assetType": "API",
  "properties": {
    "description": "GraphQL API for SAP 3PL Logistics Operations",
    "endpoint": "https://api.company.com/sap-3pl/graphql",
    "protocol": "GraphQL",
    "version": "1.0.0",
    "authentication": "OAuth2",
    "owner": "data-product-team@company.com",
    "documentation": "https://docs.api.company.com/sap-3pl/graphql",
    "schemaUrl": "https://api.company.com/sap-3pl/graphql/schema",
    "collection": "SAP-3PL-Operations/APIs"
  },
  "schema": {
    "type": "GraphQL",
    "content": "..."
  }
}
```

---

## Data Catalog Management

### Business Glossary

#### Key Terms

| Term | Definition | Category | Related Assets |
|------|------------|----------|----------------|
| **Shipment** | A collection of goods being transported from origin to destination | Logistics | silver_shipments, fact_shipment |
| **Delivery** | The act of transferring goods to the final recipient | Logistics | silver_deliveries |
| **IDoc** | Intermediate Document - SAP's standard data structure for data exchange | Technical | bronze_idocs |
| **On-Time Delivery** | Delivery completed by or before the estimated delivery date | KPI | Calculated field |
| **3PL** | Third-Party Logistics - outsourced logistics and distribution services | Business | All assets |
| **DESADV** | Dispatch Advice - IDoc type for delivery notifications | Technical | bronze_idocs |
| **SHPMNT** | Shipment - IDoc type for shipment information | Technical | bronze_idocs |

#### Business Glossary JSON

```json
{
  "glossaryTerms": [
    {
      "name": "Shipment",
      "definition": "A collection of goods being transported from an origin location to a destination location, managed by a carrier.",
      "acronym": null,
      "category": "Logistics Operations",
      "status": "Approved",
      "experts": ["john.smith@company.com"],
      "stewards": ["jane.doe@company.com"],
      "relatedTerms": ["Delivery", "Transportation", "Freight"],
      "dataAssets": [
        "fabric://lakehouse/silver_shipments",
        "fabric://warehouse/fact_shipment"
      ],
      "examples": [
        "Shipment #8000001234 containing 50 units of Widget Pro 3000"
      ]
    },
    {
      "name": "On-Time Delivery",
      "definition": "A key performance indicator measuring the percentage of deliveries completed by or before the estimated delivery date.",
      "acronym": "OTD",
      "category": "Key Performance Indicator",
      "status": "Approved",
      "calculationLogic": "COUNT(deliveries WHERE actual_delivery_date <= estimated_delivery_date) / COUNT(deliveries) * 100",
      "businessRule": "Target: >= 95%",
      "experts": ["logistics-manager@company.com"],
      "stewards": ["jane.doe@company.com"]
    }
  ]
}
```

### Asset Documentation

#### Template for Data Assets

```markdown
# Asset: silver_shipments

## Overview
**Type**: Delta Lake Table  
**Layer**: Silver (Cleansed)  
**Owner**: Data Engineering Team  
**Steward**: Jane Doe  

## Business Description
Contains cleansed and normalized shipment information extracted from SAP SHPMNT IDocs. This table serves as the primary source for shipment analytics and reporting.

## Technical Details
- **Storage**: Fabric Lakehouse
- **Format**: Delta Lake
- **Partitioning**: ship_date (daily)
- **Retention**: 2 years
- **Refresh Frequency**: Near real-time (< 5 minutes)

## Schema
| Column | Type | Nullable | Description | Business Glossary Term |
|--------|------|----------|-------------|----------------------|
| shipment_id | STRING | No | Unique identifier | Shipment |
| shipment_number | STRING | No | SAP shipment number | Shipment |
| customer_id | STRING | No | Customer identifier | Customer |
| ship_date | DATE | No | Actual ship date | Ship Date |
| ... | ... | ... | ... | ... |

## Data Quality Rules
- Completeness: 99.5%
- Accuracy: 99.9%
- Freshness: < 5 minutes
- Uniqueness: shipment_id is unique

## Access Control
- Read: logistics-team, analytics-team, customer-service
- Write: data-engineering-pipeline (automated only)
- Admin: data-engineering-team

## Related Assets
- Source: bronze_idocs
- Downstream: fact_shipment, dim_shipment
- APIs: GraphQL Shipment type, REST /api/v1/shipments

## Contact
- Technical Support: data-engineering@company.com
- Business Questions: logistics-team@company.com
```

---

## Data Quality Framework

### Data Quality Dimensions

| Dimension | Definition | Target | Measurement |
|-----------|------------|--------|-------------|
| **Completeness** | All required fields are populated | 99.5% | % of non-null required fields |
| **Accuracy** | Data correctly represents reality | 99.9% | % passing validation rules |
| **Consistency** | Data is consistent across systems | 99.0% | % matching source system |
| **Timeliness** | Data is available within SLA | 95.0% | % delivered within 5 minutes |
| **Validity** | Data conforms to business rules | 99.5% | % passing business rules |
| **Uniqueness** | No duplicate records exist | 100% | % unique keys |

### Data Quality Rules

#### Completeness Rules

```json
{
  "qualityRules": [
    {
      "ruleId": "QR-001",
      "name": "Shipment Required Fields Completeness",
      "dimension": "Completeness",
      "scope": {
        "asset": "silver_shipments",
        "layer": "Silver"
      },
      "description": "Ensures all required shipment fields are populated",
      "severity": "Critical",
      "rules": [
        {
          "field": "shipment_id",
          "condition": "IS NOT NULL",
          "threshold": 100,
          "thresholdType": "Percentage"
        },
        {
          "field": "customer_id",
          "condition": "IS NOT NULL",
          "threshold": 100,
          "thresholdType": "Percentage"
        },
        {
          "field": "ship_date",
          "condition": "IS NOT NULL",
          "threshold": 99.5,
          "thresholdType": "Percentage"
        },
        {
          "field": "origin_location",
          "condition": "IS NOT NULL AND LENGTH(origin_location) > 0",
          "threshold": 99.0,
          "thresholdType": "Percentage"
        }
      ],
      "actions": [
        {
          "type": "Alert",
          "severity": "High",
          "recipients": ["data-quality-team@company.com"],
          "condition": "threshold < 99.0"
        },
        {
          "type": "Quarantine",
          "destination": "quality_issues_table",
          "condition": "fails_validation"
        }
      ],
      "schedule": "Hourly",
      "owner": "data-steward@company.com"
    }
  ]
}
```

#### Accuracy Rules

```json
{
  "qualityRules": [
    {
      "ruleId": "QR-002",
      "name": "Shipment Date Logical Validation",
      "dimension": "Accuracy",
      "scope": {
        "asset": "silver_shipments",
        "layer": "Silver"
      },
      "description": "Validates logical relationships between dates",
      "severity": "High",
      "rules": [
        {
          "name": "ship_date_not_future",
          "condition": "ship_date <= CURRENT_DATE",
          "threshold": 100,
          "errorMessage": "Ship date cannot be in the future"
        },
        {
          "name": "delivery_after_ship",
          "condition": "actual_delivery_date IS NULL OR actual_delivery_date >= ship_date",
          "threshold": 99.9,
          "errorMessage": "Delivery date must be on or after ship date"
        },
        {
          "name": "estimated_delivery_reasonable",
          "condition": "estimated_delivery_date >= ship_date AND estimated_delivery_date <= ship_date + INTERVAL '30 days'",
          "threshold": 98.0,
          "errorMessage": "Estimated delivery date should be within 30 days of ship date"
        }
      ],
      "actions": [
        {
          "type": "Alert",
          "recipients": ["data-quality-team@company.com"],
          "condition": "threshold < 99.0"
        }
      ],
      "schedule": "Hourly"
    }
  ]
}
```

#### Validity Rules

```json
{
  "qualityRules": [
    {
      "ruleId": "QR-003",
      "name": "Shipment Business Rules Validation",
      "dimension": "Validity",
      "scope": {
        "asset": "silver_shipments",
        "layer": "Silver"
      },
      "rules": [
        {
          "name": "valid_weight",
          "condition": "total_weight > 0 AND total_weight < 50000",
          "threshold": 99.5,
          "errorMessage": "Weight must be positive and less than 50,000 kg"
        },
        {
          "name": "valid_status",
          "condition": "status IN ('CREATED', 'IN_TRANSIT', 'DELIVERED', 'DELAYED', 'CANCELLED')",
          "threshold": 100,
          "errorMessage": "Invalid shipment status"
        },
        {
          "name": "customer_exists",
          "condition": "customer_id IN (SELECT customer_id FROM dim_customer)",
          "threshold": 100,
          "errorMessage": "Customer must exist in dimension table"
        }
      ],
      "schedule": "Hourly"
    }
  ]
}
```

### Data Quality Monitoring

#### Quality Dashboard Metrics

```sql
-- Daily Data Quality Score
WITH quality_metrics AS (
  SELECT
    CURRENT_DATE as check_date,
    COUNT(*) as total_records,
    
    -- Completeness
    SUM(CASE WHEN shipment_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as shipment_id_completeness,
    SUM(CASE WHEN customer_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as customer_id_completeness,
    SUM(CASE WHEN ship_date IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as ship_date_completeness,
    
    -- Accuracy
    SUM(CASE WHEN ship_date <= CURRENT_DATE THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as valid_ship_date,
    SUM(CASE WHEN actual_delivery_date IS NULL OR actual_delivery_date >= ship_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as logical_dates,
    
    -- Validity
    SUM(CASE WHEN total_weight > 0 AND total_weight < 50000 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as valid_weight,
    
    -- Overall Score
    (
      SUM(CASE WHEN shipment_id IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN customer_id IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN ship_date IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN ship_date <= CURRENT_DATE THEN 1 ELSE 0 END) +
      SUM(CASE WHEN total_weight > 0 AND total_weight < 50000 THEN 1 ELSE 0 END)
    ) * 100.0 / (COUNT(*) * 5) as overall_quality_score
    
  FROM silver_shipments
  WHERE processing_date = CURRENT_DATE
)
SELECT * FROM quality_metrics;
```

### Automated Quality Checks

**PySpark Implementation:**

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, count, sum as spark_sum
from delta.tables import DeltaTable

def run_quality_checks(spark, table_name, check_date):
    """
    Execute data quality checks on a Delta table
    """
    # Read the table
    df = spark.read.table(table_name).filter(col("processing_date") == check_date)
    total_count = df.count()
    
    # Define quality checks
    quality_checks = {
        'completeness_shipment_id': df.filter(col("shipment_id").isNotNull()).count() / total_count * 100,
        'completeness_customer_id': df.filter(col("customer_id").isNotNull()).count() / total_count * 100,
        'completeness_ship_date': df.filter(col("ship_date").isNotNull()).count() / total_count * 100,
        'accuracy_ship_date': df.filter(col("ship_date") <= current_date()).count() / total_count * 100,
        'validity_weight': df.filter((col("total_weight") > 0) & (col("total_weight") < 50000)).count() / total_count * 100,
    }
    
    # Calculate overall score
    overall_score = sum(quality_checks.values()) / len(quality_checks)
    
    # Log results to quality metrics table
    quality_results = spark.createDataFrame([{
        'check_date': check_date,
        'table_name': table_name,
        'total_records': total_count,
        **quality_checks,
        'overall_score': overall_score,
        'check_timestamp': current_timestamp()
    }])
    
    quality_results.write.mode("append").saveAsTable("data_quality_metrics")
    
    # Alert if below threshold
    if overall_score < 95.0:
        send_quality_alert(table_name, overall_score, quality_checks)
    
    return quality_checks

def send_quality_alert(table_name, overall_score, checks):
    """
    Send alert for quality issues
    """
    # Implementation to send email/Teams notification
    print(f"ALERT: Quality score for {table_name} is {overall_score:.2f}%")
    for check, score in checks.items():
        if score < 95.0:
            print(f"  - {check}: {score:.2f}%")
```

---

## Data Lineage

### Lineage Tracking

Microsoft Purview automatically captures lineage for:
- Fabric Eventstream → Lakehouse
- Lakehouse Bronze → Silver → Gold transformations
- SQL Warehouse tables
- API consumption

### Manual Lineage Registration

For custom processes, register lineage using Purview API:

```python
import requests

def register_lineage(source_asset, target_asset, process_name):
    """
    Register data lineage in Microsoft Purview
    """
    purview_endpoint = "https://<purview-account>.purview.azure.com"
    api_version = "2022-03-01-preview"
    
    lineage_payload = {
        "entity": {
            "typeName": "Process",
            "attributes": {
                "name": process_name,
                "qualifiedName": f"process://{process_name}",
                "inputs": [
                    {
                        "guid": source_asset["guid"],
                        "typeName": source_asset["typeName"]
                    }
                ],
                "outputs": [
                    {
                        "guid": target_asset["guid"],
                        "typeName": target_asset["typeName"]
                    }
                ]
            }
        }
    }
    
    response = requests.post(
        f"{purview_endpoint}/catalog/api/atlas/v2/entity",
        json=lineage_payload,
        headers={
            "Authorization": f"Bearer {get_access_token()}",
            "Content-Type": "application/json"
        }
    )
    
    return response.json()

# Example usage
source = {
    "guid": "abc123...",
    "typeName": "fabric_lakehouse_table"
}

target = {
    "guid": "def456...",
    "typeName": "fabric_warehouse_table"
}

register_lineage(source, target, "silver_to_gold_transformation")
```

### End-to-End Lineage Example

```
SAP System (IDoc SHPMNT)
    ↓ [IDoc Simulator]
Azure Event Hub
    ↓ [Fabric Eventstream]
bronze_idocs (Delta Lake)
    ↓ [Spark Job: bronze_to_silver]
silver_shipments (Delta Lake)
    ↓ [Spark Job: silver_to_gold]
fact_shipment (SQL Warehouse)
    ↓ [GraphQL Resolver]
GraphQL API Endpoint
    ↓ [APIM Gateway]
Consumer Application
```

---

## Data Classification

### Classification Levels

| Level | Description | Examples | Access Control |
|-------|-------------|----------|----------------|
| **Public** | Non-sensitive information | Product codes, status values | All authenticated users |
| **Internal** | Business information for internal use | Shipment volumes, performance metrics | Company employees only |
| **Confidential** | Sensitive business information | Customer names, pricing | Role-based access |
| **Highly Confidential** | Critical sensitive information | Personal data, financial details | Strict need-to-know basis |

### Sensitivity Labels

#### PII (Personally Identifiable Information)

Fields classified as PII:
- `customer.contact_email`
- `customer.contact_phone`
- `recipient_name`
- `delivery_location.address`

**Purview Classification:**

```json
{
  "classifications": [
    {
      "typeName": "MICROSOFT.PERSONAL.EMAIL",
      "attributes": {},
      "entityGuid": "<guid>",
      "entityStatus": "ACTIVE",
      "propagate": true
    },
    {
      "typeName": "MICROSOFT.PERSONAL.PHONE_NUMBER",
      "attributes": {},
      "entityGuid": "<guid>",
      "entityStatus": "ACTIVE",
      "propagate": true
    }
  ]
}
```

### Auto-Classification Rules

```json
{
  "classificationRules": [
    {
      "name": "Detect Email Addresses",
      "description": "Automatically classify fields containing email addresses",
      "classification": "MICROSOFT.PERSONAL.EMAIL",
      "ruleType": "Regex",
      "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
      "dataPattern": "column",
      "minimumPercentageMatch": 80
    },
    {
      "name": "Detect Phone Numbers",
      "description": "Automatically classify fields containing phone numbers",
      "classification": "MICROSOFT.PERSONAL.PHONE_NUMBER",
      "ruleType": "Regex",
      "pattern": "^[+]?[(]?[0-9]{1,4}[)]?[-\\s\\.]?[(]?[0-9]{1,4}[)]?[-\\s\\.]?[0-9]{1,9}$",
      "dataPattern": "column",
      "minimumPercentageMatch": 80
    }
  ]
}
```

---

## API Governance

### API Registration in Purview

Register both GraphQL and REST APIs as governed assets:

```json
{
  "apis": [
    {
      "name": "SAP-3PL-GraphQL-API",
      "type": "GraphQL",
      "version": "1.0.0",
      "endpoint": "https://api.company.com/sap-3pl/graphql",
      "status": "Production",
      "owner": "api-team@company.com",
      "steward": "data-steward@company.com",
      "documentation": "https://docs.api.company.com/sap-3pl/graphql",
      "sla": {
        "availability": 99.9,
        "responseTime": 200,
        "rateLimit": 1000
      },
      "authentication": "OAuth2",
      "dataAssets": [
        "fabric://warehouse/fact_shipment",
        "fabric://warehouse/dim_customer",
        "fabric://lakehouse/silver_shipments"
      ],
      "consumers": [
        "Logistics Dashboard",
        "Customer Service Portal",
        "Mobile App"
      ],
      "changeLog": [
        {
          "version": "1.0.0",
          "date": "2025-10-23",
          "changes": "Initial release"
        }
      ]
    },
    {
      "name": "SAP-3PL-REST-API",
      "type": "REST",
      "version": "1.0.0",
      "endpoint": "https://api.company.com/sap-3pl/api/v1",
      "status": "Production",
      "openApiSpec": "https://api.company.com/sap-3pl/api/v1/openapi.json",
      "sla": {
        "availability": 99.9,
        "responseTime": 150,
        "rateLimit": 1000
      }
    }
  ]
}
```

### API Versioning Policy

1. **Major Version** (v1 → v2): Breaking changes
2. **Minor Version** (v1.1 → v1.2): New features, backward compatible
3. **Patch Version** (v1.1.1 → v1.1.2): Bug fixes

**Deprecation Policy:**
- Minimum 6 months notice before deprecation
- Support for N-1 version (previous major version)
- Clear communication in API responses and documentation

---

## Access Control

### Role-Based Access Control (RBAC)

| Role | Permissions | Scope |
|------|-------------|-------|
| **Data Consumer** | Read access to APIs and Gold layer | API endpoints, fact/dim tables |
| **Data Analyst** | Read access to all layers | Bronze, Silver, Gold, APIs |
| **Data Engineer** | Read/Write to Bronze/Silver, Read Gold | Transformation pipelines |
| **Data Steward** | Manage metadata, quality rules | Purview catalog, quality framework |
| **Data Product Owner** | Full access, governance controls | All assets and configurations |

### Row-Level Security (RLS)

Implement RLS in SQL Warehouse for customer data:

```sql
-- Create security function
CREATE FUNCTION dbo.fn_securitypredicate(@CustomerRegion AS VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_securitypredicate_result
    WHERE @CustomerRegion = USER_NAME() 
       OR IS_MEMBER('DataProductOwner') = 1
       OR IS_MEMBER('DataSteward') = 1;

-- Apply security policy
CREATE SECURITY POLICY CustomerRegionPolicy
ADD FILTER PREDICATE dbo.fn_securitypredicate(customer_region)
ON dbo.fact_shipment
WITH (STATE = ON);
```

### API Access Control

**OAuth 2.0 Scopes:**

```json
{
  "scopes": [
    {
      "name": "Shipments.Read",
      "description": "Read shipment data",
      "grantedTo": ["logistics-team", "customer-service", "analytics"]
    },
    {
      "name": "Customers.Read",
      "description": "Read customer data",
      "grantedTo": ["customer-service", "analytics"]
    },
    {
      "name": "Metrics.Read",
      "description": "Read metrics and analytics",
      "grantedTo": ["management", "analytics"]
    },
    {
      "name": "DataProduct.Admin",
      "description": "Full administrative access",
      "grantedTo": ["data-product-owners"]
    }
  ]
}
```

---

## Compliance & Privacy

### GDPR Compliance

#### Data Subject Rights

| Right | Implementation | Process |
|-------|----------------|---------|
| **Right to Access** | API endpoint to retrieve personal data | Submit request → Validate identity → Provide data export |
| **Right to Erasure** | Soft delete with flag, hard delete after retention | Submit request → Validate → Mark for deletion → Purge after retention |
| **Right to Rectification** | Update API for corrections | Submit correction → Validate → Update records |
| **Right to Portability** | Export in machine-readable format | Submit request → Generate export (JSON/CSV) |

#### Data Retention Policy

| Data Layer | Retention Period | Rationale |
|------------|-----------------|-----------|
| Bronze (Raw IDocs) | 90 days | Operational needs, troubleshooting |
| Silver (Cleansed) | 2 years | Analytics, historical reporting |
| Gold (Warehouse) | 7 years | Legal, compliance, long-term analytics |
| API Logs | 1 year | Security, audit trail |

### Privacy Impact Assessment

**PII Processing:**
- Customer names and contact information
- Delivery addresses
- Recipient information

**Mitigation:**
- Encryption at rest and in transit
- Row-level security for multi-tenant scenarios
- Access logging and monitoring
- Data minimization (only collect necessary fields)
- Pseudonymization where possible

---

## Monitoring & Reporting

### Governance Dashboards

#### 1. Data Quality Dashboard

**Metrics:**
- Overall quality score (daily, weekly, monthly trends)
- Quality by dimension (completeness, accuracy, validity)
- Failed quality checks
- Quality issues by asset

#### 2. Data Lineage Dashboard

**Metrics:**
- End-to-end lineage coverage
- Orphan assets (no lineage)
- Impact analysis statistics

#### 3. Access & Usage Dashboard

**Metrics:**
- API usage by consumer
- Most accessed assets
- Access violations/denied requests
- User activity by role

#### 4. Compliance Dashboard

**Metrics:**
- Data retention compliance
- PII classification coverage
- GDPR request fulfillment time
- Audit trail completeness

### Automated Reporting

**Weekly Governance Report:**

```python
def generate_weekly_governance_report():
    """
    Generate weekly governance summary report
    """
    report = {
        "report_date": datetime.now().strftime("%Y-%m-%d"),
        "data_quality": {
            "overall_score": get_weekly_avg_quality_score(),
            "trending": get_quality_trend(),
            "issues": get_open_quality_issues(),
            "resolved": get_resolved_quality_issues_count()
        },
        "catalog": {
            "total_assets": count_catalog_assets(),
            "documented_assets": count_documented_assets(),
            "documentation_coverage": calculate_documentation_coverage(),
            "new_assets": count_new_assets_this_week()
        },
        "access": {
            "total_api_calls": count_api_calls_this_week(),
            "unique_users": count_unique_api_users(),
            "access_violations": count_access_violations(),
            "top_consumers": get_top_api_consumers(limit=10)
        },
        "compliance": {
            "gdpr_requests": count_gdpr_requests_this_week(),
            "avg_fulfillment_time": get_avg_gdpr_fulfillment_time(),
            "retention_compliance": check_retention_compliance(),
            "classification_coverage": calculate_classification_coverage()
        }
    }
    
    # Send report
    send_email_report(report, recipients=["governance-team@company.com"])
    
    # Store in database
    store_governance_report(report)
    
    return report
```

---

## Governance Workflows

### Data Product Onboarding

**Process:**

1. **Request Initiation**
   - Submit data product proposal
   - Define business case and use cases
   - Identify stakeholders

2. **Architecture Review**
   - Review technical design
   - Assess data sources and quality
   - Evaluate security requirements

3. **Governance Setup**
   - Register in Purview
   - Define quality rules
   - Set up access controls
   - Configure monitoring

4. **Documentation**
   - Create catalog entries
   - Document business glossary terms
   - Prepare API documentation

5. **Approval & Launch**
   - Data governance board approval
   - Production deployment
   - User training and communication

### Change Management

**Process for Schema Changes:**

1. **Proposal**: Submit change request with impact analysis
2. **Review**: Technical and governance review
3. **Approval**: Governance board approval for breaking changes
4. **Communication**: Notify consumers with timeline
5. **Implementation**: Deploy with versioning
6. **Validation**: Verify lineage and quality post-change

### Incident Response

**Data Quality Incident:**

1. **Detection**: Automated alert or manual report
2. **Assessment**: Evaluate severity and impact
3. **Containment**: Quarantine bad data, switch to backup if needed
4. **Root Cause Analysis**: Identify source of issue
5. **Resolution**: Fix issue and validate
6. **Post-Mortem**: Document lessons learned and improve processes

---

## Appendix

### Governance Metrics KPIs

| KPI | Target | Measurement Frequency |
|-----|--------|----------------------|
| Data Quality Score | > 95% | Daily |
| Catalog Coverage | 100% | Weekly |
| Documentation Completeness | > 90% | Monthly |
| On-Time SLA Compliance | > 99% | Daily |
| Quality Issue Resolution Time | < 24 hours | Per incident |
| API Availability | > 99.9% | Monthly |
| Access Violation Rate | < 0.1% | Weekly |
| GDPR Request Fulfillment | < 30 days | Per request |

### Contact Information

| Role | Contact | Availability |
|------|---------|--------------|
| **Data Governance Team** | governance@company.com | Mon-Fri 9-5 |
| **Data Quality Team** | data-quality@company.com | 24/7 for critical issues |
| **Privacy Officer** | privacy@company.com | Mon-Fri 9-5 |
| **Technical Support** | data-engineering@company.com | 24/7 on-call rotation |

---

**Document Version:** 1.0.0  
**Last Reviewed:** October 23, 2025  
**Next Review:** January 23, 2026  
**Approved By:** Chief Data Officer
