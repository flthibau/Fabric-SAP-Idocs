# Workshop Setup Guide

> **Complete prerequisites and environment setup for the workshop**

---

## 📋 Prerequisites Checklist

### Azure Subscription

- [ ] Active Azure subscription with appropriate permissions
- [ ] Microsoft Fabric enabled in subscription
- [ ] Ability to create resources (Event Hub, APIM, etc.)
- [ ] Owner or Contributor role on resource group

### Software Requirements

#### **Required**:
- [ ] Azure CLI (version 2.50+)
  - Download: https://docs.microsoft.com/cli/azure/install-azure-cli
  - Verify: `az --version`

- [ ] Git
  - Download: https://git-scm.com/downloads
  - Verify: `git --version`

- [ ] Code Editor (VS Code recommended)
  - Download: https://code.visualstudio.com/

#### **Recommended**:
- [ ] Python 3.11 or higher
  - Download: https://www.python.org/downloads/
  - Verify: `python --version`

- [ ] PowerShell 7+
  - Download: https://github.com/PowerShell/PowerShell
  - Verify: `pwsh --version`

- [ ] Postman or similar API testing tool
  - Download: https://www.postman.com/downloads/

- [ ] Power BI Desktop (for dashboards)
  - Download: https://powerbi.microsoft.com/desktop/

---

## 🚀 Setup Steps

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git

# Navigate to repository
cd Fabric-SAP-Idocs

# Verify files
ls -la
```

### Step 2: Azure Login

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set subscription
az account set --subscription "Your Subscription Name"

# Verify
az account show
```

### Step 3: Create Resource Group

```bash
# Create resource group
az group create \
  --name rg-fabric-sap-idocs \
  --location eastus

# Verify
az group show --name rg-fabric-sap-idocs
```

### Step 4: Deploy Azure Infrastructure

```bash
# Navigate to infrastructure directory
cd infrastructure/bicep

# Deploy Event Hub
az deployment group create \
  --resource-group rg-fabric-sap-idocs \
  --template-file event-hub.bicep \
  --parameters partitionCount=4

# Get Event Hub connection string
EVENTHUB_NS=$(az eventhubs namespace list \
  --resource-group rg-fabric-sap-idocs \
  --query "[0].name" -o tsv)

az eventhubs namespace authorization-rule keys list \
  --resource-group rg-fabric-sap-idocs \
  --namespace-name $EVENTHUB_NS \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString \
  --output tsv

# Save connection string for later use
```

### Step 5: Setup Python Environment

```bash
# Navigate to simulator
cd ../../simulator

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Verify installation
pip list
```

### Step 6: Configure Environment Variables

```bash
# Create .env file
cp .env.example .env

# Edit .env file with your values
# Use your favorite text editor
code .env  # VS Code
# or
nano .env  # Linux
# or
notepad .env  # Windows
```

**.env file template**:
```bash
# Azure Event Hub
EVENT_HUB_CONNECTION_STRING="Endpoint=sb://eh-idoc-xxx.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=xxx"
EVENT_HUB_NAME="idoc-events"

# Azure tenant
AZURE_TENANT_ID="your-tenant-id"

# Optional: Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=xxx"
```

### Step 7: Create Microsoft Fabric Workspace

1. Go to https://app.fabric.microsoft.com/
2. Click "Workspaces" → "New workspace"
3. Name: `SAP-3PL-Workspace`
4. Description: `Workshop for SAP IDoc integration`
5. Click "Apply"
6. Note the Workspace ID (from URL)

### Step 8: Verify Setup

```bash
# Test Python environment
cd simulator
python -c "import azure.eventhub; print('Azure EventHub SDK installed')"

# Test Azure CLI
az account show

# Test Event Hub connectivity
python test_connection.py
```

---

## 🧪 Verification Script

Create and run this verification script:

**verify-setup.py**:

