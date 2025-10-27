# 🔧 MCP Server Setup - Microsoft Fabric RTI

## Overview

This guide covers installation and configuration of the MCP (Model Context Protocol) Server for Microsoft Fabric Real-Time Intelligence (RTI). The MCP server enables executing KQL queries directly from VS Code via GitHub Copilot.

---

## Why Use MCP Server?

### Benefits
✅ **Advanced Diagnostics**: Execute KQL queries directly from VS Code  
✅ **Automation**: Create/modify KQL tables via code  
✅ **Debugging**: Inspect data structure in real-time  
✅ **Productivity**: No need to switch to Fabric portal  

### Use Cases in This Project
- Automatically create `idoc_raw` table
- Validate data ingestion
- Diagnose mapping issues
- Execute analysis queries

---

## Prerequisites

### Software Required
- VS Code
- GitHub Copilot extension
- Python 3.11+ (for uvx)
- Azure CLI (for authentication)

### Access Required
- Access to Fabric Workspace
- Permissions on KQL Database
- Azure AD authentication configured

---

## Installation

### Step 1: Install uvx

```powershell
# Via pip
pip install uvx

# Verify installation
uvx --version
```

### Step 2: Locate mcp.json

Configuration file location:
```
%APPDATA%\Code\User\globalStorage\github.copilot\globalState\mcp.json
```

Full path example:
```
C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\github.copilot\globalState\mcp.json
```

### Step 3: Create/Edit mcp.json

If file doesn't exist, create it. Otherwise, add the `fabric-rti` configuration:

```json
{
  "mcpServers": {
    "fabric-rti": {
      "command": "uvx",
      "args": ["microsoft-fabric-rti-mcp"],
      "env": {
        "KUSTO_SERVICE_URI": "https://trd-50gjamacvb06uc7dnr.z8.kusto.fabric.microsoft.com",
        "KUSTO_SERVICE_DEFAULT_DB": "kqldbsapidoc"
      }
    }
  }
}
```

### Step 4: Configure for Your Environment

Replace these values with yours:

| Parameter | Description | How to Get It |
|-----------|-------------|---------------|
| `KUSTO_SERVICE_URI` | Kusto cluster URI | Fabric Portal → Eventhouse → Details → Query URI |
| `KUSTO_SERVICE_DEFAULT_DB` | KQL Database name | Your KQL Database name |

**Example for this project:**
- `KUSTO_SERVICE_URI`: `https://trd-50gjamacvb06uc7dnr.z8.kusto.fabric.microsoft.com`
- `KUSTO_SERVICE_DEFAULT_DB`: `kqldbsapidoc`

### Step 5: Restart VS Code

**Important**: Completely close VS Code (not just the window), then relaunch.

```powershell
# Close all VS Code instances
# Then relaunch
code .
```

---

## Validation

### Test 1: Verify MCP Server Starts

In VS Code GitHub Copilot Chat:

```
List my Kusto tables
```

**Expected**: GitHub Copilot uses `fabric-rti` MCP server and returns table list (e.g., `idoc_raw`).

### Test 2: Execute KQL Query

In GitHub Copilot Chat:

```
Execute KQL query: idoc_raw | count
```

**Expected**: Returns row count in `idoc_raw` table.

### Test 3: Create Table (Advanced)

```
Use MCP server to execute script recreate-idoc-table-optimized.kql
```

**Expected**: Table created/recreated successfully.

---

## Advanced Configuration

### Multiple Environments

For multiple environments (dev, staging, prod), create separate entries:

```json
{
  "mcpServers": {
    "fabric-rti-dev": {
      "command": "uvx",
      "args": ["microsoft-fabric-rti-mcp"],
      "env": {
        "KUSTO_SERVICE_URI": "https://cluster-dev.z8.kusto.fabric.microsoft.com",
        "KUSTO_SERVICE_DEFAULT_DB": "kqldbsapidoc-dev"
      }
    },
    "fabric-rti-prod": {
      "command": "uvx",
      "args": ["microsoft-fabric-rti-mcp"],
      "env": {
        "KUSTO_SERVICE_URI": "https://cluster-prod.z8.kusto.fabric.microsoft.com",
        "KUSTO_SERVICE_DEFAULT_DB": "kqldbsapidoc-prod"
      }
    }
  }
}
```

