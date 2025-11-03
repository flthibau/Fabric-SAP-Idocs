# Module 2: Event Hub Integration

> **Setting up and configuring Azure Event Hub for IDoc ingestion**

⏱️ **Duration**: 90 minutes  
🎯 **Level**: Beginner to Intermediate  
📋 **Prerequisites**: Module 1 completed, Azure subscription, Python 3.11+

---

## 📖 Module Overview

This module covers the setup and configuration of Azure Event Hubs for real-time SAP IDoc ingestion. You'll deploy Event Hub infrastructure, configure the IDoc simulator, and establish the foundation for streaming data into Microsoft Fabric.

### Learning Objectives

By the end of this module, you will be able to:

- ✅ Understand Azure Event Hubs architecture and concepts
- ✅ Deploy Event Hub namespace using Infrastructure as Code
- ✅ Configure event hub partitioning and retention
- ✅ Set up the IDoc simulator for realistic data generation
- ✅ Publish IDoc messages to Event Hub
- ✅ Monitor ingestion metrics and troubleshoot issues
- ✅ Implement error handling and dead-letter queues

---

## 📚 Lesson Content

### 1. Azure Event Hubs Fundamentals

#### What is Azure Event Hubs?

**Azure Event Hubs** is a fully managed, real-time data ingestion service capable of receiving and processing millions of events per second.

**Key Features**:
- **High Throughput**: Millions of events per second
- **Low Latency**: Sub-second ingestion
- **Partitioning**: Parallel processing for scale
- **Retention**: 1-7 days (or longer with premium)
- **Multiple Protocols**: AMQP, Kafka, HTTPS

#### Event Hub Concepts

```
┌─────────────────────────────────────────────────────┐
│           Event Hub Namespace                       │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  Event Hub: idoc-events                      │  │
│  │                                              │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │  │
│  │  │Partition│ │Partition│ │Partition│  ...    │  │
│  │  │   0    │ │   1    │ │   2    │           │  │
│  │  └────────┘ └────────┘ └────────┘           │  │
│  │                                              │  │
│  │  Consumer Groups:                            │  │
│  │  • $Default                                  │  │
│  │  • fabric-ingest                             │  │
│  │  • monitoring                                │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Partitions**:
- Ordered sequence of events
- Enables parallel processing
- Partition key determines routing
- Typically 2-32 partitions for production

**Consumer Groups**:
- Independent view of the event stream
- Multiple consumers can read same data
- Each group maintains its own offset

#### Event Hub vs. Other Services

| Feature | Event Hub | Service Bus | Storage Queue |
|---------|-----------|-------------|---------------|
| **Throughput** | Very High | Medium | Low |
| **Latency** | Sub-second | < 1 second | Seconds |
| **Message Size** | 1 MB | 256 KB | 64 KB |
| **Retention** | Days | Minutes/Days | Days |
| **Use Case** | Big data streaming | Enterprise messaging | Async task queuing |

---

### 2. Event Hub Deployment

#### Architecture

```
┌─────────────────────────────────────────┐
│     Azure Resource Group                │
│     rg-fabric-sap-idocs                 │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Event Hub Namespace              │  │
│  │  eh-idoc-flt8076                  │  │
│  │                                   │  │
│  │  SKU: Standard                    │  │
│  │  Throughput Units: 2              │  │
│  │  Auto-Inflate: Enabled            │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Event Hub: idoc-events     │  │  │
│  │  │                             │  │  │
│  │  │  Partitions: 4              │  │  │
│  │  │  Retention: 7 days          │  │  │
│  │  │  Consumer Groups:           │  │  │
│  │  │  • $Default                 │  │  │
│  │  │  • fabric-ingest            │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

#### Deployment Using Bicep

**File**: `infrastructure/bicep/event-hub.bicep`

