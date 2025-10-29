"""
INVOICE IDoc Schema - Invoice
Message type: INVOIC
IDoc type: INVOIC02
"""

from datetime import datetime
from typing import Dict, Any, List
from .base_schema import BaseIDocSchema


class INVOICESchema(BaseIDocSchema):
    """INVOIC - Billing document (Invoice)"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        super().__init__(sap_system, sap_client)
        self.idoc_type = "INVOIC02"
        self.message_type = "INVOIC"
    
    def generate(
        self,
        invoice_number: str,
        delivery_number: str,
        customer: Dict[str, Any],
        items: List[Dict[str, Any]],
        invoice_date: datetime,
        due_date: datetime,
        payment_terms: str = "Net 30",
        tax_rate: float = 0.08
    ) -> Dict[str, Any]:
        """
        Generate INVOIC IDoc
        
        Args:
            invoice_number: Invoice document number
            delivery_number: Reference delivery number
            customer: Bill-to customer
            items: List of invoice line items
            invoice_date: Invoice date
            due_date: Payment due date
            payment_terms: Payment terms description
            tax_rate: Tax rate (default 8%)
        
        Returns:
            Complete IDoc structure
        """
        control = self.create_control_record(sender="BILLING")
        
        # Calculate totals
        subtotal = sum(item.get("price", 0) * item.get("quantity", 1) for item in items)
        tax_amount = subtotal * tax_rate
        total_amount = subtotal + tax_amount
        
        # E1EDK01 - Document header (Enhanced for B2B partner sharing)
        header = {
            "segnam": "E1EDK01",
            "belnr": invoice_number,
            "bldat": self.format_date(invoice_date),
            "curcy": "USD",
            "wkurs": "1.00000",
            "zterm": payment_terms,
            "bsart": "ZINV",  # Invoice type
            "recipnt_no": customer["customer_id"],
            # B2B Partner Fields
            "customer_id": customer.get("customer_id", ""),
            "customer_name": customer.get("name", ""),
            "partner_access_scope": "CUSTOMER"
        }
        
        # E1EDK03 - Date segments
        dates = [
            {
                "segnam": "E1EDK03",
                "iddat": "012",  # Invoice date
                "datum": self.format_date(invoice_date),
                "uzeit": self.format_time(invoice_date)
            },
            {
                "segnam": "E1EDK03",
                "iddat": "013",  # Due date
                "datum": self.format_date(due_date)
            }
        ]
        
        # E1EDK14 - References
        references = [
            {
                "segnam": "E1EDK14",
                "qualf": "001",  # Reference document
                "orgid": delivery_number,
                "text": f"Delivery {delivery_number}"
            }
        ]
        
        # E1EDKA1 - Partner information
        partners = [
            {
                "segnam": "E1EDKA1",
                "parvw": "RE",  # Bill-to party
                "partn": customer["customer_id"],
                "name1": customer["name"],
                "stras": customer["street"],
                "ort01": customer["city"],
                "regio": customer["state"],
                "pstlz": customer["postal_code"],
                "land1": customer["country"],
                "telf1": customer.get("phone", ""),
                "smtp_addr": customer.get("email", "")
            }
        ]
        
        # E1EDP01 - Line items
        line_items = []
        position = 10
        
        for item in items:
            line_amount = item.get("price", 0) * item.get("quantity", 1)
            
            line_item = {
                "segnam": "E1EDP01",
                "posex": str(position),
                "menge": self.format_quantity(item["quantity"]),
                "menee": item["unit"],
                "bmng2": self.format_quantity(item["quantity"]),
                "pmene": item["unit"],
                "abftz": "0",  # Number of deliveries
                "vprei": self.format_amount(item.get("price", 0)),
                "peinh": "1",
                "netwr": self.format_amount(line_amount),
                "anetw": self.format_amount(line_amount),
                "skfbp": "100.00",  # Percent of base price
                "curcy": "USD",
                "mwskz": "S1",  # Tax code
                "matnr": item["material_id"],
                "arktx": item["description"]
            }
            
            line_items.append(line_item)
            
            # E1EDP19 - Item object identification
            line_items.append({
                "segnam": "E1EDP19",
                "qualf": "001",  # Material number
                "idtnr": item["material_id"],
                "ktext": item["description"]
            })
            
            # E1EDP26 - Pricing conditions
            line_items.append({
                "segnam": "E1EDP26",
                "qualf": "003",  # Net price
                "betrg": self.format_amount(item.get("price", 0)),
                "krate": "1.000",
                "waers": "USD"
            })
            
            position += 10
        
        # E1EDS01 - Summary segment
        summary = {
            "segnam": "E1EDS01",
            "sumid": "002",  # Total value
            "summe": self.format_amount(subtotal),
            "sunit": "USD"
        }
        
        # Tax summary
        tax_summary = {
            "segnam": "E1EDS01",
            "sumid": "011",  # Tax amount
            "summe": self.format_amount(tax_amount),
            "sunit": "USD"
        }
        
        # Grand total
        grand_total = {
            "segnam": "E1EDS01",
            "sumid": "001",  # Grand total
            "summe": self.format_amount(total_amount),
            "sunit": "USD"
        }
        
        # E1EDKT1 - Text headers (invoice notes)
        text_header = {
            "segnam": "E1EDKT1",
            "tdid": "0001",  # Text ID
            "tsspras": "E",  # Language (English)
            "tdformat": "*",
            "tdline": f"Invoice for delivery {delivery_number}. Payment terms: {payment_terms}"
        }
        
        # Assemble complete IDoc
        idoc = {
            "control": control,
            "data": {
                "E1EDK01": [header],
                "E1EDK03": dates,
                "E1EDK14": references,
                "E1EDKA1": partners,
                "E1EDP01": line_items,
                "E1EDS01": [summary, tax_summary, grand_total],
                "E1EDKT1": [text_header]
            },
            "invoice_summary": {
                "subtotal": subtotal,
                "tax_amount": tax_amount,
                "total_amount": total_amount,
                "tax_rate": tax_rate,
                "currency": "USD"
            }
        }
        
        return self.to_json(idoc)
