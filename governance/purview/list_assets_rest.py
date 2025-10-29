#!/usr/bin/env python3
"""
Direct REST API call to Purview to list assets
"""

from azure.identity import DefaultAzureCredential
import requests
import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
CATALOG_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"

def list_assets_rest():
    """Use direct REST API calls to query Purview"""
    
    print(f"🔍 Querying Purview via REST API")
    print(f"   Account: {PURVIEW_ACCOUNT}")
    print()
    
    # Get token
    credential = DefaultAzureCredential()
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print("✅ Authentication successful!")
    print()
    
    # Method 1: Query using Discovery API
    print("=" * 80)
    print("METHOD 1: DISCOVERY QUERY API")
    print("=" * 80)
    print()
    
    discovery_url = f"{CATALOG_ENDPOINT}/datamap/api/search/query?api-version=2023-09-01"
    
    payload = {
        "keywords": "*",
        "limit": 100,
        "offset": 0,
        "filter": {
            "collectionId": "yabwox"  # 3PL collection
        }
    }
    
    try:
        print(f"POST {discovery_url}")
        print(f"Payload: {json.dumps(payload, indent=2)}")
        print()
        
        response = requests.post(discovery_url, headers=headers, json=payload)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            # Pretty print response structure
            print("\n📊 Response structure:")
            print(json.dumps(data, indent=2)[:2000])  # First 2000 chars
            
            if '@search.count' in data:
                print(f"\n✅ Total assets: {data['@search.count']}")
            
            if 'value' in data:
                assets = data['value']
                print(f"✅ Returned {len(assets)} assets in this page")
                
                # Group by entity type
                by_type = {}
                for asset in assets:
                    entity_type = asset.get('entityType', 'Unknown')
                    if entity_type not in by_type:
                        by_type[entity_type] = []
                    by_type[entity_type].append(asset)
                
                print(f"\n📦 Assets by type:")
                for entity_type, items in sorted(by_type.items()):
                    print(f"\n{entity_type}: {len(items)} assets")
                    for i, asset in enumerate(items, 1):
                        name = asset.get('name', asset.get('displayText', 'N/A'))
                        print(f"   {i}. {name}")
                        print(f"      ID: {asset.get('id', 'N/A')[:40]}...")
        else:
            print(f"❌ Error response:")
            print(response.text)
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
    
    print()
    
    # Method 2: Try Atlas Search API
    print("=" * 80)
    print("METHOD 2: ATLAS SEARCH API")
    print("=" * 80)
    print()
    
    atlas_search_url = f"{CATALOG_ENDPOINT}/catalog/api/atlas/v2/search/basic?api-version=2022-03-01-preview"
    
    atlas_payload = {
        "query": "*",
        "limit": 50,
        "offset": 0
    }
    
    try:
        print(f"POST {atlas_search_url}")
        response = requests.post(atlas_search_url, headers=headers, json=atlas_payload)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            if 'value' in data:
                entities = data['value']
                print(f"✅ Found {len(entities)} entities")
                
                for i, entity in enumerate(entities[:5], 1):
                    print(f"\n{i}. {entity.get('qualifiedName', 'N/A')}")
                    print(f"   Type: {entity.get('typeName', 'N/A')}")
                    print(f"   GUID: {entity.get('guid', 'N/A')}")
            else:
                print("Response:")
                print(json.dumps(data, indent=2)[:1000])
        else:
            print(f"❌ Error: {response.text}")
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
    
    print()
    
    # Method 3: List collections
    print("=" * 80)
    print("METHOD 3: LIST ALL COLLECTIONS")
    print("=" * 80)
    print()
    
    collections_url = f"{CATALOG_ENDPOINT}/account/collections?api-version=2019-11-01-preview"
    
    try:
        print(f"GET {collections_url}")
        response = requests.get(collections_url, headers=headers)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            if 'value' in data:
                collections = data['value']
                print(f"✅ Found {len(collections)} collections:")
                
                for coll in collections:
                    name = coll.get('name', 'N/A')
                    friendly_name = coll.get('friendlyName', name)
                    print(f"   • {friendly_name} (name: {name})")
            else:
                print("Response:")
                print(json.dumps(data, indent=2))
        else:
            print(f"❌ Error: {response.text}")
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
    
    print()
    print("🌐 Purview Portal: https://web.purview.azure.com/resource/stpurview")

if __name__ == "__main__":
    list_assets_rest()
