# 📊 Configuration GitHub Projects - SAP IDoc Data Product

Ce document décrit la configuration des GitHub Projects pour organiser et suivre la roadmap du projet.

## 🎯 Structure des Projects

### Project Principal: "SAP IDoc Data Product Roadmap"

**Vue d'ensemble du projet** avec 4 boards principaux :

#### 1. 📋 Kanban Board Principal
- **Backlog** : Issues nouvelles et non assignées
- **Todo** : Issues prêtes à démarrer
- **In Progress** : Travail en cours
- **Review** : En cours de révision
- **Done** : Terminé

#### 2. 📅 Vue Timeline par Phases
- **Phase 1** : Sécurité et Gouvernance (Q4 2024 - Q1 2025)
- **Phase 2** : APIs et Accès aux Données (Q1 2025 - Q2 2025)
- **Phase 3** : Intelligence Opérationnelle (Q2 2025 - Q3 2025)
- **Phase 4** : Contrats de Données (Q3 2025 - Q4 2025)

#### 3. 🏷️ Vue par Epics
Groupement par Epic pour voir la progression globale

#### 4. 📈 Vue Métriques
Dashboard de suivi avec :
- Burn-down charts
- Vélocité par sprint
- Distribution par type d'issue

## 🏷️ Labels Standards

### Types d'Issues
- `epic` : Epic regroupant plusieurs issues
- `technical-task` : Tâche technique
- `documentation` : Tâche de documentation
- `bug` : Correction de bug
- `enhancement` : Amélioration

### Priorité
- `priority-critical` : Critique
- `priority-high` : Élevée
- `priority-medium` : Moyenne
- `priority-low` : Faible

### Composants
- `component-fabric` : Microsoft Fabric
- `component-api` : APIs (REST/GraphQL)
- `component-purview` : Microsoft Purview
- `component-security` : Sécurité (RLS)
- `component-infrastructure` : Infrastructure
- `component-governance` : Gouvernance

### Effort
- `effort-xs` : < 1 jour
- `effort-s` : 1-2 jours
- `effort-m` : 3-5 jours
- `effort-l` : 1-2 semaines
- `effort-xl` : > 2 semaines

## 📅 Milestones

### Phase 1: Sécurité et Gouvernance
- **Date**: 31 janvier 2025
- **Description**: Amélioration RLS et documentation modèle de données
- **Issues**: #1-8

### Phase 2: APIs et Accès aux Données
- **Date**: 30 avril 2025
- **Description**: APIs REST complètes et intégration Purview
- **Issues**: #9-16

### Phase 3: Intelligence Opérationnelle
- **Date**: 31 juillet 2025
- **Description**: Agent RTI et cas d'usage métier
- **Issues**: #17-20

### Phase 4: Contrats de Données
- **Date**: 31 octobre 2025
- **Description**: Gouvernance avancée et contrats dans Purview
- **Issues**: #21-24

## 🔄 Workflow GitHub Actions

### Automation des Projects

```yaml
# .github/workflows/project-automation.yml
name: Project Automation

on:
  issues:
    types: [opened, closed, labeled]
  pull_request:
    types: [opened, closed, merged]

jobs:
  update_project:
    runs-on: ubuntu-latest
    steps:
      - name: Update Project Board
        uses: actions/add-to-project@v0.4.0
        with:
          project-url: https://github.com/users/flthibau/projects/1
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Auto-Assignment des Labels

```yaml
# .github/workflows/label-automation.yml
name: Label Automation

on:
  issues:
    types: [opened]

jobs:
  auto_label:
    runs-on: ubuntu-latest
    steps:
      - name: Auto-assign labels
        uses: github/issue-labeler@v3.0
        with:
          repo-token: "${{ secrets.GITHUB_TOKEN }}"
          configuration-path: .github/labeler.yml
```

## 📊 Templates de Reporting

### Rapport Hebdomadaire

```markdown
# Rapport Hebdomadaire - Semaine du [DATE]

## 📈 Progression Globale
- **Issues fermées**: X / Y total
- **Epics complétés**: X / Y total
- **Phase actuelle**: Phase X

## 🎯 Cette Semaine
### Terminé ✅
- [ ] Issue #X - Description
- [ ] Issue #Y - Description

### En Cours 🔄
- [ ] Issue #X - Description (XX% complété)
- [ ] Issue #Y - Description (XX% complété)

### Blocages 🚫
- Issue #X : Description du blocage
- Issue #Y : Description du blocage

## 📅 Semaine Prochaine
### Priorités
1. Issue #X - Description
2. Issue #Y - Description

### Risques
- Risque 1 : Description et mitigation
- Risque 2 : Description et mitigation
```

### Dashboard KPIs

```markdown
# KPIs Dashboard - [MOIS ANNÉE]

## 📊 Métriques Générales
| Métrique | Valeur | Tendance |
|----------|---------|----------|
| Issues ouvertes | X | ↗️ ↘️ → |
| Issues fermées ce mois | X | ↗️ ↘️ → |
| Vélocité moyenne | X points/semaine | ↗️ ↘️ → |
| Time to close | X jours | ↗️ ↘️ → |

## 🎯 Progression par Epic
| Epic | Issues | Complété | Statut |
|------|--------|----------|---------|
| Epic 1 - RLS | 4 | 75% | 🟡 En cours |
| Epic 2 - Modèle | 4 | 50% | 🟡 En cours |
| Epic 3 - APIs | 4 | 0% | ⚪ Planifié |

## 📈 Qualité du Code
- **Code Coverage**: XX%
- **Tests passants**: XX%
- **Lint Errors**: X
- **Security Issues**: X
```

## 🛠️ Configuration des Intégrations

### Azure DevOps (Optionnel)
Si intégration avec Azure DevOps souhaitée :

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
    - develop

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: GitHubComment@0
  displayName: 'Update GitHub Issues'
  inputs:
    gitHubConnection: 'GitHub'
    repositoryName: '$(Build.Repository.Name)'
    comment: 'Build completed: $(Build.BuildId)'
```

### Microsoft Teams Notifications

```yaml
# .github/workflows/teams-notification.yml
name: Teams Notification

on:
  issues:
    types: [opened, closed]
  milestone:
    types: [closed]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Teams Notification
        uses: aliencube/microsoft-teams-actions@v0.8.0
        with:
          webhook_uri: ${{ secrets.TEAMS_WEBHOOK }}
          title: 'GitHub Update'
          summary: 'Issue #${{ github.event.issue.number }} ${{ github.event.action }}'
```

## 📋 Checklist de Setup

### Initial Setup
- [ ] Créer le GitHub Project "SAP IDoc Data Product Roadmap"
- [ ] Configurer les 4 vues (Kanban, Timeline, Epics, Métriques)
- [ ] Créer tous les labels standards
- [ ] Définir les 4 milestones
- [ ] Ajouter les templates d'issues

### Configuration Avancée
- [ ] Setup GitHub Actions pour automation
- [ ] Configurer les notifications Teams (optionnel)
- [ ] Créer les templates de reporting
- [ ] Former l'équipe sur l'utilisation des Projects

### Maintenance Continue
- [ ] Review hebdomadaire des métriques
- [ ] Mise à jour mensuelle des milestones
- [ ] Nettoyage trimestriel des labels
- [ ] Révision annuelle de la structure

---

**Responsable Configuration**: Florent Thibault  
**Dernière Mise à Jour**: 3 novembre 2024