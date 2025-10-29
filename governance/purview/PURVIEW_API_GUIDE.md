# Microsoft Purview API Reference Guide

## 📋 Overview

This guide documents the correct way to use Microsoft Purview APIs with Python, based on hands-on experience with the Purview Data Map and Catalog APIs.

**Last Updated:** October 28, 2025  
**Purview Account:** stpurview  
**API Version:** 2023-09-01 (Data Map), 2019-11-01-preview (Collections)

---

## 🚨 Critical Lessons Learned

### 1. **Use `/datamap/` endpoint, NOT `/catalog/`**

❌ **WRONG (Old API - Returns 405 error):**
```python
url = f"https://{account}.purview.azure.com/catalog/api/search/query?api-version=2023-09-01"
```

✅ **CORRECT (New API):**
```python
url = f"https://{account}.purview.azure.com/datamap/api/search/query?api-version=2023-09-01"
```

### 2. **Python SDK (`azure-purview-catalog`) Uses Outdated API**

The official Python SDK `azure.purview.catalog.PurviewCatalogClient` still uses the old `/catalog/` endpoint and may not return results even when assets exist in Purview.

**Solution:** Use direct REST API calls with `requests` library.

### 3. **Collection Names vs Collection IDs**

Collections have both a **friendly name** (displayed in Portal) and an **internal name** (used in API):

| Friendly Name | Internal Name (collectionId) |
|--------------|------------------------------|
| 3PL          | yabwox                       |
| stpurview    | stpurview                    |

**Always use the internal name in API filters.**

### 4. **Entity Type Names**

Fabric Lakehouse assets use specific entity type names:

| Asset Type in Portal | entityType in API         |
|---------------------|---------------------------|
| Lakehouse Table     | `fabric_lakehouse_table`  |
| Lakehouse           | `fabric_lakehouse`        |
| Lake Warehouse      | `fabric_lake_warehouse`   |
| Kusto Database      | `fabric_kusto_database`   |
| Synapse Notebook    | `fabric_synapse_notebook` |
| Workspace           | `fabric_workspace`        |

---

## 🔧 Working Code Examples

### Authentication

```python
from azure.identity import DefaultAzureCredential

# Get Azure AD token for Purview
credential = DefaultAzureCredential()
token = credential.get_token("https://purview.azure.net/.default")

headers = {
    "Authorization": f"Bearer {token.token}",
    "Content-Type": "application/json"
}
```

### List All Collections

```python
import requests

PURVIEW_ACCOUNT = "stpurview"
url = f"https://{PURVIEW_ACCOUNT}.purview.azure.com/account/collections?api-version=2019-11-01-preview"

response = requests.get(url, headers=headers)

if response.status_code == 200:
    collections = response.json()['value']
    for coll in collections:
        print(f"Friendly Name: {coll['friendlyName']}")
        print(f"Internal Name: {coll['name']}")  # Use this for collectionId filter
```

### Search Assets in a Collection

```python
import requests
import json

PURVIEW_ACCOUNT = "stpurview"
COLLECTION_ID = "yabwox"  # Internal name, not friendly name

# Use /datamap/ endpoint (not /catalog/)
url = f"https://{PURVIEW_ACCOUNT}.purview.azure.com/datamap/api/search/query?api-version=2023-09-01"

payload = {
    "keywords": "*",           # Wildcard to get all assets
    "limit": 100,             # Max results per page
    "offset": 0,              # Pagination offset
    "filter": {
        "collectionId": COLLECTION_ID  # Filter by collection
    }
}

response = requests.post(url, headers=headers, json=payload)

if response.status_code == 200:
    data = response.json()
    
    total_count = data.get('@search.count', 0)
    assets = data.get('value', [])
    
    print(f"Total assets: {total_count}")
    print(f"Returned: {len(assets)}")
    
    for asset in assets:
        print(f"Name: {asset['name']}")
        print(f"Type: {asset['entityType']}")
        print(f"ID: {asset['id']}")
        print(f"Collection: {asset['collectionId']}")
        print()
```

### Search Specific Asset Types

```python
# Search only for Lakehouse Tables
payload = {
    "keywords": "*",
    "filter": {
        "collectionId": "yabwox",
        "entityType": "fabric_lakehouse_table"  # Specific type filter
    },
    "limit": 100
}

response = requests.post(url, headers=headers, json=payload)
```

### Search by Keywords

```python
# Search for assets with "gold" in the name
payload = {
    "keywords": "gold",  # Search term
    "filter": {
        "collectionId": "yabwox"
    },
    "limit": 50
}

response = requests.post(url, headers=headers, json=payload)
```

### Group Assets by Type

```python
if response.status_code == 200:
    assets = response.json()['value']
    
    # Group by entity type
    by_type = {}
    for asset in assets:
        entity_type = asset.get('entityType', 'Unknown')
        if entity_type not in by_type:
            by_type[entity_type] = []
        by_type[entity_type].append(asset)
    
    # Display grouped results
    for entity_type, items in sorted(by_type.items()):
        print(f"\n{entity_type}: {len(items)} assets")
        for asset in items:
            print(f"   • {asset['name']}")
```

---

## 📊 Response Structure

### Successful Search Response

