# Script to create workshop Epic, issues, labels and branch for bot collaboration
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

Write-Host "[SETUP] Creating Workshop Epic and Bot Infrastructure`n" -ForegroundColor Green

function New-GitHubIssue {
    param(
        [string]$Title,
        [string]$Body,
        [string[]]$Labels,
        [int]$Milestone
    )
    
    $IssueData = @{
        title = $Title
        body = $Body
        labels = $Labels
    }
    
    if ($Milestone -gt 0) {
        $IssueData.milestone = $Milestone
    }
    
    try {
        $Response = Invoke-RestMethod -Uri "$BaseUrl/issues" -Method Post -Headers $Headers -Body ($IssueData | ConvertTo-Json -Depth 3)
        Write-Host "[OK] Issue created: #$($Response.number) - $Title" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "[ERROR] Error creating issue: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

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
        Write-Host "[OK] Created label: $Name" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 422) {
            Write-Host "[INFO] Label already exists: $Name" -ForegroundColor Yellow
        }
        else {
            Write-Host "[ERROR] Error creating $Name : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Create bot-specific labels
Write-Host "`n[STEP 1] Creating bot-specific labels..." -ForegroundColor Cyan
New-GitHubLabel -Name "bot-task" -Color "7057ff" -Description "Task suitable for AI bot automation"
New-GitHubLabel -Name "workshop" -Color "0e8a16" -Description "Workshop and training material"
New-GitHubLabel -Name "good-first-issue-bot" -Color "7057ff" -Description "Good task for bot to start with"
New-GitHubLabel -Name "bot-in-progress" -Color "fbca04" -Description "Currently being worked on by bot"
New-GitHubLabel -Name "needs-human-review" -Color "d73a4a" -Description "Requires human validation"

# Create Workshop Epic
Write-Host "`n[STEP 2] Creating Workshop Epic..." -ForegroundColor Cyan

$WorkshopEpicBody = "## Epic Overview

Create comprehensive workshop materials for upskilling on Microsoft Fabric, SAP IDoc integration, and modern data product patterns.

### Objectives
* Enable developers to understand the architecture
* Provide hands-on exercises for each component
* Create reusable training materials
* Document best practices and patterns

### Target Audience
* Data Engineers learning Microsoft Fabric
* Developers integrating SAP with cloud platforms
* Teams implementing data products

### Success Metrics
* Complete workshop guide with 5+ modules
* Hands-on labs for each major component
* Sample code and configurations
* Troubleshooting guides

## Bot Collaboration
This Epic is designed for AI bot collaboration. Each task includes:
* Clear acceptance criteria
* Step-by-step requirements
* Expected outputs
* Validation guidelines

## Workshop Modules

### Module 1: Architecture Overview
Understanding the SAP IDoc to Fabric data flow

### Module 2: Event Hub Integration
Setting up and configuring Azure Event Hub for IDoc ingestion

### Module 3: Real-Time Intelligence
Working with Eventhouse and KQL queries

### Module 4: Data Lakehouse
Building Bronze/Silver/Gold layers in OneLake

### Module 5: Security & Governance
Implementing RLS and data governance with Purview

### Module 6: API Development
Creating GraphQL and REST APIs for data access

### Module 7: Monitoring & Operations
Setting up monitoring and operational dashboards"

$WorkshopEpic = New-GitHubIssue -Title "[EPIC] Workshop - Upskilling Materials Creation" -Body $WorkshopEpicBody -Labels @("epic", "workshop", "bot-task", "priority-high") -Milestone 1

Start-Sleep -Seconds 1

# Create Workshop Tasks
Write-Host "`n[STEP 3] Creating Workshop tasks..." -ForegroundColor Cyan

# Task 1: Architecture Documentation
$Task1Body = "## Task Description
Create comprehensive architecture documentation for the workshop.

## Acceptance Criteria
* [ ] Create workshop/docs/architecture.md file
* [ ] Include high-level architecture diagram (mermaid format)
* [ ] Document data flow from SAP to Fabric
* [ ] Explain each component's role
* [ ] Add glossary of key terms

## Required Sections
1. System Overview
2. Component Architecture
3. Data Flow Diagram
4. Technology Stack
5. Integration Points

## Output Files
- workshop/docs/architecture.md
- workshop/diagrams/architecture.mmd (Mermaid diagram)

## Validation
- All sections complete
- Diagram renders correctly
- Clear explanations for beginners

## Resources
- See: /docs/architecture.md (existing)
- See: /fabric/README.md
- See: /infrastructure/README.md

## Bot Instructions
1. Read existing architecture documentation
2. Simplify for workshop audience
3. Create visual diagram using Mermaid
4. Focus on learning objectives
5. Add hands-on lab suggestions"

New-GitHubIssue -Title "Workshop Module 1: Create Architecture Overview Documentation" -Body $Task1Body -Labels @("documentation", "workshop", "bot-task", "good-first-issue-bot", "effort-l") -Milestone 1

Start-Sleep -Seconds 1

# Task 2: Event Hub Setup Guide
$Task2Body = "## Task Description
Create step-by-step guide for Event Hub setup and IDoc ingestion.

## Acceptance Criteria
* [ ] Create workshop/labs/module2-eventhub-setup.md
* [ ] Document Event Hub configuration steps
* [ ] Provide sample IDoc JSON schemas
* [ ] Include troubleshooting section
* [ ] Add validation tests

## Lab Sections
1. Prerequisites
2. Event Hub Creation
3. Connection String Configuration
4. Sending Test Messages
5. Monitoring and Validation
6. Common Issues and Solutions

## Output Files
- workshop/labs/module2-eventhub-setup.md
- workshop/samples/sample-idoc.json
- workshop/scripts/test-eventhub-connection.ps1

## Validation
- Step-by-step instructions are clear
- All commands tested and working
- Screenshots or code examples included

## Resources
- See: /simulator/README.md
- See: /infrastructure/deploy-eventhub.ps1
- See: /simulator/config/idoc_schemas/

## Bot Instructions
1. Extract Event Hub setup from existing scripts
2. Create beginner-friendly guide
3. Add explanatory comments
4. Include validation steps
5. Provide sample data"

New-GitHubIssue -Title "Workshop Module 2: Create Event Hub Integration Lab" -Body $Task2Body -Labels @("documentation", "workshop", "bot-task", "effort-xl") -Milestone 1

Start-Sleep -Seconds 1

# Task 3: KQL Query Guide
$Task3Body = "## Task Description
Create hands-on KQL query guide for Real-Time Intelligence.

## Acceptance Criteria
* [ ] Create workshop/labs/module3-kql-queries.md
* [ ] Provide 10+ example KQL queries
* [ ] Explain each query with business context
* [ ] Include practice exercises
* [ ] Add query optimization tips

## Query Categories
1. Basic Data Exploration
2. Time-Series Analysis
3. Aggregations and Grouping
4. Filtering and Joins
5. Performance Monitoring
6. Anomaly Detection

## Output Files
- workshop/labs/module3-kql-queries.md
- workshop/queries/kql-examples.kql
- workshop/exercises/kql-practice.md

## Validation
- All queries execute successfully
- Explanations are beginner-friendly
- Progressive difficulty level

## Resources
- See: /fabric/README_KQL_QUERIES.md
- See: /fabric/eventstream/

## Bot Instructions
1. Extract best KQL queries from existing files
2. Add business context to each query
3. Create progressive exercises
4. Include expected results
5. Add tips and best practices"

New-GitHubIssue -Title "Workshop Module 3: Create KQL Query Tutorial" -Body $Task3Body -Labels @("documentation", "workshop", "bot-task", "effort-l") -Milestone 1

Start-Sleep -Seconds 1

# Task 4: Lakehouse Guide
$Task4Body = "## Task Description
Create comprehensive guide for building Bronze/Silver/Gold lakehouse layers.

## Acceptance Criteria
* [ ] Create workshop/labs/module4-lakehouse-layers.md
* [ ] Document medallion architecture
* [ ] Provide sample transformation code
* [ ] Explain data quality patterns
* [ ] Include best practices

## Lab Sections
1. Medallion Architecture Concepts
2. Bronze Layer: Raw Data Ingestion
3. Silver Layer: Data Cleansing
4. Gold Layer: Business Views
5. Data Quality Checks
6. Performance Optimization

## Output Files
- workshop/labs/module4-lakehouse-layers.md
- workshop/notebooks/bronze-to-silver.ipynb (template)
- workshop/notebooks/silver-to-gold.ipynb (template)

## Validation
- Clear explanation of each layer
- Code examples are functional
- Best practices documented

## Resources
- See: /fabric/lakehouse/
- See: /fabric/data-engineering/

## Bot Instructions
1. Explain medallion architecture clearly
2. Extract transformation patterns
3. Create simple examples
4. Focus on learning objectives
5. Add visual diagrams"

New-GitHubIssue -Title "Workshop Module 4: Create Lakehouse Layers Guide" -Body $Task4Body -Labels @("documentation", "workshop", "bot-task", "effort-xl") -Milestone 1

Start-Sleep -Seconds 1

# Task 5: Security Lab
$Task5Body = "## Task Description
Create hands-on lab for implementing Row-Level Security (RLS).

## Acceptance Criteria
* [ ] Create workshop/labs/module5-security-rls.md
* [ ] Document OneLake Security setup
* [ ] Provide Service Principal configuration guide
* [ ] Include testing scenarios
* [ ] Add troubleshooting tips

## Lab Sections
1. OneLake Security Overview
2. Service Principal Setup
3. RLS Configuration
4. Testing Access Controls
5. Common Security Patterns
6. Debugging RLS Issues

## Output Files
- workshop/labs/module5-security-rls.md
- workshop/scripts/configure-rls.ps1
- workshop/tests/test-rls-access.md

## Validation
- Security concepts explained clearly
- All steps are reproducible
- Testing scenarios cover edge cases

## Resources
- See: /fabric/RLS_CONFIGURATION_GUIDE.md
- See: /docs/roadmap/RLS_ADVANCED_GUIDE.md

## Bot Instructions
1. Simplify RLS concepts for beginners
2. Create step-by-step guide
3. Add visual access control examples
4. Include common pitfalls
5. Provide validation methods"

New-GitHubIssue -Title "Workshop Module 5: Create Security & RLS Lab" -Body $Task5Body -Labels @("documentation", "workshop", "bot-task", "component-security", "effort-l") -Milestone 1

Start-Sleep -Seconds 1

# Task 6: API Development Guide
$Task6Body = "## Task Description
Create guide for developing and consuming GraphQL and REST APIs.

## Acceptance Criteria
* [ ] Create workshop/labs/module6-api-development.md
* [ ] Document GraphQL schema design
* [ ] Provide API testing examples
* [ ] Include authentication setup
* [ ] Add best practices

## Lab Sections
1. GraphQL Fundamentals
2. Schema Design Patterns
3. Query and Mutation Examples
4. Authentication and Authorization
5. API Testing with Postman
6. REST API Alternatives

## Output Files
- workshop/labs/module6-api-development.md
- workshop/samples/graphql-queries.graphql
- workshop/postman/api-collection.json

## Validation
- All API examples work
- Authentication flow is clear
- Testing instructions complete

## Resources
- See: /api/graphql/
- See: /demo-app/
- See: /api/GRAPHQL_QUERIES_REFERENCE.md

## Bot Instructions
1. Extract working GraphQL queries
2. Create beginner-friendly examples
3. Explain authentication clearly
4. Provide Postman collection
5. Add troubleshooting section"

New-GitHubIssue -Title "Workshop Module 6: Create API Development Guide" -Body $Task6Body -Labels @("documentation", "workshop", "bot-task", "component-api", "effort-xl") -Milestone 1

Start-Sleep -Seconds 1

# Task 7: Workshop README
$Task7Body = "## Task Description
Create main README for the workshop with setup instructions and module overview.

## Acceptance Criteria
* [ ] Create workshop/README.md
* [ ] List all prerequisites
* [ ] Provide setup instructions
* [ ] Link to all modules
* [ ] Include troubleshooting section

## Required Sections
1. Workshop Overview
2. Prerequisites and Setup
3. Module Index with Descriptions
4. Estimated Time per Module
5. Support and Resources
6. FAQ

## Output Files
- workshop/README.md
- workshop/setup/prerequisites.md
- workshop/setup/environment-setup.md

## Validation
- All links work
- Setup steps are complete
- Clear navigation to modules

## Bot Instructions
1. Create welcoming introduction
2. List all prerequisites clearly
3. Provide setup checklist
4. Link to all modules created
5. Add contact information"

New-GitHubIssue -Title "Workshop: Create Main README and Setup Guide" -Body $Task7Body -Labels @("documentation", "workshop", "bot-task", "good-first-issue-bot", "effort-m") -Milestone 1

Write-Host "`n[COMPLETE] Workshop infrastructure created!" -ForegroundColor Green
Write-Host "`n[SUMMARY]" -ForegroundColor Cyan
Write-Host "  - Created 1 Workshop Epic" -ForegroundColor White
Write-Host "  - Created 7 Workshop Tasks" -ForegroundColor White
Write-Host "  - Added bot-specific labels" -ForegroundColor White
Write-Host "`n[NEXT STEPS]" -ForegroundColor Cyan
Write-Host "  1. Create bot working branch: git checkout -b workshop/bot-development" -ForegroundColor White
Write-Host "  2. Configure bot with these issues" -ForegroundColor White
Write-Host "  3. Bot will work on workshop/ directory" -ForegroundColor White
Write-Host "  4. Review PRs from bot before merging to main" -ForegroundColor White
Write-Host "`n[LINK] https://github.com/$Owner/$Repository/issues?q=is:issue+label:workshop" -ForegroundColor Blue
