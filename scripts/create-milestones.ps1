# Script to create GitHub milestones only
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

Write-Host "[SETUP] Creating milestones for $Owner/$Repository`n" -ForegroundColor Green

function New-GitHubMilestone {
    param(
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
        $Response = Invoke-RestMethod -Uri "$BaseUrl/milestones" -Method Post -Headers $Headers -Body $MilestoneData -ContentType "application/json"
        Write-Host "[OK] Milestone created: $Title (Due: $DueDate)" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "[ERROR] Error creating milestone: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Create the 4 milestones
New-GitHubMilestone -Title "Phase 1: Security and Governance" -Description "RLS enhancement and data model documentation" -DueDate "2025-01-31T23:59:59Z"
New-GitHubMilestone -Title "Phase 2: Modern API Layer" -Description "Complete REST APIs and Purview integration" -DueDate "2025-04-30T23:59:59Z"
New-GitHubMilestone -Title "Phase 3: Operational Intelligence" -Description "RTI agent and business use cases" -DueDate "2025-07-31T23:59:59Z"
New-GitHubMilestone -Title "Phase 4: Data Contracts" -Description "Advanced governance and Purview data contracts" -DueDate "2025-10-31T23:59:59Z"

Write-Host "`n[COMPLETE] Milestones creation completed!" -ForegroundColor Green
Write-Host "[LINK] https://github.com/$Owner/$Repository/milestones" -ForegroundColor Blue
