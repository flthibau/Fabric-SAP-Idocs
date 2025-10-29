#!/usr/bin/env python3
"""
Vérifier les assets via Atlas Data Map API
Alternative pour voir les tables liées au Data Product
"""

from azure.identity import DefaultAzureCredential
import requests
import json

PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
DATA_PRODUCT_ID = "818affc4-2deb-439d-939f-ea0a240e4c78"

def check_data_product_via_atlas(credential):
    """Check Data Product entity via Atlas API"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Try to get entity by GUID
    url = f"{API_ENDPOINT}/catalog/api/atlas/v2/entity/guid/{DATA_PRODUCT_ID}"
    
    try:
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            entity = response.json()
            print("\n✅ Data Product Entity (Atlas API):")
            print(json.dumps(entity, indent=2))
            
            # Check for relationships
            if 'entity' in entity:
                relationships = entity['entity'].get('relationshipAttributes', {})
                print(f"\n📊 Relationship Attributes:")
                for key, value in relationships.items():
                    print(f"   {key}: {value}")
            
            return entity
        else:
            print(f"⚠️  Status: {response.status_code}")
            print(f"Response: {response.text[:500]}")
            return None
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return None

def main():
    print("\n" + "=" * 80)
    print("  VÉRIFICATION VIA ATLAS DATA MAP API")
    print("=" * 80)
    
    credential = DefaultAzureCredential()
    
    print(f"\n📦 Data Product ID: {DATA_PRODUCT_ID}")
    
    check_data_product_via_atlas(credential)
    
    print("\n" + "=" * 80)
    print("\n💡 VÉRIFICATION MANUELLE RECOMMANDÉE:")
    print(f"\n   Ouvrir dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}/")
    print(f"   datagovernance/catalog/dataProducts/{DATA_PRODUCT_ID}")
    print("\n   Vérifier l'onglet 'Data assets' pour voir les 11 tables")
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
