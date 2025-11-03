# Script to create GitHub labels for the roadmap
# Usage: .\create-github-labels.ps1 -GitHubToken "YOUR_TOKEN"

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$Owner = "flthibau",
    [string]$Repository = "Fabric-SAP-Idocs"
)

$Headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

$BaseUrl = "https://api.github.com/repos/$Owner/$Repository"

Write-Host "🏷️  Creating GitHub labels for $Owner/$Repository" -ForegroundColor Green

# Function to create a label
function New-GitHubLabel {
    param(
        [string]$Name,
        [string]$Color,
        [string]$Description
    )
    
    $LabelData = @{
        name = $Name
        color = $Color
        description = $Description
    } | ConvertTo-Json
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/labels" -Method Post -Headers $Headers -Body $LabelData -ContentType "application/json"
        Write-Host "✅ Created: $Name" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 422) {
            Write-Host "⚠️  Already exists: $Name" -ForegroundColor Yellow
        }
        else {
            Write-Host "❌ Error creating $Name : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Priority Labels
Write-Host "`n📌 Creating Priority Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "priority-critical" -Color "d73a4a" -Description "Critical priority - blocking issues"
New-GitHubLabel -Name "priority-high" -Color "ff9800" -Description "High priority - important features"
New-GitHubLabel -Name "priority-medium" -Color "fbca04" -Description "Medium priority - standard features"
New-GitHubLabel -Name "priority-low" -Color "0e8a16" -Description "Low priority - nice to have"

# Type Labels
Write-Host "`n🏷️  Creating Type Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "epic" -Color "3f51b5" -Description "Epic grouping multiple issues"
New-GitHubLabel -Name "technical-task" -Color "1d76db" -Description "Technical implementation task"
New-GitHubLabel -Name "documentation" -Color "0075ca" -Description "Documentation work"
New-GitHubLabel -Name "enhancement" -Color "a2eeef" -Description "New feature or enhancement"

# Component Labels
Write-Host "`n🔧 Creating Component Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "component-fabric" -Color "7057ff" -Description "Microsoft Fabric related"
New-GitHubLabel -Name "component-api" -Color "008672" -Description "APIs (REST/GraphQL)"
New-GitHubLabel -Name "component-purview" -Color "1d76db" -Description "Microsoft Purview"
New-GitHubLabel -Name "component-security" -Color "d93f0b" -Description "Security and RLS"
New-GitHubLabel -Name "component-infrastructure" -Color "0052cc" -Description "Infrastructure as Code"
New-GitHubLabel -Name "component-governance" -Color "5319e7" -Description "Data governance"

# Effort Labels
Write-Host "`n⏱️  Creating Effort Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "effort-xs" -Color "c2e0c6" -Description "Less than 1 day"
New-GitHubLabel -Name "effort-s" -Color "bfdadc" -Description "1-2 days"
New-GitHubLabel -Name "effort-m" -Color "fef2c0" -Description "3-5 days"
New-GitHubLabel -Name "effort-l" -Color "fad8c7" -Description "1-2 weeks"
New-GitHubLabel -Name "effort-xl" -Color "f9d0c4" -Description "More than 2 weeks"

# Status Labels
Write-Host "`n🚦 Creating Status Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "status-blocked" -Color "d73a4a" -Description "Blocked by dependencies"
New-GitHubLabel -Name "status-needs-review" -Color "fbca04" -Description "Needs review or approval"
New-GitHubLabel -Name "status-debugging" -Color "ff9800" -Description "Currently debugging"
New-GitHubLabel -Name "status-testing" -Color "1d76db" -Description "In testing phase"

# Special Labels
Write-Host "`n⭐ Creating Special Labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "roadmap" -Color "0e8a16" -Description "Part of the roadmap"

Write-Host "`n[COMPLETE] Label creation complete!" -ForegroundColor Green
Write-Host "[LINK] View labels at: https://github.com/$Owner/$Repository/labels" -ForegroundColor Blue
