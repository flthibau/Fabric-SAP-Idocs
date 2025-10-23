"""
Tests for IDoc Generator
"""

import pytest
from datetime import datetime
from src.idoc_generator import IDocGenerator
from src.utils.data_generator import DataGenerator


class TestIDocGenerator:
    """Test suite for IDoc generator"""
    
    @pytest.fixture
    def generator(self):
        """Create IDoc generator instance"""
        return IDocGenerator(
            sap_system="TEST",
            sap_client="100",
            warehouse_count=3,
            customer_count=10,
            carrier_count=5
        )
    
    @pytest.fixture
    def data_gen(self):
        """Create data generator instance"""
        return DataGenerator(
            warehouse_count=3,
            customer_count=10,
            carrier_count=5
        )
    
    def test_generator_initialization(self, generator):
        """Test that generator initializes correctly"""
        assert generator.sap_system == "TEST"
        assert generator.sap_client == "100"
        assert generator.data_gen is not None
        assert len(generator.data_gen.warehouses) == 3
        assert len(generator.data_gen.customers) == 10
        assert len(generator.data_gen.carriers) == 5
    
    def test_generate_orders_idoc(self, generator):
        """Test ORDERS IDoc generation"""
        idoc = generator.generate_orders_idoc()
        
        assert idoc is not None
        assert idoc["idoc_type"] == "ORDERS05"
        assert idoc["message_type"] == "ORDERS"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1EDK01" in idoc["data"]
        assert "E1EDP01" in idoc["data"]
        assert "order_summary" in idoc
    
    def test_generate_whscon_idoc(self, generator):
        """Test WHSCON IDoc generation"""
        idoc = generator.generate_whscon_idoc(operation_type="GR")
        
        assert idoc is not None
        assert idoc["idoc_type"] == "WHSCON01"
        assert idoc["message_type"] == "WHSCON"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1WHC00" in idoc["data"]
        assert "E1WHC10" in idoc["data"]
        assert idoc["data"]["E1WHC00"][0]["whstype"] == "GR"
    
    def test_generate_desadv_idoc(self, generator):
        """Test DESADV IDoc generation"""
        idoc = generator.generate_desadv_idoc()
        
        assert idoc is not None
        assert idoc["idoc_type"] == "DESADV01"
        assert idoc["message_type"] == "DESADV"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1EDK01" in idoc["data"]
        assert "E1EDKA1" in idoc["data"]  # Partner data
        assert "E1EDL20" in idoc["data"]  # Line items
    
    def test_generate_shpmnt_idoc(self, generator):
        """Test SHPMNT IDoc generation"""
        idoc = generator.generate_shpmnt_idoc()
        
        assert idoc is not None
        assert idoc["idoc_type"] == "SHPMNT05"
        assert idoc["message_type"] == "SHPMNT"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1SHP00" in idoc["data"]
        assert "E1SHP01" in idoc["data"]
        assert "E1SHP10" in idoc["data"]  # Tracking events
    
    def test_generate_invoice_idoc(self, generator):
        """Test INVOICE IDoc generation"""
        idoc = generator.generate_invoice_idoc()
        
        assert idoc is not None
        assert idoc["idoc_type"] == "INVOIC02"
        assert idoc["message_type"] == "INVOIC"
        assert "control" in idoc
        assert "data" in idoc
        assert "E1EDK01" in idoc["data"]
        assert "E1EDP01" in idoc["data"]
        assert "E1EDS01" in idoc["data"]  # Summary
        assert "invoice_summary" in idoc
        assert "total_amount" in idoc["invoice_summary"]
    
    def test_generate_mixed_batch(self, generator):
        """Test mixed batch generation"""
        batch_size = 50
        idocs = generator.generate_mixed_batch(batch_size)
        
        assert len(idocs) == batch_size
        
        # Count IDoc types
        idoc_types = {}
        for idoc in idocs:
            idoc_type = idoc["message_type"]
            idoc_types[idoc_type] = idoc_types.get(idoc_type, 0) + 1
        
        # Check that we have multiple types
        assert len(idoc_types) > 1
        
        # Verify expected types are present
        expected_types = {"ORDERS", "WHSCON", "DESADV", "SHPMNT", "INVOIC"}
        assert all(t in expected_types for t in idoc_types.keys())
    
    def test_control_record_format(self, generator):
        """Test control record formatting"""
        idoc = generator.generate_orders_idoc()
        control = idoc["control"]
        
        assert "tabnam" in control
        assert control["tabnam"] == "EDIDC"
        assert "docnum" in control
        assert "idoctyp" in control
        assert "mestyp" in control
        assert "credat" in control
        assert "cretim" in control
        assert len(control["credat"]) == 8  # YYYYMMDD
        assert len(control["cretim"]) == 6  # HHMMSS
    
    def test_data_generator_master_data(self, data_gen):
        """Test that master data is generated correctly"""
        assert len(data_gen.warehouses) == 3
        assert len(data_gen.customers) == 10
        assert len(data_gen.carriers) == 5
        
        # Test warehouse structure
        warehouse = data_gen.get_random_warehouse()
        assert "warehouse_id" in warehouse
        assert "name" in warehouse
        assert "city" in warehouse
        
        # Test customer structure
        customer = data_gen.get_random_customer()
        assert "customer_id" in customer
        assert "name" in customer
        assert "street" in customer
        
        # Test carrier structure
        carrier = data_gen.get_random_carrier()
        assert "carrier_id" in carrier
        assert "name" in carrier
        assert "service_level" in carrier
    
    def test_idoc_timestamp_format(self, generator):
        """Test that timestamps are properly formatted"""
        idoc = generator.generate_orders_idoc()
        
        assert "timestamp" in idoc
        # Verify ISO format
        timestamp = datetime.fromisoformat(idoc["timestamp"])
        assert isinstance(timestamp, datetime)
    
    def test_line_items_structure(self, generator):
        """Test that line items are properly structured"""
        idoc = generator.generate_orders_idoc()
        line_items = idoc["data"]["E1EDP01"]
        
        assert len(line_items) > 0
        
        # Filter for main item segments (not sub-segments)
        main_items = [item for item in line_items if item.get("segnam") == "E1EDP01"]
        assert len(main_items) > 0
        
        # Check first item structure
        first_item = main_items[0]
        assert "posex" in first_item
        assert "menge" in first_item
        assert "matnr" in first_item
        assert "arktx" in first_item


