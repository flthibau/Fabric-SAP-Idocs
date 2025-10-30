#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure Service Principal access to Fabric GraphQL API

.DESCRIPTION
    Based on Microsoft documentation:
    https://learn.microsoft.com/en-us/fabric/data-engineering/api-graphql-service-principal
    
    This script guides you through the 3 required steps:
    1. Enable Service Principals in Fabric tenant settings
    2. Grant GraphQL API Execute permissions to Service Principals
    3. Ensure workspace access is configured

.NOTES
    Requires: Fabric Admin access for step 1, Workspace Admin for step 2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64",
    
    [Parameter(Mandatory=$false)]
    [string]$GraphQLAPIId = "EB8A4C24-DCC2-4E48-992C-C3CA0D7EBDFA"
)

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURE SERVICE PRINCIPAL ACCESS TO FABRIC GRAPHQL API" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

# Load credentials
$credentialsPath = Join-Path $PSScriptRoot "partner-apps-credentials.json"
if (-not (Test-Path $credentialsPath)) {
    Write-Host "❌ Credentials file not found: $credentialsPath" -ForegroundColor Red
    exit 1
}

$credentials = Get-Content $credentialsPath | ConvertFrom-Json
Write-Host "✅ Loaded Service Principal credentials`n" -ForegroundColor Green

Write-Host "Service Principals to configure:" -ForegroundColor Yellow
foreach ($partner in $credentials.Partners) {
    Write-Host "  - $($partner.Role)" -ForegroundColor White
    Write-Host "    App ID: $($partner.AppId)" -ForegroundColor Gray
    Write-Host "    SP Object ID: $($partner.ServicePrincipalObjectId)" -ForegroundColor Gray
}

Write-Host "`n========================================================================" -ForegroundColor Magenta
Write-Host "  STEP 1: ENABLE SERVICE PRINCIPALS IN TENANT SETTINGS" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

Write-Host "⚠️  REQUIRES FABRIC TENANT ADMIN ACCESS" -ForegroundColor Yellow
Write-Host "`nThis setting allows Service Principals to use Fabric APIs." -ForegroundColor White
Write-Host "Without this, Service Principals won't be visible in Fabric Portal.`n" -ForegroundColor White

Write-Host "Manual Steps (Fabric Admin Portal):" -ForegroundColor Cyan
Write-Host "`n1. Open Fabric Admin Portal:" -ForegroundColor Yellow
Write-Host "   https://app.fabric.microsoft.com/admin-portal/tenantSettings" -ForegroundColor White

Write-Host "`n2. Navigate to:" -ForegroundColor Yellow
Write-Host "   Developer Settings > Service principals can use Fabric APIs" -ForegroundColor White

Write-Host "`n3. Enable the setting:" -ForegroundColor Yellow
Write-Host "   - Toggle to 'Enabled'" -ForegroundColor White
Write-Host "   - Apply: 'The entire organization' or specific security groups" -ForegroundColor White
Write-Host "   - Click 'Apply'" -ForegroundColor White

Write-Host "`n4. Wait 15-30 minutes for propagation" -ForegroundColor Yellow

Write-Host "`n" -ForegroundColor White
$step1 = Read-Host "Have you completed Step 1? (y/n)"

