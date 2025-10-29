"""
Create Lakehouse in Fabric using REST API
Automates creation of lh-3pl-analytics Lakehouse for Purview integration
"""
import requests
from azure.identity import DefaultAzureCredential
import json
import time

class FabricLakehouseManager:
    """Manage Fabric Lakehouse via REST API"""
    
    def __init__(self, workspace_id: str):
        """
        Initialize Fabric API client
        
        Args:
            workspace_id: Fabric workspace ID (GUID)
        """
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
    
    def create_lakehouse(
        self, 
        display_name: str, 
        description: str = None
    ) -> dict:
        """
        Create a new Lakehouse in the workspace
        
        Args:
            display_name: Lakehouse name (e.g., 'lh-3pl-analytics')
            description: Optional description
        
        Returns:
            Created lakehouse details
        """
        print(f"\n{'='*80}")
        print(f"Creating Lakehouse: {display_name}")
        print(f"{'='*80}")
        
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses"
        
        payload = {
            "displayName": display_name
        }
        
        if description:
            payload["description"] = description
        
        response = self._make_request("POST", endpoint, data=payload)
        
        if response.status_code in [200, 201, 202]:
            lakehouse = response.json()
            
            print(f"\n✅ Lakehouse created successfully!")
            print(f"   ID: {lakehouse.get('id')}")
            print(f"   Name: {lakehouse.get('displayName')}")
            print(f"   Type: {lakehouse.get('type')}")
            
            # Wait a bit for provisioning
            print(f"\n⏳ Waiting for lakehouse provisioning (10 seconds)...")
            time.sleep(10)
            
            return lakehouse
        else:
            raise Exception(f"Failed to create lakehouse: {response.text}")
    
    def list_lakehouses(self) -> list:
        """List all lakehouses in the workspace"""
        print(f"\n{'='*80}")
        print(f"Listing Lakehouses in Workspace")
        print(f"{'='*80}")
        
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses"
        response = self._make_request("GET", endpoint)
        
        if response.status_code == 200:
            result = response.json()
            lakehouses = result.get('value', [])
            
            print(f"\n📊 Found {len(lakehouses)} lakehouse(s):")
            for lh in lakehouses:
                print(f"   - {lh.get('displayName')} (ID: {lh.get('id')})")
            
            return lakehouses
        else:
            print(f"❌ Failed to list lakehouses")
            return []
    
    def get_lakehouse(self, lakehouse_id: str) -> dict:
        """Get lakehouse details"""
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses/{lakehouse_id}"
        response = self._make_request("GET", endpoint)
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"Failed to get lakehouse: {response.text}")
    
    def create_lakehouse_tables_info(self, lakehouse_name: str) -> dict:
        """
        Generate table structure information for the lakehouse
        This will be used to create tables via Spark/SQL
        """
        tables_info = {
            "lakehouse_name": lakehouse_name,
            "bronze_layer": [
                {
                    "name": "idoc_raw",
                    "description": "Raw IDoc messages from Event Hub",
                    "partition_by": ["EventDate"],
                    "columns": [
                        {"name": "MessageID", "type": "STRING"},
                        {"name": "IDocType", "type": "STRING"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "SAPClient", "type": "STRING"},
                        {"name": "Sender", "type": "STRING"},
                        {"name": "EventDate", "type": "TIMESTAMP"},
                        {"name": "Payload", "type": "STRING"},
                        {"name": "ProcessedAt", "type": "TIMESTAMP"}
                    ]
                }
            ],
            "silver_layer": [
                {
                    "name": "idoc_orders_silver",
                    "description": "Parsed SAP Orders",
                    "partition_by": ["OrderDate"],
                    "columns": [
                        {"name": "OrderNumber", "type": "STRING"},
                        {"name": "OrderType", "type": "STRING"},
                        {"name": "OrderDate", "type": "DATE"},
                        {"name": "CustomerNumber", "type": "STRING"},
                        {"name": "CustomerName", "type": "STRING"},
                        {"name": "DeliveryDate", "type": "DATE"},
                        {"name": "TotalValue", "type": "DECIMAL(15,2)"},
                        {"name": "Currency", "type": "STRING"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "ProcessedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "idoc_shipments_silver",
                    "description": "Parsed SAP Shipments",
                    "partition_by": ["ShipmentDate"],
                    "columns": [
                        {"name": "ShipmentNumber", "type": "STRING"},
                        {"name": "OrderNumber", "type": "STRING"},
                        {"name": "ShipmentDate", "type": "DATE"},
                        {"name": "CarrierCode", "type": "STRING"},
                        {"name": "TrackingNumber", "type": "STRING"},
                        {"name": "Status", "type": "STRING"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "ProcessedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "idoc_warehouse_silver",
                    "description": "Parsed Warehouse Movements",
                    "partition_by": ["MovementDate"],
                    "columns": [
                        {"name": "MovementID", "type": "STRING"},
                        {"name": "WarehouseCode", "type": "STRING"},
                        {"name": "MovementType", "type": "STRING"},
                        {"name": "MovementDate", "type": "DATE"},
                        {"name": "Quantity", "type": "INT"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "ProcessedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "idoc_invoices_silver",
                    "description": "Parsed SAP Invoices",
                    "partition_by": ["InvoiceDate"],
                    "columns": [
                        {"name": "InvoiceNumber", "type": "STRING"},
                        {"name": "OrderNumber", "type": "STRING"},
                        {"name": "InvoiceDate", "type": "DATE"},
                        {"name": "Amount", "type": "DECIMAL(15,2)"},
                        {"name": "Currency", "type": "STRING"},
                        {"name": "PaymentStatus", "type": "STRING"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "ProcessedAt", "type": "TIMESTAMP"}
                    ]
                }
            ],
            "gold_layer": [
                {
                    "name": "orders_daily_summary",
                    "description": "Daily order aggregations",
                    "partition_by": ["SummaryDate"],
                    "columns": [
                        {"name": "SummaryDate", "type": "DATE"},
                        {"name": "TotalOrders", "type": "INT"},
                        {"name": "TotalValue", "type": "DECIMAL(18,2)"},
                        {"name": "AvgOrderValue", "type": "DECIMAL(15,2)"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "UpdatedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "sla_performance",
                    "description": "SLA compliance metrics",
                    "partition_by": ["MetricDate"],
                    "columns": [
                        {"name": "MetricDate", "type": "DATE"},
                        {"name": "TotalOrders", "type": "INT"},
                        {"name": "OnTimeDeliveries", "type": "INT"},
                        {"name": "SLACompliancePercent", "type": "DECIMAL(5,2)"},
                        {"name": "SAPSystem", "type": "STRING"},
                        {"name": "UpdatedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "shipments_in_transit",
                    "description": "Real-time shipment tracking",
                    "partition_by": ["TrackingDate"],
                    "columns": [
                        {"name": "ShipmentNumber", "type": "STRING"},
                        {"name": "CurrentStatus", "type": "STRING"},
                        {"name": "DaysInTransit", "type": "INT"},
                        {"name": "EstimatedDelivery", "type": "DATE"},
                        {"name": "TrackingDate", "type": "DATE"},
                        {"name": "UpdatedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "warehouse_productivity_daily",
                    "description": "Daily warehouse productivity metrics",
                    "partition_by": ["ProductivityDate"],
                    "columns": [
                        {"name": "ProductivityDate", "type": "DATE"},
                        {"name": "WarehouseCode", "type": "STRING"},
                        {"name": "TotalMovements", "type": "INT"},
                        {"name": "PalletsPerHour", "type": "DECIMAL(10,2)"},
                        {"name": "Efficiency", "type": "DECIMAL(5,2)"},
                        {"name": "UpdatedAt", "type": "TIMESTAMP"}
                    ]
                },
                {
                    "name": "revenue_recognition_realtime",
                    "description": "Real-time revenue recognition",
                    "partition_by": ["RevenueDate"],
                    "columns": [
                        {"name": "RevenueDate", "type": "DATE"},
                        {"name": "TotalRevenue", "type": "DECIMAL(18,2)"},
                        {"name": "PendingInvoices", "type": "INT"},
                        {"name": "DSO", "type": "INT"},
                        {"name": "UpdatedAt", "type": "TIMESTAMP"}
                    ]
                }
            ]
        }
        
        return tables_info


def main():
    """Main execution"""
    
    # Configuration
    WORKSPACE_ID = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"  # JAc workspace
    LAKEHOUSE_NAME = "Lakehouse3PLAnalytics"
    LAKEHOUSE_DESCRIPTION = "3PL Real-Time Analytics - Delta Lake storage for Purview governance and BI reporting"
    
    print("\n" + "="*80)
    print("FABRIC LAKEHOUSE AUTOMATION")
    print("="*80)
    print(f"\nWorkspace: JAc ({WORKSPACE_ID})")
    print(f"Lakehouse: {LAKEHOUSE_NAME}")
    print("\n" + "="*80)
    
    try:
        # Initialize Fabric client
        fabric = FabricLakehouseManager(workspace_id=WORKSPACE_ID)
        
        # List existing lakehouses
        existing_lakehouses = fabric.list_lakehouses()
        
        # Check if lakehouse already exists
        lakehouse_exists = any(
            lh.get('displayName') == LAKEHOUSE_NAME 
            for lh in existing_lakehouses
        )
        
        if lakehouse_exists:
            print(f"\n⚠️ Lakehouse '{LAKEHOUSE_NAME}' already exists!")
            print(f"   Skipping creation...")
            
            # Get existing lakehouse details
            existing_lh = next(
                lh for lh in existing_lakehouses 
                if lh.get('displayName') == LAKEHOUSE_NAME
            )
            lakehouse = existing_lh
        else:
            # Create new lakehouse
            lakehouse = fabric.create_lakehouse(
                display_name=LAKEHOUSE_NAME,
                description=LAKEHOUSE_DESCRIPTION
            )
        
        # Generate table structure information
        print(f"\n{'='*80}")
        print(f"Table Structure Information")
        print(f"{'='*80}")
        
        tables_info = fabric.create_lakehouse_tables_info(LAKEHOUSE_NAME)
        
        # Save to JSON file
        output_file = "lakehouse_structure.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(tables_info, f, indent=2, ensure_ascii=False)
        
        print(f"\n✅ Table structure saved to: {output_file}")
        
        # Summary
        print(f"\n{'='*80}")
        print(f"SUMMARY")
        print(f"{'='*80}")
        print(f"\n✅ Lakehouse: {lakehouse.get('displayName')}")
        print(f"   ID: {lakehouse.get('id')}")
        print(f"   Workspace: JAc")
        print(f"\n📊 Tables to create:")
        print(f"   - Bronze Layer: {len(tables_info['bronze_layer'])} table(s)")
        print(f"   - Silver Layer: {len(tables_info['silver_layer'])} table(s)")
        print(f"   - Gold Layer: {len(tables_info['gold_layer'])} table(s)")
        print(f"   - Total: {len(tables_info['bronze_layer']) + len(tables_info['silver_layer']) + len(tables_info['gold_layer'])} table(s)")
        
        print(f"\n{'='*80}")
        print(f"NEXT STEPS")
        print(f"{'='*80}")
        print(f"\n1. Configure Eventhouse → Lakehouse synchronization")
        print(f"2. Create Delta tables in Lakehouse (via Mirroring or Pipeline)")
        print(f"3. Trigger Purview scan to discover Lakehouse tables")
        print(f"4. Create Business Domain in Purview")
        print(f"5. Create Data Product with Lakehouse assets")
        
        print(f"\n💡 Lakehouse URL:")
        print(f"   https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{lakehouse.get('id')}")
        
        return lakehouse
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == '__main__':
    result = main()
    
    if result:
        print(f"\n✅ Lakehouse creation successful!")
    else:
        print(f"\n❌ Lakehouse creation failed!")