```bicep
@description('Event Hub namespace name')
param namespaceName string = 'eh-idoc-${uniqueString(resourceGroup().id)}'

@description('Event Hub name')
param eventHubName string = 'idoc-events'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Number of partitions')
param partitionCount int = 4

@description('Message retention in days')
param messageRetentionInDays int = 7

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 2
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    zoneRedundant: true
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: messageRetentionInDays
    partitionCount: partitionCount
  }
}

// Consumer group for Fabric Eventstream
resource consumerGroupFabric 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  parent: eventHub
  name: 'fabric-ingest'
}

// Consumer group for monitoring
resource consumerGroupMonitoring 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  parent: eventHub
  name: 'monitoring'
}

// Authorization rule for sender
resource senderAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2023-01-01-preview' = {
  parent: eventHub
  name: 'SenderPolicy'
  properties: {
    rights: [
      'Send'
    ]
  }
}

// Authorization rule for listener
resource listenerAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2023-01-01-preview' = {
  parent: eventHub
  name: 'ListenerPolicy'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output senderConnectionString string = senderAuthRule.listKeys().primaryConnectionString
output listenerConnectionString string = listenerAuthRule.listKeys().primaryConnectionString
```

#### Deployment Commands

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "Your Subscription Name"

# Create resource group
az group create \
  --name rg-fabric-sap-idocs \
  --location eastus

# Deploy Event Hub
az deployment group create \
  --resource-group rg-fabric-sap-idocs \
  --template-file infrastructure/bicep/event-hub.bicep \
  --parameters partitionCount=4 messageRetentionInDays=7

# Get connection string
az eventhubs namespace authorization-rule keys list \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name <namespace-name> \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString \
  --output tsv
```

---

### 3. IDoc Simulator Setup

#### Simulator Architecture

```
┌─────────────────────────────────────────┐
│        IDoc Simulator (Python)          │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  IDoc Generator                   │  │
│  │  • Load scenarios from config     │  │
│  │  • Generate realistic data        │  │
│  │  • Apply business rules           │  │
│  └───────────────────────────────────┘  │
│                ↓                        │
│  ┌───────────────────────────────────┐  │
│  │  Schema Validator                 │  │
│  │  • Validate against IDoc schemas  │  │
│  │  • Check required fields          │  │
│  │  • Validate data types            │  │
│  └───────────────────────────────────┘  │
│                ↓                        │
│  ┌───────────────────────────────────┐  │
│  │  Event Hub Publisher              │  │
│  │  • Batch messages                 │  │
│  │  • Handle retries                 │  │
│  │  • Track metrics                  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
              ↓ Events
┌─────────────────────────────────────────┐
│        Azure Event Hub                  │
└─────────────────────────────────────────┘
```

#### Configuration

**File**: `simulator/config.yaml`

```yaml
# Azure Event Hub Configuration
event_hub:
  connection_string: "${EVENT_HUB_CONNECTION_STRING}"
  event_hub_name: "idoc-events"
  partition_key_field: "partner_id"  # Route by partner for ordering
  
# IDoc Generation Settings
generation:
  batch_size: 100                    # Messages per batch
  batch_interval_seconds: 10         # Time between batches
  total_messages: 1000               # Total to generate (0 = infinite)
  
  # IDoc type distribution
  idoc_types:
    - type: "ORDERS"
      probability: 0.30              # 30% of messages
    - type: "SHPMNT"
      probability: 0.25
    - type: "DESADV"
      probability: 0.20
    - type: "WHSCON"
      probability: 0.15
    - type: "INVOIC"
      probability: 0.10

# Business Scenario Configuration
scenario:
  partners:
    carriers:
      - id: "FEDEX"
        name: "FedEx Corporation"
        weight: 0.40                 # 40% of shipments
      - id: "UPS"
        name: "UPS"
        weight: 0.35
      - id: "DHL"
        name: "DHL Express"
        weight: 0.25
    
    warehouses:
      - id: "WH-EAST"
        name: "Warehouse East"
        location: "New York, NY"
      - id: "WH-WEST"
        name: "Warehouse West"
        location: "Los Angeles, CA"
      - id: "WH-CENTRAL"
        name: "Warehouse Central"
        location: "Chicago, IL"
    
    customers:
      - id: "ACME"
        name: "ACME Corporation"
        weight: 0.30
      - id: "WIDGET"
        name: "Widget Company"
        weight: 0.25
      - id: "GLOBAL"
        name: "Global Industries"
        weight: 0.45

# Data Generation Rules
data_rules:
  shipment:
    weight_range: [1.0, 500.0]       # kg
    items_range: [1, 50]
    delivery_days_range: [1, 7]      # Days from ship date
  
  order:
    value_range: [100.0, 50000.0]    # USD
    items_range: [1, 100]
  
  invoice:
    payment_terms_days: 30

