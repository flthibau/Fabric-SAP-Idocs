"""
Automate Lakehouse Shortcuts Creation for Eventhouse OneLake Delta Tables
"""
import requests
from azure.identity import DefaultAzureCredential
import json
import time

class FabricShortcutManager:
    """Manage Fabric Lakehouse Shortcuts via REST API"""
    
    def __init__(self, workspace_id: str):
        """Initialize Fabric API client"""
        self.workspace_id = workspace_id
        self.base_url = "https://api.fabric.microsoft.com/v1"
        
        # Get Azure AD token for Fabric
        self.credential = DefaultAzureCredential()
        self.token = self._get_token()
        
        print(f"✅ Authenticated to Fabric API")
        print(f"   Workspace ID: {workspace_id}")
    
    def _get_token(self) -> str:
        """Get Azure AD access token for Fabric API"""
        try:
            token = self.credential.get_token("https://api.fabric.microsoft.com/.default")
            return token.token
        except Exception as e:
            print(f"❌ Failed to get Azure AD token: {e}")
            raise
    
    def _make_request(
        self, 
        method: str, 
        endpoint: str, 
        data: dict = None
    ) -> requests.Response:
        """Make authenticated REST API request to Fabric"""
        url = f"{self.base_url}{endpoint}"
        
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        print(f"\n🔄 {method} {endpoint}")
        
        response = requests.request(
            method=method,
            url=url,
            headers=headers,
            json=data
        )
        
        if response.status_code >= 400:
            print(f"❌ Error {response.status_code}: {response.text}")
        else:
            print(f"✅ Success {response.status_code}")
        
        return response
    
    def create_onelake_shortcut(
        self,
        lakehouse_id: str,
        shortcut_name: str,
        onelake_path: str,
        target_location: str = "Tables"
    ) -> dict:
        """
        Create a OneLake shortcut in Lakehouse
        
        Args:
            lakehouse_id: Lakehouse ID (GUID)
            shortcut_name: Name for the shortcut
            onelake_path: OneLake path (https://onelake.dfs.fabric.microsoft.com/...)
            target_location: Where to create shortcut (Tables or Files)
        
        Returns:
            Shortcut details
        """
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses/{lakehouse_id}/shortcuts"
        
        # Parse OneLake path
        # Format: https://onelake.dfs.fabric.microsoft.com/{workspace_id}/{item_id}/Tables/{table_name}
        path_parts = onelake_path.replace("https://onelake.dfs.fabric.microsoft.com/", "").split("/")
        source_workspace_id = path_parts[0]
        source_item_id = path_parts[1]
        source_path = "/".join(path_parts[2:])  # Tables/table_name
        
        payload = {
            "path": f"{target_location}/{shortcut_name}",
            "name": shortcut_name,
            "target": {
                "oneLake": {
                    "workspaceId": source_workspace_id,
                    "itemId": source_item_id,
                    "path": source_path
                }
            }
        }
        
        print(f"\n📊 Creating shortcut: {shortcut_name}")
        print(f"   Target: {target_location}/{shortcut_name}")
        print(f"   Source: {source_path}")
        
        response = self._make_request("POST", endpoint, data=payload)
        
        if response.status_code in [200, 201]:
            shortcut = response.json()
            print(f"   ✅ Shortcut created successfully!")
            return shortcut
        else:
            print(f"   ⚠️ Failed to create shortcut (might already exist or table not ready)")
            return None
    
    def create_all_shortcuts(
        self,
        lakehouse_id: str,
        eventhouse_onelake_base: str,
        tables: list
    ):
        """
        Create shortcuts for all Eventhouse tables
        
        Args:
            lakehouse_id: Lakehouse ID
            eventhouse_onelake_base: Base OneLake path (e.g., https://onelake.dfs.fabric.microsoft.com/.../Tables/)
            tables: List of table names
        """
        print(f"\n{'='*80}")
        print(f"Creating Shortcuts for {len(tables)} Tables")
        print(f"{'='*80}")
        
        results = {
            "success": [],
            "failed": [],
            "skipped": []
        }
        
        for table_name in tables:
            try:
                # Construct OneLake path for this table
                table_path = f"{eventhouse_onelake_base}{table_name}"
                
                # Create shortcut
                shortcut = self.create_onelake_shortcut(
                    lakehouse_id=lakehouse_id,
                    shortcut_name=table_name,
                    onelake_path=table_path,
                    target_location="Tables"
                )
                
                if shortcut:
                    results["success"].append(table_name)
                else:
                    results["failed"].append(table_name)
                
                # Small delay between requests
                time.sleep(1)
                
            except Exception as e:
                print(f"   ❌ Error: {e}")
                results["failed"].append(table_name)
        
        # Summary
        print(f"\n{'='*80}")
        print(f"SHORTCUT CREATION SUMMARY")
        print(f"{'='*80}")
        print(f"\n✅ Success: {len(results['success'])} shortcut(s)")
        for name in results["success"]:
            print(f"   - {name}")
        
        if results["failed"]:
            print(f"\n❌ Failed: {len(results['failed'])} shortcut(s)")
            for name in results["failed"]:
                print(f"   - {name}")
        
        return results


