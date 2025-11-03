# Workshop Prerequisites

This document outlines all the prerequisites needed to successfully complete the Microsoft Fabric SAP IDoc Workshop.

## 📋 Overview

The workshop requires access to Azure and Microsoft Fabric services, along with several development tools. This page provides detailed requirements and verification steps.

---

## 🔑 Required Access and Permissions

### Azure Subscription

**Requirement**: Active Azure subscription with sufficient permissions

**Minimum Permissions:**
- Contributor role on a Resource Group (to create Event Hubs, APIM)
- OR Owner role if creating new Resource Group

**Verification:**
```powershell
# Check Azure subscription
az account show

# List subscriptions
az account list --output table
```

**Notes:**
- Free tier Azure subscription is sufficient for learning
- Estimated cost for workshop: $50-100 (with cleanup)
- Consider using Azure credits if available

---

### Azure Active Directory (Entra ID)

**Requirement**: Permissions to create and manage Service Principals

**Minimum Permissions:**
- Application Administrator role
- OR Cloud Application Administrator role
- OR Global Administrator role

**Verification:**
```powershell
# Check your AAD roles
az ad signed-in-user show --query '{UPN:userPrincipalName, ObjectId:id}'

# Check if you can create apps
az ad app list --show-mine
```

**Notes:**
- Service Principals are required for RLS implementation (Module 5)
- You'll create 3 Service Principals (FedEx, Warehouse, ACME)
- Alternative: Ask AAD admin to create SPs for you

---

### Microsoft Fabric

**Requirement**: Access to Microsoft Fabric with workspace creation permissions

**Minimum Requirements:**
- Fabric trial license OR Fabric capacity (F2 or higher)
- Permissions to create workspaces
- Admin or Member role in target workspace

**Verification:**
```powershell
# Check Fabric access
# Navigate to: https://app.fabric.microsoft.com

# Verify you can create workspace:
# 1. Click "+ New workspace"
# 2. If you see the dialog, you have access
```

**How to Get Fabric Access:**

1. **Fabric Trial** (Free, 60 days)
   - Visit: https://app.fabric.microsoft.com
   - Click "Start trial"
   - No credit card required

2. **Paid Capacity** (F2 minimum)
   - Purchase Fabric capacity in Azure Portal
   - Minimum: F2 ($262/month)
   - Pause when not in use to save costs

**Notes:**
- Trial capacity is sufficient for this workshop
- Free trial includes all Fabric features
- Data persists after trial (on paid capacity)

---

## 💻 Development Tools

### PowerShell 7+

**Requirement**: PowerShell 7.0 or higher

**Installation:**

Windows:
```powershell
# Using winget
winget install --id Microsoft.PowerShell --source winget

# OR download from
# https://github.com/PowerShell/PowerShell/releases
```

macOS:
```bash
brew install --cask powershell
```

Linux:
```bash
# Ubuntu/Debian
sudo apt-get install -y powershell

# Red Hat/CentOS
sudo yum install -y powershell
```

**Verification:**
```powershell
$PSVersionTable

# Expected output: PSVersion 7.x.x or higher
```

**Required PowerShell Modules:**
```powershell
# Install Azure modules
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Install Fabric modules (if available)
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable Az*
```

---

### Python 3.11+

**Requirement**: Python 3.11 or higher

**Installation:**

Windows:
```powershell
# Using winget
winget install Python.Python.3.11

# OR download from python.org
# https://www.python.org/downloads/
```

macOS:
```bash
brew install python@3.11
```

Linux:
```bash
# Ubuntu/Debian
sudo apt-get install python3.11 python3.11-venv

# Red Hat/CentOS
sudo yum install python311
```

**Verification:**
```bash
python --version
# Expected: Python 3.11.x or higher

# Alternative command
python3 --version
```

**Required Python Packages:**
```bash
# Navigate to simulator directory
cd simulator

# Create virtual environment
python -m venv venv

# Activate (Windows)
.\venv\Scripts\activate

# Activate (Linux/macOS)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

---

### Azure CLI

**Requirement**: Azure CLI 2.50 or higher

**Installation:**

Windows:
```powershell
# Using winget
winget install -e --id Microsoft.AzureCLI

# OR download MSI installer
# https://aka.ms/installazurecliwindows
```

macOS:
```bash
brew update && brew install azure-cli
```

Linux:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Verification:**
```bash
az --version
# Expected: azure-cli 2.50.x or higher

# Login to Azure
az login

# Set subscription
az account set --subscription "Your-Subscription-Name"
```

---

### Git

**Requirement**: Git 2.30 or higher

**Installation:**

Windows:
```powershell
winget install --id Git.Git -e --source winget
```

macOS:
```bash
brew install git
```

Linux:
```bash
sudo apt-get install git  # Ubuntu/Debian
sudo yum install git       # Red Hat/CentOS
```

**Verification:**
```bash
git --version
# Expected: git version 2.30.x or higher

# Configure Git (first time)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Clone Workshop Repository:**
```bash
git clone https://github.com/flthibau/Fabric-SAP-Idocs.git
cd Fabric-SAP-Idocs
```

---

### Visual Studio Code (Recommended)

**Requirement**: VS Code (latest version recommended)

**Installation:**

Download from: https://code.visualstudio.com/

**Recommended Extensions:**
- Python (Microsoft)
- PowerShell (Microsoft)
- Kusto (Microsoft)
- Azure Account
- REST Client (for API testing)

**Install Extensions:**
```bash
# From VS Code terminal
code --install-extension ms-python.python
code --install-extension ms-vscode.powershell
code --install-extension ms-azure-tools.vscode-azureresourcegroups
```

---

## 🌐 Optional Tools

### Postman or Similar API Client

**Purpose**: Test GraphQL and REST APIs (Module 6)

