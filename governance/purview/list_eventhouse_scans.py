"""
List all scans for Eventhouse-3PL-Analytics data source
"""
import requests
from azure.identity import DefaultAzureCredential
import json

def get_scans_for_data_source(purview_account: str, data_source_name: str):
    """Get all scans for a specific data source"""
    
    # Get Azure AD token
    credential = DefaultAzureCredential()
    token = credential.get_token("https://purview.azure.net/.default")
    
    # Prepare request
    scan_endpoint = f"https://{purview_account}.scan.purview.azure.com"
    url = f"{scan_endpoint}/datasources/{data_source_name}/scans"
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    params = {"api-version": "2018-12-01-preview"}
    
    print(f"🔍 Fetching scans for data source: {data_source_name}")
    print(f"   URL: {url}")
    print()
    
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        result = response.json()
        
        if 'value' in result and len(result['value']) > 0:
            print(f"✅ Found {len(result['value'])} scan(s):")
            print("=" * 100)
            
            for scan in result['value']:
                print(f"\n📋 Scan Name: {scan.get('name')}")
                print(f"   Kind: {scan.get('kind')}")
                print(f"   ID: {scan.get('id')}")
                
                props = scan.get('properties', {})
                print(f"\n   Properties:")
                print(f"   - Scan Rule Set: {props.get('scanRulesetName', 'N/A')}")
                print(f"   - Scan Rule Type: {props.get('scanRulesetType', 'N/A')}")
                print(f"   - Collection: {props.get('collection', {}).get('referenceName', 'N/A')}")
                print(f"   - Created At: {props.get('createdAt', 'N/A')}")
                
                # Check if connector is defined
                if 'connectedVia' in props:
                    print(f"   - Connected Via: {props['connectedVia']}")
                
                print("\n   Full Properties:")
                print(json.dumps(props, indent=4))
                print("\n" + "=" * 100)
        else:
            print("⚠️ No scans found for this data source")
            print("\n💡 You need to create a scan to discover tables in the Eventhouse")
            print("\nTo create a scan:")
            print("1. Open Purview Portal: https://web.purview.azure.com")
            print("2. Navigate to Data Map → Sources")
            print("3. Find 'Eventhouse-3PL-Analytics' data source")
            print("4. Click 'New Scan'")
            print("5. Configure scan settings:")
            print("   - Scan name: e.g., 'Scan-Eventhouse-3PL'")
            print("   - Credential: Select appropriate credential")
            print("   - Database selection: Select all or specific databases")
            print("6. Set scan schedule (once or recurring)")
            print("7. Run scan to discover all tables")
            
        return result
        
    elif response.status_code == 404:
        print(f"❌ Data source '{data_source_name}' not found")
        print("\n   Available data sources:")
        
        # List all data sources
        list_url = f"{scan_endpoint}/datasources"
        list_response = requests.get(list_url, headers=headers, params=params)
        if list_response.status_code == 200:
            sources = list_response.json()
            for source in sources.get('value', []):
                print(f"   - {source['name']} (kind: {source['kind']})")
    else:
        print(f"❌ Error {response.status_code}: {response.text}")
        
    return None

if __name__ == '__main__':
    purview_account = 'stpurview'
    data_source_name = 'Eventhouse-3PL-Analytics'
    
    get_scans_for_data_source(purview_account, data_source_name)
