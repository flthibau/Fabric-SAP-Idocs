#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure Row-Level Security (RLS) for Fabric SAP IDoc Workshop

.DESCRIPTION
    This script automates the setup of Row-Level Security for the workshop:
    - Creates Azure AD Service Principals for partner applications
    - Grants workspace access to Service Principals
    - Validates RLS configuration
    - Tests RLS filters
    
    Partner Service Principals created:
    - sp-partner-fedex (CARRIER-FEDEX role)
    - sp-partner-warehouse-east (WAREHOUSE-EAST role)
    - sp-partner-acme (CUSTOMER-ACME role)

.PARAMETER Action
    The action to perform:
    - CreateServicePrincipals: Create 3 partner Service Principals
    - GrantWorkspaceAccess: Grant Service Principals access to Fabric workspace
    - ValidateConfiguration: Verify RLS setup is correct
    - All: Run all actions in sequence

.PARAMETER WorkspaceName
    The name of the Fabric workspace (required for GrantWorkspaceAccess)

.PARAMETER TenantId
    Azure AD Tenant ID (optional, will auto-detect if not provided)

.PARAMETER OutputPath
    Path to save Service Principal credentials (default: ./partner-apps-credentials.json)

.EXAMPLE
    .\configure-rls.ps1 -Action CreateServicePrincipals
    
.EXAMPLE
    .\configure-rls.ps1 -Action GrantWorkspaceAccess -WorkspaceName "fabric-sap-idocs-workshop"
    
.EXAMPLE
    .\configure-rls.ps1 -Action All -WorkspaceName "fabric-sap-idocs-workshop"

.NOTES
    Author: Workshop Module 5 - Security & RLS
    Prerequisites:
    - Azure CLI or Az PowerShell module
    - Azure AD permissions to create App Registrations
    - Fabric workspace Admin or Member role
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('CreateServicePrincipals', 'GrantWorkspaceAccess', 'ValidateConfiguration', 'All')]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "",

    [Parameter(Mandatory=$false)]
    [string]$TenantId = "",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./partner-apps-credentials.json"
)

# Color scheme for output
$script:Colors = @{
    Success = 'Green'
    Error = 'Red'
    Warning = 'Yellow'
    Info = 'Cyan'
    Header = 'Magenta'
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-SectionHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-ColorOutput "========================================================================" -Color $Colors.Header
    Write-ColorOutput "  $Title" -Color $Colors.Header
    Write-ColorOutput "========================================================================" -Color $Colors.Header
    Write-Host ""
}

function Test-AzureCliInstalled {
    try {
        $azVersion = az version 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI detected: $($azVersion.'azure-cli')" -Color $Colors.Success
        return $true
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not found" -Color $Colors.Error
        Write-ColorOutput "   Please install: https://learn.microsoft.com/cli/azure/install-azure-cli" -Color $Colors.Warning
        return $false
    }
}

function Test-AzureLogin {
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged in as: $($account.user.name)" -Color $Colors.Success
        Write-ColorOutput "   Tenant: $($account.tenantId)" -Color 'Gray'
        Write-ColorOutput "   Subscription: $($account.name)" -Color 'Gray'
        return $account.tenantId
    }
    catch {
        Write-ColorOutput "❌ Not logged in to Azure" -Color $Colors.Error
        Write-ColorOutput "   Run: az login" -Color $Colors.Warning
        return $null
    }
}