if ($step1 -ne 'y') {
    Write-Host "`n⚠️  Please complete Step 1 before proceeding.`n" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n========================================================================" -ForegroundColor Magenta
Write-Host "  STEP 2: GRANT GRAPHQL API EXECUTE PERMISSIONS" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

Write-Host "⚠️  REQUIRES WORKSPACE ADMIN ACCESS" -ForegroundColor Yellow
Write-Host "`nService Principals need 'Execute' permission on the GraphQL API." -ForegroundColor White
Write-Host "This allows them to run queries and mutations.`n" -ForegroundColor White

Write-Host "Manual Steps (Fabric Portal):" -ForegroundColor Cyan

Write-Host "`n1. Open Workspace:" -ForegroundColor Yellow
Write-Host "   https://app.fabric.microsoft.com/groups/$WorkspaceId" -ForegroundColor White

Write-Host "`n2. Locate GraphQL API '3PL Partner API':" -ForegroundColor Yellow
Write-Host "   - Find the GraphQL API item in the workspace" -ForegroundColor White
Write-Host "   - Click the '...' (ellipsis) next to it" -ForegroundColor White

Write-Host "`n3. Manage Permissions:" -ForegroundColor Yellow
Write-Host "   - Select 'Manage permissions'" -ForegroundColor White
Write-Host "   - Click 'Add user'" -ForegroundColor White

Write-Host "`n4. Add each Service Principal:" -ForegroundColor Yellow
Write-Host "   For EACH of the following App IDs:" -ForegroundColor White
foreach ($partner in $credentials.Partners) {
    Write-Host "   - $($partner.AppId)  ($($partner.Role))" -ForegroundColor Cyan
}

Write-Host "`n   In the 'Add user' dialog:" -ForegroundColor White
Write-Host "   - Search by App ID (paste the GUID above)" -ForegroundColor White
Write-Host "   - Select the application" -ForegroundColor White
Write-Host "   - Check 'Run Queries and Mutations' (Execute permission)" -ForegroundColor White
Write-Host "   - Click 'Grant'" -ForegroundColor White
Write-Host "   - Repeat for all 3 Service Principals" -ForegroundColor White

Write-Host "`n5. Verify permissions:" -ForegroundColor Yellow
Write-Host "   - All 3 Service Principals should appear in the permissions list" -ForegroundColor White
Write-Host "   - Each should have 'Run Queries and Mutations' permission" -ForegroundColor White

Write-Host "`nAlternative: Add as Workspace Contributors (easier but broader access):" -ForegroundColor Cyan
Write-Host "  1. Click 'Manage access' in workspace" -ForegroundColor White
Write-Host "  2. Add each Service Principal with 'Contributor' role" -ForegroundColor White
Write-Host "  3. This grants both API Execute + data source access" -ForegroundColor White

Write-Host "`n" -ForegroundColor White
$step2 = Read-Host "Have you completed Step 2? (y/n)"

if ($step2 -ne 'y') {
    Write-Host "`n⚠️  Please complete Step 2 before proceeding.`n" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n========================================================================" -ForegroundColor Magenta
Write-Host "  STEP 3: VERIFY WORKSPACE ACCESS (ALREADY DONE)" -ForegroundColor Magenta
Write-Host "========================================================================`n" -ForegroundColor Magenta

Write-Host "✅ Service Principals already have VIEWER role in workspace" -ForegroundColor Green
Write-Host "   (Granted previously via grant-sp-workspace-access.ps1)`n" -ForegroundColor Gray

Write-Host "If you used 'Contributor' role in Step 2, workspace access is included." -ForegroundColor White
Write-Host "If you only granted GraphQL API permissions, VIEWER role is sufficient.`n" -ForegroundColor White

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "  CONFIGURATION COMPLETE - TESTING AUTHENTICATION" -ForegroundColor Green
Write-Host "========================================================================`n" -ForegroundColor Green

Write-Host "Testing Service Principal authentication..." -ForegroundColor Cyan
Write-Host "(Using scope: https://api.fabric.microsoft.com/.default)`n" -ForegroundColor Gray

# Test authentication for first Service Principal
$partner = $credentials.Partners[0]

Write-Host "Testing: $($partner.Role)" -ForegroundColor Yellow
Write-Host "App ID: $($partner.AppId)`n" -ForegroundColor Gray

$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$body = @{
    client_id = $partner.AppId
    client_secret = $partner.ClientSecret
    scope = "https://api.fabric.microsoft.com/.default"
    grant_type = "client_credentials"
}

try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Token acquired successfully" -ForegroundColor Green
    Write-Host "`nToken details:" -ForegroundColor Cyan
    Write-Host "  Length: $($response.access_token.Length) characters" -ForegroundColor White
    Write-Host "  Expires in: $($response.expires_in) seconds" -ForegroundColor White
    Write-Host "  Preview: $($response.access_token.Substring(0, 50))..." -ForegroundColor Gray
    
    Write-Host "`n========================================================================" -ForegroundColor Green
    Write-Host "  ✅ AUTHENTICATION WORKING!" -ForegroundColor Green
    Write-Host "========================================================================`n" -ForegroundColor Green
    
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: .\test-graphql-rls-azcli.ps1" -ForegroundColor White
    Write-Host "     OR: .\test-graphql-rls.ps1 (should now work)" -ForegroundColor White
    Write-Host "  2. Verify RLS filtering works correctly" -ForegroundColor White
    Write-Host "  3. Deploy Azure APIM for production`n" -ForegroundColor White
}
catch {
    Write-Host "❌ Authentication still failing" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)`n" -ForegroundColor Red
    
    $statusCode = $_.Exception.Response.StatusCode.value__
    
    if ($statusCode -eq 401) {
        Write-Host "⚠️  401 Unauthorized - Possible causes:" -ForegroundColor Yellow
        Write-Host "  1. Step 1 not completed or not propagated yet (wait 30 min)" -ForegroundColor White
        Write-Host "  2. Client secret expired or incorrect" -ForegroundColor White
        Write-Host "  3. App ID incorrect" -ForegroundColor White
        Write-Host "`nTry:" -ForegroundColor Cyan
        Write-Host "  - Wait 30 minutes after enabling tenant setting" -ForegroundColor White
        Write-Host "  - Verify client secret in Azure Portal" -ForegroundColor White
        Write-Host "  - Use test-graphql-rls-azcli.ps1 (Azure CLI auth) as workaround`n" -ForegroundColor White
    }
    elseif ($statusCode -eq 403) {
        Write-Host "⚠️  403 Forbidden - Possible causes:" -ForegroundColor Yellow
        Write-Host "  1. Service Principal tenant setting not enabled" -ForegroundColor White
        Write-Host "  2. Service Principal not granted API permissions" -ForegroundColor White
        Write-Host "  3. Go back to Step 1 and Step 2`n" -ForegroundColor White
    }
    else {
        Write-Host "Status Code: $statusCode" -ForegroundColor Red
        Write-Host "Check Azure AD sign-in logs for more details`n" -ForegroundColor White
    }
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  SUMMARY - REQUIRED CONFIGURATION" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "For Service Principals to access Fabric GraphQL API, you need:" -ForegroundColor White
Write-Host "`n1. ✅ Service Principal created with client secret" -ForegroundColor Green
Write-Host "   (Already done via create-partner-apps.ps1)" -ForegroundColor Gray

