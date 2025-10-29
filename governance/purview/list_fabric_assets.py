#!/usr/bin/env python3
"""
List all Fabric-related assets discovered in Purview
"""

from azure.identity import DefaultAzureCredential
from azure.purview.catalog import PurviewCatalogClient

# Configuration
PURVIEW_ACCOUNT = "stpurview"
PURVIEW_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"

def list_fabric_assets():
    """List all Fabric assets in Purview"""
    
    print(f"🔍 Connecting to Purview: {PURVIEW_ACCOUNT}")
    print()
    
    credential = DefaultAzureCredential()
    catalog_client = PurviewCatalogClient(
        endpoint=PURVIEW_ENDPOINT,
        credential=credential
    )
    
    print("✅ Authentication successful!")
    print()
    
    # Search for Fabric-related assets
    fabric_types = [
        "Lakehouse Table",
        "fabric_lakehouse",
        "fabric_table", 
        "fabric_warehouse",
        "fabric_dataset",
        "fabric_notebook",
        "powerbi_dataset"
    ]
    
    print("=" * 80)
    print("FABRIC ASSETS IN PURVIEW")
    print("=" * 80)
    print()
    
    total_found = 0
    
    for asset_type in fabric_types:
        print(f"🔎 Searching for type: {asset_type}")
        
        search_request = {
            "keywords": "*",
            "filter": {
                "entityType": asset_type
            },
            "limit": 100
        }
        
        try:
            response = catalog_client.discovery.query(search_request)
            
            if hasattr(response, 'value') and response.value:
                count = len(response.value)
                total_found += count
                print(f"   ✅ Found {count} assets")
                
                # Show first 10
                for i, asset in enumerate(response.value[:10]):
                    name = asset.get('name', 'N/A')
                    qualified_name = asset.get('qualifiedName', 'N/A')
                    print(f"      {i+1}. {name}")
                    if len(qualified_name) < 100:
                        print(f"         QN: {qualified_name}")
                
                if count > 10:
                    print(f"      ... and {count - 10} more")
            else:
                print(f"   ❌ None found")
                
        except Exception as e:
            print(f"   ❌ Error: {str(e)}")
        
        print()
    
    print("=" * 80)
    print(f"📊 Total Fabric assets found: {total_found}")
    print("=" * 80)
    print()
    
    # Try searching for lakehouse specifically
    print("=" * 80)
    print("SEARCHING FOR LAKEHOUSE 'Lakehouse3PLAnalytics'")
    print("=" * 80)
    print()
    
    lakehouse_search = {
        "keywords": "Lakehouse3PLAnalytics",
        "limit": 50
    }
    
    try:
        response = catalog_client.discovery.query(lakehouse_search)
        
        if hasattr(response, 'value') and response.value:
            print(f"✅ Found {len(response.value)} related assets:")
            for asset in response.value:
                print(f"   • {asset.get('name')} ({asset.get('assetType', 'unknown')})")
                print(f"     ID: {asset.get('id', 'N/A')}")
        else:
            print("❌ Lakehouse not found")
    except Exception as e:
        print(f"❌ Error: {str(e)}")
    
    print()
    print("🌐 Purview Portal: https://web.purview.azure.com/resource/stpurview")

if __name__ == "__main__":
    list_fabric_assets()
