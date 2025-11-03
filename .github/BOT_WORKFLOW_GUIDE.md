# Bot Workflow Guide

## Overview

This guide explains how to set up and work with an AI bot (like GitHub Copilot Workspace or similar) on this repository.

## Branch Strategy for Bot Collaboration

### Main Branch Protection
- **main** branch: Protected, human-reviewed code only
- All bot work happens on feature branches
- PRs required for merging to main

### Bot Working Branch
Create a dedicated branch for the bot to work on:

```bash
git checkout -b workshop/bot-development
git push -u origin workshop/bot-development
```

### Branch Naming Convention
- **workshop/bot-development** - Main bot working branch
- **workshop/module-1-architecture** - Specific module branches
- **workshop/fix-***** - Bot fixes
- **bot/task-***** - Individual task branches

## Labels for Bot Tasks

### Bot-Specific Labels
- `bot-task` - Tasks suitable for AI automation
- `good-first-issue-bot` - Best starting point for bot
- `bot-in-progress` - Currently being worked on by bot
- `needs-human-review` - Requires human validation after bot completion

### Workflow Labels
- `workshop` - Workshop-related tasks
- `documentation` - Documentation creation
- `effort-s/m/l/xl` - Task size estimation

## Bot Workflow

### 1. Task Assignment
```bash
# Bot should work on issues labeled with:
# - bot-task
# - good-first-issue-bot (for first task)
# - workshop
```

### 2. Bot Process
1. **Pick an issue** with `bot-task` label
2. **Add label** `bot-in-progress` to the issue
3. **Create branch** from `workshop/bot-development`
4. **Work on task** following acceptance criteria
5. **Create PR** targeting `workshop/bot-development` (NOT main)
6. **Add label** `needs-human-review` to PR
7. **Remove label** `bot-in-progress` after PR creation

### 3. Human Review Process
1. Review PR for quality and accuracy
2. Test generated content
3. Request changes if needed
4. Merge to `workshop/bot-development`
5. Eventually merge to main when module complete

### 4. Branch Lifecycle

```
main (protected)
  └── workshop/bot-development (bot's main branch)
       ├── workshop/module-1-architecture (task branch)
       ├── workshop/module-2-eventhub (task branch)
       └── workshop/module-3-kql (task branch)
```

## Bot Instructions

### For GitHub Copilot Workspace or Similar Bots

#### Task Selection
```
1. Query: "Show me issues with labels: bot-task, workshop, -bot-in-progress"
2. Pick the issue labeled with "good-first-issue-bot" first
3. Read the full issue description
4. Check acceptance criteria
5. Review linked resources
```

#### Working on Task
```
1. Create branch from workshop/bot-development
2. Create all files listed in "Output Files" section
3. Follow all items in "Acceptance Criteria"
4. Use "Resources" section to understand context
5. Follow "Bot Instructions" for specific guidance
```

#### Quality Checklist
- [ ] All acceptance criteria met
- [ ] All output files created
- [ ] Code examples tested (if applicable)
- [ ] Markdown properly formatted
- [ ] Links verified
- [ ] No hardcoded credentials
- [ ] Files in correct directories

#### Pull Request Creation
```
Title: Workshop Module X: [Brief Description]
Body:
- Closes #[issue-number]
- Summary of changes
- List of files created
- Any notes for reviewer

Labels: needs-human-review, workshop
Base branch: workshop/bot-development
```

## Directory Structure

All workshop content goes in `/workshop` directory:

```
workshop/
├── README.md                          # Main workshop guide
├── setup/
│   ├── prerequisites.md               # Setup requirements
│   └── environment-setup.md           # Environment configuration
├── docs/
│   └── architecture.md                # Architecture overview
├── labs/
│   ├── module1-architecture.md        # Lab guides
│   ├── module2-eventhub-setup.md
│   ├── module3-kql-queries.md
│   ├── module4-lakehouse-layers.md
│   ├── module5-security-rls.md
│   └── module6-api-development.md
├── samples/
│   ├── sample-idoc.json               # Sample data
│   └── graphql-queries.graphql
├── scripts/
│   ├── test-eventhub-connection.ps1   # Testing scripts
│   └── configure-rls.ps1
├── notebooks/
│   ├── bronze-to-silver.ipynb         # Jupyter notebooks
│   └── silver-to-gold.ipynb
├── queries/
│   └── kql-examples.kql               # KQL queries
├── exercises/
│   └── kql-practice.md                # Practice exercises
├── diagrams/
│   └── architecture.mmd               # Mermaid diagrams
├── postman/
│   └── api-collection.json            # Postman collections
└── tests/
    └── test-rls-access.md             # Test scenarios
```

## Best Practices for Bot

### DO
✅ Follow acceptance criteria exactly
✅ Use existing code as reference
✅ Create beginner-friendly content
✅ Include code examples and explanations
✅ Add visual diagrams when helpful
✅ Provide validation steps
✅ Include troubleshooting sections

### DON'T
❌ Commit directly to main
❌ Include hardcoded credentials
❌ Skip acceptance criteria items
❌ Create files outside /workshop directory
❌ Modify existing production code
❌ Remove or change existing functionality

## Human Review Guidelines

### What to Check
1. **Accuracy**: Content is technically correct
2. **Completeness**: All acceptance criteria met
3. **Clarity**: Explanations are clear for beginners
4. **Examples**: Code examples work and are well-commented
5. **Formatting**: Markdown properly formatted
6. **Links**: All links work correctly
7. **Structure**: Files in correct directories

### Approval Process
- Review PR description
- Check all files created
- Test code examples (if any)
- Verify acceptance criteria
- Request changes or approve
- Merge to `workshop/bot-development`

## Merging to Main

When a complete module is ready:

```bash
# Review all content in workshop/bot-development
git checkout workshop/bot-development
git pull origin workshop/bot-development

# Create PR to main
# Title: "Workshop: Complete Module X"
# Full review by human
# Merge after approval
```

## Bot Configuration Example

For GitHub Copilot Workspace:

```yaml
workspace_config:
  base_branch: workshop/bot-development
  issue_labels: [bot-task, workshop]
  auto_assign: true
  pr_labels: [needs-human-review, workshop]
  file_scope: [workshop/**]
```

## FAQ

### Q: Can the bot modify existing code outside /workshop?
**A:** No, bot should only work in /workshop directory for safety.

### Q: Should bot create PRs to main or workshop/bot-development?
**A:** Always to `workshop/bot-development` for human review first.

### Q: What if bot gets stuck?
**A:** Add `needs-human-review` label and human will provide guidance in comments.

### Q: How to prioritize tasks?
**A:** Use `good-first-issue-bot` first, then by issue number order.

### Q: Can bot close issues?
**A:** No, humans close issues after merging and validation.

## Resources

- [Workshop Epic](https://github.com/flthibau/Fabric-SAP-Idocs/labels/workshop)
- [Bot Tasks](https://github.com/flthibau/Fabric-SAP-Idocs/labels/bot-task)
- [Good First Issues](https://github.com/flthibau/Fabric-SAP-Idocs/labels/good-first-issue-bot)

## Support

For questions about bot workflow:
- Review this guide
- Check issue comments
- Ask in PR reviews
