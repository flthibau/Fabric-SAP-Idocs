#!/usr/bin/env python3
"""
Créer le Business Domain "Supply Chain" (domaine métier global)
Ce domain contiendra plusieurs Data Products: 3PL Logistics, Manufacturing, etc.

Correction de l'architecture:
- AVANT: Domain = "3PL Logistics" (trop spécifique)
- APRES: Domain = "Supply Chain" (domaine métier global)
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid
from datetime import datetime

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def create_supply_chain_domain(credential):
    """Créer le Business Domain 'Supply Chain'"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Domain configuration - Supply Chain (global business domain)
    domain_payload = {
        "id": str(uuid.uuid4()),
        "name": "Supply Chain",
        "type": "LineOfBusiness",  # Changed from domainType to type
        "status": "PUBLISHED",
        "description": "Global Supply Chain business domain encompassing logistics, warehousing, transportation, and inventory management. This domain provides a unified governance framework for all supply chain data products including 3PL operations, manufacturing, procurement, and distribution.",
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "Chief Supply Chain Officer"
                }
            ],
            "expert": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "Supply Chain Data Architect"
                }
            ]
        },
        "managedAttributes": [
            {
                "name": "businessArea",
                "value": "Operations"
            },
            {
                "name": "organizationalUnit",
                "value": "Supply Chain & Logistics"
            },
            {
                "name": "criticality",
                "value": "High"
            },
            {
                "name": "dataClassification",
                "value": "Confidential"
            },
            {
                "name": "regulatoryCompliance",
                "value": "GDPR, SOX, Industry Standards"
            },
            {
                "name": "sharingScope",
                "value": "Internal + B2B Partners"
            },
            {
                "name": "industryVertical",
                "value": "Third-Party Logistics (3PL)"
            }
        ],
        "isLeaf": False  # Peut contenir d'autres sous-domains
    }
    
    # POST to create domain
    url = f"{API_ENDPOINT}/datagovernance/catalog/businessdomains?api-version={API_VERSION}"
    
    print("\n" + "=" * 80)
    print("  CRÉATION DU BUSINESS DOMAIN 'SUPPLY CHAIN'")
    print("=" * 80)
    print(f"\n📦 Domain: {domain_payload['name']}")
    print(f"📋 Type: {domain_payload['type']}")
    print(f"📄 Description: {domain_payload['description'][:100]}...")
    print(f"\n🔗 Endpoint: {url}")
    print("\n🚀 Création en cours...")
    
    try:
        response = requests.post(url, headers=headers, json=domain_payload)
        
        if response.status_code == 201:
            result = response.json()
            print("\n✅ SUCCESS - Business Domain créé !")
            print(f"\n📋 Détails:")
            print(f"   ID: {result.get('id')}")
            print(f"   Name: {result.get('name')}")
            print(f"   Type: {result.get('type')}")
            print(f"   Status: {result.get('status')}")
            print(f"   Created: {result.get('createdAt', datetime.now().isoformat())}")
            
            # Save result
            with open("supply_chain_domain_created.json", "w") as f:
                json.dump(result, f, indent=2)
            
            print(f"\n💾 Résultat sauvegardé: supply_chain_domain_created.json")
            
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
    
    # Create Supply Chain domain
    result = create_supply_chain_domain(credential)
    
    if result:
        print("\n" + "=" * 80)
        print("  ARCHITECTURE DE GOUVERNANCE CORRIGÉE")
        print("=" * 80)
        print("\n📊 Structure:")
        print("   Business Domain: Supply Chain (NEW)")
        print("      └── Data Product: 3PL Logistics Analytics (à migrer)")
        print("            ├── Data Assets (9 tables)")
        print("            ├── Business Glossary (8 termes)")
        print("            └── OKRs (3 objectifs + 9 KRs)")
        
        print("\n📝 Prochaines étapes:")
        print("   1. ✅ Domain 'Supply Chain' créé")
        print("   2. ⏳ Mettre à jour Data Product pour pointer vers ce domain")
        print("   3. ⏳ Vérifier que OKRs pointent vers Data Product (pas Domain)")
        print("   4. ⏳ Vérifier que Glossary Terms pointent vers Data Product")
        
        print("\n🌐 Visualiser dans Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print(f"   Unified Catalog → Domains → Supply Chain")
        
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
