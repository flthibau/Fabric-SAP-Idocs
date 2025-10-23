"""
Tests for Event Hub Publisher
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from src.eventstream_publisher import EventStreamPublisher


class TestEventStreamPublisher:
    """Test suite for Event Hub publisher"""
    
    @pytest.fixture
    def mock_producer(self):
        """Create mock Event Hub producer"""
        producer = AsyncMock()
        producer.create_batch = AsyncMock()
        producer.send_batch = AsyncMock()
        producer.close = AsyncMock()
        return producer
    
    @pytest.fixture
    def sample_idoc(self):
        """Create sample IDoc message"""
        return {
            "idoc_type": "ORDERS05",
            "message_type": "ORDERS",
            "sap_system": "TEST",
            "timestamp": "2025-10-23T10:00:00",
            "control": {
                "docnum": "1234567890",
                "mestyp": "ORDERS"
            },
            "data": {
                "E1EDK01": [{"belnr": "ORDER001"}]
            }
        }
    
    @pytest.mark.asyncio
    async def test_publisher_initialization_with_connection_string(self):
        """Test publisher initialization with connection string"""
        with patch('src.eventstream_publisher.EventHubProducerClient') as mock_client:
            publisher = EventStreamPublisher(
                connection_string="Endpoint=sb://test.servicebus.windows.net/;SharedAccessKeyName=test;SharedAccessKey=test==",
                eventhub_name="test-eventhub"
            )
            
            assert publisher.eventhub_name == "test-eventhub"
            assert publisher.use_azure_credential is False
            assert publisher.messages_sent == 0
            assert publisher.bytes_sent == 0
    
    @pytest.mark.asyncio
    async def test_publisher_initialization_with_azure_credential(self):
        """Test publisher initialization with Azure AD"""
        with patch('src.eventstream_publisher.EventHubProducerClient') as mock_client, \
             patch('src.eventstream_publisher.DefaultAzureCredential') as mock_cred:
            
            publisher = EventStreamPublisher(
                namespace="test-namespace",
                eventhub_name="test-eventhub",
                use_azure_credential=True
            )
            
            assert publisher.eventhub_name == "test-eventhub"
            assert publisher.use_azure_credential is True
    
    def test_publisher_initialization_failure(self):
        """Test that publisher raises error without credentials"""
        with pytest.raises(ValueError):
            publisher = EventStreamPublisher(eventhub_name="test")
    
    @pytest.mark.asyncio
    async def test_send_message_success(self, mock_producer, sample_idoc):
        """Test successful message sending"""
        with patch('src.eventstream_publisher.EventHubProducerClient.from_connection_string') as mock_client:
            mock_batch = MagicMock()
            mock_batch.add = MagicMock()
            mock_producer.create_batch.return_value = mock_batch
            
            mock_client.return_value = mock_producer
            
            publisher = EventStreamPublisher(
                connection_string="Endpoint=sb://test.servicebus.windows.net/",
                eventhub_name="test"
            )
            
            result = await publisher.send_message(sample_idoc)
            
            assert result is True
            assert publisher.messages_sent == 1
            assert publisher.bytes_sent > 0
    
    @pytest.mark.asyncio
    async def test_send_batch_success(self, mock_producer, sample_idoc):
        """Test successful batch sending"""
        with patch('src.eventstream_publisher.EventHubProducerClient.from_connection_string') as mock_client:
            mock_batch = MagicMock()
            mock_batch.add = MagicMock()
            mock_batch.__len__ = MagicMock(return_value=3)
            mock_producer.create_batch.return_value = mock_batch
            
            mock_client.return_value = mock_producer
            
            publisher = EventStreamPublisher(
                connection_string="Endpoint=sb://test.servicebus.windows.net/",
                eventhub_name="test"
            )
            
            batch = [sample_idoc, sample_idoc, sample_idoc]
            result = await publisher.send_batch(batch)
            
            assert result == 3
            assert publisher.messages_sent == 3
    
    def test_get_statistics(self):
        """Test statistics retrieval"""
        with patch('src.eventstream_publisher.EventHubProducerClient.from_connection_string'):
            publisher = EventStreamPublisher(
                connection_string="Endpoint=sb://test.servicebus.windows.net/",
                eventhub_name="test"
            )
            
            publisher.messages_sent = 100
            publisher.bytes_sent = 50000
            
            stats = publisher.get_statistics()
            
            assert stats["messages_sent"] == 100
            assert stats["bytes_sent"] == 50000
            assert stats["avg_message_size"] == 500
    
    def test_get_statistics_zero_messages(self):
        """Test statistics with zero messages"""
        with patch('src.eventstream_publisher.EventHubProducerClient.from_connection_string'):
            publisher = EventStreamPublisher(
                connection_string="Endpoint=sb://test.servicebus.windows.net/",
                eventhub_name="test"
            )
            
            stats = publisher.get_statistics()
            
            assert stats["messages_sent"] == 0
            assert stats["bytes_sent"] == 0
            assert stats["avg_message_size"] == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
