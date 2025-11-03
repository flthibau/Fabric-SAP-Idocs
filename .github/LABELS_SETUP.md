# GitHub Labels Configuration

This file contains all the labels to create in your GitHub repository.
You can create them manually or use the GitHub CLI.

## Using GitHub CLI (gh)

```bash
# Install GitHub CLI first: https://cli.github.com/

# Priority Labels
gh label create "priority-critical" --color "d73a4a" --description "Critical priority - blocking issues"
gh label create "priority-high" --color "ff9800" --description "High priority - important features"
gh label create "priority-medium" --color "fbca04" --description "Medium priority - standard features"
gh label create "priority-low" --color "0e8a16" --description "Low priority - nice to have"

# Type Labels
gh label create "epic" --color "3f51b5" --description "Epic grouping multiple issues"
gh label create "technical-task" --color "1d76db" --description "Technical implementation task"
gh label create "documentation" --color "0075ca" --description "Documentation work"
gh label create "enhancement" --color "a2eeef" --description "New feature or enhancement"
gh label create "bug" --color "d73a4a" --description "Bug fix"

# Component Labels
gh label create "component-fabric" --color "7057ff" --description "Microsoft Fabric related"
gh label create "component-api" --color "008672" --description "APIs (REST/GraphQL)"
gh label create "component-purview" --color "1d76db" --description "Microsoft Purview"
gh label create "component-security" --color "d93f0b" --description "Security and RLS"
gh label create "component-infrastructure" --color "0052cc" --description "Infrastructure as Code"
gh label create "component-governance" --color "5319e7" --description "Data governance"

# Effort Labels
gh label create "effort-xs" --color "c2e0c6" --description "Less than 1 day"
gh label create "effort-s" --color "bfdadc" --description "1-2 days"
gh label create "effort-m" --color "fef2c0" --description "3-5 days"
gh label create "effort-l" --color "fad8c7" --description "1-2 weeks"
gh label create "effort-xl" --color "f9d0c4" --description "More than 2 weeks"

# Status Labels
gh label create "status-blocked" --color "d73a4a" --description "Blocked by dependencies"
gh label create "status-needs-review" --color "fbca04" --description "Needs review or approval"
gh label create "status-debugging" --color "ff9800" --description "Currently debugging"
gh label create "status-testing" --color "1d76db" --description "In testing phase"

# Roadmap Label
gh label create "roadmap" --color "0e8a16" --description "Part of the roadmap"
```

## Manual Creation via GitHub UI

Go to: `https://github.com/flthibau/Fabric-SAP-Idocs/labels`

Then create each label with the following details:

### Priority Labels

| Name | Color | Description |
|------|-------|-------------|
| priority-critical | `#d73a4a` (Red) | Critical priority - blocking issues |
| priority-high | `#ff9800` (Orange) | High priority - important features |
| priority-medium | `#fbca04` (Yellow) | Medium priority - standard features |
| priority-low | `#0e8a16` (Green) | Low priority - nice to have |

### Type Labels

| Name | Color | Description |
|------|-------|-------------|
| epic | `#3f51b5` (Deep Purple) | Epic grouping multiple issues |
| technical-task | `#1d76db` (Blue) | Technical implementation task |
| documentation | `#0075ca` (Light Blue) | Documentation work |
| enhancement | `#a2eeef` (Cyan) | New feature or enhancement |
| bug | `#d73a4a` (Red) | Bug fix |

### Component Labels

| Name | Color | Description |
|------|-------|-------------|
| component-fabric | `#7057ff` (Purple) | Microsoft Fabric related |
| component-api | `#008672` (Teal) | APIs (REST/GraphQL) |
| component-purview | `#1d76db` (Blue) | Microsoft Purview |
| component-security | `#d93f0b` (Dark Orange) | Security and RLS |
| component-infrastructure | `#0052cc` (Dark Blue) | Infrastructure as Code |
| component-governance | `#5319e7` (Violet) | Data governance |

### Effort Labels

| Name | Color | Description |
|------|-------|-------------|
| effort-xs | `#c2e0c6` (Light Green) | Less than 1 day |
| effort-s | `#bfdadc` (Light Blue) | 1-2 days |
| effort-m | `#fef2c0` (Light Yellow) | 3-5 days |
| effort-l | `#fad8c7` (Light Orange) | 1-2 weeks |
| effort-xl | `#f9d0c4` (Light Red) | More than 2 weeks |

### Status Labels

| Name | Color | Description |
|------|-------|-------------|
| status-blocked | `#d73a4a` (Red) | Blocked by dependencies |
| status-needs-review | `#fbca04` (Yellow) | Needs review or approval |
| status-debugging | `#ff9800` (Orange) | Currently debugging |
| status-testing | `#1d76db` (Blue) | In testing phase |

### Special Labels

| Name | Color | Description |
|------|-------|-------------|
| roadmap | `#0e8a16` (Green) | Part of the roadmap |

## Notes

- If you have existing labels that conflict, you may need to rename or delete them first
- The GitHub CLI method is faster if you have many labels to create
- Colors are specified in hex format (#RRGGBB)
