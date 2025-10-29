"""
Analyze discovered Kusto/KQL assets from Purview scan
"""
import json

# Load discovered assets
with open('discovered_assets.json', 'r', encoding='utf-8') as f:
    assets = json.load(f)

# Filter KQL/Kusto related assets
kql_assets = [
    asset for asset in assets 
    if 'kusto' in asset.get('entityType', '').lower() 
    or 'kql' in asset.get('displayText', '').lower()
    or 'kql' in asset.get('name', '').lower()
    or 'eventhouse' in asset.get('displayText', '').lower()
]

print(f"Found {len(kql_assets)} KQL/Kusto-related assets\n")
print("=" * 100)

# Group by entity type
by_type = {}
for asset in kql_assets:
    entity_type = asset.get('entityType', 'unknown')
    if entity_type not in by_type:
        by_type[entity_type] = []
    by_type[entity_type].append(asset)

# Display summary
for entity_type, items in sorted(by_type.items()):
    print(f"\n{entity_type}: {len(items)} assets")
    print("-" * 100)
    for item in items[:10]:  # Show first 10 of each type
        print(f"  📊 {item.get('displayText', 'N/A')}")
        print(f"     ID: {item.get('id', 'N/A')}")
        print(f"     Qualified Name: {item.get('qualifiedName', 'N/A')[:120]}...")
        print(f"     Collection: {item.get('collectionId', 'N/A')}")
        if item.get('description'):
            print(f"     Description: {item.get('description')}")
        print()

# Look specifically for our 3PL Eventhouse
print("\n" + "=" * 100)
print("Searching for 3PL Eventhouse assets:")
print("=" * 100)

idoc_related = [
    asset for asset in assets
    if 'idoc' in asset.get('displayText', '').lower()
    or 'idoc' in asset.get('name', '').lower()
    or '3pl' in asset.get('displayText', '').lower()
    or '3pl' in asset.get('name', '').lower()
]

print(f"\nFound {len(idoc_related)} IDoc/3PL-related assets:")
for asset in idoc_related:
    print(f"  📊 {asset.get('entityType')}: {asset.get('displayText')}")
    print(f"     Qualified Name: {asset.get('qualifiedName', 'N/A')[:120]}")
    print()

# Export KQL assets to separate file
with open('kql_assets.json', 'w', encoding='utf-8') as f:
    json.dump(kql_assets, f, indent=2, ensure_ascii=False)
    
print(f"\nExported {len(kql_assets)} KQL assets to kql_assets.json")
