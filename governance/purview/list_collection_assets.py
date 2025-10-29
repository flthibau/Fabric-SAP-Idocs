#!/usr/bin/env python3
"""
List all assets in the 3PL collection in Purview
"""

from azure.identity import DefaultAzureCredential
from azure.purview.catalog import PurviewCatalogClient
import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
COLLECTION_NAME = "3PL"

def list_collection_assets():
    """List all assets in the 3PL collection"""
    
    print(f"🔍 Listing assets in collection: {COLLECTION_NAME}")
    print(f"   Purview account: {PURVIEW_ACCOUNT}")
    print()
    
    credential = DefaultAzureCredential()
    catalog_client = PurviewCatalogClient(
        endpoint=ENDPOINT,
        credential=credential
    )
    
    print("✅ Authentication successful!")
    print()
    
    # Method 1: Search with collection filter
    print("=" * 80)
    print(f"METHOD 1: SEARCH WITH COLLECTION FILTER")
    print("=" * 80)
    print()
    
    search_request = {
        "keywords": "*",
        "filter": {
            "collectionId": COLLECTION_NAME
        },
        "limit": 100
    }
    
    try:
        print(f"🔎 Searching for all assets in collection '{COLLECTION_NAME}'...")
        response = catalog_client.discovery.query(search_request)
        
        if hasattr(response, 'value') and response.value:
            assets = response.value
            print(f"✅ Found {len(assets)} assets")
            print()
            
            # Group by type
            by_type = {}
            for asset in assets:
                asset_type = asset.get('assetType', 'Unknown')
                if asset_type not in by_type:
                    by_type[asset_type] = []
                by_type[asset_type].append(asset)
            
            # Display grouped results
            for asset_type, items in sorted(by_type.items()):
                print(f"📦 {asset_type}: {len(items)} assets")
                for i, asset in enumerate(items, 1):
                    name = asset.get('name', 'N/A')
                    asset_id = asset.get('id', 'N/A')
                    qualified_name = asset.get('qualifiedName', 'N/A')
                    
                    print(f"   {i}. {name}")
                    print(f"      ID: {asset_id}")
                    if len(qualified_name) < 120:
                        print(f"      Qualified Name: {qualified_name}")
                    
                    # Show additional properties
                    if 'description' in asset:
                        desc = asset['description'][:100]
                        print(f"      Description: {desc}...")
                
                print()
        else:
            print("❌ No assets found")
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
    
    print()
    
    # Method 2: Search without filter to see all assets
    print("=" * 80)
    print(f"METHOD 2: BROAD SEARCH (NO FILTER)")
    print("=" * 80)
    print()
    
    try:
        print(f"🔎 Searching for 'lakehouse' or 'idoc' keywords...")
        
        for keyword in ["lakehouse", "idoc", "gold", "silver"]:
            search_request = {
                "keywords": keyword,
                "limit": 20
            }
            
            response = catalog_client.discovery.query(search_request)
            
            if hasattr(response, 'value') and response.value:
                print(f"\n🔍 Keyword '{keyword}': {len(response.value)} results")
                for asset in response.value[:5]:
                    print(f"   • {asset.get('name')} ({asset.get('assetType', 'unknown')})")
                    print(f"     Collection: {asset.get('collectionId', 'N/A')}")
            else:
                print(f"   No results for '{keyword}'")
    
    except Exception as e:
        print(f"❌ Error in broad search: {str(e)}")
    
    print()
    
    # Method 3: Try to query using REST API directly
    print("=" * 80)
    print(f"METHOD 3: LIST ALL ENTITY TYPES")
    print("=" * 80)
    print()
    
    try:
        # Get all type definitions to see what entity types exist
        print("🔎 Fetching all entity type definitions...")
        
        # Note: This uses the Atlas API
        # We'll search for any entity to discover types
        search_all = {
            "keywords": "*",
            "limit": 50
        }
        
        response = catalog_client.discovery.query(search_all)
        
        if hasattr(response, 'value') and response.value:
            all_types = set()
            for asset in response.value:
                all_types.add(asset.get('assetType', 'Unknown'))
            
            print(f"✅ Discovered {len(all_types)} unique asset types:")
            for t in sorted(all_types):
                print(f"   • {t}")
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
    
    print()
    print("=" * 80)
    print(f"💡 SUMMARY")
    print("=" * 80)
    print(f"• Collection: {COLLECTION_NAME}")
    print(f"• Portal: https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print(f"• If assets are visible in Portal but not via API:")
    print(f"  - Check collection name spelling (case-sensitive)")
    print(f"  - Wait 5-10 minutes for indexing")
    print(f"  - Verify API permissions")

if __name__ == "__main__":
    list_collection_assets()
