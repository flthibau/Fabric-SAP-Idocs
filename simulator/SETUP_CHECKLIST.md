# Complete Setup Checklist

Quick reference for setting up the SAP IDoc Simulator end-to-end.

## ✅ Setup Checklist

### 1. Azure Event Hub Setup (15 minutes)

**Option A: Azure Portal** (Recommended for first-time)
- [ ] Sign in to [Azure Portal](https://portal.azure.com)
- [ ] Create Event Hubs Namespace
  - Resource Group: `rg-idoc-fabric-dev`
  - Name: `eh-idoc-fabric-dev-001` (globally unique)
  - Location: Your region (e.g., East US)
  - Pricing: Standard, 2 TUs
- [ ] Create Event Hub
  - Name: `idoc-events`
  - Partitions: 4
  - Retention: 7 days
- [ ] Create Shared Access Policy
  - Name: `simulator-send`
  - Rights: Send
- [ ] Copy Connection String (save for step 3)

**Option B: Azure CLI** (For automation)
```bash
az login
az group create --name rg-idoc-fabric-dev --location eastus
az eventhubs namespace create --name eh-idoc-fabric-dev-001 --resource-group rg-idoc-fabric-dev --location eastus --sku Standard --capacity 2
az eventhubs eventhub create --name idoc-events --namespace-name eh-idoc-fabric-dev-001 --resource-group rg-idoc-fabric-dev --partition-count 4 --message-retention 7
az eventhubs eventhub authorization-rule create --name simulator-send --eventhub-name idoc-events --namespace-name eh-idoc-fabric-dev-001 --resource-group rg-idoc-fabric-dev --rights Send
az eventhubs eventhub authorization-rule keys list --name simulator-send --eventhub-name idoc-events --namespace-name eh-idoc-fabric-dev-001 --resource-group rg-idoc-fabric-dev --query primaryConnectionString --output tsv
```

📘 **[Detailed Event Hub Setup Guide](EVENTHUB_SETUP.md)**

### 2. Python Environment Setup (5 minutes)

```powershell
# Navigate to simulator directory
cd c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\simulator

# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# If execution policy error:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install dependencies
pip install -r requirements.txt
```

### 3. Configuration (2 minutes)

```powershell
# Copy environment template
copy .env.example .env

# Edit .env file (use your connection string from step 1)
notepad .env
```

Update these values in `.env`:
```ini
EVENT_HUB_CONNECTION_STRING=Endpoint=sb://eh-idoc-fabric-dev-001.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=YOUR_KEY;EntityPath=idoc-events
EVENT_HUB_NAME=idoc-events
MESSAGE_RATE=10
BATCH_SIZE=100
RUN_DURATION_SECONDS=3600
LOG_LEVEL=INFO
```

### 4. Test Run (2 minutes)

```powershell
# Run simulator (1 hour, 10 msg/min)
python main.py

# For quick test (5 minutes):
# Edit .env: RUN_DURATION_SECONDS=300
```

Expected output:
```json
{"timestamp": "...", "level": "INFO", "message": "IDoc Generator initialized for system S4HPRD, client 100"}
{"timestamp": "...", "level": "INFO", "message": "Event Hub publisher initialized successfully"}
{"timestamp": "...", "level": "INFO", "message": "Starting IDoc simulator - Rate: 10 msg/min"}
```

### 5. Verify in Azure Portal (2 minutes)

- [ ] Go to Event Hub Namespace in Azure Portal
- [ ] Click on "idoc-events" Event Hub
- [ ] Click "Overview" - check "Incoming Messages" chart
- [ ] Should see message count increasing

### 6. Run Tests (Optional, 3 minutes)

```powershell
# Run all tests
pytest

# Run with coverage report
pytest --cov=src --cov-report=html

# Open coverage report
start htmlcov\index.html
```

---

## 🎯 Quick Reference

### Essential Commands

| Action | Command |
|--------|---------|
| Activate venv | `.\venv\Scripts\Activate.ps1` |
| Install deps | `pip install -r requirements.txt` |
| Run simulator | `python main.py` |
| Run tests | `pytest` |
| Stop simulator | `Ctrl+C` |

### Key Files

| File | Purpose |
|------|---------|
| `.env` | Your configuration (connection string, rate, etc.) |
| `config/config.yaml` | Simulator settings |
| `config/scenarios.yaml` | Business scenarios |
| `main.py` | Entry point |

### Configuration Quick Tweaks

**Faster rate (100 msg/min):**
```ini
MESSAGE_RATE=100
```

**Continuous run:**
```ini
RUN_DURATION_SECONDS=0
```

**Dry run (no sending):**
Edit `config/config.yaml`:
```yaml
simulator:
  dry_run: true
```

---

## 📊 Verification Steps

### Step 1: Check Simulator Logs

Look for these messages:
- ✅ "IDoc Generator initialized"
- ✅ "Event Hub publisher initialized successfully"
- ✅ "Sent batch of X messages"
- ✅ Periodic metrics every 60 seconds

### Step 2: Check Azure Portal

1. Navigate to your Event Hub
2. Click "Metrics"
3. Add metric: "Incoming Messages"
4. Should see rising graph

### Step 3: Check Message Count

After 1 minute at 10 msg/min:
- Expected: ~10-17 messages (batches of 100)
- Portal shows: Incoming messages count

---

## ⚠️ Troubleshooting

### "No module named 'azure'"
```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### "Cannot connect to Event Hub"
- ✅ Check connection string in `.env`
- ✅ Verify Event Hub exists in Azure Portal
- ✅ Check network connectivity: `Test-NetConnection -ComputerName eh-idoc-fabric-dev-001.servicebus.windows.net -Port 5671`

### "Unauthorized access"
- ✅ Verify Shared Access Policy has "Send" rights
- ✅ Connection string matches policy name
- ✅ Key hasn't been regenerated

### "Rate too slow/fast"
Edit `.env`:
```ini
MESSAGE_RATE=100  # For faster (100 msg/min)
MESSAGE_RATE=1    # For slower (1 msg/min)
```

---

## 📚 Documentation Links

- **[EVENTHUB_SETUP.md](EVENTHUB_SETUP.md)** - Complete Event Hub setup guide (Portal/CLI/PowerShell)
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide for simulator
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)** - Implementation details and features
- **[README.md](README.md)** - Simulator overview
- **[../README.md](../README.md)** - Main project documentation
- **[../docs/architecture.md](../docs/architecture.md)** - Architecture documentation

---

## 🎉 Success Criteria

You've successfully set up the simulator when:

1. ✅ Event Hub is created in Azure
2. ✅ Python virtual environment is activated
3. ✅ Dependencies are installed
4. ✅ `.env` is configured with connection string
5. ✅ Simulator runs without errors
6. ✅ Azure Portal shows incoming messages
7. ✅ Logs show "Sent batch of X messages"
8. ✅ Metrics are printed every 60 seconds

---

## ⏭️ Next Steps

After simulator is running successfully:

1. **Monitor Performance** - Watch Azure Portal metrics
2. **Adjust Rate** - Fine-tune MESSAGE_RATE in `.env`
3. **Set Up Fabric Eventstream** - Configure Fabric to consume from Event Hub (next phase)
4. **Create Bronze Layer** - Set up Lakehouse tables (next phase)
5. **Build Data Pipeline** - Silver and Gold transformations (next phase)

---

**Total Setup Time**: ~30 minutes (first time), ~10 minutes (subsequent times)

**Status**: Ready to generate SAP IDoc messages! 🚀
