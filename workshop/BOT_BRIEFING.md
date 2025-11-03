# Bot Task Assignment - Workshop Creation

## 🤖 Mission Brief

You are an AI bot tasked with creating comprehensive workshop materials for Microsoft Fabric SAP IDoc integration. All workshop content will be created in the `/workshop` directory.

## 📋 Your Tasks

View all your tasks here: https://github.com/flthibau/Fabric-SAP-Idocs/issues?q=is:issue+label:workshop+label:bot-task

### Priority Order

1. **Start Here**: Issue #22 (labeled `good-first-issue-bot`)
   - Create main workshop README
   - This establishes the foundation
   
2. **Next**: Issue #16 (Module 1 - Architecture)
   - Architecture documentation with Mermaid diagrams
   
3. **Then**: Issues #17-21 (Modules 2-6)
   - Event Hub, KQL, Lakehouse, Security, APIs

## 🔧 Working Instructions

### Branch Strategy
- **Your working branch**: `workshop/bot-development`
- **NEVER commit to**: `main` (protected)
- **Create feature branches from**: `workshop/bot-development`

Example workflow:
```bash
git checkout workshop/bot-development
git pull origin workshop/bot-development
git checkout -b workshop/task-22-readme
# ... do your work ...
git add .
git commit -m "Workshop: Create main README and setup guide"
git push -u origin workshop/task-22-readme
# ... create PR targeting workshop/bot-development ...
```

### Label Workflow

When you start a task:
1. Add label `bot-in-progress` to the issue
2. Create your feature branch
3. Do the work

When you finish:
1. Create PR targeting `workshop/bot-development`
2. Add label `needs-human-review` to the PR
3. Remove label `bot-in-progress` from issue

### File Organization

All workshop files go in `/workshop`:

```
workshop/
├── README.md                          # Your first task!
├── setup/
│   ├── prerequisites.md
│   └── environment-setup.md
├── docs/
│   └── architecture.md
├── labs/
│   ├── module1-architecture.md
│   ├── module2-eventhub-setup.md
│   ├── module3-kql-queries.md
│   ├── module4-lakehouse-layers.md
│   ├── module5-security-rls.md
│   └── module6-api-development.md
├── samples/
│   ├── sample-idoc.json
│   └── graphql-queries.graphql
├── scripts/
│   ├── test-eventhub-connection.ps1
│   └── configure-rls.ps1
├── notebooks/
│   ├── bronze-to-silver.ipynb
│   └── silver-to-gold.ipynb
├── queries/
│   └── kql-examples.kql
├── exercises/
│   └── kql-practice.md
├── diagrams/
│   └── architecture.mmd
├── postman/
│   └── api-collection.json
└── tests/
    └── test-rls-access.md
```

## 📚 Resources to Use

Each issue has a "Resources" section pointing to existing files. Read these FIRST:

- `/docs/architecture.md` - Current architecture
- `/fabric/README.md` - Fabric setup
- `/simulator/README.md` - Event Hub simulator
- `/fabric/README_KQL_QUERIES.md` - KQL examples
- `/fabric/lakehouse/` - Lakehouse code
- `/fabric/RLS_CONFIGURATION_GUIDE.md` - Security guide
- `/api/graphql/` - GraphQL API

## ✅ Quality Checklist

For each task, ensure:

- [ ] All acceptance criteria met
- [ ] All output files created
- [ ] Markdown properly formatted
- [ ] Code examples tested (if applicable)
- [ ] Links verified
- [ ] No hardcoded credentials
- [ ] Beginner-friendly explanations
- [ ] Visual diagrams included (when specified)

## 🎯 Content Guidelines

### Tone
- Beginner-friendly but professional
- Step-by-step explanations
- Clear learning objectives

### Code Examples
- Well-commented
- Working and tested
- Progressive difficulty

### Diagrams
- Use Mermaid format
- Clear labels
- Business context

## 🚫 Don't Do This

❌ Commit directly to `main`  
❌ Modify files outside `/workshop`  
❌ Include credentials or secrets  
❌ Skip acceptance criteria  
❌ Create files without context  

## 🎉 Success Metrics

After all tasks complete, we'll have:
- Complete workshop guide with 6 modules
- Hands-on labs for each component
- Sample code and configurations
- Troubleshooting guides
- Professional training materials

## 📞 Need Help?

If you get stuck:
1. Add comment to the issue
2. Add label `needs-human-review`
3. Human will provide guidance

## 🔗 Important Links

- **All Workshop Issues**: https://github.com/flthibau/Fabric-SAP-Idocs/issues?q=is:issue+label:workshop
- **Bot Tasks Only**: https://github.com/flthibau/Fabric-SAP-Idocs/issues?q=is:issue+label:bot-task
- **Your Branch**: https://github.com/flthibau/Fabric-SAP-Idocs/tree/workshop/bot-development
- **Workflow Guide**: See `.github/BOT_WORKFLOW_GUIDE.md`

## 🚀 Ready to Start?

1. Read the [Bot Workflow Guide](../.github/BOT_WORKFLOW_GUIDE.md)
2. Pick up Issue #22 (good-first-issue-bot)
3. Follow the acceptance criteria
4. Create amazing workshop content!

Good luck! 🎓