class TestDataGenerator:
    """Test suite for data generator"""
    
    @pytest.fixture
    def data_gen(self):
        """Create data generator instance"""
        return DataGenerator(
            warehouse_count=5,
            customer_count=100,
            carrier_count=20
        )
    
    def test_generate_document_number(self, data_gen):
        """Test document number generation"""
        doc_num = data_gen.generate_document_number("TEST")
        
        assert doc_num.startswith("TEST")
        assert len(doc_num) > 4
        
        # Generate another to ensure uniqueness
        doc_num2 = data_gen.generate_document_number("TEST")
        assert doc_num != doc_num2
    
    def test_generate_tracking_number(self, data_gen):
        """Test tracking number generation"""
        tracking = data_gen.generate_tracking_number()
        
        assert tracking.startswith("1Z")
        assert len(tracking) == 18
    
    def test_random_date_range(self, data_gen):
        """Test random date generation"""
        date = data_gen.random_date_range(days_ago=7, days_ahead=30)
        
        assert isinstance(date, datetime)
        
        # Verify it's within expected range
        from datetime import timedelta
        min_date = datetime.now() - timedelta(days=8)
        max_date = datetime.now() + timedelta(days=31)
        assert min_date < date < max_date
    
    def test_get_random_products(self, data_gen):
        """Test random product generation"""
        products = data_gen.get_random_products(min_items=3, max_items=5)
        
        assert 3 <= len(products) <= 5
        
        for product in products:
            assert "material_id" in product
            assert "description" in product
            assert "quantity" in product
            assert "price" in product
            assert product["quantity"] > 0
            assert product["price"] > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
