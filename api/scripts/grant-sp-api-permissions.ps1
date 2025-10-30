#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Grant API permissions to Service Principals for Fabric access

.DESCRIPTION
    Adds required API permissions (Power BI/Fabric) to the Service Principals
    so they can authenticate and access GraphQL API with RLS.

.NOTES
    Requires: Azure AD admin permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
)

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  GRANT API PERMISSIONS TO SERVICE PRINCIPALS" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"
$credentials = Get-Content $credentialsPath | ConvertFrom-Json

# Power BI Service / Fabric API permissions
$powerBIResourceId = "00000009-0000-0000-c000-000000000000" # Power BI Service
$fabricResourceId = "https://api.fabric.microsoft.com"

Write-Host "Required API Permissions:" -ForegroundColor Yellow
Write-Host "  - Power BI Service: Dataset.Read.All (Delegated)" -ForegroundColor White
Write-Host "  - Power BI Service: Workspace.Read.All (Application)" -ForegroundColor White
Write-Host "`n" -ForegroundColor White

foreach ($partner in $credentials.Partners) {
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "  Configuring: $($partner.Role)" -ForegroundColor Magenta
    Write-Host "========================================================================`n" -ForegroundColor Magenta
    
    Write-Host "App ID: $($partner.AppId)" -ForegroundColor White
    Write-Host "`nAdding Power BI API permissions..." -ForegroundColor Cyan
    
    # Add Workspace.Read.All permission (Application)
    $workspaceReadAllId = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f" # Workspace.Read.All
    
    try {
        az ad app permission add `
            --id $partner.AppId `
            --api $powerBIResourceId `
            --api-permissions "$workspaceReadAllId=Role" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Added Workspace.Read.All (Application)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Permission may already exist or failed to add" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Add Dataset.Read.All permission (Application)
    $datasetReadAllId = "7504609f-c495-4c64-8542-686125a5a36f" # Dataset.Read.All
    
    try {
        az ad app permission add `
            --id $partner.AppId `
            --api $powerBIResourceId `
            --api-permissions "$datasetReadAllId=Role" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Added Dataset.Read.All (Application)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Permission may already exist" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "========================================================================" -ForegroundColor Red
Write-Host "  ⚠️  ADMIN CONSENT REQUIRED" -ForegroundColor Red
Write-Host "========================================================================`n" -ForegroundColor Red

Write-Host "The API permissions have been added but require ADMIN CONSENT." -ForegroundColor Yellow
Write-Host "`nOption 1: Grant consent via Azure Portal (RECOMMENDED):" -ForegroundColor Cyan
Write-Host "  1. Go to: https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps" -ForegroundColor White
Write-Host "  2. Search for each App ID and click on it" -ForegroundColor White
Write-Host "  3. Go to 'API permissions'" -ForegroundColor White
Write-Host "  4. Click 'Grant admin consent for [tenant]'" -ForegroundColor White
Write-Host "`n" -ForegroundColor White

Write-Host "Option 2: Grant consent via Azure CLI (requires Global Admin):" -ForegroundColor Cyan

foreach ($partner in $credentials.Partners) {
    Write-Host "`nFor $($partner.Role):" -ForegroundColor Yellow
    Write-Host "az ad app permission admin-consent --id $($partner.AppId)" -ForegroundColor White
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ALTERNATIVE: USE DELEGATED AUTH (NO ADMIN CONSENT)" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "If admin consent is blocked, you can test with user delegated auth:" -ForegroundColor Yellow
Write-Host "  1. Use interactive user login instead of Service Principal" -ForegroundColor White
Write-Host "  2. User must have access to workspace with RLS roles assigned" -ForegroundColor White
Write-Host "  3. Test script will need modification to use user auth flow`n" -ForegroundColor White

Write-Host "========================================================================" -ForegroundColor Green
Write-Host "  NEXT STEPS" -ForegroundColor Green
Write-Host "========================================================================`n" -ForegroundColor Green

Write-Host "After granting admin consent:" -ForegroundColor Yellow
Write-Host "  1. Wait 5-10 minutes for permissions to propagate" -ForegroundColor White
Write-Host "  2. Run: .\test-graphql-rls.ps1" -ForegroundColor White
Write-Host "  3. Verify RLS filtering works correctly`n" -ForegroundColor White
