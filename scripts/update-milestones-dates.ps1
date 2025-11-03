# Script to update GitHub milestones with correct future dates
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

Write-Host "[SETUP] Updating milestones with correct future dates`n" -ForegroundColor Green

function Update-GitHubMilestone {
    param(
        [int]$Number,
        [string]$Title,
        [string]$Description,
        [string]$DueDate
    )
    
    $MilestoneData = @{
        title = $Title
        description = $Description
        due_on = $DueDate
    } | ConvertTo-Json
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/milestones/$Number" -Method Patch -Headers $Headers -Body $MilestoneData -ContentType "application/json"
        Write-Host "[OK] Milestone updated: $Title (Due: $DueDate)" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "[ERROR] Error updating milestone: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Update the 4 milestones with correct future dates (November 2025 - October 2026)
Update-GitHubMilestone -Number 1 -Title "Phase 1: Security and Governance" -Description "RLS enhancement and data model documentation" -DueDate "2026-01-31T23:59:59Z"
Update-GitHubMilestone -Number 2 -Title "Phase 2: Modern API Layer" -Description "Complete REST APIs and Purview integration" -DueDate "2026-04-30T23:59:59Z"
Update-GitHubMilestone -Number 3 -Title "Phase 3: Operational Intelligence" -Description "RTI agent and business use cases" -DueDate "2026-07-31T23:59:59Z"
Update-GitHubMilestone -Number 4 -Title "Phase 4: Data Contracts" -Description "Advanced governance and Purview data contracts" -DueDate "2026-10-31T23:59:59Z"

Write-Host "`n[COMPLETE] Milestones updated with correct dates!" -ForegroundColor Green
Write-Host "[INFO] New timeline: November 2025 - October 2026" -ForegroundColor Cyan
Write-Host "[LINK] https://github.com/$Owner/$Repository/milestones" -ForegroundColor Blue
