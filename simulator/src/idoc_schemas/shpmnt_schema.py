"""
SHPMNT IDoc Schema - Shipment
Message type: SHPMNT
IDoc type: SHPMNT05
"""

from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from .base_schema import BaseIDocSchema


class SHPMNTSchema(BaseIDocSchema):
    """SHPMNT - Shipment tracking and status updates"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        super().__init__(sap_system, sap_client)
        self.idoc_type = "SHPMNT05"
        self.message_type = "SHPMNT"
    
    def generate(
        self,
        shipment_number: str,
        delivery_number: str,
        warehouse: Dict[str, Any],
        customer: Dict[str, Any],
        carrier: Dict[str, Any],
        tracking_number: str,
        shipment_status: str,
        pickup_date: datetime,
        delivery_date: Optional[datetime] = None,
        tracking_events: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Generate SHPMNT IDoc
        
        Args:
            shipment_number: Shipment document number
            delivery_number: Related delivery number
            warehouse: Origin warehouse
            customer: Destination customer
            carrier: Carrier information
            tracking_number: Tracking number
            shipment_status: Current status (A=In transit, B=Delivered, C=Exception)
            pickup_date: Pickup date/time
            delivery_date: Actual delivery date (if delivered)
            tracking_events: List of tracking events
        
        Returns:
            Complete IDoc structure
        """
        control = self.create_control_record(sender=warehouse["warehouse_id"])
        
        # E1SHP00 - Shipment header (Enhanced for B2B partner sharing)
        header = {
            "segnam": "E1SHP00",
            "tknum": shipment_number,
            "shtyp": "0001",  # Shipment type
            "vsart": carrier["service_level"],
            "tdlnr": carrier["carrier_id"],  # Carrier ID for partner filtering
            "signi": tracking_number,  # Carrier tracking number for external access
            "shpsts": shipment_status,
            "datbg": self.format_date(pickup_date),
            "uatbg": self.format_time(pickup_date),
            # B2B Partner Fields
            "carrier_name": carrier.get("name", ""),  # Carrier company name
            "customer_id": customer.get("customer_id", ""),  # Customer ID for filtering
            "customer_name": customer.get("name", ""),  # Customer company name
            "partner_access_scope": "CARRIER_CUSTOMER"  # Defines who can access this shipment
        }
        
        if delivery_date:
            header["daten"] = self.format_date(delivery_date)
            header["uaten"] = self.format_time(delivery_date)
        
        # E1SHP01 - Shipment item (delivery reference)
        shipment_items = [
            {
                "segnam": "E1SHP01",
                "tknum": shipment_number,
                "tpnum": "0001",
                "vbeln": delivery_number,
                "lifex": delivery_number
            }
        ]
        
        # E1SHP02 - Partner data
        partners = [
            {
                "segnam": "E1SHP02",
                "parvw": "SP",  # Carrier
                "parnr": carrier["carrier_id"],
                "name1": carrier["name"]
            },
            {
                "segnam": "E1SHP02",
                "parvw": "SH",  # Ship-from
                "parnr": warehouse["warehouse_id"],
                "name1": warehouse["name"],
                "stras": f"{warehouse['city']}, {warehouse['state']}",
                "ort01": warehouse["city"],
                "land1": warehouse["country"],
                "pstlz": warehouse["postal_code"]
            },
            {
                "segnam": "E1SHP02",
                "parvw": "CN",  # Consignee
                "parnr": customer["customer_id"],
                "name1": customer["name"],
                "stras": customer["street"],
                "ort01": customer["city"],
                "land1": customer["country"],
                "pstlz": customer["postal_code"]
            }
        ]
        
        # E1SHP03 - Date segments
        dates = [
            {
                "segnam": "E1SHP03",
                "tddat": "021",  # Pickup date
                "tduhr": self.format_time(pickup_date),
                "tddat_iso": self.format_date(pickup_date)
            }
        ]
        
        if delivery_date:
            dates.append({
                "segnam": "E1SHP03",
                "tddat": "022",  # Delivery date
                "tduhr": self.format_time(delivery_date),
                "tddat_iso": self.format_date(delivery_date)
            })
        
        # E1SHP10 - Tracking events/status updates
        events = []
        if tracking_events:
            for event in tracking_events:
                events.append({
                    "segnam": "E1SHP10",
                    "tknum": shipment_number,
                    "tsrfo": event.get("sequence", 1),
                    "tstyp": event.get("event_type", "STATUS_UPDATE"),
                    "tsdat": self.format_date(event.get("timestamp", datetime.now())),
                    "tsuhr": self.format_time(event.get("timestamp", datetime.now())),
                    "tsrst": event.get("status_code", ""),
                    "tstxt": event.get("description", ""),
                    "tsloc": event.get("location", "")
                })
        else:
            # Default tracking event
            events.append({
                "segnam": "E1SHP10",
                "tknum": shipment_number,
                "tsrfo": "1",
                "tstyp": "STATUS_UPDATE",
                "tsdat": self.format_date(pickup_date),
                "tsuhr": self.format_time(pickup_date),
                "tsrst": shipment_status,
                "tstxt": self._get_status_text(shipment_status),
                "tslo c": warehouse["city"]
            })
        
        # Assemble complete IDoc
        idoc = {
            "control": control,
            "data": {
                "E1SHP00": [header],
                "E1SHP01": shipment_items,
                "E1SHP02": partners,
                "E1SHP03": dates,
                "E1SHP10": events
            }
        }
        
        return self.to_json(idoc)
    
    def _get_status_text(self, status_code: str) -> str:
        """Get human-readable status text"""
        status_map = {
            "A": "In Transit",
            "B": "Delivered",
            "C": "Exception",
            "P": "Picked Up",
            "D": "Out for Delivery",
            "E": "Delivery Exception",
            "R": "Returned"
        }
        return status_map.get(status_code, "Unknown Status")
