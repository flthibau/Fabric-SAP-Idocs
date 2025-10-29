#!/usr/bin/env python3
"""
Créer le Data Product "3PL Logistics Analytics" dans le Domain "Supply Chain"
Architecture correcte: Supply Chain (Domain) → 3PL Logistics Analytics (Data Product)
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def get_supply_chain_domain_id():
    """Load Supply Chain Domain ID"""
    try:
        with open("supply_chain_domain_created.json", "r") as f:
            data = json.load(f)
            return data.get("id")
    except FileNotFoundError:
        print("❌ ERROR: supply_chain_domain_created.json not found!")
        print("   Run: python create_supply_chain_domain.py first")
        exit(1)

def create_data_product(credential, domain_id):
    """Créer le Data Product dans le Domain Supply Chain"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Data Product configuration
    data_product_payload = {
        "id": str(uuid.uuid4()),
        "name": "3PL Logistics Analytics",
        "type": "Analytical",
        "domain": domain_id,  # Supply Chain Domain
        "status": "Draft",
        "endorsed": True,
        "description": "Real-time analytics data product for Third-Party Logistics (3PL) operations. Provides near real-time KPIs for order performance, shipment tracking, warehouse efficiency, and revenue monitoring. Data is ingested from SAP ERP via Event Hub and processed through medallion architecture (Bronze/Silver/Gold layers).",
        "businessUse": "Enables 3PL clients and partners to monitor logistics operations in real-time. Key use cases: SLA compliance tracking, shipment visibility, warehouse productivity optimization, invoice aging management, and financial performance analysis.",
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
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
        "termsOfUse": [
            {
                "name": "Data Usage Policy",
                "url": "https://internal-wiki.example.com/data-governance/usage-policy"
            }
        ],
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
        "sensitivityLabel": "Internal - Partner Shared",
        "audience": [
            "DataEngineer",
            "BIEngineer",
            "DataAnalyst",
            "BusinessAnalyst",
            "Executive"
        ],
        "updateFrequency": "Hourly",
        "managedAttributes": [
            {
                "name": "latency",
                "value": "<5 minutes end-to-end"
            },
            {
                "name": "availability",
                "value": "99.9% uptime"
            },
            {
                "name": "dataFreshness",
                "value": "Real-time (streaming)"
            },
            {
                "name": "coverage",
                "value": "Orders, Shipments, Warehouse, Invoices"
            },
            {
                "name": "geography",
                "value": "Global (all 3PL operations)"
            },
            {
                "name": "compliance",
                "value": "GDPR, SOX"
            },
            {
                "name": "retentionPeriod",
                "value": "365 days (2555 for invoices)"
            },
            {
                "name": "dataQualityScore",
                "value": "95%"
            }
        ]
    }
    
    # POST to create Data Product
    url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts?api-version={API_VERSION}"
    
    print("\n" + "=" * 80)
    print("  CRÉATION DU DATA PRODUCT - SUPPLY CHAIN DOMAIN")
    print("=" * 80)
    print(f"\n📦 Data Product: {data_product_payload['name']}")
    print(f"📋 Type: {data_product_payload['type']}")
    print(f"🏢 Domain: {domain_id} (Supply Chain)")
    print(f"📄 Description: {data_product_payload['description'][:100]}...")
    print(f"\n🔗 Endpoint: {url}")
    print("\n🚀 Création en cours...")
    
    try:
        response = requests.post(url, headers=headers, json=data_product_payload)
        
        if response.status_code == 201:
            result = response.json()
            print("\n✅ SUCCESS - Data Product créé !")
            print(f"\n📋 Détails:")
            print(f"   ID: {result.get('id')}")
            print(f"   Name: {result.get('name')}")
            print(f"   Type: {result.get('type')}")
            print(f"   Domain: {result.get('domain')}")
            print(f"   Status: {result.get('status')}")
            print(f"   Endorsed: {result.get('endorsed')}")
            print(f"   Created: {result.get('systemData', {}).get('createdAt')}")
            
            # Save result
            with open("data_product_supply_chain.json", "w") as f:
                json.dump(result, f, indent=2)
            
            print(f"\n💾 Résultat sauvegardé: data_product_supply_chain.json")
            return result
        else:
            print(f"\n❌ FAILED - Status Code: {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return None

def main():
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Get Supply Chain Domain ID
    domain_id = get_supply_chain_domain_id()
    print(f"\n📦 Supply Chain Domain ID: {domain_id}")
    
    # Create Data Product
    result = create_data_product(credential, domain_id)
    
    if result:
        print("\n" + "=" * 80)
        print("  ARCHITECTURE CRÉÉE")
        print("=" * 80)
        print("\n✅ Structure:")
        print(f"   Domain: Supply Chain ({domain_id})")
        print(f"      └── Data Product: 3PL Logistics Analytics ({result.get('id')})")
        print(f"            ├── Type: Analytical")
        print(f"            ├── Status: Draft (Endorsed)")
        print(f"            ├── Data Quality Score: 95%")
        print(f"            └── Update Frequency: Hourly")
        
        print("\n📝 Prochaines étapes:")
        print("   1. ✅ Data Product créé")
        print("   2. ⏳ Lier les 9 tables Lakehouse (manuel via Portal)")
        print("   3. ⏳ Créer Business Glossary (8 termes)")
        print("   4. ⏳ Créer OKRs (3 Objectives + 9 KRs)")
        
        print("\n🌐 Visualiser dans Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print(f"   Unified Catalog → Domains → Supply Chain → Data Products")
        
        print("\n📋 Data Product ID à utiliser pour lier les tables:")
        print(f"   {result.get('id')}")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
