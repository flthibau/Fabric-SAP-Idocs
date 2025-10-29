"""
Check Eventhouse-3PL-Analytics data source configuration and scans in Purview
"""
from purview_automation import PurviewAutomation
import json

def main():
    purview = PurviewAutomation(
        purview_account_name='stpurview',
        resource_group='MC_flthibau_Westeurope'
    )
    
    # List all data sources
    print('=' * 100)
    print('DATA SOURCES REGISTERED IN PURVIEW')
    print('=' * 100)
    sources = purview.list_data_sources()
    for source in sources:
        print(f'\n📊 {source["name"]}')
        print(f'   Kind: {source["kind"]}')
        print(f'   Collection: {source.get("properties", {}).get("collection", {}).get("referenceName", "N/A")}')
    
    # Get specific data source details
    print('\n' + '=' * 100)
    print('EVENTHOUSE-3PL-ANALYTICS DATA SOURCE DETAILS')
    print('=' * 100)
    
    try:
        eventhouse_source = purview.get_data_source('Eventhouse-3PL-Analytics')
        print(json.dumps(eventhouse_source, indent=2))
    except Exception as e:
        print(f'❌ Error: {e}')
        print('\nℹ️ Data source may not exist or name is different')
    
    # List scans for Eventhouse
    print('\n' + '=' * 100)
    print('SCANS FOR EVENTHOUSE-3PL-ANALYTICS')
    print('=' * 100)
    
    try:
        url = f'{purview.scan_endpoint}/datasources/Eventhouse-3PL-Analytics/scans'
        params = {'api-version': '2018-12-01-preview'}
        response = purview.session.get(url, params=params)
        response.raise_for_status()
        scans = response.json()
        
        if 'value' in scans and len(scans['value']) > 0:
            print(f'\nFound {len(scans["value"])} scan(s):')
            for scan in scans['value']:
                print(f'\n📋 Scan: {scan.get("name")}')
                print(f'   Kind: {scan.get("kind")}')
                print(f'   Properties:')
                print(json.dumps(scan.get('properties', {}), indent=4))
        else:
            print('\n⚠️ No scans found for Eventhouse-3PL-Analytics')
            print('\nℹ️ You may need to create a scan for this data source')
            
    except Exception as e:
        print(f'❌ Error getting scans: {e}')
        print('\nℹ️ This may indicate the data source does not exist')

if __name__ == '__main__':
    main()
