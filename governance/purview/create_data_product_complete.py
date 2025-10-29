#!/usr/bin/env python3
"""
Create Data Product in Microsoft Purview Unified Catalog
Links to the Business Domain created earlier
Reference: https://learn.microsoft.com/en-us/rest/api/purview/purviewdatagovernance/create-data-product
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def create_data_product():
    """Create 3PL Real-Time Analytics Data Product"""
    
    print("=" * 80)
    print("CREATE DATA PRODUCT IN PURVIEW UNIFIED CATALOG")
    print("Using Unified Catalog API (2025-09-15-preview)")
    print("=" * 80)
    print()
    
    # Authenticate
    print("🔐 Authenticating with Azure...")
    credential = DefaultAzureCredential()
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print("✅ Authentication successful!")
    print()
    
    # Step 1: Load Business Domain ID from previous creation
    print("📋 Step 1: Loading Business Domain ID...")
    try:
        with open("business_domain_created.json", "r") as f:
            domain_info = json.load(f)
            domain_id = domain_info.get("id")
            domain_name = domain_info.get("name", "3PL Logistics")
            print(f"   ✅ Found domain: {domain_name}")
            print(f"   Domain ID: {domain_id}")
    except FileNotFoundError:
        print("   ⚠️  business_domain_created.json not found")
        print("   Please run create_business_domain.py first")
        return
    
    print()
    
    # Step 2: Create Data Product payload
    print("📦 Step 2: Preparing Data Product configuration...")
    
    data_product_id = str(uuid.uuid4())
    data_product_name = "3PL Real-Time Analytics"
    
    # Data Product payload following official API schema
    data_product_payload = {
        "id": data_product_id,
        "name": data_product_name,
        "domain": domain_id,  # Link to Business Domain
        "description": "Real-time analytics data product for Third-Party Logistics operations. Provides near real-time KPIs for order performance, shipment tracking, warehouse efficiency, and revenue monitoring. Data is ingested from SAP ERP via Event Hub and processed through medallion architecture (Bronze/Silver/Gold layers).",
        "type": "Analytical",  # Master, Reference, Analytical, AI, Operational, etc.
        "status": "PUBLISHED",
        "businessUse": "Enables 3PL clients and partners to monitor logistics operations in real-time. Key use cases: SLA compliance tracking, shipment visibility, warehouse productivity optimization, invoice aging management, and financial performance analysis.",
        "updateFrequency": "Hourly",  # Data refreshes in near real-time (<5 min)
        "audience": [
            "DataEngineer",
            "BIEngineer", 
            "DataAnalyst",
            "BusinessAnalyst",
            "Executive"
        ],
        "endorsed": True,  # Officially endorsed data product
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",  # Current user
                    "description": "Operations Manager - 3PL Business Unit"
                }
            ],
            "expert": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "Supply Chain Analyst"
                }
            ]
        },
        "documentation": [
            {
                "name": "Data Product Domain Model",
                "url": "https://github.com/flthibau/Fabric-SAP-Idocs/blob/main/governance/3PL-DATA-PRODUCT-DOMAIN-MODEL.md"
            },
            {
                "name": "Architecture Documentation",
                "url": "https://github.com/flthibau/Fabric-SAP-Idocs/blob/main/docs/architecture.md"
            },
            {
                "name": "Business Glossary",
                "url": "https://github.com/flthibau/Fabric-SAP-Idocs/blob/main/governance/BUSINESS-GLOSSARY.md"
            }
        ],
        "termsOfUse": [
            {
                "name": "Data Usage Policy",
                "url": "https://internal-wiki.example.com/data-governance/usage-policy"
            }
        ],
        "managedAttributes": [
            {"name": "latency", "value": "<5 minutes end-to-end"},
            {"name": "availability", "value": "99.9% uptime"},
            {"name": "dataFreshness", "value": "Real-time (streaming)"},
            {"name": "coverage", "value": "Orders, Shipments, Warehouse, Invoices"},
            {"name": "geography", "value": "Global (all 3PL operations)"},
            {"name": "compliance", "value": "GDPR, SOX"},
            {"name": "retentionPeriod", "value": "365 days (2555 for invoices)"}
        ],
        "additionalProperties": {
            "assetCount": 11  # 4 Silver + 7 Gold tables
        },
        "dataQualityScore": 95.0,  # Based on validation results
        "sensitivityLabel": "Internal - Partner Shared"
    }
    
    print(f"   Name: {data_product_name}")
    print(f"   Type: {data_product_payload['type']}")
    print(f"   Domain: {domain_name}")
    print(f"   Status: {data_product_payload['status']}")
    print(f"   Update Frequency: {data_product_payload['updateFrequency']}")
    print(f"   Audience: {', '.join(data_product_payload['audience'])}")
    print()
    
    # Step 3: Create Data Product via API
    print("🔄 Step 3: Creating Data Product via Unified Catalog API...")
    
    # POST {endpoint}/datagovernance/catalog/dataProducts?api-version=2025-09-15-preview
    create_url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts?api-version={API_VERSION}"
    
    print(f"   Endpoint: {create_url}")
    print(f"   Method: POST")
    print()
    
    try:
        response = requests.post(create_url, headers=headers, json=data_product_payload)
        
        print(f"   Status: {response.status_code}")
        
        if response.status_code in [200, 201]:
            print(f"   ✅ SUCCESS! Data Product created!")
            
            try:
                result = response.json()
                print()
                print("=" * 80)
                print("📊 DATA PRODUCT CREATED!")
                print("=" * 80)
                print()
                print(f"   ID: {result.get('id', data_product_id)}")
                print(f"   Name: {result.get('name', data_product_name)}")
                print(f"   Domain: {result.get('domain', domain_id)}")
                print(f"   Type: {result.get('type', 'Analytical')}")
                print(f"   Status: {result.get('status', 'PUBLISHED')}")
                print(f"   Endorsed: {result.get('endorsed', True)}")
                print()
                print("Full response:")
                print(json.dumps(result, indent=2))
                
                # Save result
                with open("data_product_created.json", "w") as f:
                    json.dump(result, f, indent=2)
                
                print()
                print("💾 Response saved to: data_product_created.json")
                
            except Exception as e:
                print(f"   ✅ Success (response parsing issue): {str(e)}")
                result = {
                    "status": "created",
                    "id": data_product_id,
                    "name": data_product_name,
                    "domain": domain_id
                }
            
            success = True
            
        elif response.status_code == 400:
            print(f"   ❌ Bad Request - Invalid payload")
            print()
            print("Error details:")
            print(response.text)
            success = False
            
        elif response.status_code == 401:
            print(f"   ❌ Unauthorized")
            print()
            print("Error details:")
            print(response.text[:500])
            success = False
            
        elif response.status_code == 403:
            print(f"   ❌ Forbidden - Insufficient permissions")
            print()
            print("Error details:")
            print(response.text[:500])
            success = False
            
        elif response.status_code == 404:
            print(f"   ❌ Endpoint not found")
            print()
            print("Error details:")
            print(response.text[:500])
            success = False
            
        elif response.status_code == 409:
            print(f"   ⚠️  Data Product already exists")
            print()
            print("Response:")
            print(response.text[:500])
            success = True
            
        else:
            print(f"   ❌ Unexpected error {response.status_code}")
            print()
            print("Response:")
            print(response.text[:500])
            success = False
    
    except Exception as e:
        print(f"   ❌ Exception occurred: {str(e)}")
        success = False
    
    print()
    
    if success:
        print("=" * 80)
        print("✅ DATA PRODUCT SETUP COMPLETE!")
        print("=" * 80)
        print()
        print("📊 Summary:")
        print(f"   Business Domain: {domain_name} ({domain_id})")
        print(f"   Data Product: {data_product_name}")
        print(f"   Type: Analytical (Real-Time)")
        print(f"   Asset Count: 11 tables (4 Silver + 7 Gold)")
        print(f"   Update Frequency: Hourly (actually <5 min real-time)")
        print(f"   Data Quality Score: 95%")
        print()
        print("🎯 Next Steps:")
        print()
        print("   1. Link Fabric Lakehouse tables to Data Product")
        print("      - Use Data Product Relationships API")
        print("      - Link 11 tables (idoc_*_silver, gold views)")
        print()
        print("   2. Create Business Glossary Terms")
        print("      - Order, Shipment, Warehouse Movement, Invoice")
        print("      - SLA Compliance, Customer, Carrier")
        print()
        print("   3. Define OKRs (Objectives & Key Results)")
        print("      - SLA Compliance: >95%")
        print("      - On-Time Delivery: >92%")
        print("      - Data Freshness: <5 min")
        print()
        print("   4. Configure Data Sharing Policies")
        print("      - Define partner access scopes")
        print("      - Set up row-level security")
        print()
        print("   5. Verify in Purview Portal")
        print(f"      https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print()
    else:
        print("=" * 80)
        print("⚠️  DATA PRODUCT CREATION DID NOT SUCCEED")
        print("=" * 80)
        print()
        print("📋 MANUAL CREATION VIA PURVIEW PORTAL:")
        print()
        print("1. Open Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print()
        print("2. Navigate to: Data Catalog → Unified Catalog → Data Products")
        print()
        print("3. Click: + New Data Product")
        print()
        print("4. Fill in details:")
        print(f"   - Name: {data_product_name}")
        print(f"   - Domain: {domain_name}")
        print(f"   - Type: Analytical")
        print(f"   - Description: {data_product_payload['description'][:100]}...")
        print()
    
    # Save configuration
    with open("data_product_config.json", "w") as f:
        json.dump(data_product_payload, f, indent=2)
    
    print()
    print(f"💾 Configuration saved to: data_product_config.json")
    print()
    print("=" * 80)
    print("📚 API REFERENCES:")
    print("   Create Data Product API:")
    print("   https://learn.microsoft.com/en-us/rest/api/purview/purviewdatagovernance/create-data-product")
    print("=" * 80)

if __name__ == "__main__":
    create_data_product()
