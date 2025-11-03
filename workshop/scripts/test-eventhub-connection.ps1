# Test Event Hub Connection Script
# This script validates your Event Hub setup and connection

param(
    [Parameter(Mandatory=$false)]
    [string]$ConnectionString = $env:EVENT_HUB_CONNECTION_STRING,
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubName = $env:EVENT_HUB_NAME
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Event Hub Connection Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if connection string is provided
if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    Write-Host "❌ Error: EVENT_HUB_CONNECTION_STRING not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please provide the connection string in one of these ways:" -ForegroundColor Yellow
    Write-Host "1. Set environment variable: `$env:EVENT_HUB_CONNECTION_STRING='...'" -ForegroundColor Gray
    Write-Host "2. Pass as parameter: .\test-eventhub-connection.ps1 -ConnectionString '...'" -ForegroundColor Gray
    Write-Host "3. Create .env file in simulator folder" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Parse connection string
Write-Host "📝 Parsing connection string..." -ForegroundColor Yellow
try {
    # Extract endpoint
    if ($ConnectionString -match "Endpoint=sb://([^/;]+)") {
        $Endpoint = $matches[1]
        Write-Host "✓ Endpoint: $Endpoint" -ForegroundColor Green
    } else {
        Write-Host "❌ Error: Could not parse endpoint from connection string" -ForegroundColor Red
        exit 1
    }
    
    # Extract shared access key name
    if ($ConnectionString -match "SharedAccessKeyName=([^;]+)") {
        $KeyName = $matches[1]
        Write-Host "✓ Shared Access Key Name: $KeyName" -ForegroundColor Green
    } else {
        Write-Host "❌ Error: Could not parse SharedAccessKeyName" -ForegroundColor Red
        exit 1
    }
    
    # Extract entity path (Event Hub name)
    if ($ConnectionString -match "EntityPath=([^;]+)") {
        $EntityPath = $matches[1]
        Write-Host "✓ Entity Path (Event Hub Name): $EntityPath" -ForegroundColor Green
        if ([string]::IsNullOrWhiteSpace($EventHubName)) {
            $EventHubName = $EntityPath
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($EventHubName)) {
            Write-Host "⚠ Warning: EntityPath not in connection string. Using provided EventHubName." -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "❌ Error parsing connection string: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test network connectivity
Write-Host "🌐 Testing network connectivity..." -ForegroundColor Yellow
try {
    $result = Test-NetConnection -ComputerName $Endpoint -Port 5671 -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Host "✓ Network connection successful (Port 5671 - AMQP over TLS)" -ForegroundColor Green
    } else {
        Write-Host "❌ Network connection failed to $Endpoint on port 5671" -ForegroundColor Red
        Write-Host "   This could be due to firewall rules or network restrictions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Warning: Could not test network connection: $_" -ForegroundColor Yellow
}

Write-Host ""

# Check Python environment
Write-Host "🐍 Checking Python environment..." -ForegroundColor Yellow
try {
    $pythonCheck = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCheck) {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Python installed: $pythonVersion" -ForegroundColor Green
            
            # Check for azure-eventhub package
            $pipList = pip list 2>&1 | Select-String "azure-eventhub"
            if ($pipList) {
                Write-Host "✓ azure-eventhub package installed: $pipList" -ForegroundColor Green
            } else {
                Write-Host "⚠ Warning: azure-eventhub package not found" -ForegroundColor Yellow
                Write-Host "   Install with: pip install azure-eventhub" -ForegroundColor Gray
            }
        } else {
            Write-Host "⚠ Warning: Python command failed" -ForegroundColor Yellow
            Write-Host "   Python is required to run the IDoc simulator" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠ Warning: Python not found in PATH" -ForegroundColor Yellow
        Write-Host "   Python is required to run the IDoc simulator" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠ Warning: Error checking Python environment" -ForegroundColor Yellow
    Write-Host "   Python is required to run the IDoc simulator" -ForegroundColor Gray
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connection Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Endpoint: $Endpoint" -ForegroundColor White
Write-Host "  Event Hub Name: $EventHubName" -ForegroundColor White
Write-Host "  Access Key Name: $KeyName" -ForegroundColor White
Write-Host ""

# Next steps
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. To test sending messages, run the Python test:" -ForegroundColor White
Write-Host "   cd ../simulator" -ForegroundColor Gray
Write-Host "   python test_eventhub.py" -ForegroundColor Gray
Write-Host ""
Write-Host "2. To run the full simulator:" -ForegroundColor White
Write-Host "   cd ../simulator" -ForegroundColor Gray
Write-Host "   python main.py" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitor messages in Azure Portal:" -ForegroundColor White
Write-Host "   - Navigate to Event Hub Namespace > Metrics" -ForegroundColor Gray
Write-Host "   - Add chart: 'Incoming Messages'" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Connection test complete!" -ForegroundColor Green
Write-Host ""
