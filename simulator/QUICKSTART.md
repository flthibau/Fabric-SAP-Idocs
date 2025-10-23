# Quick Start Guide - SAP IDoc Simulator

This guide will help you get the IDoc simulator running quickly.

## Prerequisites

- Python 3.11 or higher
- Azure Event Hub (or connection string) - **[Create Event Hub](EVENTHUB_SETUP.md)** if you don't have one
- pip (Python package manager)

## Installation

### 1. Navigate to simulator directory

```powershell
cd simulator
```

### 2. Create virtual environment

```powershell
python -m venv venv
```

### 3. Activate virtual environment

```powershell
.\venv\Scripts\Activate.ps1
```

If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 4. Install dependencies

```powershell
pip install -r requirements.txt
```

## Configuration

### 1. Copy environment template

```powershell
copy .env.example .env
```

### 2. Edit `.env` file

Open `.env` in your editor and configure:

```ini
# Required: Event Hub connection string
EVENT_HUB_CONNECTION_STRING=Endpoint=sb://YOUR-NAMESPACE.servicebus.windows.net/;SharedAccessKeyName=YOUR-KEY-NAME;SharedAccessKey=YOUR-KEY

# Required: Event Hub name
EVENT_HUB_NAME=idoc-events

# Optional: Adjust simulation parameters
MESSAGE_RATE=10
BATCH_SIZE=100
RUN_DURATION_SECONDS=3600
LOG_LEVEL=INFO
```

## Running the Simulator

### Basic Run (1 hour, 10 msg/min)

```powershell
python main.py
```

### Custom Message Rate (100 msg/min)

Edit `.env`:
```ini
MESSAGE_RATE=100
```

Then run:
```powershell
python main.py
```

### Dry Run (Generate but don't send)

Edit `config/config.yaml`:
```yaml
simulator:
  dry_run: true
```

Then run:
```powershell
python main.py
```

### Continuous Run

Edit `.env`:
```ini
RUN_DURATION_SECONDS=0
```

## Testing

### Run all tests

```powershell
pytest
```

### Run with coverage

```powershell
pytest --cov=src --cov-report=html
```

### Run specific test file

```powershell
pytest tests/test_generator.py -v
```

## Monitoring

The simulator logs to console in JSON format. You'll see:

```json
{
  "timestamp": "2025-10-23T10:00:00",
  "name": "main",
  "level": "INFO",
  "message": "Metrics: {...}"
}
```

Metrics are printed every 60 seconds showing:
- Total messages sent
- Messages per second/minute
- Bytes sent
- Average message size

## Sample Output

```
================================================================================
SAP IDoc Simulator for 3PL - Microsoft Fabric Integration
Started at: 2025-10-23T10:00:00
================================================================================
{"timestamp": "2025-10-23T10:00:01", "level": "INFO", "message": "IDoc Generator initialized for system S4HPRD, client 100"}
{"timestamp": "2025-10-23T10:00:01", "level": "INFO", "message": "Event Hub publisher initialized successfully"}
{"timestamp": "2025-10-23T10:00:01", "level": "INFO", "message": "Starting IDoc simulator - Rate: 10 msg/min, Batch size: 100"}
{"timestamp": "2025-10-23T10:01:01", "level": "INFO", "message": "Metrics: {elapsed_time_seconds: 60, total_messages: 100, ...}"}
```

## IDoc Types Generated

The simulator generates these IDoc types with realistic 3PL data:

1. **ORDERS** (25%) - Purchase/Sales Orders
2. **WHSCON** (30%) - Warehouse Confirmations (GR, PI, PA, GI, CC)
3. **DESADV** (20%) - Dispatch Advice / Advance Shipping Notice
4. **SHPMNT** (15%) - Shipment Tracking Updates
5. **INVOICE** (10%) - Invoices

## Troubleshooting

### Issue: "ImportError: No module named 'azure'"

**Solution**: Make sure you activated the virtual environment and installed dependencies:
```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Issue: "Connection refused" or "Authentication failed"

**Solution**: Check your Event Hub connection string in `.env`:
- Verify the connection string is correct
- Ensure the Event Hub exists
- Check network connectivity to Azure

### Issue: "Rate too slow/fast"

**Solution**: Adjust `MESSAGE_RATE` in `.env`:
- For faster: Increase MESSAGE_RATE (e.g., 100 for 100 msg/min)
- For slower: Decrease MESSAGE_RATE (e.g., 1 for 1 msg/min)

### Issue: "Memory usage high"

**Solution**: Reduce `BATCH_SIZE` in `.env`:
```ini
BATCH_SIZE=50
```

## Next Steps

1. **Verify Event Hub**: Check Azure Portal to confirm messages are arriving
2. **Set up Fabric Eventstream**: Configure Eventstream to consume from Event Hub
3. **Monitor Performance**: Watch metrics to ensure target throughput
4. **Adjust Distribution**: Modify `config/scenarios.yaml` for custom business scenarios

## Stopping the Simulator

Press `Ctrl+C` to gracefully stop the simulator. It will print final statistics before exiting.

## Advanced Configuration

### Custom Business Scenarios

Edit `config/scenarios.yaml` to define custom scenarios with specific IDoc sequences.

### Time-based Distribution

The simulator automatically adjusts IDoc distribution based on time of day (morning/afternoon/evening/night).

### Master Data

Adjust the number of warehouses, customers, and carriers in `.env`:

```ini
WAREHOUSE_COUNT=5
CUSTOMER_COUNT=100
CARRIER_COUNT=20
```

## Support

For issues or questions:
1. Check the main [README.md](../README.md)
2. Review [Architecture Documentation](../docs/architecture.md)
3. Check application logs for detailed error messages
