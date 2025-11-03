# PowerShell script to automatically create roadmap issues
# This script uses the GitHub API to create issues defined in the roadmap

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$Owner = "flthibau",
    [string]$Repository = "Fabric-SAP-Idocs"
)

# Base configuration
$Headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "PowerShell-GitHub-Roadmap-Script"
}

$BaseUrl = "https://api.github.com/repos/$Owner/$Repository"

Write-Host "🚀 Creating issues for SAP IDoc Data Product roadmap" -ForegroundColor Green
Write-Host "Repository: $Owner/$Repository" -ForegroundColor Cyan

# Function to create an issue
function New-GitHubIssue {
    param(
        [string]$Title,
        [string]$Body,
        [string[]]$Labels,
        [string]$Milestone
    )
    
    $IssueData = @{
        title = $Title
        body = $Body
        labels = $Labels
    }
    
    if ($Milestone) {
        $IssueData.milestone = $Milestone
    }
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/issues" -Method Post -Headers $Headers -Body ($IssueData | ConvertTo-Json -Depth 3)
        Write-Host "✅ Issue created: #$($Response.number) - $Title" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "❌ Error creating issue: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Function to create a milestone
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
    }
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/milestones" -Method Post -Headers $Headers -Body ($MilestoneData | ConvertTo-Json)
        Write-Host "📅 Milestone created: $Title" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "❌ Error creating milestone: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Creating milestones
Write-Host "`n📅 Creating milestones..." -ForegroundColor Yellow

$Milestone1 = New-GitHubMilestone -Title "Phase 1: Security & Governance" -Description "RLS enhancement and data model documentation" -DueDate "2025-01-31T23:59:59Z"
$Milestone2 = New-GitHubMilestone -Title "Phase 2: Modern API Layer" -Description "Complete REST APIs and Purview integration" -DueDate "2025-04-30T23:59:59Z"
$Milestone3 = New-GitHubMilestone -Title "Phase 3: Operational Intelligence" -Description "RTI agent and business use cases" -DueDate "2025-07-31T23:59:59Z"
$Milestone4 = New-GitHubMilestone -Title "Phase 4: Data Contracts" -Description "Advanced governance and Purview data contracts" -DueDate "2025-10-31T23:59:59Z"

# Defining Epics and Issues
Write-Host "`n📋 Creating Epics and Issues..." -ForegroundColor Yellow

# Epic 1: OneLake Security - Row-Level Security Enhancement
$Epic1Body = @"
## Epic Overview

Enhance the Row-Level Security (RLS) implementation in OneLake to provide granular, multi-level security for SAP IDoc data.

### Roadmap Phase
- Phase: Phase 1 - Security and Governance
- Priority: Critical

## Business Value

### Problem Statement
Current RLS implementation needs improvements to support more complex security scenarios and optimized performance.

### Value Delivered
- Enhanced security for sensitive data
- Improved query performance with filtering
- Support for advanced multi-tenant scenarios

### Success Metrics
- 100% of access properly filtered
- Less than 10ms performance overhead
- 0 security breaches identified

## Technical Scope

### Impacted Components
- OneLake Security
- Fabric Warehouse
- GraphQL API
- Security documentation

## Related Issues
- Issue 1 - Audit current RLS configuration
- Issue 2 - Design new security models
- Issue 3 - Implement multi-level RLS
- Issue 4 - Security testing and validation
"@

New-GitHubIssue -Title "[EPIC] OneLake Security - Row-Level Security Enhancement" -Body $Epic1Body -Labels @("epic", "component-security", "priority-critical", "roadmap") -Milestone $Milestone1.number

# Epic 1 Issues
$Issues = @(
    @{
        Title = "Audit current RLS configuration"
        Body = "Analyze the current RLS implementation in OneLake and identify improvement areas."
        Labels = @("technical-task", "component-security", "effort-m", "roadmap")
    },
    @{
        Title = "Design new security models"
        Body = "Design new RLS security models to support advanced use cases."
        Labels = @("technical-task", "component-security", "effort-l", "roadmap")
    },
    @{
        Title = "Implement multi-level RLS"
        Body = "Implement the new RLS configuration with multi-level support in OneLake."
        Labels = @("technical-task", "component-security", "effort-xl", "roadmap")
    },
    @{
        Title = "Security testing and validation"
        Body = "Create and execute a complete security test suite to validate RLS implementation."
        Labels = @("technical-task", "component-security", "effort-l", "roadmap")
    }
)

foreach ($Issue in $Issues) {
    New-GitHubIssue -Title $Issue.Title -Body $Issue.Body -Labels $Issue.Labels -Milestone $Milestone1.number
}

# Epic 2: Data Model Documentation
$Epic2Body = @"
## Epic Overview

Create comprehensive and professional documentation of the SAP IDoc data model to facilitate understanding and usage of the data product.

