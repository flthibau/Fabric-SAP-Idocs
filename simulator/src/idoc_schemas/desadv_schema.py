"""
DESADV IDoc Schema - Dispatch Advice (Advance Shipping Notice)
Message type: DESADV
IDoc type: DESADV01
"""

from datetime import datetime
from typing import Dict, Any, List, Optional
from .base_schema import BaseIDocSchema


class DESADVSchema(BaseIDocSchema):
    """DESADV - Dispatch Advice for outbound deliveries"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        super().__init__(sap_system, sap_client)
        self.idoc_type = "DESADV01"
        self.message_type = "DESADV"
    
    def generate(
        self,
        delivery_number: str,
        warehouse: Dict[str, Any],
        customer: Dict[str, Any],
        carrier: Dict[str, Any],
        items: List[Dict[str, Any]],
        shipment_date: datetime,
        tracking_number: str
    ) -> Dict[str, Any]:
        """
        Generate DESADV IDoc
        
        Args:
            delivery_number: Delivery document number
            warehouse: Warehouse information
            customer: Customer/ship-to information
            carrier: Carrier information
            items: List of items being shipped
            shipment_date: Planned shipment date
            tracking_number: Carrier tracking number
        
        Returns:
            Complete IDoc structure
        """
        control = self.create_control_record(sender=warehouse["warehouse_id"])
        
        # E1EDK01 - Document header
        header = {
            "segnam": "E1EDK01",
            "belnr": delivery_number,
            "bldat": self.format_date(shipment_date),
            "ntgew": sum(item.get("weight_kg", 0) * item.get("quantity", 1) for item in items),
            "brgew": sum(item.get("weight_kg", 0) * item.get("quantity", 1) for item in items) * 1.1,  # Gross weight
            "gewei": "KGM",  # Weight unit
            "volum": sum(item.get("volume_m3", 0) * item.get("quantity", 1) for item in items),
            "voleh": "MTQ",  # Volume unit
            "vsart": carrier["service_level"],
            "traid": tracking_number
        }
        
        # E1EDK14 - Organizational data
        org_data = {
            "segnam": "E1EDK14",
            "qualf": "008",  # Delivery plant
            "orgid": warehouse["warehouse_id"]
        }
        
        # E1EDK03 - Date segments
        dates = [
            {
                "segnam": "E1EDK03",
                "iddat": "012",  # Delivery date
                "datum": self.format_date(shipment_date),
                "uzeit": self.format_time(shipment_date)
            }
        ]
        
        # E1EDKA1 - Partner information (Ship-to)
        partners = [
            {
                "segnam": "E1EDKA1",
                "parvw": "WE",  # Ship-to party
                "partn": customer["customer_id"],
                "name1": customer["name"],
                "stras": customer["street"],
                "ort01": customer["city"],
                "regio": customer["state"],
                "pstlz": customer["postal_code"],
                "land1": customer["country"]
            },
            {
                "segnam": "E1EDKA1",
                "parvw": "SP",  # Carrier
                "partn": carrier["carrier_id"],
                "name1": carrier["name"]
            }
        ]
        
        # E1EDL20 - Delivery item segments
        delivery_items = []
        position = 10
        
        for item in items:
            item_segment = {
                "segnam": "E1EDL20",
                "posex": str(position),
                "matnr": item["material_id"],
                "maktx": item["description"],
                "arktx": item["description"],
                "lfimg": self.format_quantity(item["quantity"]),
                "vrkme": item["unit"],
                "ntgew": self.format_quantity(item["weight_kg"] * item["quantity"]),
                "gewei": "KGM",
                "volum": self.format_quantity(item.get("volume_m3", 0) * item["quantity"]),
                "voleh": "MTQ"
            }
            
            delivery_items.append(item_segment)
            position += 10
        
        # E1EDL24 - Batch information (optional)
        batches = []
        for idx, item in enumerate(items):
            batch_segment = {
                "segnam": "E1EDL24",
                "posnr": str((idx + 1) * 10),
                "charg": f"BATCH{datetime.now().strftime('%Y%m%d')}{idx+1:04d}",
                "lfimg": self.format_quantity(item["quantity"]),
                "vrkme": item["unit"]
            }
            batches.append(batch_segment)
        
        # Assemble complete IDoc
        idoc = {
            "control": control,
            "data": {
                "E1EDK01": [header],
                "E1EDK14": [org_data],
                "E1EDK03": dates,
                "E1EDKA1": partners,
                "E1EDL20": delivery_items,
                "E1EDL24": batches
            }
        }
        
        return self.to_json(idoc)
