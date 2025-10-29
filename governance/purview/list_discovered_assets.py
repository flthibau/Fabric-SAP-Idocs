"""
List Discovered Assets in Purview
Query all assets discovered by the Fabric scan
"""

import os
import json
import logging
from azure.identity import DefaultAzureCredential
import requests
from typing import List, Dict

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PurviewAssetExplorer:
    def __init__(self, purview_account_name: str):
        self.purview_account_name = purview_account_name
        self.catalog_endpoint = f"https://{purview_account_name}.purview.azure.com"
        self.api_version = "2023-09-01"
        
        # Authenticate
        self.credential = DefaultAzureCredential()
        self.token = self.credential.get_token("https://purview.azure.net/.default")
        logger.info(f"Authenticated to Purview account: {purview_account_name}")
    
    def _make_request(self, method: str, url: str, data: dict = None):
        """Make authenticated request to Purview Catalog API"""
        headers = {
            "Authorization": f"Bearer {self.token.token}",
            "Content-Type": "application/json"
        }
        
        # Add API version if not already in URL
        separator = "&" if "?" in url else "?"
        if "api-version" not in url:
            url = f"{url}{separator}api-version={self.api_version}"
        
        response = requests.request(method, url, headers=headers, json=data)
        return response
    
    def search_assets(self, query: str = "*", filters: dict = None, limit: int = 1000) -> List[Dict]:
        """
        Search for assets in the catalog
        
        Args:
            query: Search query (default: * for all)
            filters: Additional filters
            limit: Maximum results
        
        Returns:
            List of asset objects
        """
        url = f"{self.catalog_endpoint}/datamap/api/search/query"
        
        payload = {
            "keywords": query,
            "limit": limit,
            "offset": 0
        }
        
        if filters:
            payload.update(filters)
        
        response = self._make_request("POST", url, data=payload)
        
        if response.status_code == 200:
            result = response.json()
            entities = result.get("value", [])
            logger.info(f"Found {len(entities)} assets")
            return entities
        else:
            logger.error(f"Search failed: {response.status_code}")
            logger.error(response.text)
            return []
    
    def get_entity_by_guid(self, guid: str) -> Dict:
        """Get full entity details by GUID"""
        url = f"{self.catalog_endpoint}/datamap/api/atlas/v2/entity/guid/{guid}"
        response = self._make_request("GET", url)
        
        if response.status_code == 200:
            return response.json().get("entity", {})
        else:
            logger.error(f"Failed to get entity {guid}: {response.status_code}")
            return {}
    
    def list_assets_by_data_source(self, data_source_name: str = "Fabric-JAc") -> List[Dict]:
        """List all assets from a specific data source"""
        logger.info(f"Searching assets from data source: {data_source_name}")
        
        # Search for all assets
        all_assets = self.search_assets(query="*")
        
        # Filter by data source (qualified name contains data source)
        filtered_assets = []
        for asset in all_assets:
            qualified_name = asset.get("qualifiedName", "")
            if data_source_name.lower() in qualified_name.lower() or "fabric" in qualified_name.lower():
                filtered_assets.append(asset)
        
        logger.info(f"Found {len(filtered_assets)} assets from {data_source_name}")
        return filtered_assets
    
    def categorize_assets(self, assets: List[Dict]) -> Dict[str, List[Dict]]:
        """Categorize assets by type (tables, databases, etc.)"""
        categorized = {
            "databases": [],
            "tables": [],
            "columns": [],
            "other": []
        }
        
        for asset in assets:
            entity_type = asset.get("entityType", "").lower()
            
            if "database" in entity_type:
                categorized["databases"].append(asset)
            elif "table" in entity_type or "dataset" in entity_type:
                categorized["tables"].append(asset)
            elif "column" in entity_type:
                categorized["columns"].append(asset)
            else:
                categorized["other"].append(asset)
        
        return categorized
    
    def print_asset_summary(self, assets: List[Dict]):
        """Print a formatted summary of assets"""
        categorized = self.categorize_assets(assets)
        
        print("\n" + "=" * 80)
        print("DISCOVERED ASSETS SUMMARY")
        print("=" * 80)
        
        for category, items in categorized.items():
            if items:
                print(f"\n{category.upper()} ({len(items)}):")
                print("-" * 80)
                
                for item in items:
                    name = item.get("name", "Unknown")
                    entity_type = item.get("entityType", "Unknown")
                    qualified_name = item.get("qualifiedName", "N/A")
                    
                    print(f"  📊 {name}")
                    print(f"     Type: {entity_type}")
                    print(f"     Qualified Name: {qualified_name}")
                    
                    # Show collection if available
                    if "attributes" in item and item["attributes"]:
                        collection = item["attributes"].get("collectionId", "N/A")
                        print(f"     Collection: {collection}")
                    
                    print()
        
        print("=" * 80)
        print(f"TOTAL ASSETS: {len(assets)}")
        print("=" * 80)
    
    def export_assets_to_json(self, assets: List[Dict], filename: str = "discovered_assets.json"):
        """Export assets to JSON file"""
        with open(filename, "w") as f:
            json.dump(assets, f, indent=2, default=str)
        logger.info(f"Exported {len(assets)} assets to {filename}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="List Discovered Assets in Purview")
    parser.add_argument(
        "--data-source",
        type=str,
        default="Fabric-JAc",
        help="Data source name to filter by (default: Fabric-JAc)"
    )
    parser.add_argument(
        "--export",
        action="store_true",
        help="Export results to JSON file"
    )
    args = parser.parse_args()
    
    # Purview account
    PURVIEW_ACCOUNT = "stpurview"
    
    # Create explorer
    explorer = PurviewAssetExplorer(PURVIEW_ACCOUNT)
    
    # List assets from Fabric data source
    assets = explorer.list_assets_by_data_source(args.data_source)
    
    # Print summary
    explorer.print_asset_summary(assets)
    
    # Export if requested
    if args.export:
        explorer.export_assets_to_json(assets)


if __name__ == "__main__":
    main()
