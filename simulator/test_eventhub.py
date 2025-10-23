"""
Quick test to verify Event Hub connection with Entra ID
"""
import asyncio
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData
from azure.identity.aio import DefaultAzureCredential
from dotenv import load_dotenv
import os

load_dotenv()

async def test_connection():
    namespace = os.getenv("EVENT_HUB_NAMESPACE")
    eventhub_name = os.getenv("EVENT_HUB_NAME")
    
    print(f"Testing Entra ID connection to:")
    print(f"  Namespace: {namespace}.servicebus.windows.net")
    print(f"  Event Hub: {eventhub_name}\n")
    
    try:
        # Create credential
        credential = DefaultAzureCredential()
        
        # Create producer with Entra ID
        fully_qualified_namespace = f"{namespace}.servicebus.windows.net"
        producer = EventHubProducerClient(
            fully_qualified_namespace=fully_qualified_namespace,
            eventhub_name=eventhub_name,
            credential=credential
        )
        print("✓ Producer created successfully with Entra ID")
        
        # Try to create a batch
        async with producer:
            batch = await producer.create_batch()
            print(f"✓ Batch created successfully (max size: {batch.max_size_in_bytes} bytes)")
            
            # Add a test message
            batch.add(EventData("Test message from Entra ID"))
            print(f"✓ Test message added to batch")
            
            # Send the batch
            await producer.send_batch(batch)
            print("✓ Batch sent successfully!")
            
        await credential.close()
        print("\n✅ Event Hub connection test with Entra ID PASSED!")
        
    except Exception as e:
        print(f"\n❌ Event Hub connection test FAILED!")
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_connection())