```python
#!/usr/bin/env python3
"""Verify workshop environment setup"""

import sys
import subprocess
import os
from pathlib import Path

def check_command(command, version_flag="--version"):
    """Check if command exists and get version"""
    try:
        result = subprocess.run([command, version_flag], 
                              capture_output=True, text=True, timeout=5)
        return True, result.stdout.split('\n')[0]
    except Exception as e:
        return False, str(e)

def check_python_package(package):
    """Check if Python package is installed"""
    try:
        __import__(package)
        return True
    except ImportError:
        return False

def check_env_var(var_name):
    """Check if environment variable is set"""
    return os.getenv(var_name) is not None

def main():
    print("🔍 Verifying Workshop Setup\n")
    
    all_ok = True
    
    # Check CLI tools
    print("📦 Checking CLI Tools:")
    tools = [
        ("az", "--version"),
        ("git", "--version"),
        ("python", "--version"),
    ]
    
    for tool, flag in tools:
        ok, version = check_command(tool, flag)
        status = "✅" if ok else "❌"
        print(f"  {status} {tool}: {version if ok else 'Not found'}")
        all_ok = all_ok and ok
    
    # Check Python packages
    print("\n📚 Checking Python Packages:")
    packages = [
        "azure.eventhub",
        "azure.identity",
        "yaml",
        "dotenv"
    ]
    
    for package in packages:
        ok = check_python_package(package)
        status = "✅" if ok else "❌"
        print(f"  {status} {package}")
        all_ok = all_ok and ok
    
    # Check environment variables
    print("\n🔐 Checking Environment Variables:")
    env_vars = [
        "EVENT_HUB_CONNECTION_STRING",
        "EVENT_HUB_NAME",
    ]
    
    for var in env_vars:
        ok = check_env_var(var)
        status = "✅" if ok else "❌"
        print(f"  {status} {var}")
        all_ok = all_ok and ok
    
    # Check files
    print("\n📄 Checking Required Files:")
    files = [
        "config.yaml",
        ".env",
        "requirements.txt"
    ]
    
    for file in files:
        ok = Path(file).exists()
        status = "✅" if ok else "❌"
        print(f"  {status} {file}")
        all_ok = all_ok and ok
    
    # Summary
    print("\n" + "="*50)
    if all_ok:
        print("✅ All checks passed! You're ready to start the workshop.")
        return 0
    else:
        print("❌ Some checks failed. Please review the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

Run verification:
```bash
cd simulator
python ../workshop/setup/verify-setup.py
```

---

## 🔧 Common Setup Issues

### Issue: Azure CLI not found
**Solution**:
```bash
# Install Azure CLI
# Windows (PowerShell):
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

# macOS:
brew install azure-cli

# Linux:
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Issue: Python packages fail to install
**Solution**:
```bash
# Upgrade pip
python -m pip install --upgrade pip

# Install with verbose output
pip install -r requirements.txt --verbose

# If behind proxy:
pip install -r requirements.txt --proxy=http://proxy:port
```

### Issue: Event Hub connection fails
**Solution**:
```bash
# Verify connection string format
echo $EVENT_HUB_CONNECTION_STRING

# Check firewall/network
# Event Hub uses port 5671 (AMQP) or 443 (HTTPS)

# Test with simple script:
python -c "
from azure.eventhub import EventHubProducerClient
import os
conn_str = os.getenv('EVENT_HUB_CONNECTION_STRING')
producer = EventHubProducerClient.from_connection_string(conn_str, eventhub_name=os.getenv('EVENT_HUB_NAME'))
producer.close()
print('Connection successful!')
"
```

### Issue: Fabric workspace access denied
**Solution**:
1. Ensure you have Fabric enabled in subscription
2. Check workspace permissions (need Admin or Member role)
3. Verify Fabric capacity is running
4. Try logging out and back in to Fabric portal

---

## 📚 Additional Resources

- [Azure CLI Installation Guide](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Microsoft Fabric Getting Started](https://learn.microsoft.com/fabric/get-started/)
- [Python Virtual Environments](https://docs.python.org/3/tutorial/venv.html)
- [Event Hubs Troubleshooting](https://learn.microsoft.com/azure/event-hubs/troubleshooting-guide)

---

## ✅ Next Steps

Once setup is complete:

1. **Start Module 1**: [Architecture Overview](../module-1-architecture/README.md)
2. **Join Community**: Ask questions in GitHub Discussions
3. **Bookmark Resources**: Keep documentation links handy

---

**[← Back to Workshop Home](../README.md)**