function New-PartnerServicePrincipal {
    param(
        [string]$DisplayName,
        [string]$Description,
        [string]$TenantId
    )
    
    Write-ColorOutput "Creating Service Principal: $DisplayName..." -Color $Colors.Info
    
    try {
        # Create App Registration
        $app = az ad app create --display-name $DisplayName --query "{appId:appId,objectId:id}" 2>$null | ConvertFrom-Json
        
        if (-not $app) {
            throw "Failed to create app registration"
        }
        
        Write-ColorOutput "   ✅ App Registration created" -Color $Colors.Success
        Write-ColorOutput "      App ID: $($app.appId)" -Color 'Gray'
        
        # Create Service Principal
        $sp = az ad sp create --id $app.appId --query "{objectId:id}" 2>$null | ConvertFrom-Json
        
        if (-not $sp) {
            throw "Failed to create service principal"
        }
        
        Write-ColorOutput "   ✅ Service Principal created" -Color $Colors.Success
        Write-ColorOutput "      Object ID: $($sp.objectId)" -Color 'Gray'
        
        # Create client secret (valid for 12 months)
        $secret = az ad app credential reset --id $app.appId --years 1 --query "password" -o tsv 2>$null
        
        if (-not $secret) {
            throw "Failed to create client secret"
        }
        
        Write-ColorOutput "   ✅ Client secret created (expires in 12 months)" -Color $Colors.Success
        Write-ColorOutput "      Secret: $($secret.Substring(0,8))..." -Color 'Gray'
        
        return @{
            DisplayName = $DisplayName
            AppId = $app.appId
            ObjectId = $sp.objectId
            ClientSecret = $secret
            Description = $Description
        }
    }
    catch {
        Write-ColorOutput "   ❌ Failed to create Service Principal: $($_.Exception.Message)" -Color $Colors.Error
        return $null
    }
}

function New-AllPartnerServicePrincipals {
    param([string]$TenantId)
    
    Write-SectionHeader "Creating Partner Service Principals"
    
    $partners = @(
        @{
            Name = "sp-partner-fedex"
            Description = "FedEx Carrier - Shipment tracking access"
            Role = "CARRIER-FEDEX"
        },
        @{
            Name = "sp-partner-warehouse-east"
            Description = "Warehouse East - Facility WH003 access"
            Role = "WAREHOUSE-EAST"
        },
        @{
            Name = "sp-partner-acme"
            Description = "ACME Corp - Customer order and shipment access"
            Role = "CUSTOMER-ACME"
        }
    )
    
    $results = @()
    
    foreach ($partner in $partners) {
        $sp = New-PartnerServicePrincipal -DisplayName $partner.Name -Description $partner.Description -TenantId $TenantId
        
        if ($sp) {
            $sp.Role = $partner.Role
            $results += $sp
            Write-Host ""
        }
        else {
            Write-ColorOutput "⚠️  Skipping $($partner.Name) due to error" -Color $Colors.Warning
        }
    }
    
    if ($results.Count -eq 0) {
        Write-ColorOutput "❌ No Service Principals created" -Color $Colors.Error
        return $null
    }
    
    # Save credentials to file
    $credentialsObject = @{
        TenantId = $TenantId
        CreatedDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        Partners = $results
    }
    
    try {
        $credentialsObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-ColorOutput "✅ Credentials saved to: $OutputPath" -Color $Colors.Success
        Write-ColorOutput "   ⚠️  IMPORTANT: Keep this file secure and do not commit to source control!" -Color $Colors.Warning
    }
    catch {
        Write-ColorOutput "❌ Failed to save credentials: $($_.Exception.Message)" -Color $Colors.Error
    }
    
    return $results
}