Write-Host "`n2. ⚠️  Tenant setting: 'Service principals can use Fabric APIs' enabled" -ForegroundColor Yellow
Write-Host "   Location: Admin Portal > Tenant Settings > Developer Settings" -ForegroundColor Gray
Write-Host "   Required: Fabric Admin role" -ForegroundColor Gray

Write-Host "`n3. ⚠️  GraphQL API permissions: 'Run Queries and Mutations' granted" -ForegroundColor Yellow
Write-Host "   Location: Workspace > GraphQL API > ... > Manage permissions" -ForegroundColor Gray
Write-Host "   Required: Workspace Admin role" -ForegroundColor Gray

Write-Host "`n4. ✅ Workspace access: VIEWER or higher role" -ForegroundColor Green
Write-Host "   (Already done via grant-sp-workspace-access.ps1)" -ForegroundColor Gray

Write-Host "`n5. ⚠️  OneLake RLS: Service Principals assigned to RLS roles" -ForegroundColor Yellow
Write-Host "   Location: Lakehouse > SQL Analytics Endpoint > Security > Manage Roles" -ForegroundColor Gray
Write-Host "   Or: See ONELAKE_RLS_CONFIGURATION_GUIDE.md" -ForegroundColor Gray

Write-Host "`nDocumentation:" -ForegroundColor Cyan
Write-Host "  https://learn.microsoft.com/en-us/fabric/data-engineering/api-graphql-service-principal`n" -ForegroundColor White