**Alternatives:**
- Postman (recommended): https://www.postman.com/downloads/
- Insomnia: https://insomnia.rest/download
- REST Client (VS Code extension)
- cURL (command line)

---

### Azure Storage Explorer

**Purpose**: Browse OneLake data and Delta Lake tables

**Installation:**
Download from: https://azure.microsoft.com/features/storage-explorer/

**Verification:**
- Can connect to Azure subscription
- Can browse Storage accounts

---

### Microsoft Power BI Desktop

**Purpose**: Optional - Create reports on Fabric Lakehouse

**Installation:**
Download from: https://powerbi.microsoft.com/desktop/

**Notes:**
- Not required for workshop
- Useful for additional exploration
- Can connect to Lakehouse via Direct Lake

---

## 📊 Network Requirements

### Required Outbound Connectivity

Ensure your network allows HTTPS (443) access to:

**Azure Services:**
- `*.azure.com`
- `*.windows.net`
- `*.microsoft.com`
- `*.servicebus.windows.net` (Event Hubs)

**Microsoft Fabric:**
- `*.fabric.microsoft.com`
- `*.powerbi.com`
- `*.analysis.windows.net`

**GitHub:**
- `github.com`
- `raw.githubusercontent.com`

**Python Packages:**
- `pypi.org`
- `files.pythonhosted.org`

---

## 💾 Hardware Requirements

### Minimum Specifications

- **CPU**: 2 cores
- **RAM**: 8 GB
- **Disk**: 10 GB free space
- **Internet**: Stable broadband connection (5 Mbps+)

### Recommended Specifications

- **CPU**: 4 cores
- **RAM**: 16 GB
- **Disk**: 20 GB free space (SSD)
- **Internet**: 25 Mbps+ for smoother experience

---

## ✅ Pre-Workshop Checklist

Before starting the workshop, verify you have:

### Azure & Fabric
- [ ] Azure subscription with Contributor access
- [ ] Ability to create Service Principals in Azure AD
- [ ] Fabric workspace created or trial activated
- [ ] Admin/Member access to Fabric workspace

### Development Tools
- [ ] PowerShell 7+ installed and verified
- [ ] Python 3.11+ installed with pip working
- [ ] Azure CLI installed and logged in
- [ ] Git installed and configured
- [ ] VS Code installed (optional but recommended)

### Repository
- [ ] Repository cloned locally
- [ ] Can navigate to repository directory
- [ ] Can view files in `/workshop` folder

### Network & Access
- [ ] Can access Azure Portal (portal.azure.com)
- [ ] Can access Fabric Portal (app.fabric.microsoft.com)
- [ ] Can access GitHub (github.com)
- [ ] Firewall allows required outbound connections

---

## 🔍 Verification Script

Run this script to verify your environment:

```powershell
# Save as: verify-prerequisites.ps1

Write-Host "🔍 Verifying Workshop Prerequisites..." -ForegroundColor Cyan

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "✅ PowerShell $psVersion - OK" -ForegroundColor Green
} else {
    Write-Host "❌ PowerShell $psVersion - Need 7.0+" -ForegroundColor Red
}

# Check Python
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "3\.1[1-9]") {
        Write-Host "✅ $pythonVersion - OK" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $pythonVersion - Need 3.11+" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Python not found" -ForegroundColor Red
}

# Check Azure CLI
try {
    $azVersion = (az --version)[0]
    Write-Host "✅ Azure CLI - OK" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI not found" -ForegroundColor Red
}

# Check Git
try {
    $gitVersion = git --version
    Write-Host "✅ $gitVersion - OK" -ForegroundColor Green
} catch {
    Write-Host "❌ Git not found" -ForegroundColor Red
}

# Check Azure login
try {
    $account = az account show --query name -o tsv 2>$null
    if ($account) {
        Write-Host "✅ Azure logged in: $account" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Not logged in to Azure - Run: az login" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Not logged in to Azure" -ForegroundColor Yellow
}

Write-Host "`n✅ Prerequisite check complete!" -ForegroundColor Cyan
```

**Run the script:**
```powershell
.\verify-prerequisites.ps1
```

---

## 🆘 Troubleshooting Prerequisites

### Issue: Cannot Install PowerShell Modules

**Error**: "Access denied" or "requires elevation"

**Solution:**
```powershell
# Install for current user only (no admin needed)
Install-Module -Name Az -Scope CurrentUser -Force

# OR run PowerShell as Administrator
```

---

### Issue: Python pip Fails

**Error**: "pip is not recognized" or SSL errors

**Solution:**
```bash
# Reinstall pip
python -m ensurepip --upgrade

# Upgrade pip
python -m pip install --upgrade pip

# For SSL errors, update certificates
pip install --upgrade certifi
```

---

### Issue: Azure CLI Login Fails

**Error**: "Browser authentication failed"

**Solution:**
```bash
# Use device code authentication
az login --use-device-code

# OR use service principal
az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>
```

---

### Issue: Cannot Access Fabric Portal

**Error**: "Fabric is not available in your region" or access denied

**Solution:**
1. Verify Fabric is available in your tenant region
2. Check with your IT admin about Fabric enablement
3. Try incognito/private browser window
4. Clear browser cache and cookies

---

## 📞 Getting Help

If you're stuck on prerequisites:

1. **Review Error Messages**: Copy exact error text
2. **Check Documentation**: Each tool has detailed docs
3. **Ask for Help**: 
   - GitHub Issues: [Report setup issues](https://github.com/flthibau/Fabric-SAP-Idocs/issues)
   - Community: Microsoft Fabric Community forums

---

## ✨ Next Steps

Once all prerequisites are verified:

➡️ Continue to [Environment Setup](./environment-setup.md)

---

**Last Updated**: November 2024  
**Version**: 1.0