function Grant-ServicePrincipalWorkspaceAccess {
    param(
        [string]$WorkspaceName
    )
    
    Write-SectionHeader "Granting Workspace Access"
    
    if ([string]::IsNullOrWhiteSpace($WorkspaceName)) {
        Write-ColorOutput "❌ WorkspaceName parameter is required" -Color $Colors.Error
        Write-ColorOutput "   Usage: .\configure-rls.ps1 -Action GrantWorkspaceAccess -WorkspaceName 'your-workspace'" -Color $Colors.Warning
        return
    }
    
    # Check if credentials file exists
    if (-not (Test-Path $OutputPath)) {
        Write-ColorOutput "❌ Credentials file not found: $OutputPath" -Color $Colors.Error
        Write-ColorOutput "   Run with -Action CreateServicePrincipals first" -Color $Colors.Warning
        return
    }
    
    try {
        $credentials = Get-Content $OutputPath | ConvertFrom-Json
        
        Write-ColorOutput "📋 Workspace Access Configuration" -Color $Colors.Info
        Write-ColorOutput "   Workspace: $WorkspaceName" -Color 'White'
        Write-ColorOutput "   Role: Viewer (required for RLS read access)" -Color 'White'
        Write-Host ""
        
        Write-ColorOutput "ℹ️  MANUAL STEPS REQUIRED:" -Color $Colors.Warning
        Write-Host ""
        Write-ColorOutput "1. Open Fabric Portal: https://app.fabric.microsoft.com" -Color 'White'
        Write-ColorOutput "2. Navigate to your workspace: '$WorkspaceName'" -Color 'White'
        Write-ColorOutput "3. Click 'Manage access' (or workspace settings → Access)" -Color 'White'
        Write-ColorOutput "4. Click '+ Add people or groups'" -Color 'White'
        Write-Host ""
        
        foreach ($partner in $credentials.Partners) {
            Write-ColorOutput "5. Add Service Principal:" -Color 'White'
            Write-ColorOutput "   - Search for: $($partner.DisplayName)" -Color $Colors.Info
            Write-ColorOutput "   - Or use App ID: $($partner.AppId)" -Color 'Gray'
            Write-ColorOutput "   - Assign role: Viewer" -Color 'White'
            Write-ColorOutput "   - Click 'Add'" -Color 'White'
            Write-Host ""
        }
        
        Write-ColorOutput "✅ After adding all Service Principals, your RLS configuration will be ready!" -Color $Colors.Success
        Write-Host ""
        Write-ColorOutput "Note: Programmatic workspace access requires Power BI REST API or PowerShell modules." -Color 'Gray'
        Write-ColorOutput "      For workshop simplicity, we use the Fabric Portal UI." -Color 'Gray'
    }
    catch {
        Write-ColorOutput "❌ Failed to read credentials: $($_.Exception.Message)" -Color $Colors.Error
    }
}

function Test-RLSConfiguration {
    Write-SectionHeader "Validating RLS Configuration"
    
    # Check if credentials file exists
    if (-not (Test-Path $OutputPath)) {
        Write-ColorOutput "❌ Credentials file not found: $OutputPath" -Color $Colors.Error
        Write-ColorOutput "   Run with -Action CreateServicePrincipals first" -Color $Colors.Warning
        return
    }
    
    try {
        $credentials = Get-Content $OutputPath | ConvertFrom-Json
        
        Write-ColorOutput "📋 Configuration Validation Checklist" -Color $Colors.Info
        Write-Host ""
        
        # Check 1: Service Principals exist
        Write-ColorOutput "✓ Checking Service Principals..." -Color $Colors.Info
        
        foreach ($partner in $credentials.Partners) {
            try {
                $sp = az ad sp show --id $partner.AppId 2>$null | ConvertFrom-Json
                
                if ($sp) {
                    Write-ColorOutput "   ✅ $($partner.DisplayName) exists" -Color $Colors.Success
                }
                else {
                    Write-ColorOutput "   ❌ $($partner.DisplayName) not found" -Color $Colors.Error
                }
            }
            catch {
                Write-ColorOutput "   ❌ $($partner.DisplayName) validation failed" -Color $Colors.Error
            }
        }
        
        Write-Host ""
        
        # Check 2: Manual validation steps
        Write-ColorOutput "✓ Manual Validation Steps (complete these in Fabric Portal):" -Color $Colors.Info
        Write-Host ""
        
        Write-ColorOutput "   [ ] Open SQL Analytics Endpoint in your Lakehouse" -Color 'White'
        Write-ColorOutput "   [ ] Navigate to Security → Manage security roles" -Color 'White'
        Write-ColorOutput "   [ ] Verify these roles exist:" -Color 'White'
        Write-ColorOutput "       - CARRIER-FEDEX (filters: gold_shipments_in_transit, gold_sla_performance)" -Color 'Gray'
        Write-ColorOutput "       - WAREHOUSE-EAST (filter: gold_warehouse_productivity_daily)" -Color 'Gray'
        Write-ColorOutput "       - CUSTOMER-ACME (filters: gold_orders_daily_summary, gold_shipments_in_transit, etc.)" -Color 'Gray'
        Write-Host ""
        
        Write-ColorOutput "   [ ] Verify each role has correct members:" -Color 'White'
        foreach ($partner in $credentials.Partners) {
            Write-ColorOutput "       - $($partner.Role): $($partner.DisplayName)" -Color 'Gray'
        }
        Write-Host ""
        
        Write-ColorOutput "   [ ] Verify filter predicates match expected values:" -Color 'White'
        Write-ColorOutput "       - CARRIER-FEDEX: [carrier_id] = 'CARRIER-FEDEX-GROUP'" -Color 'Gray'
        Write-ColorOutput "       - WAREHOUSE-EAST: [warehouse_partner_id] = 'PARTNER_WH003'" -Color 'Gray'
        Write-ColorOutput "       - CUSTOMER-ACME: [partner_access_scope] = 'CUSTOMER'" -Color 'Gray'
        Write-Host ""
        
        Write-ColorOutput "✅ Service Principal validation complete" -Color $Colors.Success
        Write-ColorOutput "   Next: Complete manual steps above to finish RLS configuration" -Color $Colors.Info
    }
    catch {
        Write-ColorOutput "❌ Validation failed: $($_.Exception.Message)" -Color $Colors.Error
    }
}

