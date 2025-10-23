"""
Main IDoc Generator
Generates realistic SAP IDoc messages for 3PL scenarios
"""

import asyncio
import random
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from src.idoc_schemas import (
    DESADVSchema,
    SHPMNTSchema,
    INVOICESchema,
    ORDERSSchema,
    WHSCONSchema
)
from src.utils.data_generator import DataGenerator
from src.utils.logger import setup_logger

logger = setup_logger("idoc_generator")


class IDocGenerator:
    """Generates realistic IDoc messages for 3PL business scenarios"""
    
    def __init__(
        self,
        sap_system: str = "S4HPRD",
        sap_client: str = "100",
        warehouse_count: int = 5,
        customer_count: int = 100,
        carrier_count: int = 20
    ):
        """
        Initialize IDoc generator
        
        Args:
            sap_system: SAP system ID
            sap_client: SAP client number
            warehouse_count: Number of warehouses to simulate
            customer_count: Number of customers to simulate
            carrier_count: Number of carriers to simulate
        """
        self.sap_system = sap_system
        self.sap_client = sap_client
        
        # Initialize data generator
        self.data_gen = DataGenerator(
            warehouse_count=warehouse_count,
            customer_count=customer_count,
            carrier_count=carrier_count
        )
        
        # Initialize IDoc schemas
        self.desadv_schema = DESADVSchema(sap_system, sap_client)
        self.shpmnt_schema = SHPMNTSchema(sap_system, sap_client)
        self.invoice_schema = INVOICESchema(sap_system, sap_client)
        self.orders_schema = ORDERSSchema(sap_system, sap_client)
        self.whscon_schema = WHSCONSchema(sap_system, sap_client)
        
        logger.info(f"IDoc Generator initialized for system {sap_system}, client {sap_client}")
        logger.info(f"Master data: {warehouse_count} warehouses, {customer_count} customers, {carrier_count} carriers")
    
    def generate_orders_idoc(self) -> Dict[str, Any]:
        """Generate a purchase/sales order IDoc"""
        customer = self.data_gen.get_random_customer()
        warehouse = self.data_gen.get_random_warehouse()
        items = self.data_gen.get_random_products(min_items=1, max_items=8)
        
        order_number = self.data_gen.generate_document_number("ORD")
        order_date = datetime.now()
        delivery_date = self.data_gen.random_date_range(days_ago=0, days_ahead=14)
        
        priority = random.choice(["1", "2", "2", "2", "3"])  # Weighted towards normal priority
        order_type = random.choice(["ZOR", "ZOR", "ZOR", "ZRE"])  # Mostly standard orders
        
        idoc = self.orders_schema.generate(
            order_number=order_number,
            customer=customer,
            warehouse=warehouse,
            items=items,
            order_date=order_date,
            requested_delivery_date=delivery_date,
            order_type=order_type,
            priority=priority
        )
        
        logger.debug(f"Generated ORDERS IDoc: {order_number}")
        return idoc
    
    def generate_whscon_idoc(self, operation_type: Optional[str] = None) -> Dict[str, Any]:
        """Generate a warehouse confirmation IDoc"""
        warehouse = self.data_gen.get_random_warehouse()
        items = self.data_gen.get_random_products(min_items=1, max_items=10)
        
        # Random operation type if not specified
        if not operation_type:
            operation_type = random.choice(["GR", "PI", "PA", "GI", "CC"])
        
        confirmation_number = self.data_gen.generate_document_number("WHC")
        reference_doc = self.data_gen.generate_document_number("REF")
        operation_date = datetime.now()
        
        # Add some variance to simulate real warehouse operations
        for item in items:
            target_qty = item["quantity"]
            # 90% accuracy rate
            if random.random() > 0.9:
                variance = random.randint(-3, 3)
                item["target_quantity"] = target_qty
                item["quantity"] = max(0, target_qty + variance)
                if variance != 0:
                    item["variance_reason"] = random.choice([
                        "COUNT_DISCREPANCY",
                        "DAMAGED_GOODS",
                        "SYSTEM_ERROR",
                        "WRONG_ITEM_RECEIVED"
                    ])
        
        status = random.choice(["COMPLETE", "COMPLETE", "COMPLETE", "PARTIAL"])  # Mostly complete
        
        idoc = self.whscon_schema.generate(
            confirmation_number=confirmation_number,
            warehouse=warehouse,
            operation_type=operation_type,
            reference_document=reference_doc,
            items=items,
            operation_date=operation_date,
            operator=f"USER{random.randint(1, 50):03d}",
            status=status
        )
        
        logger.debug(f"Generated WHSCON IDoc: {confirmation_number} - {operation_type}")
        return idoc
    
    def generate_desadv_idoc(self) -> Dict[str, Any]:
        """Generate a dispatch advice (ASN) IDoc"""
        warehouse = self.data_gen.get_random_warehouse()
        customer = self.data_gen.get_random_customer()
        carrier = self.data_gen.get_random_carrier()
        items = self.data_gen.get_random_products(min_items=1, max_items=12)
        
        delivery_number = self.data_gen.generate_document_number("DEL")
        tracking_number = self.data_gen.generate_tracking_number()
        shipment_date = self.data_gen.random_date_range(days_ago=0, days_ahead=3)
        
        idoc = self.desadv_schema.generate(
            delivery_number=delivery_number,
            warehouse=warehouse,
            customer=customer,
            carrier=carrier,
            items=items,
            shipment_date=shipment_date,
            tracking_number=tracking_number
        )
        
        logger.debug(f"Generated DESADV IDoc: {delivery_number}")
        return idoc
    
    def generate_shpmnt_idoc(self) -> Dict[str, Any]:
        """Generate a shipment tracking IDoc"""
        warehouse = self.data_gen.get_random_warehouse()
        customer = self.data_gen.get_random_customer()
        carrier = self.data_gen.get_random_carrier()
        
        shipment_number = self.data_gen.generate_document_number("SHP")
        delivery_number = self.data_gen.generate_document_number("DEL")
        tracking_number = self.data_gen.generate_tracking_number()
        
        # Simulate shipment lifecycle
        pickup_date = self.data_gen.random_date_range(days_ago=5, days_ahead=0)
        
        # Shipment status distribution
        status_choice = random.random()
        if status_choice < 0.6:  # 60% in transit
            shipment_status = "A"
            delivery_date = None
            tracking_events = self._generate_tracking_events(pickup_date, status="IN_TRANSIT")
        elif status_choice < 0.9:  # 30% delivered
            shipment_status = "B"
            delivery_date = pickup_date + timedelta(days=random.randint(1, 5))
            tracking_events = self._generate_tracking_events(pickup_date, delivery_date, status="DELIVERED")
        else:  # 10% exception
            shipment_status = "C"
            delivery_date = None
            tracking_events = self._generate_tracking_events(pickup_date, status="EXCEPTION")
        
        idoc = self.shpmnt_schema.generate(
            shipment_number=shipment_number,
            delivery_number=delivery_number,
            warehouse=warehouse,
            customer=customer,
            carrier=carrier,
            tracking_number=tracking_number,
            shipment_status=shipment_status,
            pickup_date=pickup_date,
            delivery_date=delivery_date,
            tracking_events=tracking_events
        )
        
        logger.debug(f"Generated SHPMNT IDoc: {shipment_number} - Status: {shipment_status}")
        return idoc
    
    def generate_invoice_idoc(self) -> Dict[str, Any]:
        """Generate an invoice IDoc"""
        customer = self.data_gen.get_random_customer()
        items = self.data_gen.get_random_products(min_items=1, max_items=15)
        
        invoice_number = self.data_gen.generate_document_number("INV")
        delivery_number = self.data_gen.generate_document_number("DEL")
        invoice_date = datetime.now()
        due_date = invoice_date + timedelta(days=30)
        
        payment_terms = random.choice(["Net 30", "Net 45", "Net 60", "Due on Receipt"])
        tax_rate = random.choice([0.06, 0.07, 0.08, 0.09, 0.10])  # Various state tax rates
        
        idoc = self.invoice_schema.generate(
            invoice_number=invoice_number,
            delivery_number=delivery_number,
            customer=customer,
            items=items,
            invoice_date=invoice_date,
            due_date=due_date,
            payment_terms=payment_terms,
            tax_rate=tax_rate
        )
        
        logger.debug(f"Generated INVOICE IDoc: {invoice_number}")
        return idoc
    
    def generate_mixed_batch(self, batch_size: int = 100) -> List[Dict[str, Any]]:
        """
        Generate a mixed batch of different IDoc types
        
        Args:
            batch_size: Number of IDocs to generate
        
        Returns:
            List of IDoc messages
        """
        idocs = []
        
        # Distribution of IDoc types (realistic 3PL scenario)
        # ORDERS: 25%, WHSCON: 30%, DESADV: 20%, SHPMNT: 15%, INVOICE: 10%
        idoc_distribution = (
            ["ORDERS"] * 25 +
            ["WHSCON"] * 30 +
            ["DESADV"] * 20 +
            ["SHPMNT"] * 15 +
            ["INVOICE"] * 10
        )
        
        for _ in range(batch_size):
            idoc_type = random.choice(idoc_distribution)
            
            if idoc_type == "ORDERS":
                idoc = self.generate_orders_idoc()
            elif idoc_type == "WHSCON":
                idoc = self.generate_whscon_idoc()
            elif idoc_type == "DESADV":
                idoc = self.generate_desadv_idoc()
            elif idoc_type == "SHPMNT":
                idoc = self.generate_shpmnt_idoc()
            elif idoc_type == "INVOICE":
                idoc = self.generate_invoice_idoc()
            
            idocs.append(idoc)
        
        logger.info(f"Generated batch of {batch_size} mixed IDocs")
        return idocs
    
    def _generate_tracking_events(
        self,
        pickup_date: datetime,
        delivery_date: Optional[datetime] = None,
        status: str = "IN_TRANSIT"
    ) -> List[Dict[str, Any]]:
        """Generate realistic tracking events for a shipment"""
        events = []
        cities = ["Chicago", "Indianapolis", "Columbus", "Pittsburgh", "Philadelphia"]
        
        # Pickup event
        events.append({
            "sequence": 1,
            "event_type": "PICKUP",
            "timestamp": pickup_date,
            "status_code": "P",
            "description": "Package picked up",
            "location": cities[0]
        })
        
        if status == "IN_TRANSIT":
            # Add in-transit scans
            for i in range(random.randint(1, 3)):
                scan_time = pickup_date + timedelta(days=i+1, hours=random.randint(0, 23))
                events.append({
                    "sequence": i + 2,
                    "event_type": "IN_TRANSIT",
                    "timestamp": scan_time,
                    "status_code": "A",
                    "description": "In transit",
                    "location": cities[min(i+1, len(cities)-1)]
                })
        
        elif status == "DELIVERED" and delivery_date:
            # Add in-transit and delivery events
            transit_days = (delivery_date - pickup_date).days
            for i in range(transit_days):
                scan_time = pickup_date + timedelta(days=i+1, hours=random.randint(8, 18))
                events.append({
                    "sequence": i + 2,
                    "event_type": "IN_TRANSIT",
                    "timestamp": scan_time,
                    "status_code": "A",
                    "description": "In transit",
                    "location": cities[min(i+1, len(cities)-2)]
                })
            
            # Out for delivery
            events.append({
                "sequence": len(events) + 1,
                "event_type": "OUT_FOR_DELIVERY",
                "timestamp": delivery_date - timedelta(hours=2),
                "status_code": "D",
                "description": "Out for delivery",
                "location": cities[-1]
            })
            
            # Delivered
            events.append({
                "sequence": len(events) + 1,
                "event_type": "DELIVERED",
                "timestamp": delivery_date,
                "status_code": "B",
                "description": "Delivered",
                "location": cities[-1]
            })
        
        elif status == "EXCEPTION":
            # Add exception event
            exception_time = pickup_date + timedelta(days=random.randint(1, 3))
            events.append({
                "sequence": 2,
                "event_type": "EXCEPTION",
                "timestamp": exception_time,
                "status_code": "E",
                "description": random.choice([
                    "Delivery exception - Address incorrect",
                    "Delivery exception - Customer not available",
                    "Delivery exception - Weather delay",
                    "Delivery exception - Mechanical delay"
                ]),
                "location": cities[random.randint(1, len(cities)-1)]
            })
        
        return events
