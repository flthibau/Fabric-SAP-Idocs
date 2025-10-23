# SAP IDoc Simulator

## Overview

Python-based simulator for generating realistic SAP IDoc messages for 3PL (Third-Party Logistics) scenarios. Publishes messages directly to Azure Event Hubs for ingestion into Microsoft Fabric Eventstream.

## Features

- Generate multiple IDoc types (DESADV, SHPMNT, INVOICE, ORDERS, WHSCON)
- Configurable message rates and volumes
- Realistic 3PL business scenarios
- Schema validation
- Direct Event Hub publishing
- Configurable error simulation

## Project Structure

```
simulator/
├── src/
│   ├── idoc_generator.py          # Main IDoc generation logic
│   ├── eventstream_publisher.py   # Event Hub publisher
│   ├── idoc_schemas/
│   │   ├── __init__.py
│   │   ├── desadv_schema.py       # Delivery notification schema
│   │   ├── shpmnt_schema.py       # Shipment schema
│   │   ├── invoice_schema.py      # Invoice schema
│   │   ├── orders_schema.py       # Purchase order schema
│   │   └── whscon_schema.py       # Warehouse confirmation schema
│   └── utils/
│       └── data_generator.py      # Helper functions for data generation
├── config/
│   ├── config.yaml                # Main configuration
│   └── scenarios.yaml             # Business scenario definitions
├── tests/
│   ├── test_generator.py
│   └── test_publisher.py
├── requirements.txt
└── README.md
```

## Prerequisites

- Python 3.11 or higher
- Azure Event Hubs namespace - **[Setup Instructions](EVENTHUB_SETUP.md)** 📘
- Connection string for Event Hub

## Installation

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
.\venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Configuration

1. Copy `.env.example` to `.env`
2. Configure your Event Hub connection:

```bash
EVENT_HUB_CONNECTION_STRING=Endpoint=sb://...
EVENT_HUB_NAME=sap-idocs
```

3. Edit `config/config.yaml` for generation settings:

```yaml
generation:
  message_rate: 100  # messages per minute
  idoc_types:
    - DESADV
    - SHPMNT
    - INVOICE
  duration: 3600  # seconds (1 hour)
```

## Usage

### Generate and Publish IDocs

```bash
# Run the simulator
python src/idoc_generator.py

# With specific configuration
python src/idoc_generator.py --config config/config.yaml

# Generate specific IDoc type
python src/idoc_generator.py --type SHPMNT --count 100

# Test mode (no publishing)
python src/idoc_generator.py --test-mode
```

### Run Tests

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=src
```

## IDoc Types

### DESADV - Delivery Notification
Notifies about planned deliveries to customers.

**Key Fields:**
- Delivery Number
- Customer ID
- Planned Delivery Date
- Items and Quantities

### SHPMNT - Shipment
Contains shipment information including routing and tracking.

**Key Fields:**
- Shipment Number
- Origin/Destination
- Carrier
- Tracking Number
- Weight/Volume

### INVOICE - Billing Document
Invoice data for shipments and deliveries.

**Key Fields:**
- Invoice Number
- Customer ID
- Total Amount
- Line Items

### ORDERS - Purchase Order
Customer purchase orders.

**Key Fields:**
- Order Number
- Customer ID
- Order Date
- Items and Quantities

### WHSCON - Warehouse Confirmation
Warehouse confirmations for goods movements.

**Key Fields:**
- Confirmation Number
- Warehouse Location
- Movement Type
- Quantities

## Development

### Adding a New IDoc Type

1. Create schema file in `src/idoc_schemas/`
2. Implement schema class extending `BaseIdocSchema`
3. Add generator logic
4. Update configuration
5. Add tests

## Troubleshooting

### Connection Issues
- Verify Event Hub connection string
- Check network connectivity
- Ensure Event Hub exists

### Performance
- Adjust message rate in configuration
- Use batch publishing for high volumes
- Monitor Event Hub throttling

## Contributing

1. Create a feature branch
2. Implement changes with tests
3. Run linting: `flake8 src/`
4. Submit pull request

## License

[Your License]
