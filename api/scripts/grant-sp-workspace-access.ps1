#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Grant Service Principals access to Fabric workspace and GraphQL API

.DESCRIPTION
    Assigns the 3 partner Service Principals to the Fabric workspace with
    Viewer role so they can access the GraphQL API with RLS filtering.

.NOTES
    Author: GitHub Copilot
    Date: October 29, 2025
    Requires: Azure CLI, partner-apps-credentials.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
)

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  GRANT SERVICE PRINCIPALS ACCESS TO FABRIC WORKSPACE" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "Workspace ID: $WorkspaceId" -ForegroundColor White
Write-Host "Tenant ID: $TenantId`n" -ForegroundColor White

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"

if (-not (Test-Path $credentialsPath)) {
    Write-Host "❌ Credentials file not found: $credentialsPath" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credentialsPath | ConvertFrom-Json

Write-Host "✅ Loaded Service Principal credentials`n" -ForegroundColor Green

# Check Azure CLI login
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Cyan
$accountInfo = az account show 2>$null | ConvertFrom-Json

if (-not $accountInfo) {
    Write-Host "⚠️  Not logged in to Azure CLI. Logging in..." -ForegroundColor Yellow
    az login --tenant $TenantId
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Azure CLI login failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Authenticated with Azure CLI`n" -ForegroundColor Green

# Display manual instructions (Fabric API currently requires Portal or REST API)
Write-Host "========================================================================" -ForegroundColor Magenta
Write-Host "  MANUAL STEPS REQUIRED IN FABRIC PORTAL" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

Write-Host "Unfortunately, Fabric workspace access must be configured via Portal." -ForegroundColor Yellow
Write-Host "Follow these steps:`n" -ForegroundColor Yellow

Write-Host "1. Open Fabric Portal:" -ForegroundColor Cyan
Write-Host "   https://msit.powerbi.com/groups/$WorkspaceId`n" -ForegroundColor White

Write-Host "2. Click 'Manage access' (top right)`n" -ForegroundColor Cyan

Write-Host "3. Click '+ Add people'`n" -ForegroundColor Cyan

Write-Host "4. Add each Service Principal with VIEWER role:`n" -ForegroundColor Cyan

foreach ($partner in $credentials.Partners) {
    Write-Host "   Partner: $($partner.Role)" -ForegroundColor Yellow
    Write-Host "   App ID: $($partner.AppId)" -ForegroundColor White
    Write-Host "   SP Object ID: $($partner.ServicePrincipalObjectId)" -ForegroundColor White
    Write-Host "   Search by: $($partner.AppId) or Service Principal name" -ForegroundColor Gray
    Write-Host "   Role: VIEWER (read-only access with RLS)" -ForegroundColor Green
    Write-Host ""
}

Write-Host "5. Click 'Grant access'`n" -ForegroundColor Cyan

Write-Host "========================================================================" -ForegroundColor Magenta
Write-Host "  ALTERNATIVE: CONFIGURE VIA LAKEHOUSE PERMISSIONS" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

Write-Host "You can also grant access directly to the Lakehouse:`n" -ForegroundColor Yellow

Write-Host "1. Navigate to Lakehouse3PLAnalytics in Fabric Portal`n" -ForegroundColor Cyan

Write-Host "2. Click 'Manage permissions' (Settings menu)`n" -ForegroundColor Cyan

Write-Host "3. Add Service Principals with READ permission`n" -ForegroundColor Cyan

Write-Host "4. Ensure RLS roles are assigned (already configured)`n" -ForegroundColor Cyan

Write-Host "========================================================================" -ForegroundColor Green
Write-Host "  VERIFICATION" -ForegroundColor Green
Write-Host "========================================================================`n" -ForegroundColor Green

Write-Host "After granting access in Portal, test RLS:" -ForegroundColor Yellow
Write-Host "  .\test-graphql-rls.ps1`n" -ForegroundColor White

Write-Host "Expected: Each Service Principal sees only their filtered data.`n" -ForegroundColor White

# Try to use Fabric REST API (if available)
Write-Host "Attempting to grant access via Fabric REST API..." -ForegroundColor Cyan

$fabricScope = "https://api.fabric.microsoft.com/.default"

# Get admin token
try {
    $adminToken = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
    
    if ($adminToken) {
        Write-Host "✅ Obtained Fabric API token`n" -ForegroundColor Green
        
        # Add each Service Principal to workspace
        foreach ($partner in $credentials.Partners) {
            Write-Host "Adding $($partner.Role) to workspace..." -ForegroundColor Cyan
            
            $body = @{
                identifier = $partner.ServicePrincipalObjectId
                principalType = "ServicePrincipal"
                role = "Viewer"
            } | ConvertTo-Json
            
            $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/roleAssignments"
            
            try {
                $headers = @{
                    "Authorization" = "Bearer $adminToken"
                    "Content-Type" = "application/json"
                }
                
                $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
                Write-Host "✅ $($partner.Role) added with Viewer role" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠️  API call failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "   Please use manual Portal steps above" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`n✅ Access configuration attempted via API" -ForegroundColor Green
        Write-Host "   Verify in Portal and run test-graphql-rls.ps1`n" -ForegroundColor White
    }
}
catch {
    Write-Host "⚠️  Fabric REST API not available, use manual Portal steps`n" -ForegroundColor Yellow
}

Write-Host "========================================================================`n" -ForegroundColor Cyan
