"""
WHSCON IDoc Schema - Warehouse Confirmation
Message type: WHSCON
IDoc type: WHSCON01
"""

from datetime import datetime
from typing import Dict, Any, List, Optional
from .base_schema import BaseIDocSchema


class WHSCONSchema(BaseIDocSchema):
    """WHSCON - Warehouse operations confirmation (goods receipt, picking, packing)"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        super().__init__(sap_system, sap_client)
        self.idoc_type = "WHSCON01"
        self.message_type = "WHSCON"
    
    def generate(
        self,
        confirmation_number: str,
        warehouse: Dict[str, Any],
        operation_type: str,
        reference_document: str,
        items: List[Dict[str, Any]],
        operation_date: datetime,
        operator: str = "WMS_USER",
        status: str = "COMPLETE"
    ) -> Dict[str, Any]:
        """
        Generate WHSCON IDoc
        
        Args:
            confirmation_number: Confirmation document number
            warehouse: Warehouse location
            operation_type: Type of operation (GR=Goods Receipt, PI=Picking, PA=Packing, GI=Goods Issue)
            reference_document: Reference document (PO, Delivery, etc.)
            items: List of items processed
            operation_date: Operation completion date/time
            operator: Operator/user ID
            status: Operation status (COMPLETE, PARTIAL, CANCELLED)
        
        Returns:
            Complete IDoc structure
        """
        control = self.create_control_record(sender=warehouse["warehouse_id"])
        
        # E1WHC00 - Confirmation header (Enhanced for B2B partner sharing)
        header = {
            "segnam": "E1WHC00",
            "confno": confirmation_number,
            "lgnum": warehouse["warehouse_id"],
            "whstype": operation_type,
            "refdoc": reference_document,
            "status": status,
            "confdat": self.format_date(operation_date),
            "conftim": self.format_time(operation_date),
            "usnam": operator,
            "warehouse_id": warehouse["warehouse_id"],
            "warehouse_name": warehouse["name"],
            # B2B Partner Fields
            "warehouse_partner_id": warehouse.get("partner_id", ""),  # External warehouse operator ID
            "warehouse_partner_name": warehouse.get("partner_name", ""),  # Partner company name
            "partner_access_scope": "WAREHOUSE_PARTNER"  # Defines who can access this data
        }
        
        # E1WHC01 - Operation details
        operation_details = {
            "segnam": "E1WHC01",
            "oprtyp": operation_type,
            "oprdes": self._get_operation_description(operation_type),
            "strtdat": self.format_date(operation_date),
            "strttim": self.format_time(operation_date),
            "enddat": self.format_date(operation_date),
            "endtim": self.format_time(operation_date),
            "duration": "0",  # Duration in seconds (can be calculated)
            "resource": operator,
            "equipment": self._get_equipment_type(operation_type)
        }
        
        # E1WHC10 - Item confirmations
        confirmed_items = []
        position = 10
        
        for item in items:
            confirmed_qty = item.get("quantity", 0)
            
            item_confirmation = {
                "segnam": "E1WHC10",
                "itemno": str(position),
                "matnr": item["material_id"],
                "maktx": item["description"],
                "charg": item.get("batch", f"BATCH{datetime.now().strftime('%Y%m%d')}{position}"),
                "werks": warehouse["warehouse_id"],
                "lgort": item.get("storage_location", "0001"),
                "confqty": self.format_quantity(confirmed_qty),
                "unit": item["unit"],
                "targetqty": self.format_quantity(item.get("target_quantity", confirmed_qty)),
                "variance": self.format_quantity(confirmed_qty - item.get("target_quantity", confirmed_qty)),
                "weight": self.format_quantity(item.get("weight_kg", 0) * confirmed_qty),
                "weight_unit": "KGM",
                "status": "CONFIRMED"
            }
            
            confirmed_items.append(item_confirmation)
            
            # E1WHC11 - Serial numbers (if applicable)
            if item.get("serial_numbers"):
                for serial_no in item["serial_numbers"]:
                    confirmed_items.append({
                        "segnam": "E1WHC11",
                        "itemno": str(position),
                        "sernr": serial_no,
                        "matnr": item["material_id"]
                    })
            
            # E1WHC12 - Handling unit (if applicable)
            if item.get("handling_unit"):
                confirmed_items.append({
                    "segnam": "E1WHC12",
                    "itemno": str(position),
                    "exidv": item["handling_unit"],  # External HU ID
                    "vhilm": item.get("packaging_material", "PALLET"),
                    "inhalt": item["description"],
                    "vegr1": str(confirmed_qty),
                    "vhart": "001"  # HU type
                })
            
            # E1WHC13 - Bin/location details
            if operation_type in ["GR", "PI"]:
                confirmed_items.append({
                    "segnam": "E1WHC13",
                    "itemno": str(position),
                    "lgtyp": "001",  # Storage type
                    "lgpla": item.get("bin_location", f"BIN-{position:04d}"),
                    "nltyp": item.get("dest_storage_type", ""),
                    "nlpla": item.get("dest_bin", ""),
                    "quantity": self.format_quantity(confirmed_qty),
                    "unit": item["unit"]
                })
            
            position += 10
        
        # E1WHC20 - Resource utilization (optional)
        resources = [
            {
                "segnam": "E1WHC20",
                "restype": "LABOR",
                "resid": operator,
                "duration": "3600",  # seconds
                "efficiency": "95.5"  # percentage
            }
        ]
        
        if operation_type in ["PI", "PA"]:
            resources.append({
                "segnam": "E1WHC20",
                "restype": "EQUIPMENT",
                "resid": self._get_equipment_id(operation_type),
                "duration": "3600",
                "efficiency": "98.0"
            })
        
        # E1WHC30 - Quality inspection results (for GR operations)
        quality_checks = []
        if operation_type == "GR":
            quality_checks.append({
                "segnam": "E1WHC30",
                "insptype": "VISUAL",
                "result": "PASS",
                "inspector": operator,
                "inspdate": self.format_date(operation_date),
                "insptime": self.format_time(operation_date),
                "remarks": "All items inspected and approved"
            })
        
        # E1WHC40 - Exception/discrepancy reporting
        exceptions = []
        for item in items:
            variance = item.get("quantity", 0) - item.get("target_quantity", item.get("quantity", 0))
            if abs(variance) > 0.01:  # Tolerance threshold
                exceptions.append({
                    "segnam": "E1WHC40",
                    "excptype": "QUANTITY_VARIANCE",
                    "severity": "MEDIUM" if abs(variance) < 5 else "HIGH",
                    "itemno": str(items.index(item) * 10 + 10),
                    "matnr": item["material_id"],
                    "expected": self.format_quantity(item.get("target_quantity", 0)),
                    "actual": self.format_quantity(item.get("quantity", 0)),
                    "variance": self.format_quantity(variance),
                    "reason": item.get("variance_reason", "COUNT_DISCREPANCY"),
                    "action": "INVENTORY_ADJUSTMENT"
                })
        
        # Summary statistics
        total_items = len(items)
        total_qty = sum(item.get("quantity", 0) for item in items)
        total_weight = sum(item.get("weight_kg", 0) * item.get("quantity", 1) for item in items)
        
        # E1WHC50 - Summary segment
        summary = {
            "segnam": "E1WHC50",
            "totalitems": str(total_items),
            "totalqty": self.format_quantity(total_qty),
            "totalweight": self.format_quantity(total_weight),
            "weight_unit": "KGM",
            "exceptions": str(len(exceptions)),
            "completion_rate": self.format_amount((total_items - len(exceptions)) / total_items * 100 if total_items > 0 else 100, 2)
        }
        
        # Assemble complete IDoc
        idoc = {
            "control": control,
            "data": {
                "E1WHC00": [header],
                "E1WHC01": [operation_details],
                "E1WHC10": confirmed_items,
                "E1WHC20": resources,
                "E1WHC30": quality_checks,
                "E1WHC40": exceptions,
                "E1WHC50": [summary]
            },
            "confirmation_summary": {
                "total_items": total_items,
                "total_quantity": total_qty,
                "total_weight_kg": total_weight,
                "exception_count": len(exceptions),
                "completion_rate": (total_items - len(exceptions)) / total_items * 100 if total_items > 0 else 100,
                "status": status
            }
        }
        
        return self.to_json(idoc)
    
    def _get_operation_description(self, operation_type: str) -> str:
        """Get human-readable operation description"""
        operations = {
            "GR": "Goods Receipt",
            "PI": "Picking",
            "PA": "Packing",
            "GI": "Goods Issue",
            "CC": "Cycle Count",
            "PI": "Physical Inventory",
            "TR": "Transfer Posting"
        }
        return operations.get(operation_type, "Unknown Operation")
    
    def _get_equipment_type(self, operation_type: str) -> str:
        """Get equipment type for operation"""
        equipment = {
            "GR": "FORKLIFT",
            "PI": "RF_SCANNER",
            "PA": "PACKING_STATION",
            "GI": "DOCK_DOOR",
            "CC": "RF_SCANNER"
        }
        return equipment.get(operation_type, "MANUAL")
    
    def _get_equipment_id(self, operation_type: str) -> str:
        """Get equipment ID"""
        import random
        equipment_ids = {
            "PI": f"SCANNER{random.randint(1, 20):03d}",
            "PA": f"STATION{random.randint(1, 10):02d}",
            "GR": f"LIFT{random.randint(1, 15):02d}",
            "GI": f"DOCK{random.randint(1, 8):02d}"
        }
        return equipment_ids.get(operation_type, "EQUIP001")
