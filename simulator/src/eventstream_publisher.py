"""
Azure Event Hub Publisher for IDoc messages
"""

import asyncio
import json
from typing import Dict, Any, List
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData
from azure.identity.aio import DefaultAzureCredential
from src.utils.logger import setup_logger

logger = setup_logger("eventstream_publisher")


class EventStreamPublisher:
    """Publishes IDoc messages to Azure Event Hub"""
    
    def __init__(
        self,
        connection_string: str = None,
        namespace: str = None,
        eventhub_name: str = None,
        use_azure_credential: bool = False
    ):
        """
        Initialize Event Hub publisher
        
        Args:
            connection_string: Event Hub connection string (if not using Azure AD)
            namespace: Event Hub namespace (for Azure AD auth)
            eventhub_name: Event Hub name
            use_azure_credential: Use Azure AD authentication
        """
        self.eventhub_name = eventhub_name
        self.use_azure_credential = use_azure_credential
        
        if use_azure_credential and namespace:
            # Use Azure AD authentication
            self.credential = DefaultAzureCredential()
            fully_qualified_namespace = f"{namespace}.servicebus.windows.net"
            self.producer = EventHubProducerClient(
                fully_qualified_namespace=fully_qualified_namespace,
                eventhub_name=eventhub_name,
                credential=self.credential
            )
            logger.info(f"Initialized Event Hub producer with Azure AD auth: {fully_qualified_namespace}/{eventhub_name}")
        elif connection_string:
            # Use connection string authentication
            self.producer = EventHubProducerClient.from_connection_string(
                conn_str=connection_string,
                eventhub_name=eventhub_name
            )
            logger.info(f"Initialized Event Hub producer with connection string: {eventhub_name}")
        else:
            raise ValueError("Either connection_string or (namespace + use_azure_credential) must be provided")
        
        self.messages_sent = 0
        self.bytes_sent = 0
    
    async def send_message(self, idoc_message: Dict[str, Any]) -> bool:
        """
        Send a single IDoc message to Event Hub
        
        Args:
            idoc_message: IDoc message in JSON format
        
        Returns:
            True if successful, False otherwise
        """
        try:
            # Convert to JSON string
            message_body = json.dumps(idoc_message)
            
            # Create Event Data with properties
            event_data = EventData(message_body)
            event_data.properties = {
                "idoc_type": idoc_message.get("idoc_type", ""),
                "message_type": idoc_message.get("message_type", ""),
                "sap_system": idoc_message.get("sap_system", ""),
                "timestamp": idoc_message.get("timestamp", "")
            }
            
            # Send to Event Hub
            async with self.producer:
                event_batch = await self.producer.create_batch()
                event_batch.add(event_data)
                await self.producer.send_batch(event_batch)
            
            self.messages_sent += 1
            self.bytes_sent += len(message_body)
            
            logger.debug(f"Sent IDoc message: {idoc_message.get('idoc_type')} - {idoc_message.get('control', {}).get('docnum')}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending message: {str(e)}", exc_info=True)
            return False
    
    async def send_batch(self, idoc_messages: List[Dict[str, Any]]) -> int:
        """
        Send a batch of IDoc messages to Event Hub
        
        Args:
            idoc_messages: List of IDoc messages
        
        Returns:
            Number of messages successfully sent
        """
        sent_count = 0
        
        try:
            async with self.producer:
                event_batch = await self.producer.create_batch()
                
                for idoc_message in idoc_messages:
                    try:
                        message_body = json.dumps(idoc_message)
                        event_data = EventData(message_body)
                        event_data.properties = {
                            "idoc_type": idoc_message.get("idoc_type", ""),
                            "message_type": idoc_message.get("message_type", ""),
                            "sap_system": idoc_message.get("sap_system", ""),
                            "timestamp": idoc_message.get("timestamp", "")
                        }
                        
                        # Try to add to batch
                        event_batch.add(event_data)
                        self.bytes_sent += len(message_body)
                        
                    except ValueError:
                        # Batch is full, send it and create a new one
                        await self.producer.send_batch(event_batch)
                        sent_count += len(event_batch)
                        logger.info(f"Sent batch of {len(event_batch)} messages")
                        
                        # Create new batch and add current message
                        event_batch = await self.producer.create_batch()
                        message_body = json.dumps(idoc_message)
                        event_data = EventData(message_body)
                        event_data.properties = {
                            "idoc_type": idoc_message.get("idoc_type", ""),
                            "message_type": idoc_message.get("message_type", ""),
                            "sap_system": idoc_message.get("sap_system", ""),
                            "timestamp": idoc_message.get("timestamp", "")
                        }
                        event_batch.add(event_data)
                
                # Send remaining messages in batch
                if len(event_batch) > 0:
                    await self.producer.send_batch(event_batch)
                    sent_count += len(event_batch)
                    logger.info(f"Sent final batch of {len(event_batch)} messages")
            
            self.messages_sent += sent_count
            logger.info(f"Successfully sent {sent_count} messages in batch")
            return sent_count
            
        except Exception as e:
            logger.error(f"Error sending batch: {str(e)}", exc_info=True)
            return sent_count
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get publisher statistics"""
        return {
            "messages_sent": self.messages_sent,
            "bytes_sent": self.bytes_sent,
            "avg_message_size": self.bytes_sent / self.messages_sent if self.messages_sent > 0 else 0
        }
    
    async def close(self):
        """Close the Event Hub connection"""
        try:
            await self.producer.close()
            if self.use_azure_credential:
                await self.credential.close()
            logger.info("Event Hub producer closed")
        except Exception as e:
            logger.error(f"Error closing producer: {str(e)}")
