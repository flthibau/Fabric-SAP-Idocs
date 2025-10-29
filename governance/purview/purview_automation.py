"""
Microsoft Purview Automation Script
Automates Data Product registration using Purview REST API

Purview REST API Documentation:
https://learn.microsoft.com/en-us/rest/api/purview/
"""

import os
import json
import requests
from azure.identity import DefaultAzureCredential
from typing import Dict, List, Optional
import yaml
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PurviewAutomation:
    """Automate Purview Data Product registration via REST API"""
    
    def __init__(self, purview_account_name: str, resource_group: str):
        """
        Initialize Purview automation client
        
        Args:
            purview_account_name: Purview account name (e.g., 'stpurview')
            resource_group: Resource group name
        """
        self.account_name = purview_account_name
        self.resource_group = resource_group
        
        # Purview endpoints
        self.catalog_endpoint = f"https://{purview_account_name}.purview.azure.com"
        self.scan_endpoint = f"https://{purview_account_name}.scan.purview.azure.com"
        
        # Get Azure AD token
        self.credential = DefaultAzureCredential()
        self.token = self._get_token()
        
        logger.info(f"Initialized Purview client for account: {purview_account_name}")
    
    def _get_token(self) -> str:
        """Get Azure AD access token for Purview"""
        try:
            token = self.credential.get_token("https://purview.azure.net/.default")
            logger.info("Successfully obtained Azure AD token")
            return token.token
        except Exception as e:
            logger.error(f"Failed to get Azure AD token: {e}")
            raise
    
    def _make_request(
        self, 
        method: str, 
        url: str, 
        data: Optional[Dict] = None,
        api_version: str = "2022-03-01-preview"
    ) -> requests.Response:
        """
        Make authenticated REST API request to Purview
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            url: Full URL or endpoint path
            data: Request body (JSON)
            api_version: Purview API version
        
        Returns:
            Response object
        """
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        # Add API version if not in URL
        if "api-version" not in url:
            separator = "&" if "?" in url else "?"
            url = f"{url}{separator}api-version={api_version}"
        
        logger.debug(f"{method} {url}")
        
        response = requests.request(
            method=method,
            url=url,
            headers=headers,
            json=data
        )
        
        # Log response
        if response.status_code >= 400:
            logger.error(f"API Error {response.status_code}: {response.text}")
        else:
            logger.info(f"API Success {response.status_code}")
        
        return response
    
    # ====================
    # GLOSSARY OPERATIONS
    # ====================
    
    def create_glossary(self, name: str, description: str) -> Dict:
        """
        Create a business glossary (or get existing one)
        
        Args:
            name: Glossary name
            description: Glossary description
        
        Returns:
            Created or existing glossary object
        """
        # First, try to get existing glossary
        list_url = f"{self.catalog_endpoint}/catalog/api/atlas/v2/glossary"
        list_response = self._make_request("GET", list_url)
        
        if list_response.status_code == 200:
            glossaries = list_response.json()
            for glossary in glossaries:
                if glossary.get("name") == name:
                    logger.info(f"Found existing glossary: {name} (GUID: {glossary.get('guid')})")
                    return glossary
        
        # Create new glossary if not found
        url = f"{self.catalog_endpoint}/catalog/api/atlas/v2/glossary"
        
        payload = {
            "name": name,
            "shortDescription": description[:100],
            "longDescription": description,
            "language": "en",
            "usage": "Data Product terminology standardization"
        }
        
        response = self._make_request("POST", url, data=payload)
        
        if response.status_code in [200, 201]:
            glossary = response.json()
            logger.info(f"Created glossary: {glossary.get('name')} (GUID: {glossary.get('guid')})")
            return glossary
        else:
            raise Exception(f"Failed to create glossary: {response.text}")
    
    def create_glossary_term(
        self, 
        glossary_guid: str,
        name: str,
        definition: str,
        **kwargs
    ) -> Dict:
        """
        Create a glossary term
        
        Args:
            glossary_guid: Parent glossary GUID
            name: Term name
            definition: Term definition
            **kwargs: Additional properties (synonyms, related_terms, owner, etc.)
        
        Returns:
            Created term object
        """
        url = f"{self.catalog_endpoint}/catalog/api/atlas/v2/glossary/term"
        
        payload = {
            "name": name,
            "shortDescription": definition[:100],
            "longDescription": definition,
            "anchor": {
                "glossaryGuid": glossary_guid
            },
            "status": "Approved"
        }
        
        # Add optional fields
        if "synonyms" in kwargs:
            payload["abbreviation"] = ", ".join(kwargs["synonyms"])
        
        if "owner" in kwargs:
            payload["experts"] = [{"id": kwargs["owner"]}]
        
        # Custom attributes are not supported in basic term creation
        # Store technical mapping in longDescription instead
        if "technical_mapping" in kwargs:
            payload["longDescription"] = f"{definition}\n\nTechnical Mapping: {kwargs['technical_mapping']}"
        
        response = self._make_request("POST", url, data=payload)
        
        if response.status_code in [200, 201]:
            term = response.json()
            logger.info(f"Created term: {term.get('name')} (GUID: {term.get('guid')})")
            return term
        elif response.status_code == 409:
            # Term already exists
            logger.info(f"Term '{name}' already exists (skipping)")
            return {"name": name, "status": "existing"}
        else:
            logger.error(f"Failed to create term '{name}': {response.text}")
            return {}
    
    def import_business_glossary_from_md(self, glossary_file: str) -> List[Dict]:
        """
        Import business glossary from BUSINESS-GLOSSARY.md
        
        Args:
            glossary_file: Path to BUSINESS-GLOSSARY.md
        
        Returns:
            List of created terms
        """
        logger.info(f"Importing glossary from: {glossary_file}")
        
        # Create main glossary
        glossary = self.create_glossary(
            name="3PL Real-Time Analytics",
            description="Business glossary for 3PL Data Product"
        )
        glossary_guid = glossary.get("guid")
        
        # Parse markdown and extract terms
        terms = self._parse_glossary_markdown(glossary_file)
        
        # Create terms in Purview
        created_terms = []
        for term_data in terms:
            term = self.create_glossary_term(
                glossary_guid=glossary_guid,
                **term_data
            )
            if term:
                created_terms.append(term)
        
        logger.info(f"Imported {len(created_terms)} glossary terms")
        return created_terms
    
    def _parse_glossary_markdown(self, file_path: str) -> List[Dict]:
        """
        Parse BUSINESS-GLOSSARY.md and extract terms
        
        Args:
            file_path: Path to markdown file
        
        Returns:
            List of term dictionaries
        """
        terms = []
        
        # Read markdown file
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Simple parsing logic (can be enhanced)
        # Look for term definitions in markdown
        
        # Example terms from BUSINESS-GLOSSARY.md
        example_terms = [
            {
                "name": "Order",
                "definition": "Customer purchase request for logistics services",
                "synonyms": ["Sales Order", "Purchase Order"],
                "owner": "Operations Manager",
                "technical_mapping": "idoc_orders_silver.order_number"
            },
            {
                "name": "Shipment",
                "definition": "Physical movement of goods from origin to destination",
                "synonyms": ["Delivery", "Transport"],
                "owner": "Transportation Manager",
                "technical_mapping": "idoc_shipments_silver.shipment_number"
            },
            {
                "name": "SLA Compliance %",
                "definition": "Percentage of orders delivered within 24 hours",
                "owner": "Operations Manager",
                "technical_mapping": "sla_performance.sla_compliance_pct"
            },
            {
                "name": "On-Time Delivery %",
                "definition": "Percentage of shipments delivered by planned delivery date",
                "owner": "Transportation Manager",
                "technical_mapping": "shipments_in_transit.on_time_shipments"
            },
            {
                "name": "Warehouse Productivity",
                "definition": "Warehouse movements per hour per operator",
                "owner": "Warehouse Manager",
                "technical_mapping": "warehouse_productivity.total_movements"
            },
            {
                "name": "Days Sales Outstanding (DSO)",
                "definition": "Average days to collect payment after invoice",
                "owner": "Finance Manager",
                "technical_mapping": "revenue_realtime.avg_payment_efficiency"
            }
        ]
        
        # TODO: Implement full markdown parsing
        # For now, return example terms
        logger.warning("Using example terms - full markdown parsing not yet implemented")
        return example_terms
    
    # ====================
    # DATA SOURCE OPERATIONS
    # ====================
    
    def list_data_sources(self) -> List[Dict]:
        """
        List all data sources registered in Purview
        
        Returns:
            List of data source objects
        """
        logger.info("Listing all data sources in Purview")
        
        url = f"{self.scan_endpoint}/datasources"
        response = self._make_request("GET", url, api_version="2018-12-01-preview")
        
        if response.status_code == 200:
            data_sources = response.json().get("value", [])
            logger.info(f"Found {len(data_sources)} data source(s)")
            for ds in data_sources:
                logger.info(f"  - {ds.get('name')} (kind: {ds.get('kind')})")
            return data_sources
        else:
            logger.error(f"Failed to list data sources: {response.status_code}")
            logger.error(response.text)
            return []
    
    def get_data_source(self, data_source_name: str) -> Optional[Dict]:
        """
        Get details of a specific data source
        
        Args:
            data_source_name: Name of the data source
        
        Returns:
            Data source object or None if not found
        """
        logger.info(f"Getting data source: {data_source_name}")
        
        url = f"{self.scan_endpoint}/datasources/{data_source_name}"
        response = self._make_request("GET", url, api_version="2018-12-01-preview")
        
        if response.status_code == 200:
            data_source = response.json()
            logger.info(f"Found data source: {data_source.get('name')} (kind: {data_source.get('kind')})")
            return data_source
        elif response.status_code == 404:
            logger.warning(f"Data source '{data_source_name}' not found")
            return None
        else:
            logger.error(f"Failed to get data source: {response.status_code}")
            logger.error(response.text)
            return None
    
    def register_kusto_data_source(
        self,
        data_source_name: str,
        cluster_uri: str,
        database_name: Optional[str] = None,
        collection_name: Optional[str] = None
    ) -> Dict:
        """
        Register Eventhouse (Kusto) as data source
        
        Args:
            data_source_name: Friendly name
            cluster_uri: Kusto cluster URI
            database_name: Database name (optional)
            collection_name: Collection to assign (default: Bronze)
        
        Returns:
            Registered data source object
        """
        if collection_name is None:
            collection_name = "Bronze"
        
        url = f"{self.scan_endpoint}/datasources/{data_source_name}"
        
        payload = {
            "kind": "AzureDataExplorer",
            "name": data_source_name,
            "properties": {
                "endpoint": cluster_uri,
                "collection": {
                    "type": "CollectionReference",
                    "referenceName": collection_name
                }
            }
        }
        
        # Add database if specified
        if database_name:
            payload["properties"]["database"] = database_name
        
        response = self._make_request("PUT", url, data=payload, api_version="2018-12-01-preview")
        
        if response.status_code in [200, 201]:
            data_source = response.json()
            logger.info(f"Registered data source: {data_source_name} → Collection: {collection_name}")
            return data_source
        else:
            logger.error(f"Failed to register data source: {response.text}")
            return {}
    
    def create_scan(
        self,
        data_source_name: str,
        scan_name: str,
        scan_kind: str = "PowerBI",
        database_name: Optional[str] = None
    ) -> Dict:
        """
        Create and run a scan on registered data source
        
        Args:
            data_source_name: Data source name
            scan_name: Scan name
            scan_kind: Type of scan (PowerBI for Fabric, AzureDataExplorer, etc.)
            database_name: Database to scan (optional)
        
        Returns:
            Scan configuration object
        """
        url = f"{self.scan_endpoint}/datasources/{data_source_name}/scans/{scan_name}"
        
        # Determine scan configuration based on data source kind
        if scan_kind == "PowerBI":
            # For Fabric/PowerBI data sources - try MSI scan
            payload = {
                "name": scan_name,
                "kind": "PowerBIMsiScan",
                "properties": {
                    "scanRulesetName": "PowerBI",
                    "scanRulesetType": "System",
                    "includePersonalWorkspaces": False
                }
            }
        elif scan_kind == "Fabric":
            payload = {
                "name": scan_name,
                "kind": "PowerBIMsiScan",
                "properties": {
                    "scanRulesetName": "PowerBI",
                    "scanRulesetType": "System",
                    "includePersonalWorkspaces": False
                }
            }
        elif scan_kind == "AzureDataExplorer":
            payload = {
                "name": scan_name,
                "kind": "AzureDataExplorerMsiScan",
                "properties": {
                    "scanRulesetName": "AzureDataExplorer",
                    "scanRulesetType": "System"
                }
            }
        else:
            logger.error(f"Unsupported scan kind: {scan_kind}")
            return {}
        
        # Add database filter if specified
        if database_name:
            payload["properties"]["database"] = database_name
        
        response = self._make_request("PUT", url, data=payload, api_version="2018-12-01-preview")
        
        if response.status_code in [200, 201]:
            scan = response.json()
            logger.info(f"Created scan: {scan_name} on {data_source_name}")
            
            # Trigger scan run
            self.run_scan(data_source_name, scan_name)
            
            return scan
        else:
            logger.error(f"Failed to create scan: {response.text}")
            return {}

    
    def run_scan(self, data_source_name: str, scan_name: str) -> Dict:
        """
        Trigger a scan run
        
        Args:
            data_source_name: Data source name
            scan_name: Scan name
        
        Returns:
            Scan run object
        """
        url = f"{self.scan_endpoint}/datasources/{data_source_name}/scans/{scan_name}/run"
        
        # Generate run ID
        import uuid
        run_id = str(uuid.uuid4())
        
        payload = {
            "scanLevel": "Full"
        }
        
        full_url = f"{url}?runId={run_id}"
        response = self._make_request("POST", full_url, data=payload, api_version="2018-12-01-preview")
        
        if response.status_code in [200, 201, 202]:
            logger.info(f"Triggered scan run: {scan_name} (Run ID: {run_id})")
            return {"scanName": scan_name, "runId": run_id, "status": "Running"}
        else:
            logger.error(f"Failed to run scan: {response.text}")
            return {}
    
    def _get_subscription_id(self) -> str:
        """Get current Azure subscription ID"""
        import subprocess
        result = subprocess.run(
            ["az", "account", "show", "--query", "id", "-o", "tsv"],
            capture_output=True,
            text=True
        )
        return result.stdout.strip()
    
    # ====================
    # COLLECTION OPERATIONS
    # ====================
    
    def create_collection(
        self,
        collection_name: str,
        parent_collection: Optional[str] = None
    ) -> Dict:
        """
        Create a collection for organizing assets
        
        Args:
            collection_name: Collection name
            parent_collection: Parent collection name (defaults to root collection)
        
        Returns:
            Created collection object
        """
        # Get root collection name (usually account name)
        if parent_collection is None:
            parent_collection = self.account_name
        
        url = f"{self.catalog_endpoint}/account/collections/{collection_name}"
        
        payload = {
            "name": collection_name,
            "parentCollection": {
                "referenceName": parent_collection
            },
            "description": f"3PL Data Product - {collection_name}"
        }
        
        response = self._make_request("PUT", url, data=payload, api_version="2019-11-01-preview")
        
        if response.status_code in [200, 201]:
            collection = response.json()
            logger.info(f"Created collection: {collection_name}")
            return collection
        else:
            logger.error(f"Failed to create collection: {response.text}")
            return {}
    
    # ====================
    # LINEAGE OPERATIONS
    # ====================
    
    def create_lineage(
        self,
        source_entity_guid: str,
        target_entity_guid: str,
        process_name: str
    ) -> Dict:
        """
        Create lineage relationship between entities
        
        Args:
            source_entity_guid: Source entity GUID
            target_entity_guid: Target entity GUID
            process_name: Name of transformation process
        
        Returns:
            Created lineage object
        """
        url = f"{self.catalog_endpoint}/catalog/api/atlas/v2/entity"
        
        payload = {
            "entity": {
                "typeName": "Process",
                "attributes": {
                    "name": process_name,
                    "qualifiedName": f"{process_name}@{self.account_name}",
                    "inputs": [{"guid": source_entity_guid}],
                    "outputs": [{"guid": target_entity_guid}]
                }
            }
        }
        
        response = self._make_request("POST", url, data=payload)
        
        if response.status_code in [200, 201]:
            lineage = response.json()
            logger.info(f"Created lineage: {process_name}")
            return lineage
        else:
            logger.error(f"Failed to create lineage: {response.text}")
            return {}
    
    # ====================
    # DATA QUALITY OPERATIONS
    # ====================
    
    def create_data_quality_rule(
        self,
        asset_guid: str,
        rule_name: str,
        rule_type: str,
        field_name: str,
        **kwargs
    ) -> Dict:
        """
        Create a data quality rule on an asset
        
        Args:
            asset_guid: Asset GUID (table/view)
            rule_name: Rule name
            rule_type: Rule type (Completeness, Uniqueness, Validity, etc.)
            field_name: Column name to validate
            **kwargs: Additional rule properties (threshold, expression, etc.)
        
        Returns:
            Created rule object
        """
        # Note: Data Quality rules API is in preview
        # This is a placeholder for the actual implementation
        url = f"{self.catalog_endpoint}/catalog/api/dataquality/rules"
        
        payload = {
            "name": rule_name,
            "assetGuid": asset_guid,
            "ruleType": rule_type,
            "fieldName": field_name,
            "properties": kwargs
        }
        
        logger.info(f"Data Quality API: {rule_type} rule '{rule_name}' on {field_name}")
        logger.warning("Data Quality Rules API is in preview - configure manually in Portal")
        
        # TODO: Implement when API is GA
        return {"rule_name": rule_name, "status": "Pending manual configuration"}
    
    # ====================
    # ORCHESTRATION
    # ====================
    
    def setup_data_product(
        self, 
        fabric_data_source_name: str = "Fabric-JAc",
        scan_name: str = "Scan-DKT",
        cluster_uri: Optional[str] = None
    ) -> Dict:
        """
        Complete Data Product setup in Purview
        
        Args:
            fabric_data_source_name: Name of Fabric data source in Purview (default: Fabric-JAc)
            scan_name: Name of existing scan to trigger (default: Scan-DKT)
            cluster_uri: Optional cluster URI (for backward compatibility)
        
        Returns:
            Summary of created resources
        """
        logger.info("=" * 70)
        logger.info("Starting Data Product setup in Purview")
        logger.info("=" * 70)
        
        summary = {
            "glossary": None,
            "terms": [],
            "collections": [],
            "data_sources": [],
            "scans": [],
            "lineage": []
        }
        
        try:
            # Step 1: Create collections
            logger.info("\n[1/5] Creating collections...")
            collections = ["Bronze", "Silver", "Gold", "API"]
            for coll_name in collections:
                coll = self.create_collection(coll_name)
                if coll:
                    summary["collections"].append(coll)
            
            # Step 2: Import business glossary
            logger.info("\n[2/5] Importing business glossary...")
            glossary_file = "../BUSINESS-GLOSSARY.md"
            if os.path.exists(glossary_file):
                terms = self.import_business_glossary_from_md(glossary_file)
                summary["terms"] = terms
            else:
                logger.warning(f"Glossary file not found: {glossary_file}")
            
            # Step 3: Verify Fabric data source and create scan
            logger.info("\n[3/5] Setting up scan on Fabric data source...")
            
            # List all data sources
            data_sources = self.list_data_sources()
            summary["data_sources"] = data_sources
            
            # Get specific Fabric data source
            fabric_ds = self.get_data_source(fabric_data_source_name)
            
            if fabric_ds:
                logger.info(f"Found Fabric data source: {fabric_data_source_name}")
                ds_kind = fabric_ds.get('kind')
                logger.info(f"  Kind: {ds_kind}")
                logger.info(f"  Collection: {fabric_ds.get('properties', {}).get('collection', {}).get('referenceName')}")
                
                # Trigger existing scan instead of creating new one
                logger.info(f"Triggering existing scan: {scan_name}")
                scan_result = self.run_scan(fabric_data_source_name, scan_name)
                
                if scan_result:
                    summary["scans"].append(scan_result)
                    logger.info(f"✅ Scan '{scan_name}' triggered on {fabric_data_source_name}")
                    logger.info(f"   Run ID: {scan_result.get('runId', 'N/A')}")
                else:
                    logger.warning(f"Could not trigger scan '{scan_name}' - it may not exist yet")
                    logger.info("Please create the scan in Purview Portal first")
            else:
                logger.error(f"Fabric data source '{fabric_data_source_name}' not found!")
                logger.info("Available data sources:")
                for ds in data_sources:
                    logger.info(f"  - {ds.get('name')} (kind: {ds.get('kind')})")
            
            # Step 4: Create Data Quality rules placeholders
            logger.info("\n[4/5] Data Quality Rules...")
            logger.warning("Data Quality Rules require manual configuration in Purview Portal")
            logger.info("Reference: governance/DATA-QUALITY-RULES.md")
            
            # Step 5: Create lineage
            logger.info("\n[5/5] Lineage mapping...")
            logger.info("Lineage will be created after assets are discovered from scan")
            logger.info("Check Purview Portal → Data Map → {fabric_data_source_name} for scan results")
            
            logger.info("\n" + "=" * 70)
            logger.info("Data Product setup completed!")
            logger.info("=" * 70)
            logger.info(f"Collections created: {len(summary['collections'])}")
            logger.info(f"Glossary terms created: {len(summary['terms'])}")
            logger.info(f"Data sources registered: {len(summary['data_sources'])}")
            
        except Exception as e:
            logger.error(f"Data Product setup failed: {e}")
            raise
        
        return summary


def main():
    """Main execution"""
    import argparse
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Purview Data Product Automation")
    parser.add_argument(
        "--fabric-source",
        type=str,
        default="Fabric-JAc",
        help="Name of Fabric data source in Purview (default: Fabric-JAc)"
    )
    parser.add_argument(
        "--scan-name",
        type=str,
        default="Scan-DKT",
        help="Name of existing scan to trigger (default: Scan-DKT)"
    )
    args = parser.parse_args()
    
    # Purview configuration
    PURVIEW_ACCOUNT = "stpurview"
    RESOURCE_GROUP = "purview"
    
    # Initialize automation
    purview = PurviewAutomation(
        purview_account_name=PURVIEW_ACCOUNT,
        resource_group=RESOURCE_GROUP
    )
    
    # Run full setup
    summary = purview.setup_data_product(
        fabric_data_source_name=args.fabric_source,
        scan_name=args.scan_name
    )
    
    # Save summary
    with open("purview_setup_summary.json", "w") as f:
        json.dump(summary, f, indent=2, default=str)
    
    logger.info("\nSetup summary saved to: purview_setup_summary.json")


if __name__ == "__main__":
    main()