# Error Injection (for testing)
error_injection:
  enabled: false
  error_rate: 0.05                   # 5% of messages
  error_types:
    - "missing_required_field"
    - "invalid_data_type"
    - "malformed_json"
```

#### Installation

```bash
# Navigate to simulator directory
cd simulator

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Dependencies in requirements.txt:
# azure-eventhub==5.11.4
# azure-identity==1.14.0
# pyyaml==6.0.1
# faker==20.0.0
# python-dotenv==1.0.0
```

#### Environment Configuration

**File**: `.env`

```bash
# Azure Event Hub
EVENT_HUB_CONNECTION_STRING="Endpoint=sb://eh-idoc-flt8076.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=xxx"
EVENT_HUB_NAME="idoc-events"

# Optional: Azure Monitor for metrics
APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=xxx"
```

---

### 4. Publishing IDoc Messages

#### Publisher Implementation

**File**: `simulator/main.py`

```python
import asyncio
import json
import logging
from datetime import datetime
from typing import List, Dict
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData
import yaml
from dotenv import load_dotenv
import os

from idoc_generator import IdocGenerator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IdocPublisher:
    """Publishes IDoc messages to Azure Event Hub"""
    
    def __init__(self, config_path: str = "config.yaml"):
        load_dotenv()
        
        # Load configuration
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Get Event Hub connection details
        self.connection_string = os.getenv('EVENT_HUB_CONNECTION_STRING')
        self.event_hub_name = os.getenv('EVENT_HUB_NAME', self.config['event_hub']['event_hub_name'])
        
        # Initialize generator
        self.generator = IdocGenerator(self.config)
        
        # Statistics
        self.stats = {
            'total_sent': 0,
            'total_failed': 0,
            'by_type': {}
        }
    
    async def publish_batch(self, messages: List[Dict]) -> None:
        """Publish a batch of messages to Event Hub"""
        
        async with EventHubProducerClient.from_connection_string(
            conn_str=self.connection_string,
            eventhub_name=self.event_hub_name
        ) as producer:
            
            # Create event batch
            event_data_batch = await producer.create_batch()
            
            for message in messages:
                try:
                    # Add partition key for ordered processing
                    partition_key = message.get('partner', {}).get('partner_number', '')
                    
                    # Create event
                    event_data = EventData(json.dumps(message))
                    event_data.properties = {
                        'idoc_type': message.get('idoc_type'),
                        'message_type': message.get('message_type'),
                        'partner_id': partition_key,
                        'timestamp': datetime.utcnow().isoformat()
                    }
                    
                    # Add to batch
                    event_data_batch.add(event_data)
                    
                    # Track statistics
                    idoc_type = message.get('idoc_type', 'UNKNOWN')
                    self.stats['by_type'][idoc_type] = self.stats['by_type'].get(idoc_type, 0) + 1
                    
                except ValueError:
                    # Batch is full, send and create new batch
                    await producer.send_batch(event_data_batch)
                    event_data_batch = await producer.create_batch()
                    event_data_batch.add(event_data)
            
            # Send remaining messages
            if len(event_data_batch) > 0:
                await producer.send_batch(event_data_batch)
                self.stats['total_sent'] += len(messages)
                logger.info(f"Sent batch of {len(messages)} messages")
    
    async def run(self):
        """Main execution loop"""
        
        batch_size = self.config['generation']['batch_size']
        batch_interval = self.config['generation']['batch_interval_seconds']
        total_messages = self.config['generation']['total_messages']
        
        logger.info(f"Starting IDoc publisher")
        logger.info(f"Batch size: {batch_size}, Interval: {batch_interval}s")
        
        messages_generated = 0
        
        try:
            while total_messages == 0 or messages_generated < total_messages:
                # Generate batch
                messages = self.generator.generate_batch(batch_size)
                
                # Publish to Event Hub
                await self.publish_batch(messages)
                
                messages_generated += len(messages)
                
                # Log progress
                logger.info(f"Progress: {messages_generated}/{total_messages if total_messages > 0 else '∞'}")
                logger.info(f"Statistics: {self.stats}")
                
                # Wait before next batch
                if total_messages == 0 or messages_generated < total_messages:
                    await asyncio.sleep(batch_interval)
        
        except KeyboardInterrupt:
            logger.info("Interrupted by user")
        
        finally:
            logger.info(f"Final statistics: {self.stats}")

