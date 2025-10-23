"""
ORDERS IDoc Schema - Purchase Order
Message type: ORDERS
IDoc type: ORDERS05
"""

from datetime import datetime, timedelta
from typing import Dict, Any, List
from .base_schema import BaseIDocSchema


class ORDERSSchema(BaseIDocSchema):
    """ORDERS - Purchase Order / Sales Order"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        super().__init__(sap_system, sap_client)
        self.idoc_type = "ORDERS05"
        self.message_type = "ORDERS"
    
    def generate(
        self,
        order_number: str,
        customer: Dict[str, Any],
        warehouse: Dict[str, Any],
        items: List[Dict[str, Any]],
        order_date: datetime,
        requested_delivery_date: datetime,
        order_type: str = "ZOR",  # Standard order
        priority: str = "2"  # Normal priority
    ) -> Dict[str, Any]:
        """
        Generate ORDERS IDoc
        
        Args:
            order_number: Sales/Purchase order number
            customer: Customer information
            warehouse: Delivery warehouse
            items: List of order items
            order_date: Order creation date
            requested_delivery_date: Requested delivery date
            order_type: Order type (ZOR, ZRE for returns, etc.)
            priority: Priority (1=High, 2=Normal, 3=Low)
        
        Returns:
            Complete IDoc structure
        """
        control = self.create_control_record(sender="SALES")
        
        # Calculate totals
        total_value = sum(item.get("price", 0) * item.get("quantity", 1) for item in items)
        total_weight = sum(item.get("weight_kg", 0) * item.get("quantity", 1) for item in items)
        
        # E1EDK01 - Document header
        header = {
            "segnam": "E1EDK01",
            "action": "004",  # Create
            "kzabs": "",
            "curcy": "USD",
            "hwaer": "USD",
            "wkurs": "1.00000",
            "zterm": "Net 30",
            "kundeuinr": customer.get("tax_id", ""),
            "eigenuinr": "",
            "bsart": order_type,
            "belnr": order_number,
            "ntgew": self.format_quantity(total_weight),
            "gewei": "KGM",
            "fkart_rl": "",
            "ablad": warehouse["warehouse_id"],
            "bstzd": "",
            "vsart": "01",  # Shipping type
            "vsart_bez": "Standard Shipping",
            "recipnt_no": customer["customer_id"],
            "kzazu": "X",  # Delivery complete indicator
            "wkurs_m": "1.00000",
            "vsbed": priority
        }
        
        # E1EDK02 - Document data
        doc_data = {
            "segnam": "E1EDK02",
            "qualf": "001",  # Order type
            "belnr": order_number,
            "datum": self.format_date(order_date)
        }
        
        # E1EDK03 - Date segments
        dates = [
            {
                "segnam": "E1EDK03",
                "iddat": "012",  # Order date
                "datum": self.format_date(order_date),
                "uzeit": self.format_time(order_date)
            },
            {
                "segnam": "E1EDK03",
                "iddat": "002",  # Requested delivery date
                "datum": self.format_date(requested_delivery_date)
            }
        ]
        
        # E1EDKA1 - Partner information
        partners = [
            {
                "segnam": "E1EDKA1",
                "parvw": "AG",  # Sold-to party
                "partn": customer["customer_id"],
                "name1": customer["name"],
                "name2": "",
                "name3": "",
                "stras": customer["street"],
                "ort01": customer["city"],
                "ort02": "",
                "regio": customer["state"],
                "pstlz": customer["postal_code"],
                "land1": customer["country"],
                "isoal": customer["country"],
                "telf1": customer.get("phone", ""),
                "telf2": "",
                "smtp_addr": customer.get("email", "")
            },
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
                "parvw": "RE",  # Bill-to party
                "partn": customer["customer_id"],
                "name1": customer["name"],
                "stras": customer["street"],
                "ort01": customer["city"],
                "regio": customer["state"],
                "pstlz": customer["postal_code"],
                "land1": customer["country"]
            }
        ]
        
        # E1EDP01 - Line items
        line_items = []
        position = 10
        
        for item in items:
            line_value = item.get("price", 0) * item.get("quantity", 1)
            
            # Main item segment
            line_item = {
                "segnam": "E1EDP01",
                "posex": str(position),
                "action": "004",  # Create
                "pstyp": "TAN",  # Item category
                "menge": self.format_quantity(item["quantity"]),
                "menee": item["unit"],
                "bmng2": self.format_quantity(item["quantity"]),
                "pmene": item["unit"],
                "abftz": "0",
                "vprei": self.format_amount(item.get("price", 0)),
                "peinh": "1",
                "netwr": self.format_amount(line_value),
                "anetw": self.format_amount(line_value),
                "skfbp": "100.00",
                "curcy": "USD",
                "preis": self.format_amount(item.get("price", 0)),
                "mwskz": "S1",  # Tax code
                "msatz": "8.00",  # Tax rate
                "meins": item["unit"],
                "posex_id": str(position),
                "kzabs": "",
                "matkl": item.get("category", ""),
                "matwa": item["material_id"],
                "werks": warehouse["warehouse_id"],
                "lprio": priority,
                "route": "01",
                "lgort": "0001",  # Storage location
                "vstel": warehouse["warehouse_id"],
                "delco": "",
                "matnr": item["material_id"],
                "arktx": item["description"]
            }
            
            line_items.append(line_item)
            
            # E1EDP19 - Object identification
            line_items.append({
                "segnam": "E1EDP19",
                "qualf": "002",  # Material number
                "idtnr": item["material_id"],
                "ktext": item["description"]
            })
            
            # E1EDP26 - Pricing
            line_items.append({
                "segnam": "E1EDP26",
                "qualf": "003",  # Net price
                "betrg": self.format_amount(item.get("price", 0)),
                "krate": "1.000",
                "waers": "USD"
            })
            
            # E1EDPT1 - Item text
            line_items.append({
                "segnam": "E1EDPT1",
                "tdid": "0001",
                "tdline": item["description"]
            })
            
            # E1EDP20 - Schedule line
            line_items.append({
                "segnam": "E1EDP20",
                "edatu": self.format_date(requested_delivery_date),
                "wmeng": self.format_quantity(item["quantity"]),
                "ameng": self.format_quantity(item["quantity"]),
                "edatu_old": "",
                "ezeit": "000000"
            })
            
            position += 10
        
        # E1EDS01 - Summary
        summary = {
            "segnam": "E1EDS01",
            "sumid": "001",  # Grand total
            "summe": self.format_amount(total_value),
            "sunit": "USD",
            "waerq": "USD"
        }
        
        # E1EDKT1 - Header text
        text_header = {
            "segnam": "E1EDKT1",
            "tdid": "0001",
            "tsspras": "E",
            "tdformat": "*",
            "tdline": f"Order {order_number} - Priority: {self._get_priority_text(priority)}"
        }
        
        # Assemble complete IDoc
        idoc = {
            "control": control,
            "data": {
                "E1EDK01": [header],
                "E1EDK02": [doc_data],
                "E1EDK03": dates,
                "E1EDKA1": partners,
                "E1EDP01": line_items,
                "E1EDS01": [summary],
                "E1EDKT1": [text_header]
            },
            "order_summary": {
                "total_value": total_value,
                "total_weight_kg": total_weight,
                "total_items": len(items),
                "currency": "USD"
            }
        }
        
        return self.to_json(idoc)
    
    def _get_priority_text(self, priority: str) -> str:
        """Get human-readable priority text"""
        priority_map = {
            "1": "High",
            "2": "Normal",
            "3": "Low"
        }
        return priority_map.get(priority, "Normal")
