#!/usr/bin/env python3
"""
Create Business Domain (Governance Domain) in Microsoft Purview Unified Catalog
Uses the official Unified Catalog API (Public Preview - 2025-09-15-preview)
Reference: https://learn.microsoft.com/en-us/rest/api/purview/purviewdatagovernance/create-domain
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid

# Configuration
PURVIEW_ACCOUNT = "stpurview"
# Unified Catalog API endpoint
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def create_business_domain():
    """Create 3PL Logistics Business Domain using official Unified Catalog API"""
    
    print("=" * 80)
    print("CREATE BUSINESS DOMAIN IN PURVIEW UNIFIED CATALOG")
    print("Using Unified Catalog API (2025-09-15-preview)")
    print("=" * 80)
    print()
    
    # Authenticate with purview.azure.net scope
    print("🔐 Authenticating with Azure...")
    credential = DefaultAzureCredential()
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print("✅ Authentication successful!")
    print(f"   Token scope: https://purview.azure.net")
    print()
    
    # Business Domain payload (following official API schema)
    # Reference: https://learn.microsoft.com/en-us/rest/api/purview/purviewdatagovernance/create-domain
    domain_id = str(uuid.uuid4())
    domain_name = "3PL Logistics"
    
    domain_payload = {
        "id": domain_id,
        "name": domain_name,
        "description": "Governance domain for Third-Party Logistics (3PL) operations including SAP order management, shipments, warehousing, and invoicing. This domain encompasses real-time analytics and KPIs for logistics performance monitoring.",
        "type": "LineOfBusiness",  # FunctionalUnit, LineOfBusiness, DataDomain, Regulatory, Project
        "status": "PUBLISHED",
        "isRestricted": False,
        "thumbnail": {
            "color": "#0078D4"  # Azure blue
        },
        "managedAttributes": [
            {"name": "businessArea", "value": "Supply Chain & Logistics"},
            {"name": "organizationalUnit", "value": "Operations"},
            {"name": "criticality", "value": "High"},
            {"name": "dataClassification", "value": "Partner Shared"},
            {"name": "sharingScope", "value": "B2B - External Partners"}
        ]
    }
    
    print("📋 Business Domain Configuration:")
    print(f"   ID: {domain_id}")
    print(f"   Name: {domain_name}")
    print(f"   Type: {domain_payload['type']}")
    print(f"   Status: {domain_payload['status']}")
    print(f"   Description: {domain_payload['description'][:80]}...")
    print()
    
    # Official endpoint from Microsoft documentation
    # POST {endpoint}/datagovernance/catalog/businessdomains?api-version=2025-09-15-preview
    create_domain_url = f"{API_ENDPOINT}/datagovernance/catalog/businessdomains?api-version={API_VERSION}"
    
    print("🔄 Creating Business Domain via Unified Catalog API...")
    print(f"   Endpoint: {create_domain_url}")
    print(f"   Method: POST")
    print()
    
    try:
        response = requests.post(create_domain_url, headers=headers, json=domain_payload)
        
        print(f"   Status: {response.status_code}")
        
        if response.status_code in [200, 201]:
            print(f"   ✅ SUCCESS! Business Domain created!")
            try:
                result = response.json()
                print()
                print("=" * 80)
                print("📊 BUSINESS DOMAIN CREATED!")
                print("=" * 80)
                print()
                print(f"   ID: {result.get('id', domain_id)}")
                print(f"   Name: {result.get('name', domain_name)}")
                print(f"   Type: {result.get('type', 'LineOfBusiness')}")
                print(f"   Status: {result.get('status', 'PUBLISHED')}")
                print()
                print("Full response:")
                print(json.dumps(result, indent=2))
                
                # Save result
                with open("business_domain_created.json", "w") as f:
                    json.dump(result, f, indent=2)
                print()
                print("💾 Response saved to: business_domain_created.json")
                
            except Exception as e:
                print(f"   ✅ Success (response parsing issue): {str(e)}")
                result = {"status": "created", "id": domain_id, "name": domain_name}
            
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
            print()
            print("💡 Solution: Ensure you have 'Data Curator' or 'Collection Admin' role")
            success = False
            
        elif response.status_code == 403:
            print(f"   ❌ Forbidden - Insufficient permissions")
            print()
            print("Error details:")
            print(response.text[:500])
            print()
            print("💡 Solution: Request 'Data Curator' role in Purview")
            print(f"   Portal: https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
            success = False
            
        elif response.status_code == 404:
            print(f"   ❌ Endpoint not found")
            print()
            print("Error details:")
            print(response.text[:500])
            print()
            print("⚠️  The API endpoint may not be available in your Purview instance yet")
            print("   The Unified Catalog API is in Public Preview (Oct 2025)")
            success = False
            
        elif response.status_code == 409:
            print(f"   ⚠️  Domain already exists")
            print()
            print("Response:")
            print(response.text[:500])
            success = True  # Domain exists, so it's OK
            
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
    
    if not success:
        print("=" * 80)
        print("⚠️  API CALL DID NOT SUCCEED")
        print("=" * 80)
        print()
        print("📋 MANUAL CREATION VIA PURVIEW PORTAL:")
        print()
        print("1. Open Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print()
        print("2. Navigate to: Data Catalog → Unified Catalog → Domains")
        print()
        print("3. Click: + New Domain")
        print()
        print("4. Fill in the following details:")
        print()
        print("   📝 BASIC INFORMATION:")
        print(f"      Name: {domain_name}")
        print(f"      Type: {domain_payload['type']}")
        print(f"      Description:")
        print(f"      {domain_payload['description']}")
        print()
        print("   🏷️  MANAGED ATTRIBUTES:")
        for attr in domain_payload['managedAttributes']:
            print(f"      {attr['name']}: {attr['value']}")
        print()
        print("5. Click: Create")
        print()
    else:
        print("=" * 80)
        print("✅ BUSINESS DOMAIN SETUP COMPLETE!")
        print("=" * 80)
        print()
        print("🎯 Next Steps:")
        print()
        print("   1. Create Data Product in the domain")
        print("      - Link Fabric Lakehouse tables")
        print("      - Define SLAs and OKRs")
        print()
        print("   2. Create Business Glossary")
        print("      - Define business terms (Order, Shipment, SLA, etc.)")
        print()
        print("   3. Link Fabric Collection to Domain")
        print("      - Associate collection '3PL' with the domain")
        print()
    
    # Save configuration for reference
    with open("business_domain_config.json", "w") as f:
        json.dump(domain_payload, f, indent=2)
    
    print()
    print(f"💾 Configuration saved to: business_domain_config.json")
    print()
    print(f"🌐 Purview Portal: https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print()
    print("=" * 80)
    print("📚 API REFERENCES:")
    print("   Create Domain API:")
    print("   https://learn.microsoft.com/en-us/rest/api/purview/purviewdatagovernance/create-domain")
    print()
    print("   Unified Catalog Overview:")
    print("   https://learn.microsoft.com/en-us/rest/api/purview/unified-catalog-api-overview")
    print()
    print("   Authentication:")
    print("   https://learn.microsoft.com/en-us/purview/data-gov-api-rest-data-plane")
    print("=" * 80)

if __name__ == "__main__":
    create_business_domain()
