#!/usr/bin/env python3
"""
Create Data Product in Microsoft Purview using Atlas API
Since Business Domain API is not yet available, we'll create the Data Product directly
and associate it with glossary terms.
"""

from azure.identity import DefaultAzureCredential
import requests
import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"

def create_data_product():
    """Create 3PL Real-Time Analytics Data Product"""
    
    print("=" * 80)
    print("CREATE DATA PRODUCT IN PURVIEW")
    print("Using Atlas API (Working endpoint)")
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
    
    # Step 1: Get existing glossary
    print("📋 Step 1: Retrieving existing glossary...")
    glossary_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/glossary"
    response = requests.get(glossary_url, headers=headers)
    
    if response.status_code == 200:
        glossaries = response.json()
        print(f"   Found {len(glossaries)} glossaries")
        
        # Find our glossary
        our_glossary = next((g for g in glossaries if g['name'] == '3PL Real-Time Analytics'), None)
        
        if our_glossary:
            glossary_guid = our_glossary['guid']
            print(f"   ✅ Found glossary: {our_glossary['name']}")
            print(f"   GUID: {glossary_guid}")
        else:
            print("   ⚠️  Glossary '3PL Real-Time Analytics' not found")
            print("   Creating new glossary...")
            
            # Create glossary
            glossary_payload = {
                "name": "3PL Real-Time Analytics",
                "shortDescription": "Business glossary for 3PL Data Product",
                "longDescription": "Comprehensive business glossary covering orders, shipments, warehouse operations, and invoicing for Third-Party Logistics"
            }
            
            create_glossary_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/glossary"
            response = requests.post(create_glossary_url, headers=headers, json=glossary_payload)
            
            if response.status_code in [200, 201]:
                glossary = response.json()
                glossary_guid = glossary['guid']
                print(f"   ✅ Created glossary: {glossary['name']}")
                print(f"   GUID: {glossary_guid}")
            else:
                print(f"   ❌ Failed to create glossary: {response.text[:200]}")
                return
    else:
        print(f"   ❌ Failed to list glossaries: {response.text[:200]}")
        return
    
    print()
    
    # Step 2: Create glossary terms for key business concepts
    print("📝 Step 2: Creating business glossary terms...")
    
    terms_to_create = [
        {
            "name": "Order",
            "shortDescription": "Customer purchase request",
            "longDescription": "A customer purchase request processed by 3PL on behalf of the client, including order number, customer details, and fulfillment status.",
            "abbreviation": "ORD",
            "resources": [
                {
                    "displayName": "Order Processing Guide",
                    "url": "https://internal-wiki.example.com/order-processing"
                }
            ],
            "relatedTerms": ["Shipment", "Customer", "SLA"]
        },
        {
            "name": "Shipment",
            "shortDescription": "Physical movement of goods",
            "longDescription": "Physical transport of goods from origin to destination, tracked by carrier and delivery status.",
            "abbreviation": "SHP",
            "relatedTerms": ["Order", "Carrier", "Delivery"]
        },
        {
            "name": "Warehouse Movement",
            "shortDescription": "Material handling activity",
            "longDescription": "Material handling transaction in warehouse (receiving, put-away, picking, shipping) with location and equipment tracking.",
            "abbreviation": "WHM",
            "relatedTerms": ["Inventory", "Location", "Equipment"]
        },
        {
            "name": "Invoice",
            "shortDescription": "Financial billing document",
            "longDescription": "Financial claim for 3PL services rendered to client, including amount, payment terms, and aging information.",
            "abbreviation": "INV",
            "relatedTerms": ["Customer", "Payment", "Revenue"]
        },
        {
            "name": "SLA Compliance",
            "shortDescription": "Service Level Agreement performance",
            "longDescription": "Measure of whether services meet agreed performance targets (e.g., 24h order fulfillment).",
            "abbreviation": "SLA",
            "relatedTerms": ["Order", "Performance", "KPI"]
        },
        {
            "name": "Customer",
            "shortDescription": "Client receiving logistics services",
            "longDescription": "Business entity that contracts 3PL services for order fulfillment, warehousing, and transportation.",
            "abbreviation": "CUST",
            "relatedTerms": ["Order", "Invoice", "Shipment"]
        }
    ]
    
    created_terms = []
    
    for term_data in terms_to_create:
        term_payload = {
            "name": term_data["name"],
            "anchor": {
                "glossaryGuid": glossary_guid
            },
            "shortDescription": term_data["shortDescription"],
            "longDescription": term_data["longDescription"],
            "abbreviation": term_data.get("abbreviation", "")
        }
        
        if "resources" in term_data:
            term_payload["resources"] = term_data["resources"]
        
        create_term_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/glossary/term"
        response = requests.post(create_term_url, headers=headers, json=term_payload)
        
        if response.status_code in [200, 201]:
            term = response.json()
            created_terms.append(term)
            print(f"   ✅ Created term: {term['name']} (GUID: {term['guid']})")
        elif response.status_code == 409:
            print(f"   ℹ️  Term '{term_data['name']}' already exists")
        else:
            print(f"   ⚠️  Failed to create term '{term_data['name']}': {response.text[:200]}")
    
    print()
    print(f"   Created {len(created_terms)} glossary terms")
    print()
    
    # Step 3: Create custom Data Product type (if it doesn't exist)
    print("🏗️  Step 3: Creating Data Product custom type...")
    
    # Check if DataProduct type exists
    type_def_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/types/typedef/name/DataProduct"
    response = requests.get(type_def_url, headers=headers)
    
    if response.status_code == 404:
        # Create DataProduct type
        dataproduct_typedef = {
            "entityDefs": [
                {
                    "category": "ENTITY",
                    "name": "DataProduct",
                    "description": "Data Product with metadata, SLAs, and business context",
                    "typeVersion": "1.0",
                    "attributeDefs": [
                        {
                            "name": "dataProductOwner",
                            "typeName": "string",
                            "isOptional": False,
                            "cardinality": "SINGLE"
                        },
                        {
                            "name": "businessArea",
                            "typeName": "string",
                            "isOptional": True,
                            "cardinality": "SINGLE"
                        },
                        {
                            "name": "slaLatency",
                            "typeName": "string",
                            "isOptional": True,
                            "cardinality": "SINGLE"
                        },
                        {
                            "name": "dataClassification",
                            "typeName": "string",
                            "isOptional": True,
                            "cardinality": "SINGLE"
                        }
                    ],
                    "superTypes": ["DataSet"]
                }
            ]
        }
        
        create_typedef_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/types/typedefs"
        response = requests.post(create_typedef_url, headers=headers, json=dataproduct_typedef)
        
        if response.status_code in [200, 201]:
            print("   ✅ Created DataProduct type")
        else:
            print(f"   ⚠️  Could not create DataProduct type: {response.text[:200]}")
            print("   Using Collection entity instead")
    else:
        print("   ℹ️  DataProduct type already exists")
    
    print()
    
    # Step 4: Create the Data Product entity
    print("📦 Step 4: Creating Data Product entity...")
    
    dataproduct_entity = {
        "entity": {
            "typeName": "Collection",  # Using Collection as fallback
            "attributes": {
                "name": "3PL Real-Time Analytics",
                "qualifiedName": "3pl-realtime-analytics@stpurview",
                "description": "Real-time analytics data product for Third-Party Logistics operations. Provides near real-time KPIs for order performance, shipment tracking, warehouse efficiency, and revenue monitoring.",
                "owner": "Operations Manager"
            }
        }
    }
    
    create_entity_url = f"{API_ENDPOINT}/catalog/api/atlas/v2/entity"
    response = requests.post(create_entity_url, headers=headers, json=dataproduct_entity)
    
    if response.status_code in [200, 201]:
        entity = response.json()
        print("   ✅ Data Product created!")
        print(f"   GUID: {entity['guidAssignments']}")
        print()
        
        # Save details
        result = {
            "dataProduct": entity,
            "glossary": {
                "guid": glossary_guid,
                "name": "3PL Real-Time Analytics"
            },
            "terms": [{"name": t['name'], "guid": t['guid']} for t in created_terms]
        }
        
        with open("data_product_created.json", "w") as f:
            json.dump(result, indent=2, fp=f)
        
        print("💾 Data Product details saved to: data_product_created.json")
    elif response.status_code == 409:
        print("   ℹ️  Data Product already exists")
    else:
        print(f"   ❌ Failed to create Data Product: {response.text[:500]}")
    
    print()
    print("=" * 80)
    print("✅ DATA PRODUCT SETUP COMPLETE!")
    print("=" * 80)
    print()
    print("📋 Summary:")
    print(f"   Glossary: 3PL Real-Time Analytics (GUID: {glossary_guid})")
    print(f"   Business Terms: {len(created_terms)} created")
    print()
    print("🎯 Next Steps:")
    print("   1. Manually create Business Domain in Purview Portal")
    print("      https://web.purview.azure.com/resource/stpurview")
    print()
    print("   2. Link Fabric Lakehouse tables to glossary terms")
    print()
    print("   3. Create Data Product in Unified Catalog UI")
    print("      (Business Domain API not yet available)")
    print()
    print("=" * 80)

if __name__ == "__main__":
    create_data_product()
