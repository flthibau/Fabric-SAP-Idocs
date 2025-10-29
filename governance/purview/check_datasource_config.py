#!/usr/bin/env python3
"""
Check Purview data source configuration details
"""

from azure.identity import DefaultAzureCredential
from azure.purview.scanning import PurviewScanningClient

# Configuration
PURVIEW_ACCOUNT = "stpurview"
ENDPOINT = f"https://{PURVIEW_ACCOUNT}.scan.purview.azure.com"

def check_data_source_config():
    """Check data source and scan configuration"""
    
    print(f"🔍 Checking Purview scan configuration")
    print(f"   Account: {PURVIEW_ACCOUNT}")
    print()
    
    # Authenticate
    credential = DefaultAzureCredential()
    scan_client = PurviewScanningClient(
        endpoint=ENDPOINT,
        credential=credential
    )
    
    print("✅ Authentication successful!")
    print()
    
    # List all data sources
    print("=" * 80)
    print("DATA SOURCES IN PURVIEW")
    print("=" * 80)
    print()
    
    try:
        data_sources = scan_client.data_sources.list_all()
        
        for ds in data_sources:
            print(f"📁 Data Source: {ds.get('name')}")
            print(f"   Kind: {ds.get('kind')}")
            print(f"   ID: {ds.get('id')}")
            
            # Get properties
            props = ds.get('properties', {})
            if 'endpoint' in props:
                print(f"   Endpoint: {props['endpoint']}")
            if 'resourceId' in props:
                print(f"   Resource ID: {props['resourceId']}")
            if 'collection' in props:
                coll = props['collection']
                if isinstance(coll, dict):
                    print(f"   Collection: {coll.get('referenceName', 'N/A')}")
            
            # List scans for this data source
            print(f"   📋 Scans:")
            try:
                scans = scan_client.scans.list_by_data_source(data_source_name=ds.get('name'))
                
                for scan in scans:
                    print(f"      • {scan.get('name')} (kind: {scan.get('kind')})")
                    
                    # Get scan details
                    scan_props = scan.get('properties', {})
                    if 'scanRulesetName' in scan_props:
                        print(f"        Ruleset: {scan_props['scanRulesetName']}")
                    
                    # Check scan runs
                    try:
                        runs = scan_client.scan_result.list_scan_history(
                            data_source_name=ds.get('name'),
                            scan_name=scan.get('name')
                        )
                        
                        run_list = list(runs)[:3]  # Last 3 runs
                        if run_list:
                            print(f"        Recent runs:")
                            for run in run_list:
                                status = run.get('status', 'Unknown')
                                run_id = run.get('id', 'N/A')
                                start_time = run.get('startTime', 'N/A')
                                print(f"          - {run_id[:8]}... | {status} | {start_time}")
                        
                    except Exception as e:
                        print(f"        No scan history: {str(e)}")
            
            except Exception as e:
                print(f"      Error listing scans: {str(e)}")
            
            print()
    
    except Exception as e:
        print(f"❌ Error listing data sources: {str(e)}")
    
    print()
    print("💡 Insights:")
    print("   • For Fabric/Power BI scans, check if workspace GUID is correct")
    print("   • Fabric capacity must be ON during scan")
    print("   • Check scan history for errors")
    print("   • Purview Portal: https://web.purview.azure.com/resource/stpurview")

if __name__ == "__main__":
    check_data_source_config()
