"""
Check Purview Scan Status
Monitor the status of a running scan in real-time
"""

import os
import sys
import time
import logging
from datetime import datetime
from azure.identity import DefaultAzureCredential
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ScanStatusChecker:
    def __init__(self, purview_account_name: str):
        self.purview_account_name = purview_account_name
        self.scan_endpoint = f"https://{purview_account_name}.scan.purview.azure.com"
        
        # Authenticate
        self.credential = DefaultAzureCredential()
        self.token = self.credential.get_token("https://purview.azure.net/.default")
        logger.info(f"Authenticated to Purview account: {purview_account_name}")
    
    def _make_request(self, method: str, url: str, api_version: str = "2018-12-01-preview"):
        """Make authenticated request to Purview API"""
        headers = {
            "Authorization": f"Bearer {self.token.token}",
            "Content-Type": "application/json"
        }
        
        # Add API version to URL
        separator = "&" if "?" in url else "?"
        full_url = f"{url}{separator}api-version={api_version}"
        
        response = requests.request(method, full_url, headers=headers)
        return response
    
    def get_scan_runs(self, data_source_name: str, scan_name: str):
        """Get all scan runs for a specific scan"""
        url = f"{self.scan_endpoint}/datasources/{data_source_name}/scans/{scan_name}/runs"
        response = self._make_request("GET", url)
        
        if response.status_code == 200:
            runs = response.json().get("value", [])
            return runs
        else:
            logger.error(f"Failed to get scan runs: {response.status_code}")
            logger.error(response.text)
            return []
    
    def get_scan_run_details(self, data_source_name: str, scan_name: str, run_id: str):
        """Get details of a specific scan run"""
        url = f"{self.scan_endpoint}/datasources/{data_source_name}/scans/{scan_name}/runs/{run_id}"
        response = self._make_request("GET", url)
        
        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Failed to get scan run details: {response.status_code}")
            return None
    
    def monitor_scan(
        self, 
        data_source_name: str, 
        scan_name: str, 
        run_id: str = None,
        check_interval: int = 10
    ):
        """
        Monitor a scan run until completion
        
        Args:
            data_source_name: Name of data source
            scan_name: Name of scan
            run_id: Specific run ID to monitor (optional - will use latest if not provided)
            check_interval: Seconds between status checks
        """
        logger.info("=" * 70)
        logger.info(f"Monitoring Scan: {scan_name} on {data_source_name}")
        logger.info("=" * 70)
        
        # If no run_id provided, get the latest run
        if not run_id:
            runs = self.get_scan_runs(data_source_name, scan_name)
            if not runs:
                logger.error("No scan runs found")
                return None
            
            # Get the most recent run
            latest_run = sorted(runs, key=lambda x: x.get('startTime', ''), reverse=True)[0]
            run_id = latest_run.get('id')
            logger.info(f"Monitoring latest run: {run_id}")
        
        # Monitor until completion
        start_time = datetime.now()
        status = "Running"
        
        while status in ["Running", "Queued"]:
            details = self.get_scan_run_details(data_source_name, scan_name, run_id)
            
            if details:
                status = details.get('status', 'Unknown')
                scan_level = details.get('scanLevelType', 'N/A')
                start = details.get('startTime', 'N/A')
                end = details.get('endTime', 'N/A')
                
                # Calculate elapsed time
                elapsed = (datetime.now() - start_time).total_seconds()
                
                # Display status
                print(f"\r[{elapsed:.0f}s] Status: {status} | Level: {scan_level} | Started: {start[:19] if start != 'N/A' else 'N/A'}", end='', flush=True)
                
                if status not in ["Running", "Queued"]:
                    print()  # New line after completion
                    break
            
            time.sleep(check_interval)
        
        # Final status
        logger.info("\n" + "=" * 70)
        logger.info(f"Scan completed with status: {status}")
        logger.info("=" * 70)
        
        if details:
            logger.info(f"Run ID: {run_id}")
            logger.info(f"Start Time: {details.get('startTime', 'N/A')}")
            logger.info(f"End Time: {details.get('endTime', 'N/A')}")
            logger.info(f"Scan Level: {details.get('scanLevelType', 'N/A')}")
            
            # Show statistics if available
            if 'scanResultStatistics' in details:
                stats = details['scanResultStatistics']
                logger.info("\nScan Statistics:")
                for key, value in stats.items():
                    logger.info(f"  {key}: {value}")
        
        return details


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Monitor Purview Scan Status")
    parser.add_argument(
        "--data-source",
        type=str,
        default="Fabric-JAc",
        help="Data source name (default: Fabric-JAc)"
    )
    parser.add_argument(
        "--scan-name",
        type=str,
        default="Scan-DKT",
        help="Scan name (default: Scan-DKT)"
    )
    parser.add_argument(
        "--run-id",
        type=str,
        help="Specific run ID to monitor (optional - uses latest if not provided)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=10,
        help="Check interval in seconds (default: 10)"
    )
    args = parser.parse_args()
    
    # Purview account
    PURVIEW_ACCOUNT = "stpurview"
    
    # Create checker
    checker = ScanStatusChecker(PURVIEW_ACCOUNT)
    
    # Monitor scan
    result = checker.monitor_scan(
        data_source_name=args.data_source,
        scan_name=args.scan_name,
        run_id=args.run_id,
        check_interval=args.interval
    )
    
    if result and result.get('status') == 'Succeeded':
        logger.info("\n✅ Scan completed successfully!")
        logger.info("You can now view the discovered assets in Purview Portal:")
        logger.info(f"https://web.purview.azure.com/resource/stpurview/overview")
    elif result:
        logger.warning(f"\n⚠️ Scan finished with status: {result.get('status')}")
    else:
        logger.error("\n❌ Could not retrieve scan status")


if __name__ == "__main__":
    main()