if __name__ == "__main__":
    publisher = IdocPublisher()
    asyncio.run(publisher.run())
```

#### Usage

```bash
# Generate specific number of messages
python main.py --count 100

# Continuous generation (Ctrl+C to stop)
python main.py --count 0

# Custom configuration
python main.py --config custom-config.yaml

# Verbose logging
python main.py --count 100 --verbose
```

---

## 🧪 Hands-On Labs

### Lab 1: Deploy Azure Event Hub

**Objective**: Deploy Event Hub infrastructure using Bicep.

**Instructions**:

1. **Prepare Bicep template**
   ```bash
   cd infrastructure/bicep
   # Review event-hub.bicep
   ```

2. **Deploy to Azure**
   ```bash
   # Login
   az login
   
   # Create resource group
   az group create \
     --name rg-fabric-sap-idocs \
     --location eastus
   
   # Deploy Event Hub
   az deployment group create \
     --resource-group rg-fabric-sap-idocs \
     --template-file event-hub.bicep \
     --parameters partitionCount=4
   ```

3. **Verify deployment**
   ```bash
   # List Event Hubs
   az eventhubs eventhub list \
     --resource-group rg-fabric-sap-idocs \
     --namespace-name <namespace-name>
   
   # Get properties
   az eventhubs eventhub show \
     --resource-group rg-fabric-sap-idocs \
     --namespace-name <namespace-name> \
     --name idoc-events
   ```

4. **Get connection string**
   ```bash
   az eventhubs namespace authorization-rule keys list \
     --resource-group rg-fabric-sap-idocs \
     --namespace-name <namespace-name> \
     --name RootManageSharedAccessKey \
     --query primaryConnectionString \
     --output tsv
   ```

**Expected Output**: Event Hub namespace and event hub created successfully.

**Solution**: [Lab 1 Solution](./labs/lab1-solution.md)

---

### Lab 2: Configure IDoc Simulator

**Objective**: Set up and configure the IDoc simulator.

**Instructions**:

1. **Install dependencies**
   ```bash
   cd simulator
   python -m venv venv
   source venv/bin/activate  # or venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```

2. **Configure environment**
   ```bash
   # Create .env file
   cp .env.example .env
   
   # Edit .env and add your Event Hub connection string
   # EVENT_HUB_CONNECTION_STRING="Endpoint=sb://..."
   ```

3. **Test configuration**
   ```bash
   # Validate config
   python -c "import yaml; yaml.safe_load(open('config.yaml'))"
   
   # Test Event Hub connection
   python test_connection.py
   ```

4. **Review configuration**
   - Open `config.yaml`
   - Understand partner distribution
   - Review IDoc type probabilities
   - Check data generation rules

**Expected Output**: Configuration validated, connection successful.

**Solution**: [Lab 2 Solution](./labs/lab2-solution.md)

---

### Lab 3: Generate and Publish IDoc Messages

**Objective**: Generate sample IDocs and publish to Event Hub.

**Instructions**:

1. **Generate single batch**
   ```bash
   python main.py --count 10
   ```

2. **Monitor in Azure Portal**
   - Navigate to Event Hub in Azure Portal
   - View "Incoming Messages" metric
   - Check "Throughput" graph

3. **Generate continuous stream**
   ```bash
   # Run for 5 minutes
   python main.py --count 300
   ```

4. **Verify message content**
   ```bash
   # Use Event Hub capture or consumer
   python consume_sample.py --count 5
   ```

5. **Exercise**: Modify configuration
   - Change IDoc type distribution
   - Adjust batch size and interval
   - Enable error injection
   - Re-run and observe differences

**Expected Output**: Messages published successfully, visible in Azure Portal.

**Solution**: [Lab 3 Solution](./labs/lab3-solution.md)

---

### Lab 4: Monitor and Troubleshoot

**Objective**: Monitor Event Hub metrics and troubleshoot common issues.

**Instructions**:

1. **View metrics in Azure Portal**
   - Incoming Messages
   - Outgoing Messages
   - Throttled Requests
   - Server Errors

