"""
Get Eventhouse Cluster URI for Purview Registration

This script retrieves the Eventhouse cluster URI from Fabric
"""

import subprocess
import json
import sys


def get_eventhouse_cluster_uri():
    """
    Get Eventhouse cluster URI using Azure REST API
    
    Returns:
        Cluster URI string
    """
    print("🔍 Searching for Eventhouse cluster URI...\n")
    
    # Method 1: Try to get from Fabric workspace
    try:
        print("Method 1: Querying Fabric workspace...")
        
        # Get workspace ID
        workspace_id = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"
        
        # Use az rest to call Fabric API
        cmd = [
            "az", "rest",
            "--method", "GET",
            "--url", f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items",
            "--headers", "Content-Type=application/json"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            data = json.loads(result.stdout)
            
            # Find Eventhouse item
            for item in data.get("value", []):
                if item.get("type") == "Eventhouse":
                    print(f"✅ Found Eventhouse: {item.get('displayName')}")
                    eventhouse_id = item.get("id")
                    
                    # Get Eventhouse details
                    detail_cmd = [
                        "az", "rest",
                        "--method", "GET",
                        "--url", f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{eventhouse_id}",
                        "--headers", "Content-Type=application/json"
                    ]
                    
                    detail_result = subprocess.run(detail_cmd, capture_output=True, text=True)
                    
                    if detail_result.returncode == 0:
                        detail_data = json.loads(detail_result.stdout)
                        properties = detail_data.get("properties", {})
                        cluster_uri = properties.get("queryServiceUri") or properties.get("ingestionServiceUri")
                        
                        if cluster_uri:
                            print(f"✅ Cluster URI: {cluster_uri}\n")
                            return cluster_uri
        
        print("⚠️ Method 1 failed\n")
    
    except Exception as e:
        print(f"⚠️ Method 1 error: {e}\n")
    
    # Method 2: Manual configuration
    print("Method 2: Using known cluster URI...")
    
    # This is the cluster URI from previous successful queries
    known_cluster_uri = "https://6rxha4yxc46ezfypjp5sfvszzi-lc27f4a2mlbevckqaygbfn6yoa.z1.fabric.microsoft.com"
    
    print(f"✅ Using: {known_cluster_uri}\n")
    return known_cluster_uri


def main():
    """Main execution"""
    cluster_uri = get_eventhouse_cluster_uri()
    
    print("=" * 70)
    print("EVENTHOUSE CLUSTER URI")
    print("=" * 70)
    print(f"\n{cluster_uri}\n")
    print("=" * 70)
    print("\nUse this URI for Purview data source registration:")
    print(f"  python purview_automation.py --cluster-uri '{cluster_uri}'")
    print("=" * 70)
    
    return cluster_uri


if __name__ == "__main__":
    cluster_uri = main()
    sys.exit(0)
