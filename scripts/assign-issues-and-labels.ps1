# Script to assign issues to milestones and add labels
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

Write-Host "[SETUP] Assigning issues to milestones and adding labels`n" -ForegroundColor Green

function Update-GitHubIssue {
    param(
        [int]$IssueNumber,
        [string[]]$Labels,
        [int]$Milestone
    )
    
    $IssueData = @{
        labels = $Labels
        milestone = $Milestone
    } | ConvertTo-Json
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/issues/$IssueNumber" -Method Patch -Headers $Headers -Body $IssueData -ContentType "application/json"
        Write-Host "[OK] Issue #$IssueNumber updated - Milestone: $Milestone, Labels: $($Labels -join ', ')" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "[ERROR] Error updating issue #$IssueNumber" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Phase 1: Security and Governance (Milestone 1)
Write-Host "`n[PHASE 1] Assigning Phase 1 issues..." -ForegroundColor Cyan

# Epic 1: OneLake Security - Row-Level Security Enhancement
Update-GitHubIssue -IssueNumber 1 -Labels @("epic", "component-security", "priority-critical", "roadmap") -Milestone 1

# Tasks for Epic 1
Update-GitHubIssue -IssueNumber 2 -Labels @("technical-task", "component-security", "effort-m", "roadmap", "status-debugging") -Milestone 1
Update-GitHubIssue -IssueNumber 3 -Labels @("technical-task", "component-security", "effort-l", "roadmap") -Milestone 1
Update-GitHubIssue -IssueNumber 4 -Labels @("technical-task", "component-security", "effort-xl", "roadmap") -Milestone 1
Update-GitHubIssue -IssueNumber 5 -Labels @("technical-task", "component-security", "effort-l", "roadmap") -Milestone 1

# Epic 6: Data Model Documentation
Update-GitHubIssue -IssueNumber 6 -Labels @("epic", "documentation", "priority-high", "roadmap") -Milestone 1

# Tasks for Epic 6
Update-GitHubIssue -IssueNumber 7 -Labels @("documentation", "effort-m", "roadmap") -Milestone 1
Update-GitHubIssue -IssueNumber 8 -Labels @("documentation", "effort-l", "roadmap") -Milestone 1
Update-GitHubIssue -IssueNumber 9 -Labels @("documentation", "effort-m", "roadmap") -Milestone 1
Update-GitHubIssue -IssueNumber 10 -Labels @("documentation", "effort-s", "roadmap") -Milestone 1

# Phase 2: Modern API Layer (Milestone 2)
Write-Host "`n[PHASE 2] Assigning Phase 2 issues..." -ForegroundColor Cyan

# Epic 11: Complete REST APIs
Update-GitHubIssue -IssueNumber 11 -Labels @("epic", "component-api", "priority-critical", "roadmap") -Milestone 2

# Epic 12: API Access Materialization in Purview
Update-GitHubIssue -IssueNumber 12 -Labels @("epic", "component-purview", "priority-high", "roadmap") -Milestone 2

# Phase 3: Operational Intelligence (Milestone 3)
Write-Host "`n[PHASE 3] Assigning Phase 3 issues..." -ForegroundColor Cyan

# Epic 13: RTI Operational Agent
Update-GitHubIssue -IssueNumber 13 -Labels @("epic", "component-fabric", "priority-high", "roadmap") -Milestone 3

# Phase 4: Data Contracts (Milestone 4)
Write-Host "`n[PHASE 4] Assigning Phase 4 issues..." -ForegroundColor Cyan

# Epic 14: Data Contracts in Purview
Update-GitHubIssue -IssueNumber 14 -Labels @("epic", "component-purview", "priority-critical", "roadmap") -Milestone 4

Write-Host "`n[COMPLETE] All issues assigned to milestones with labels!" -ForegroundColor Green
Write-Host "[SUMMARY]" -ForegroundColor Cyan
Write-Host "  - Phase 1 (Milestone 1): 10 issues (Epic 1 + 4 tasks + Epic 6 + 4 tasks)" -ForegroundColor White
Write-Host "  - Phase 2 (Milestone 2): 2 epics" -ForegroundColor White
Write-Host "  - Phase 3 (Milestone 3): 1 epic" -ForegroundColor White
Write-Host "  - Phase 4 (Milestone 4): 1 epic" -ForegroundColor White
Write-Host "`n[LINK] https://github.com/$Owner/$Repository/issues" -ForegroundColor Blue
