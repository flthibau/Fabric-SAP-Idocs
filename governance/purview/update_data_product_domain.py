#!/usr/bin/env python3
"""
Mettre à jour le Data Product pour pointer vers le nouveau Domain "Supply Chain"
Correction: Domain = "Supply Chain", Data Product = "3PL Logistics Analytics"

AVANT: Data Product pointait vers Domain "3PL Logistics" (trop spécifique)
APRES: Data Product pointe vers Domain "Supply Chain" (domaine métier global)
"""

from azure.identity import DefaultAzureCredential
import requests
import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def update_data_product(credential, data_product_id, new_domain_id):
    """Mettre à jour le Data Product pour pointer vers le nouveau Domain"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # PATCH payload - Only update the domain field
    patch_payload = {
        "domain": new_domain_id
    }
    
    # PATCH endpoint
    url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts/{data_product_id}?api-version={API_VERSION}"
    
    print("\n" + "=" * 80)
    print("  MISE À JOUR DU DATA PRODUCT")
    print("=" * 80)
    print(f"\n📦 Data Product ID: {data_product_id}")
    print(f"🔄 Nouveau Domain ID: {new_domain_id}")
    print(f"\n🔗 Endpoint: {url}")
    print("\n🚀 Mise à jour en cours...")
    
    try:
        response = requests.patch(url, headers=headers, json=patch_payload)
        
        if response.status_code == 200:
            result = response.json()
            print("\n✅ SUCCESS - Data Product mis à jour !")
            print(f"\n📋 Détails:")
            print(f"   ID: {result.get('id')}")
            print(f"   Name: {result.get('name')}")
            print(f"   Domain: {result.get('domain')}")
            print(f"   Type: {result.get('type')}")
            print(f"   Status: {result.get('status')}")
            
            # Save updated result
            with open("data_product_updated.json", "w") as f:
                json.dump(result, f, indent=2)
            
            print(f"\n💾 Résultat sauvegardé: data_product_updated.json")
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
    
    # Load IDs
    try:
        with open("data_product_created.json", "r") as f:
            data_product = json.load(f)
            data_product_id = data_product.get("id")
            old_domain_id = data_product.get("domain")
    except FileNotFoundError:
        print("❌ ERROR: data_product_created.json not found!")
        return
    
    try:
        with open("supply_chain_domain_created.json", "r") as f:
            domain = json.load(f)
            new_domain_id = domain.get("id")
    except FileNotFoundError:
        print("❌ ERROR: supply_chain_domain_created.json not found!")
        return
    
    print(f"\n📊 Configuration:")
    print(f"   Data Product: 3PL Real-Time Analytics")
    print(f"   Ancien Domain: {old_domain_id} (3PL Logistics)")
    print(f"   Nouveau Domain: {new_domain_id} (Supply Chain)")
    
    # Update Data Product
    result = update_data_product(credential, data_product_id, new_domain_id)
    
    if result:
        print("\n" + "=" * 80)
        print("  ARCHITECTURE CORRIGÉE")
        print("=" * 80)
        print("\n✅ Structure finale:")
        print("   Domain: Supply Chain (041de34f-62cf-4c8a-9a17-d1cc823e9538)")
        print("      └── Data Product: 3PL Logistics Analytics")
        print("            ├── Data Assets (9 tables)")
        print("            ├── Business Glossary (8 termes)")
        print("            └── OKRs (3 objectifs + 9 KRs)")
        
        print("\n🌐 Visualiser dans Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
        print(f"   Unified Catalog → Domains → Supply Chain → Data Products")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