2. **Enable diagnostic logs**
   ```bash
   # Create Log Analytics workspace
   az monitor log-analytics workspace create \
     --resource-group rg-fabric-sap-idocs \
     --workspace-name law-fabric-sap-idocs
   
   # Enable diagnostics
   az monitor diagnostic-settings create \
     --resource <event-hub-resource-id> \
     --workspace <workspace-id> \
     --logs '[{"category": "OperationalLogs", "enabled": true}]' \
     --metrics '[{"category": "AllMetrics", "enabled": true}]'
   ```

3. **Query logs**
   ```kql
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.EVENTHUB"
   | where Category == "OperationalLogs"
   | order by TimeGenerated desc
   | take 100
   ```

4. **Common troubleshooting scenarios**:
   - Connection failures
   - Throttling errors
   - Message too large errors
   - Partition key issues

**Expected Output**: Metrics visible, diagnostic logs configured.

**Solution**: [Lab 4 Solution](./labs/lab4-solution.md)

---

## 📋 Knowledge Check

### Quiz

1. **What is the maximum message size for Azure Event Hubs Standard tier?**
   - [ ] 256 KB
   - [ ] 512 KB
   - [x] 1 MB
   - [ ] 10 MB

2. **How do partitions help with scaling?**
   - [ ] They reduce storage costs
   - [x] They enable parallel processing
   - [ ] They compress data
   - [ ] They filter messages

3. **What is the purpose of a partition key?**
   - [ ] To encrypt messages
   - [x] To route messages to specific partitions for ordering
   - [ ] To compress data
   - [ ] To validate schema

4. **What is a consumer group?**
   - [ ] A group of Event Hubs
   - [ ] A security group
   - [x] An independent view of the event stream
   - [ ] A message filter

5. **What is the default message retention in Event Hubs Standard?**
   - [ ] 1 day
   - [x] 7 days
   - [ ] 30 days
   - [ ] 90 days

**Answers**: See [Quiz Answers](./labs/quiz-answers.md)

---

## 🎯 Best Practices

### Event Hub Configuration

✅ **DO**:
- Use appropriate number of partitions (typically 4-32)
- Enable auto-inflate for variable workloads
- Use separate consumer groups for different applications
- Implement retry logic with exponential backoff
- Monitor throughput units utilization

❌ **DON'T**:
- Don't use too few partitions (limits parallelism)
- Don't share consumer groups between independent consumers
- Don't send messages larger than 1 MB
- Don't ignore throttling errors

### Publisher Best Practices

✅ **DO**:
- Batch messages for better throughput
- Use partition keys for message ordering
- Implement connection pooling
- Handle transient errors gracefully
- Monitor publish success rate

❌ **DON'T**:
- Don't create a new client for each message
- Don't ignore connection errors
- Don't send without partition key if ordering matters
- Don't forget to close connections

---

## 📚 Additional Resources

### Documentation
- [Azure Event Hubs Overview](https://learn.microsoft.com/azure/event-hubs/event-hubs-about)
- [Event Hubs Programming Guide](https://learn.microsoft.com/azure/event-hubs/event-hubs-programming-guide)
- [Event Hubs Python SDK](https://learn.microsoft.com/python/api/overview/azure/eventhub-readme)

### Code Samples
- [IDoc Simulator](../../simulator/)
- [Event Hub Bicep Templates](../../infrastructure/bicep/)

---

## ✅ Module Completion

### Summary

In this module, you learned:

- ✅ Azure Event Hubs architecture and concepts
- ✅ Infrastructure deployment with Bicep
- ✅ IDoc simulator setup and configuration
- ✅ Message publishing patterns
- ✅ Monitoring and troubleshooting
- ✅ Best practices for Event Hub usage

### Next Steps

You're now ready to move to **[Module 3: Real-Time Intelligence](../module-3-real-time-intelligence/README.md)** where you'll:
- Create Fabric Eventhouse
- Configure Eventstream ingestion
- Write KQL queries
- Build real-time dashboards

---

**[← Previous: Module 1](../module-1-architecture/README.md)** | **[Back to Workshop Home](../README.md)** | **[Next: Module 3 →](../module-3-real-time-intelligence/README.md)**