```json
{
  "@search.count": 16,
  "value": [
    {
      "objectType": "Tables",
      "updateBy": "ServiceAdmin",
      "id": "004e8bb1-721d-47f8-8f19-67f6f6f60000",
      "collectionId": "yabwox",
      "displayText": "idoc_invoices_silver",
      "isIndexed": true,
      "qualifiedName": "https://app.fabric.microsoft.com/groups/...",
      "entityType": "fabric_lakehouse_table",
      "updateTime": 1761637200769,
      "domainId": "stpurview",
      "assetType": ["Fabric"],
      "createBy": "ServiceAdmin",
      "createTime": 1761637197362,
      "name": "idoc_invoices_silver",
      "@search.score": 34.786293
    }
  ]
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `@search.count` | Total number of matching assets |
| `value` | Array of asset objects |
| `name` | Asset name |
| `displayText` | Display name (may differ from name) |
| `entityType` | Type identifier (e.g., `fabric_lakehouse_table`) |
| `assetType` | Array of broader categories (e.g., `["Fabric"]`) |
| `collectionId` | Internal collection name |
| `id` | Unique asset GUID |
| `qualifiedName` | Full URL/path to asset |
| `isIndexed` | Whether asset is searchable |

---

## 🔍 Common Use Cases

### 1. Find All Gold Materialized Lake Views

```python
payload = {
    "keywords": "gold_*",  # Wildcard search
    "filter": {
        "collectionId": "yabwox",
        "entityType": "fabric_lakehouse_table"
    },
    "limit": 50
}
```

### 2. Find All Tables in a Lakehouse

```python
# Filter by qualifiedName pattern
payload = {
    "keywords": "*",
    "filter": {
        "collectionId": "yabwox",
        "entityType": "fabric_lakehouse_table"
        # Note: Additional filtering by lakehouse needs post-processing
    },
    "limit": 100
}

# Post-filter by qualifiedName
assets = response.json()['value']
lakehouse_id = "f6c1a6af-d3c9-4c00-ab80-4c5b2669b99f"
lakehouse_tables = [
    a for a in assets 
    if lakehouse_id in a.get('qualifiedName', '')
]
```

### 3. Count Assets by Type in Collection

```python
response = requests.post(url, headers=headers, json={
    "keywords": "*",
    "filter": {"collectionId": "yabwox"},
    "limit": 1000
})

assets = response.json()['value']
type_counts = {}
for asset in assets:
    entity_type = asset['entityType']
    type_counts[entity_type] = type_counts.get(entity_type, 0) + 1

for entity_type, count in sorted(type_counts.items()):
    print(f"{entity_type}: {count}")
```

---

## ⚙️ Environment Setup

### Required Python Packages

```bash
pip install azure-identity requests
```

### Authentication Methods

**Azure CLI (Recommended for local development):**
```bash
az login --tenant <tenant-id>
```

**Managed Identity (for Azure services):**
```python
from azure.identity import ManagedIdentityCredential
credential = ManagedIdentityCredential()
```

**Service Principal:**
```python
from azure.identity import ClientSecretCredential

credential = ClientSecretCredential(
    tenant_id="<tenant-id>",
    client_id="<client-id>",
    client_secret="<client-secret>"
)
```

---

## 🐛 Troubleshooting

### Problem: "No assets found" but assets visible in Portal

**Causes:**
1. Using old `/catalog/` endpoint instead of `/datamap/`
2. Wrong collection ID (using friendly name instead of internal name)
3. Assets not yet indexed (wait 5-10 minutes after scan)
4. Incorrect entity type filter

**Solutions:**
1. ✅ Use `/datamap/api/search/query`
2. ✅ List collections first to get internal names
3. ✅ Wait for scan to complete and index
4. ✅ Search without entity type filter first to discover types

### Problem: 405 Method Not Allowed

**Cause:** Using deprecated API endpoint

**Solution:** Replace `/catalog/` with `/datamap/`

### Problem: Asset type not recognized

**Cause:** Using Portal display name instead of API entity type

**Solution:** Use entity types like `fabric_lakehouse_table`, not "Lakehouse Table"

---

## 📚 API Endpoints Reference

### Data Map API (Current)

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Search Assets | POST | `/datamap/api/search/query?api-version=2023-09-01` |
| Get Asset | GET | `/datamap/api/atlas/v2/entity/guid/{guid}?api-version=2023-09-01` |

### Collections API

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List Collections | GET | `/account/collections?api-version=2019-11-01-preview` |
| Get Collection | GET | `/account/collections/{collectionName}?api-version=2019-11-01-preview` |

### Scanning API

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List Data Sources | GET | `https://{account}.scan.purview.azure.com/datasources?api-version=2018-12-01-preview` |
| Trigger Scan | POST | `https://{account}.scan.purview.azure.com/datasources/{ds}/scans/{scan}/run?api-version=2018-12-01-preview` |

---

## 📝 Complete Working Example

See `governance/purview/list_assets_rest.py` for a full implementation that:
- ✅ Authenticates with Azure AD
- ✅ Lists all collections
- ✅ Searches assets in a specific collection
- ✅ Groups results by entity type
- ✅ Handles errors gracefully

---

## 🔗 Official Documentation

- [Microsoft Purview REST API Reference](https://learn.microsoft.com/en-us/rest/api/purview/)
- [Purview Data Map API](https://learn.microsoft.com/en-us/rest/api/purview/datamapdataplane)
- [Azure Identity Python SDK](https://learn.microsoft.com/en-us/python/api/azure-identity/)

---

## ✅ Quick Checklist

Before making Purview API calls:

- [ ] Use `/datamap/` endpoint (not `/catalog/`)
- [ ] Get collection internal names via Collections API
- [ ] Use correct entity type names (`fabric_lakehouse_table`, etc.)
- [ ] Include proper authentication token
- [ ] Handle pagination for large result sets
- [ ] Wait 5-10 minutes after scans for indexing
- [ ] Check response status codes and error messages

---

**Last validated:** October 28, 2025 with Purview account `stpurview`  
**Working environment:** Microsoft Fabric + Purview integration
