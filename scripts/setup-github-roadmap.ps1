# Interactive script to set up GitHub roadmap (labels + issues)
# This script will prompt for your GitHub token securely

Write-Host "`n[SETUP] GitHub Roadmap Setup - Interactive Mode`n" -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path ".\create-github-labels.ps1")) {
    Write-Host "[ERROR] Please run this script from the 'scripts' directory" -ForegroundColor Red
    Write-Host "   Run: cd scripts" -ForegroundColor Yellow
    exit 1
}

Write-Host "This script will:" -ForegroundColor Cyan
Write-Host "  1. Create GitHub labels (priority, type, component, effort, status)" -ForegroundColor White
Write-Host "  2. Create 4 milestones (Phase 1-4)" -ForegroundColor White
Write-Host "  3. Create 6 Epic issues" -ForegroundColor White
Write-Host "  4. Create technical task issues`n" -ForegroundColor White

# Prompt for GitHub token
Write-Host "[REQUIRED] GitHub Setup:" -ForegroundColor Yellow
Write-Host "   Need a GitHub Personal Access Token with 'repo' scope" -ForegroundColor White
Write-Host "   Create one at: https://github.com/settings/tokens`n" -ForegroundColor Blue

# Check if token file exists
$tokenFile = ".\.github-token"
$plainToken = $null

if (Test-Path $tokenFile) {
    Write-Host "[INFO] Using token from .github-token file`n" -ForegroundColor Cyan
    $plainToken = Get-Content $tokenFile -Raw
    $plainToken = $plainToken.Trim()
}
else {
    $token = Read-Host "Enter your GitHub Personal Access Token (starts with ghp_ or github_pat_)" -AsSecureString
    
    # Convert SecureString to plain text (only in memory, never stored)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Validate token format
if (-not ($plainToken.StartsWith("ghp_") -or $plainToken.StartsWith("github_pat_"))) {
    Write-Host "`n[ERROR] Invalid token format. GitHub tokens start with 'ghp_' or 'github_pat_'" -ForegroundColor Red
    exit 1
}

Write-Host "`n[OK] Token validated`n" -ForegroundColor Green

# Configuration
$Owner = "flthibau"
$Repository = "Fabric-SAP-Idocs"

Write-Host "Repository: $Owner/$Repository`n" -ForegroundColor Cyan

# Ask for confirmation
$confirm = Read-Host "Proceed with setup? (y/n)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "`n[CANCELLED] Setup cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n" -NoNewline

# Step 1: Create Labels
Write-Host "========================================" -ForegroundColor Gray
Write-Host "Step 1/2: Creating GitHub Labels" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Gray

try {
    .\create-github-labels.ps1 -GitHubToken $plainToken -Owner $Owner -Repository $Repository
    Write-Host "`n[SUCCESS] Labels created successfully`n" -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Error creating labels: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Continuing with issue creation...`n" -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# Step 2: Create Issues
Write-Host "========================================" -ForegroundColor Gray
Write-Host "Step 2/2: Creating GitHub Issues and Milestones" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Gray

try {
    .\create-github-issues.ps1 -GitHubToken $plainToken -Owner $Owner -Repository $Repository
    Write-Host "`n[SUCCESS] Issues created successfully`n" -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Error creating issues: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Clear token from memory
$plainToken = $null
$token = $null

# Summary
Write-Host "========================================" -ForegroundColor Gray
Write-Host "[COMPLETE] Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Gray

Write-Host "[SUMMARY] What was created:" -ForegroundColor Cyan
Write-Host "   - GitHub labels (priority, type, component, effort, status)" -ForegroundColor Green
Write-Host "   - 4 Milestones (Phase 1-4)" -ForegroundColor Green
Write-Host "   - 6 Epic issues" -ForegroundColor Green
Write-Host "   - Technical task issues`n" -ForegroundColor Green

Write-Host "[LINKS] View Results:" -ForegroundColor Cyan
Write-Host "   - Issues: https://github.com/$Owner/$Repository/issues" -ForegroundColor Blue
Write-Host "   - Labels: https://github.com/$Owner/$Repository/labels" -ForegroundColor Blue
Write-Host "   - Milestones: https://github.com/$Owner/$Repository/milestones`n" -ForegroundColor Blue

Write-Host "[NEXT STEPS]" -ForegroundColor Cyan
Write-Host "   1. Create a GitHub Project board" -ForegroundColor White
Write-Host "   2. Add issues to the project" -ForegroundColor White
Write-Host "   3. Start working on Epic 1 (OneLake Security RLS)`n" -ForegroundColor White

Write-Host "For more info, see: ..\QUICKSTART_ROADMAP.md`n" -ForegroundColor Gray
