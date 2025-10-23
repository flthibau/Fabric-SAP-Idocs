"""
Tests for IDoc Schemas
"""

import pytest
from datetime import datetime
from src.idoc_schemas import (
    DESADVSchema,
    SHPMNTSchema,
    INVOICESchema,
    ORDERSSchema,
    WHSCONSchema
)


class TestDESADVSchema:
    """Test DESADV IDoc schema"""
    
    @pytest.fixture
    def schema(self):
        return DESADVSchema()
    
    @pytest.fixture
    def sample_data(self):
        return {
            "delivery_number": "DEL12345",
            "warehouse": {
                "warehouse_id": "WH001",
                "name": "Chicago DC",
                "city": "Chicago",
                "state": "IL",
                "country": "US",
                "postal_code": "60601"
            },
            "customer": {
                "customer_id": "CUST001",
                "name": "Test Customer",
                "street": "123 Main St",
                "city": "New York",
                "state": "NY",
                "postal_code": "10001",
                "country": "US"
            },
            "carrier": {
                "carrier_id": "CAR001",
                "name": "FedEx",
                "service_level": "EXPRESS"
            },
            "items": [
                {
                    "material_id": "MAT001",
                    "description": "Test Product",
                    "quantity": 10,
                    "unit": "EA",
                    "weight_kg": 2.5,
                    "volume_m3": 0.01
                }
            ],
            "shipment_date": datetime.now(),
            "tracking_number": "1Z999AA10123456784"
        }
    
    def test_desadv_generation(self, schema, sample_data):
        """Test DESADV IDoc generation"""
        idoc = schema.generate(**sample_data)
        
        assert idoc["idoc_type"] == "DESADV01"
        assert idoc["message_type"] == "DESADV"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1EDK01" in idoc["data"]
        assert "E1EDL20" in idoc["data"]


class TestSHPMNTSchema:
    """Test SHPMNT IDoc schema"""
    
    @pytest.fixture
    def schema(self):
        return SHPMNTSchema()
    
    def test_shpmnt_generation_in_transit(self, schema):
        """Test SHPMNT IDoc for in-transit shipment"""
        idoc = schema.generate(
            shipment_number="SHP12345",
            delivery_number="DEL12345",
            warehouse={"warehouse_id": "WH001", "name": "Test WH", "city": "Chicago", "state": "IL", "country": "US", "postal_code": "60601"},
            customer={"customer_id": "CUST001", "name": "Test", "street": "123 St", "city": "NYC", "postal_code": "10001", "country": "US"},
            carrier={"carrier_id": "CAR001", "name": "FedEx", "service_level": "EXPRESS"},
            tracking_number="1Z999AA10123456784",
            shipment_status="A",
            pickup_date=datetime.now()
        )
        
        assert idoc["idoc_type"] == "SHPMNT05"
        assert idoc["data"]["E1SHP00"][0]["shpsts"] == "A"


class TestINVOICESchema:
    """Test INVOICE IDoc schema"""
    
    @pytest.fixture
    def schema(self):
        return INVOICESchema()
    
    def test_invoice_generation(self, schema):
        """Test INVOICE IDoc generation"""
        idoc = schema.generate(
            invoice_number="INV12345",
            delivery_number="DEL12345",
            customer={"customer_id": "CUST001", "name": "Test", "street": "123 St", "city": "NYC", "state": "NY", "postal_code": "10001", "country": "US"},
            items=[
                {"material_id": "MAT001", "description": "Product", "quantity": 5, "unit": "EA", "price": 100.00}
            ],
            invoice_date=datetime.now(),
            due_date=datetime.now(),
            tax_rate=0.08
        )
        
        assert idoc["idoc_type"] == "INVOIC02"
        assert "invoice_summary" in idoc
        assert idoc["invoice_summary"]["tax_rate"] == 0.08
        # Subtotal should be 500 (5 * 100)
        assert idoc["invoice_summary"]["subtotal"] == 500.00
        # Total should be 540 (500 + 8% tax)
        assert idoc["invoice_summary"]["total_amount"] == 540.00


class TestORDERSSchema:
    """Test ORDERS IDoc schema"""
    
    @pytest.fixture
    def schema(self):
        return ORDERSSchema()
    
    def test_orders_generation(self, schema):
        """Test ORDERS IDoc generation"""
        idoc = schema.generate(
            order_number="ORD12345",
            customer={"customer_id": "CUST001", "name": "Test", "street": "123 St", "city": "NYC", "state": "NY", "postal_code": "10001", "country": "US"},
            warehouse={"warehouse_id": "WH001", "name": "Test WH"},
            items=[
                {"material_id": "MAT001", "description": "Product", "quantity": 10, "unit": "EA", "price": 50.00, "category": "Electronics", "weight_kg": 1.0}
            ],
            order_date=datetime.now(),
            requested_delivery_date=datetime.now(),
            priority="2"
        )
        
        assert idoc["idoc_type"] == "ORDERS05"
        assert "order_summary" in idoc
        assert idoc["order_summary"]["total_value"] == 500.00


class TestWHSCONSchema:
    """Test WHSCON IDoc schema"""
    
    @pytest.fixture
    def schema(self):
        return WHSCONSchema()
    
    def test_whscon_generation_goods_receipt(self, schema):
        """Test WHSCON IDoc for goods receipt"""
        idoc = schema.generate(
            confirmation_number="WHC12345",
            warehouse={"warehouse_id": "WH001", "name": "Test WH"},
            operation_type="GR",
            reference_document="PO12345",
            items=[
                {"material_id": "MAT001", "description": "Product", "quantity": 100, "unit": "EA", "weight_kg": 1.5}
            ],
            operation_date=datetime.now(),
            status="COMPLETE"
        )
        
        assert idoc["idoc_type"] == "WHSCON01"
        assert idoc["data"]["E1WHC00"][0]["whstype"] == "GR"
        assert idoc["data"]["E1WHC00"][0]["status"] == "COMPLETE"
        assert "confirmation_summary" in idoc


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
