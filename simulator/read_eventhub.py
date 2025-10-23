#!/usr/bin/env python3
"""
Event Hub Reader CLI - Read and display messages from Azure Event Hub
"""

import asyncio
import argparse
import json
from datetime import datetime
from azure.eventhub.aio import EventHubConsumerClient
from azure.identity.aio import DefaultAzureCredential
from dotenv import load_dotenv
import os

# Load environment
load_dotenv()

class EventHubReader:
    def __init__(self, namespace: str, eventhub_name: str, consumer_group: str = "$Default"):
        self.namespace = namespace
        self.eventhub_name = eventhub_name
        self.consumer_group = consumer_group
        self.message_count = 0
        self.max_messages = None
        self.show_details = False
        self.client = None
        self.should_stop = False
        
    async def on_event(self, partition_context, event):
        """Process each event received"""
        self.message_count += 1
        
        # Parse message body
        try:
            body = json.loads(event.body_as_str())
            
            # Display message
            print(f"\n{'='*80}")
            print(f"📨 Message #{self.message_count} | Partition: {partition_context.partition_id}")
            print(f"{'='*80}")
            
            # Basic info
            idoc_type = body.get('idoc_type', 'N/A')
            message_type = body.get('message_type', 'N/A')
            timestamp = body.get('timestamp', 'N/A')
            sap_system = body.get('sap_system', 'N/A')
            
            print(f"IDoc Type:     {idoc_type}")
            print(f"Message Type:  {message_type}")
            print(f"SAP System:    {sap_system}")
            print(f"Timestamp:     {timestamp}")
            
            # Event properties
            if event.properties:
                print(f"\n📋 Properties:")
                for key, value in event.properties.items():
                    print(f"  {key}: {value}")
            
            # Show full details if requested
            if self.show_details:
                print(f"\n📄 Full Message:")
                print(json.dumps(body, indent=2))
            else:
                # Show summary based on IDoc type
                if idoc_type == "ORDERS":
                    control = body.get('control', {})
                    print(f"\nOrder Details:")
                    print(f"  Order Number: {control.get('docnum', 'N/A')}")
                    
                elif idoc_type == "WHSCON":
                    control = body.get('control', {})
                    print(f"\nWarehouse Confirmation:")
                    print(f"  Confirmation: {control.get('docnum', 'N/A')}")
                    
                elif idoc_type == "DESADV":
                    control = body.get('control', {})
                    print(f"\nDelivery Notification:")
                    print(f"  Delivery: {control.get('docnum', 'N/A')}")
                    
                elif idoc_type == "SHPMNT":
                    control = body.get('control', {})
                    print(f"\nShipment:")
                    print(f"  Shipment: {control.get('docnum', 'N/A')}")
                    
                elif idoc_type == "INVOICE":
                    control = body.get('control', {})
                    print(f"\nInvoice:")
                    print(f"  Invoice: {control.get('docnum', 'N/A')}")
            
            # Message size
            size_bytes = len(event.body_as_str())
            print(f"\n📊 Size: {size_bytes:,} bytes ({size_bytes/1024:.2f} KB)")
            
        except json.JSONDecodeError:
            print(f"❌ Failed to parse message body as JSON")
            print(f"Raw body: {event.body_as_str()[:200]}...")
        
        # Update checkpoint
        await partition_context.update_checkpoint(event)
        
        # Stop if max messages reached
        if self.max_messages and self.message_count >= self.max_messages:
            print(f"\n✅ Reached max messages limit ({self.max_messages})")
            self.should_stop = True
            # Close the client to stop receiving
            if self.client:
                await self.client.close()
            return
    
    async def on_partition_initialize(self, partition_context):
        """Called when a partition is initialized"""
        print(f"\n🔵 Initialized partition: {partition_context.partition_id}")
    
    async def on_partition_close(self, partition_context, reason):
        """Called when a partition is closed"""
        print(f"\n🔴 Closed partition: {partition_context.partition_id} (Reason: {reason})")
    
    async def on_error(self, partition_context, error):
        """Called when an error occurs"""
        if partition_context:
            print(f"\n❌ Error in partition {partition_context.partition_id}: {error}")
        else:
            print(f"\n❌ Error: {error}")
    
    async def read_messages(self, max_messages=None, show_details=False, starting_position="-1"):
        """
        Read messages from Event Hub
        
        Args:
            max_messages: Maximum number of messages to read (None = continuous)
            show_details: Show full message details
            starting_position: Where to start reading ("-1" = from end, "@latest" = latest, offset number)
        """
        self.max_messages = max_messages
        self.show_details = show_details
        
        print(f"\n{'='*80}")
        print(f"📡 Event Hub Reader")
        print(f"{'='*80}")
        print(f"Namespace:      {self.namespace}.servicebus.windows.net")
        print(f"Event Hub:      {self.eventhub_name}")
        print(f"Consumer Group: {self.consumer_group}")
        print(f"Max Messages:   {max_messages if max_messages else 'Unlimited'}")
        print(f"Show Details:   {show_details}")
        print(f"Starting From:  {starting_position}")
        print(f"{'='*80}\n")
        print("🔍 Listening for messages... (Press Ctrl+C to stop)\n")
        
        credential = DefaultAzureCredential()
        
        try:
            self.client = EventHubConsumerClient(
                fully_qualified_namespace=f"{self.namespace}.servicebus.windows.net",
                eventhub_name=self.eventhub_name,
                consumer_group=self.consumer_group,
                credential=credential
            )
            
            async with self.client:
                # Use asyncio.wait_for with timeout for max_messages case
                if self.max_messages:
                    try:
                        await asyncio.wait_for(
                            self.client.receive(
                                on_event=self.on_event,
                                on_partition_initialize=self.on_partition_initialize,
                                on_partition_close=self.on_partition_close,
                                on_error=self.on_error,
                                starting_position=starting_position
                            ),
                            timeout=30.0  # 30 seconds timeout
                        )
                    except asyncio.TimeoutError:
                        if self.message_count == 0:
                            print("\n⚠️  No messages found in Event Hub (timeout after 30 seconds)")
                        else:
                            print(f"\n⏱️  Timeout reached - read {self.message_count} messages")
                else:
                    # Continuous mode - no timeout
                    await self.client.receive(
                        on_event=self.on_event,
                        on_partition_initialize=self.on_partition_initialize,
                        on_partition_close=self.on_partition_close,
                        on_error=self.on_error,
                        starting_position=starting_position
                    )
                
        except KeyboardInterrupt:
            print(f"\n\n⏹️  Stopped by user")
        except Exception as e:
            print(f"\n❌ Error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            await credential.close()
            
        print(f"\n{'='*80}")
        print(f"📊 Summary")
        print(f"{'='*80}")
        print(f"Total messages read: {self.message_count}")
        print(f"{'='*80}\n")


async def main():
    parser = argparse.ArgumentParser(
        description="Read messages from Azure Event Hub",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Read last 10 messages with details
  python read_eventhub.py --max 10 --details
  
  # Read latest messages continuously
  python read_eventhub.py --from-latest
  
  # Read last 5 messages
  python read_eventhub.py --max 5
  
  # Read from specific offset
  python read_eventhub.py --from-offset 100
        """
    )
    
    parser.add_argument(
        "--namespace",
        default=os.getenv("EVENT_HUB_NAMESPACE"),
        help="Event Hub namespace (default: from .env)"
    )
    parser.add_argument(
        "--eventhub",
        default=os.getenv("EVENT_HUB_NAME"),
        help="Event Hub name (default: from .env)"
    )
    parser.add_argument(
        "--consumer-group",
        default="$Default",
        help="Consumer group (default: $Default)"
    )
    parser.add_argument(
        "--max",
        type=int,
        help="Maximum number of messages to read"
    )
    parser.add_argument(
        "--details",
        action="store_true",
        help="Show full message details (JSON)"
    )
    parser.add_argument(
        "--from-latest",
        action="store_true",
        help="Start reading from latest messages"
    )
    parser.add_argument(
        "--from-offset",
        type=int,
        help="Start reading from specific offset"
    )
    
    args = parser.parse_args()
    
    if not args.namespace or not args.eventhub:
        print("❌ Error: Namespace and Event Hub name required (set in .env or use --namespace/--eventhub)")
        return
    
    # Determine starting position
    if args.from_latest:
        starting_position = "@latest"
    elif args.from_offset is not None:
        starting_position = str(args.from_offset)
    else:
        starting_position = "-1"  # From end (most recent)
    
    reader = EventHubReader(
        namespace=args.namespace,
        eventhub_name=args.eventhub,
        consumer_group=args.consumer_group
    )
    
    await reader.read_messages(
        max_messages=args.max,
        show_details=args.details,
        starting_position=starting_position
    )


if __name__ == "__main__":
    asyncio.run(main())