In GitHub Copilot, specify environment:

```
Use fabric-rti-prod MCP server to execute this query
```

### Enable Debug Logs

To diagnose MCP server issues, enable logs:

```json
{
  "mcpServers": {
    "fabric-rti": {
      "command": "uvx",
      "args": ["microsoft-fabric-rti-mcp"],
      "env": {
        "KUSTO_SERVICE_URI": "https://trd-50gjamacvb06uc7dnr.z8.kusto.fabric.microsoft.com",
        "KUSTO_SERVICE_DEFAULT_DB": "kqldbsapidoc",
        "LOG_LEVEL": "DEBUG"
      }
    }
  }
}
```

---

## Troubleshooting

### MCP Server Won't Start

**Symptoms**: GitHub Copilot doesn't see MCP server, error `fabric-rti not found`.

**Solutions**:
1. Verify `uvx` installed: `uvx --version`
2. Check `mcp.json` file path
3. Validate JSON syntax (use JSON validator)
4. Restart VS Code **completely** (close all windows)

### Authentication Fails

**Symptoms**: `Authentication failed` error when executing queries.

**Solutions**:
1. Login to Azure CLI: `az login`
2. Verify correct account: `az account show`
3. Check permissions on KQL Database (Contributor or higher)

### "Database not found"

**Symptoms**: Error `Database 'kqldbsapidoc' not found`.

**Solutions**:
1. Verify exact database name in Fabric Portal
2. Ensure `KUSTO_SERVICE_DEFAULT_DB` matches exact name
3. Test manually:
   ```
   az kusto database show --cluster-name <cluster> --name kqldbsapidoc
   ```

### Incorrect Cluster URI

**Symptoms**: `Could not resolve host` or `Connection timeout`.

**Solutions**:
1. Verify URI in Fabric Portal → Eventhouse → Details → **Query URI**
2. URI must start with `https://` and end with `.z8.kusto.fabric.microsoft.com`
3. No trailing slash `/`

---

## Usage in This Project

### Useful Commands via GitHub Copilot

#### List Tables
```
List all tables in kqldbsapidoc database
```

#### Execute Query
```
Execute this KQL query:
idoc_raw
| summarize count() by message_type
```

#### Create Table
```
Use fabric-rti MCP server to execute recreate-idoc-table-optimized.kql script
```

#### Validate Ingestion
```
Execute queries from validate-ingestion.kql file
```

#### Diagnose Data
```
Show me the last 10 messages from idoc_raw table with all fields
```

---

## Resources

### Official Documentation
- [MCP Server GitHub](https://github.com/microsoft/fabric-rti-mcp)
- [Microsoft Fabric RTI](https://learn.microsoft.com/fabric/real-time-intelligence/)
- [KQL Documentation](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

### Related Files in This Project
- `fabric/warehouse/schema/recreate-idoc-table-optimized.kql`: Table creation script
- `fabric/warehouse/schema/validate-ingestion.kql`: Validation queries
- `fabric/warehouse/schema/diagnose-mapping-issue.kql`: Advanced diagnostics

---

## Project Usage History

### Actions Performed with MCP Server

1. **Initial Diagnosis**: Executed queries to inspect data structure
   - Discovered columns were snake_case (auto-mapping)
   
2. **Created Optimized Table**: 
   ```
   Use MCP server to create table with recreate-idoc-table-optimized.kql script
   ```
   
3. **Validated Ingestion**:
   ```
   idoc_raw | count
   // Result: 605 messages
   ```

4. **Distribution Analysis**:
   ```
   idoc_raw
   | summarize count() by message_type
   | render piechart
   ```

---

## Setup Checklist

- [ ] `uvx` installed
- [ ] `mcp.json` file created in correct location
- [ ] `KUSTO_SERVICE_URI` configured with correct URI
- [ ] `KUSTO_SERVICE_DEFAULT_DB` configured with correct name
- [ ] VS Code restarted completely
- [ ] Azure CLI authenticated (`az login`)
- [ ] Test passed: list tables
- [ ] Test passed: execute simple query
- [ ] Test passed: create/modify table

---

**✨ MCP Server Configuration Complete!**

*You can now execute KQL queries and manage Fabric tables directly from VS Code via GitHub Copilot.*