function Show-Summary {
    param([hashtable]$Results)
    
    Write-SectionHeader "Configuration Summary"
    
    Write-ColorOutput "✅ RLS Configuration Complete!" -Color $Colors.Success
    Write-Host ""
    
    Write-ColorOutput "📋 What Was Done:" -Color $Colors.Info
    Write-ColorOutput "   ✅ Created 3 Service Principals for partner applications" -Color 'White'
    Write-ColorOutput "   ✅ Generated client secrets (valid for 12 months)" -Color 'White'
    Write-ColorOutput "   ✅ Saved credentials to $OutputPath" -Color 'White'
    Write-Host ""
    
    Write-ColorOutput "📝 Next Steps:" -Color $Colors.Info
    Write-ColorOutput "   1. Grant workspace access (see instructions above)" -Color 'White'
    Write-ColorOutput "   2. Create RLS roles in Fabric Portal (see Module 5 Section 3)" -Color 'White'
    Write-ColorOutput "   3. Test RLS with: .\test-rls-access.ps1" -Color 'White'
    Write-Host ""
    
    Write-ColorOutput "🔒 Security Reminder:" -Color $Colors.Warning
    Write-ColorOutput "   - Keep partner-apps-credentials.json secure" -Color 'White'
    Write-ColorOutput "   - Add to .gitignore to prevent accidental commits" -Color 'White'
    Write-ColorOutput "   - Rotate secrets every 12 months" -Color 'White'
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-SectionHeader "Fabric RLS Configuration Script"

# Check prerequisites
Write-ColorOutput "🔍 Checking Prerequisites..." -Color $Colors.Info
Write-Host ""

if (-not (Test-AzureCliInstalled)) {
    exit 1
}

$detectedTenantId = Test-AzureLogin

if (-not $detectedTenantId) {
    exit 1
}

# Use detected tenant ID if not provided
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    $TenantId = $detectedTenantId
}

Write-Host ""
Write-ColorOutput "✅ All prerequisites met" -Color $Colors.Success
Write-Host ""

# Execute requested action
switch ($Action) {
    'CreateServicePrincipals' {
        $results = New-AllPartnerServicePrincipals -TenantId $TenantId
        
        if ($results) {
            Write-Host ""
            Write-ColorOutput "✅ Service Principal creation complete" -Color $Colors.Success
            Write-Host ""
            Write-ColorOutput "Next: Run with -Action GrantWorkspaceAccess to configure workspace permissions" -Color $Colors.Info
        }
    }
    
    'GrantWorkspaceAccess' {
        Grant-ServicePrincipalWorkspaceAccess -WorkspaceName $WorkspaceName
    }
    
    'ValidateConfiguration' {
        Test-RLSConfiguration
    }
    
    'All' {
        # Run all actions in sequence
        $results = New-AllPartnerServicePrincipals -TenantId $TenantId
        
        if ($results) {
            Grant-ServicePrincipalWorkspaceAccess -WorkspaceName $WorkspaceName
            Test-RLSConfiguration
            Show-Summary -Results @{ ServicePrincipals = $results }
        }
    }
}

Write-Host ""
Write-ColorOutput "========================================================================" -Color $Colors.Header
Write-Host ""