def main():
    """Main execution"""
    
    # Configuration
    WORKSPACE_ID = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"  # JAc workspace
    LAKEHOUSE_ID = "21a1bc2d-92e4-41fb-8ca8-1c16569fc483"  # Lakehouse3PLAnalytics
    EVENTHOUSE_ID = "5c2c08ee-cb8f-4248-a1c8-ea35a4e6e057"  # kqldbsapidoc
    
    # OneLake base path
    ONELAKE_BASE = f"https://onelake.dfs.fabric.microsoft.com/{WORKSPACE_ID}/{EVENTHOUSE_ID}/Tables/"
    
    # Tables to create shortcuts for
    TABLES = [
        # Bronze
        "idoc_raw",
        
        # Silver
        "idoc_orders_silver",
        "idoc_shipments_silver",
        "idoc_warehouse_silver",
        "idoc_invoices_silver",
        
        # Gold (Materialized Views)
        "orders_daily_summary",
        "sla_performance",
        "shipments_in_transit",
        "warehouse_productivity_daily",
        "revenue_recognition_realtime"
    ]
    
    print("\n" + "="*80)
    print("FABRIC LAKEHOUSE SHORTCUTS AUTOMATION")
    print("="*80)
    print(f"\nWorkspace: JAc ({WORKSPACE_ID})")
    print(f"Lakehouse: Lakehouse3PLAnalytics ({LAKEHOUSE_ID})")
    print(f"Eventhouse: kqldbsapidoc ({EVENTHOUSE_ID})")
    print(f"\nOneLake Base Path:")
    print(f"  {ONELAKE_BASE}")
    print(f"\nTables to create shortcuts for: {len(TABLES)}")
    print("\n" + "="*80)
    
    # Wait confirmation
    print("\n⏳ IMPORTANT: OneLake Availability must be enabled first!")
    print("   Have you activated OneLake Availability on all tables? (yes/no)")
    
    # For automation, we'll proceed directly
    # In interactive mode, you could add input() here
    
    print("\n🚀 Proceeding with shortcut creation...")
    time.sleep(2)
    
    try:
        # Initialize Fabric client
        fabric = FabricShortcutManager(workspace_id=WORKSPACE_ID)
        
        # Create all shortcuts
        results = fabric.create_all_shortcuts(
            lakehouse_id=LAKEHOUSE_ID,
            eventhouse_onelake_base=ONELAKE_BASE,
            tables=TABLES
        )
        
        # Final summary
        print(f"\n{'='*80}")
        print(f"AUTOMATION COMPLETE")
        print(f"{'='*80}")
        
        if len(results["success"]) == len(TABLES):
            print(f"\n🎉 SUCCESS! All {len(TABLES)} shortcuts created!")
        elif len(results["success"]) > 0:
            print(f"\n⚠️ PARTIAL SUCCESS: {len(results['success'])}/{len(TABLES)} shortcuts created")
            print(f"\nℹ️ Some tables may not be ready yet in OneLake")
            print(f"   Wait 2-3 minutes and retry for failed tables")
        else:
            print(f"\n❌ FAILED: No shortcuts created")
            print(f"\nℹ️ OneLake Delta tables may not be ready yet")
            print(f"   Please wait 2-5 minutes after enabling OneLake Availability")
        
        print(f"\n{'='*80}")
        print(f"NEXT STEPS")
        print(f"{'='*80}")
        print(f"\n1. Verify shortcuts in Lakehouse:")
        print(f"   https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{LAKEHOUSE_ID}")
        print(f"\n2. Test shortcuts in SQL Endpoint:")
        print(f"   SELECT * FROM INFORMATION_SCHEMA.TABLES;")
        print(f"\n3. Trigger Purview scan:")
        print(f"   cd governance/purview")
        print(f"   python purview_automation.py")
        
        return results
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == '__main__':
    result = main()
    
    if result and len(result["success"]) > 0:
        print(f"\n✅ Shortcut creation successful!")
    else:
        print(f"\n⚠️ Please check errors above and retry if needed")
