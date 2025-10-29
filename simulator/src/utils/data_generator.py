"""
Helper functions for generating realistic business data
"""

import random
from datetime import datetime, timedelta
from typing import List, Dict, Any
from faker import Faker

fake = Faker()


class DataGenerator:
    """Generates realistic 3PL business data"""
    
    def __init__(self, warehouse_count: int = 5, customer_count: int = 100, carrier_count: int = 20):
        self.warehouse_count = warehouse_count
        self.customer_count = customer_count
        self.carrier_count = carrier_count
        
        # Pre-generate master data for consistency
        self.warehouses = self._generate_warehouses()
        self.customers = self._generate_customers()
        self.carriers = self._generate_carriers()
        self.products = self._generate_products()
    
    def _generate_warehouses(self) -> List[Dict[str, Any]]:
        """Generate warehouse master data"""
        warehouses = []
        cities = ["Chicago", "Atlanta", "Los Angeles", "Dallas", "Newark"]
        partner_names = [
            "LogiTech Warehousing",
            "Global Storage Solutions",
            "Premier Logistics Partners",
            "Integrated Fulfillment Services",
            "Strategic Distribution Inc"
        ]
        
        for i in range(self.warehouse_count):
            # First 2 warehouses are owned, rest are partner-operated
            is_partner = i >= 2
            warehouses.append({
                "warehouse_id": f"WH{i+1:03d}",
                "name": f"{cities[i]} Distribution Center",
                "city": cities[i],
                "state": fake.state_abbr(),
                "country": "US",
                "postal_code": fake.postcode(),
                # B2B Partner Fields
                "partner_id": f"PARTNER-WH{i+1:03d}" if is_partner else "",
                "partner_name": partner_names[i] if is_partner else "",
                "is_partner_operated": is_partner
            })
        
        return warehouses
    
    def _generate_customers(self) -> List[Dict[str, Any]]:
        """Generate customer master data"""
        customers = []
        
        for i in range(self.customer_count):
            customers.append({
                "customer_id": f"CUST{i+1:06d}",
                "name": fake.company(),
                "street": fake.street_address(),
                "city": fake.city(),
                "state": fake.state_abbr(),
                "postal_code": fake.postcode(),
                "country": "US",
                "phone": fake.phone_number(),
                "email": fake.company_email()
            })
        
        return customers
    
    def _generate_carriers(self) -> List[Dict[str, Any]]:
        """Generate carrier master data (B2B partners)"""
        carrier_names = [
            "FedEx Ground", "UPS", "DHL Express", "USPS Priority",
            "XPO Logistics", "J.B. Hunt", "Schneider", "Werner",
            "Knight-Swift", "YRC Freight", "Old Dominion", "Estes Express",
            "ABF Freight", "Saia", "R+L Carriers", "Southeastern Freight",
            "Dayton Freight", "TForce Freight", "ArcBest", "Averitt Express"
        ]
        
        carriers = []
        for i in range(min(self.carrier_count, len(carrier_names))):
            carrier_id = f"CARRIER-{carrier_names[i].upper().replace(' ', '-')[:10]}"
            carriers.append({
                "carrier_id": carrier_id,
                "name": carrier_names[i],
                "scac": f"{''.join(random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ', k=4))}",
                "service_level": random.choice(["STANDARD", "EXPRESS", "EXPEDITED", "ECONOMY"])
            })
        
        return carriers
    
    def _generate_products(self) -> List[Dict[str, Any]]:
        """Generate product master data"""
        products = []
        categories = [
            ("Electronics", ["Laptop", "Monitor", "Keyboard", "Mouse", "Headphones"]),
            ("Furniture", ["Desk", "Chair", "Cabinet", "Shelf", "Table"]),
            ("Apparel", ["Shirt", "Pants", "Jacket", "Shoes", "Hat"]),
            ("Food", ["Cereal", "Snacks", "Beverages", "Canned Goods", "Pasta"]),
            ("Hardware", ["Screws", "Nails", "Bolts", "Tools", "Paint"])
        ]
        
        product_id = 1
        for category, items in categories:
            for item in items:
                products.append({
                    "material_id": f"MAT{product_id:08d}",
                    "description": f"{item} - {category}",
                    "category": category,
                    "unit": random.choice(["EA", "CS", "PL", "BX"]),
                    "weight_kg": round(random.uniform(0.1, 25.0), 2),
                    "volume_m3": round(random.uniform(0.001, 0.5), 3)
                })
                product_id += 1
        
        return products
    
    def get_random_warehouse(self) -> Dict[str, Any]:
        """Get a random warehouse"""
        return random.choice(self.warehouses)
    
    def get_random_customer(self) -> Dict[str, Any]:
        """Get a random customer"""
        return random.choice(self.customers)
    
    def get_random_carrier(self) -> Dict[str, Any]:
        """Get a random carrier"""
        return random.choice(self.carriers)
    
    def get_random_products(self, min_items: int = 1, max_items: int = 10) -> List[Dict[str, Any]]:
        """Get random products with quantities"""
        num_items = random.randint(min_items, max_items)
        selected_products = random.sample(self.products, min(num_items, len(self.products)))
        
        items = []
        for product in selected_products:
            items.append({
                **product,
                "quantity": random.randint(1, 100),
                "price": round(random.uniform(10.0, 1000.0), 2)
            })
        
        return items
    
    def generate_document_number(self, prefix: str = "DOC") -> str:
        """Generate a unique document number"""
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        random_suffix = random.randint(1000, 9999)
        return f"{prefix}{timestamp}{random_suffix}"
    
    def generate_tracking_number(self) -> str:
        """Generate a carrier tracking number"""
        return f"1Z{''.join(random.choices('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', k=16))}"
    
    def random_date_range(self, days_ago: int = 7, days_ahead: int = 30) -> datetime:
        """Generate a random date within a range"""
        start_date = datetime.now() - timedelta(days=days_ago)
        end_date = datetime.now() + timedelta(days=days_ahead)
        time_between = end_date - start_date
        random_days = random.randint(0, time_between.days)
        return start_date + timedelta(days=random_days)
