#!/usr/bin/env python3
"""
Link Fabric Lakehouse Tables to Data Product in Microsoft Purview

This script:
1. Searches for Fabric KQL Database tables in Purview Data Map
2. Creates relationships between tables and the Data Product
3. Uses official Unified Catalog API (2025-09-15-preview)

Tables to link (11 total):
- Silver: idoc_orders_silver, idoc_shipments_silver, idoc_warehouse_silver, idoc_invoices_silver
- Gold: orders_daily_summary, sla_performance, shipments_in_transit, warehouse_productivity, 
        revenue_realtime, invoice_aging, customer_performance
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import time

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"
CATALOG_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
ATLAS_API_VERSION = "2022-08-01-preview"

# Tables to link
SILVER_TABLES = [
    "idoc_orders_silver",
    "idoc_shipments_silver", 
    "idoc_warehouse_silver",
    "idoc_invoices_silver"
]

GOLD_TABLES = [
    "orders_daily_summary",
    "sla_performance",
    "shipments_in_transit",
    "warehouse_productivity",
    "revenue_realtime",
    "invoice_aging",
    "customer_performance"
]

ALL_TABLES = SILVER_TABLES + GOLD_TABLES

def get_data_product_id():
    """Load Data Product ID from saved file"""
    try:
        with open("data_product_created.json", "r") as f:
            data = json.load(f)
            return data.get("id")
    except FileNotFoundError:
        print("❌ ERROR: data_product_created.json not found!")
        print("   Run create_data_product_complete.py first")
        exit(1)

def search_fabric_assets(credential, table_names):
    """
    Search for Fabric tables in Purview Data Map using Atlas API
    Uses REST API to find assets by name
    """
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    assets_found = {}
    
    print("\n🔍 Searching for Fabric tables in Purview Data Map...")
    print("=" * 70)
    
    for table_name in table_names:
        try:
            # Use Atlas Search API
            search_url = f"{CATALOG_ENDPOINT}/catalog/api/search/query?api-version={ATLAS_API_VERSION}"
            
            search_payload = {
                "keywords": table_name,
                "limit": 10,
                "filter": {
                    "or": [
                        {"entityType": "kusto_table"},  # Fabric KQL tables
                        {"entityType": "fabric_table"},  # Alternative type
                        {"entityType": "kql_table"}
                    ]
                }
            }
            
            response = requests.post(search_url, headers=headers, json=search_payload)
            
            if response.status_code == 200:
                result = response.json()
                values = result.get('value', [])
                
                # Find exact match
                for asset in values:
                    asset_name = asset.get('name', '')
                    if table_name.lower() == asset_name.lower():
                        asset_id = asset.get('id')
                        qualified_name = asset.get('qualifiedName')
                        assets_found[table_name] = {
                            'id': asset_id,
                            'qualifiedName': qualified_name,
                            'name': asset_name,
                            'type': asset.get('entityType', 'unknown')
                        }
                        print(f"✅ Found: {table_name}")
                        print(f"   ID: {asset_id}")
                        print(f"   Type: {asset.get('entityType')}")
                        break
                
                if table_name not in assets_found:
                    print(f"⚠️  Not found: {table_name}")
            else:
                print(f"⚠️  Search failed for {table_name} (Status: {response.status_code})")
            
            time.sleep(0.5)  # Rate limiting
            
        except Exception as e:
            print(f"❌ Error searching for {table_name}: {str(e)}")
    
    print("=" * 70)
    print(f"\n📊 Found {len(assets_found)} out of {len(table_names)} tables")
    
    return assets_found

def create_relationship_unified_catalog(credential, data_product_id, asset_id, asset_name):
    """
    Create relationship using Unified Catalog API
    POST {endpoint}/datagovernance/catalog/dataProducts/{dataProductId}/relationships
    """
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Create relationship payload
    relationship_payload = {
        f"relationship_{asset_name}": {
            "description": f"Data asset in 3PL Real-Time Analytics: {asset_name}",
            "relationshipType": "Contains",  # Data Product contains this asset
            "entityId": asset_id
        }
    }
    
    # POST to create relationship
    url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts/{data_product_id}/relationships?api-version={API_VERSION}&entityType=DATAASSET"
    
    try:
        response = requests.post(url, headers=headers, json=relationship_payload)
        
        if response.status_code == 200:
            print(f"   ✅ Linked: {asset_name}")
            return True
        else:
            print(f"   ❌ Failed: {asset_name} (Status: {response.status_code})")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ Error linking {asset_name}: {str(e)}")
        return False

def main():
    print("\n" + "=" * 70)
    print("  LINKING FABRIC TABLES TO DATA PRODUCT")
    print("=" * 70)
    
    # Authenticate
    print("\n🔐 Authenticating with Azure...")
    credential = DefaultAzureCredential()
    
    # Get Data Product ID
    data_product_id = get_data_product_id()
    print(f"\n📦 Data Product ID: {data_product_id}")
    
    # Search for Fabric assets
    assets_found = search_fabric_assets(credential, ALL_TABLES)
    
    if not assets_found:
        print("\n⚠️  No assets found in Purview Data Map!")
        print("\nℹ️  POSSIBLE REASONS:")
        print("   1. Tables not yet scanned in Purview Data Map")
        print("   2. Need to run Fabric tenant scan first")
        print("   3. Tables exist but with different names")
        print("\n💡 NEXT STEPS:")
        print("   1. Go to Purview Portal: https://web.purview.azure.com/resource/stpurview")
        print("   2. Navigate to Data Map > Scans")
        print("   3. Run scan on Fabric workspace")
        print("   4. Wait for scan to complete, then re-run this script")
        return
    
    # Create relationships
    print("\n🔗 Creating relationships...")
    print("=" * 70)
    
    success_count = 0
    
    for table_name, asset_info in assets_found.items():
        asset_id = asset_info['id']
        print(f"\n📊 {table_name}...")
        
        if create_relationship_unified_catalog(credential, data_product_id, asset_id, table_name):
            success_count += 1
        
        time.sleep(1)  # Rate limiting
    
    # Summary
    print("\n" + "=" * 70)
    print("  SUMMARY")
    print("=" * 70)
    print(f"\n✅ Successfully linked: {success_count} tables")
    print(f"⚠️  Failed/Not found: {len(ALL_TABLES) - success_count} tables")
    print(f"\n📊 Total tables processed: {len(ALL_TABLES)}")
    
    if success_count > 0:
        print("\n✨ SUCCESS! Data Product now linked to Fabric tables")
        print("\n🌐 View in Purview Portal:")
        print(f"   https://web.purview.azure.com/resource/stpurview/datagovernance/catalog/dataProducts/{data_product_id}")
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    main()