### Roadmap Phase
- Phase: Phase 1 - Security and Governance
- Priority: High

## Business Value

### Problem Statement
The current data model lacks clear and structured documentation, making onboarding and partner usage difficult.

### Value Delivered
- Improved developer experience
- Reduced integration time
- Better data governance

### Success Metrics
- 100% documentation completeness
- 50% reduction in onboarding time
- 0 recurring questions about the model

## Technical Scope

### Impacted Components
- Technical documentation
- Data schemas
- ERD diagrams
- Business glossary
"@

New-GitHubIssue -Title "[EPIC] Data Model Documentation" -Body $Epic2Body -Labels @("epic", "documentation", "priority-high", "roadmap") -Milestone $Milestone1.number

# Epic 2 Issues
$Issues2 = @(
    @{
        Title = "Map existing data entities"
        Body = "Identify and catalog all data entities present in the system."
        Labels = @("documentation", "effort-m", "roadmap")
    },
    @{
        Title = "Document business data schema"
        Body = "Create detailed documentation of data schemas with business definitions."
        Labels = @("documentation", "effort-l", "roadmap")
    },
    @{
        Title = "ERD diagrams and relationships"
        Body = "Design Entity-Relationship diagrams and document entity relationships."
        Labels = @("documentation", "effort-m", "roadmap")
    },
    @{
        Title = "Business glossary and definitions"
        Body = "Create a comprehensive glossary of business terms and technical definitions."
        Labels = @("documentation", "effort-s", "roadmap")
    }
)

foreach ($Issue in $Issues2) {
    New-GitHubIssue -Title $Issue.Title -Body $Issue.Body -Labels $Issue.Labels -Milestone $Milestone1.number
}

# Epic 3: Complete REST APIs
$Epic3Body = @"
## Epic Overview

Develop complete REST APIs with CRUD operations to provide modern and standardized access to SAP IDoc data.

### Roadmap Phase
- Phase: Phase 2 - Modern API Layer
- Priority: Critical

## Business Value

### Problem Statement
Data access is currently limited to GraphQL. Partners request standard REST APIs to facilitate integration.

### Value Delivered
- Standardized access via REST
- Full CRUD support
- Simplified partner integration

### Success Metrics
- 100% functional REST APIs
- Less than 100ms average latency
- Complete OpenAPI documentation
"@

New-GitHubIssue -Title "[EPIC] Complete REST APIs" -Body $Epic3Body -Labels @("epic", "component-api", "priority-critical", "roadmap") -Milestone $Milestone2.number

# Epic 4: API Access Materialization in Purview
$Epic4Body = @"
## Epic Overview

Integrate and reference all APIs (GraphQL and REST) in Microsoft Purview for centralized governance.

### Roadmap Phase
- Phase: Phase 2 - Modern API Layer
- Priority: High

## Business Value

### Problem Statement
APIs are not referenced in the data catalog, limiting discoverability and governance.

### Value Delivered
- Unified API catalog
- Centralized access metadata
- Improved monitoring and governance
"@

New-GitHubIssue -Title "[EPIC] API Access Materialization in Purview" -Body $Epic4Body -Labels @("epic", "component-purview", "priority-high", "roadmap") -Milestone $Milestone2.number

# Epic 5: RTI Operational Agent
$Epic5Body = @"
## Epic Overview

Develop an RTI (Real-Time Intelligence) agent to automate business use cases and operational analysis.

### Roadmap Phase
- Phase: Phase 3 - Operational Intelligence
- Priority: High

## Business Value

### Problem Statement
Operational analyses are mostly manual, limiting reactivity and efficiency.

### Value Delivered
- Automated analysis
- Proactive anomaly detection
- Real-time operational insights
"@

New-GitHubIssue -Title "[EPIC] RTI Operational Agent" -Body $Epic5Body -Labels @("epic", "component-fabric", "priority-high", "roadmap") -Milestone $Milestone3.number

# Epic 6: Data Contracts in Purview
$Epic6Body = @"
## Epic Overview

Implement formalized data contracts in Microsoft Purview to guarantee quality and compliance.

### Roadmap Phase
- Phase: Phase 4 - Data Contracts and Advanced Governance
- Priority: Critical

## Business Value

### Problem Statement
Absence of formalized contracts to guarantee data quality and compliance.

### Value Delivered
- Guaranteed data quality
- Automated compliance
- Formalized data SLAs
"@

New-GitHubIssue -Title "[EPIC] Data Contracts in Purview" -Body $Epic6Body -Labels @("epic", "component-purview", "priority-critical", "roadmap") -Milestone $Milestone4.number

Write-Host "`n[COMPLETE] Issue creation completed!" -ForegroundColor Green
Write-Host "[INFO] Access your GitHub project to see all created issues." -ForegroundColor Cyan
Write-Host "[LINK] https://github.com/$Owner/$Repository/issues" -ForegroundColor Blue