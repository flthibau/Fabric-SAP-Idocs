# Script PowerShell pour créer automatiquement les issues de la roadmap
# Ce script utilise l'API GitHub pour créer les issues définies dans la roadmap

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$Repository,
    
    [string]$Owner = "flthibau"
)

# Configuration de base
$Headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "PowerShell-GitHub-Roadmap-Script"
}

$BaseUrl = "https://api.github.com/repos/$Owner/$Repository"

Write-Host "🚀 Création des issues pour la roadmap SAP IDoc Data Product" -ForegroundColor Green
Write-Host "Repository: $Owner/$Repository" -ForegroundColor Cyan

# Fonction pour créer une issue
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
        Write-Host "✅ Issue créée: #$($Response.number) - $Title" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "❌ Erreur lors de la création de l'issue: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Fonction pour créer un milestone
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
        Write-Host "📅 Milestone créé: $Title" -ForegroundColor Green
        return $Response
    }
    catch {
        Write-Host "❌ Erreur lors de la création du milestone: $Title" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Création des milestones
Write-Host "`n📅 Création des milestones..." -ForegroundColor Yellow

$Milestone1 = New-GitHubMilestone -Title "Phase 1: Sécurité et Gouvernance" -Description "Amélioration RLS et documentation modèle de données" -DueDate "2025-01-31T23:59:59Z"
$Milestone2 = New-GitHubMilestone -Title "Phase 2: APIs et Accès aux Données" -Description "APIs REST complètes et intégration Purview" -DueDate "2025-04-30T23:59:59Z"
$Milestone3 = New-GitHubMilestone -Title "Phase 3: Intelligence Opérationnelle" -Description "Agent RTI et cas d'usage métier" -DueDate "2025-07-31T23:59:59Z"
$Milestone4 = New-GitHubMilestone -Title "Phase 4: Contrats de Données" -Description "Gouvernance avancée et contrats dans Purview" -DueDate "2025-10-31T23:59:59Z"

# Définition des Epics et Issues
Write-Host "`n📋 Création des Epics et Issues..." -ForegroundColor Yellow

# Epic 1: Amélioration du Row-Level Security (RLS)
$Epic1Body = @"
## 🎯 Vue d'ensemble de l'Epic

Améliorer l'implémentation du Row-Level Security (RLS) dans OneLake pour offrir une sécurité granulaire et multi-niveaux pour les données SAP IDoc.

### Phase de la Roadmap
- **Phase**: Phase 1 - Sécurité et Gouvernance
- **Priorité**: Critique

## 📊 Valeur Métier

### Problème à Résoudre
L'implémentation actuelle du RLS nécessite des améliorations pour supporter des scénarios de sécurité plus complexes et des performances optimisées.

### Valeur Apportée
- Sécurité renforcée pour les données sensibles
- Performance améliorée des requêtes filtrées
- Support de scenarios multi-tenants avancés

### Métriques de Succès
- 100% des accès filtrés correctement
- < 10ms overhead de performance
- 0 faille de sécurité identifiée

## 🛠️ Scope Technique

### Composants Impactés
- [x] OneLake Security
- [x] Fabric Warehouse
- [x] GraphQL API
- [x] Documentation sécurité

## 📋 Issues Associées
- Issue #1 - Audit configuration RLS actuelle
- Issue #2 - Design nouveaux modèles sécurité  
- Issue #3 - Implémentation RLS multi-niveaux
- Issue #4 - Tests sécurité et validation
"@

New-GitHubIssue -Title "[EPIC] Amélioration du Row-Level Security (RLS)" -Body $Epic1Body -Labels @("epic", "component-security", "priority-critical") -Milestone $Milestone1.number

# Issues de l'Epic 1
$Issues = @(
    @{
        Title = "Audit de la configuration RLS actuelle"
        Body = "Analyser l'implémentation actuelle du RLS dans OneLake et identifier les points d'amélioration."
        Labels = @("technical-task", "component-security", "effort-m")
    },
    @{
        Title = "Design des nouveaux modèles de sécurité"
        Body = "Concevoir les nouveaux modèles de sécurité RLS pour supporter les cas d'usage avancés."
        Labels = @("technical-task", "component-security", "effort-l")
    },
    @{
        Title = "Implémentation RLS multi-niveaux"
        Body = "Implémenter la nouvelle configuration RLS avec support multi-niveaux dans OneLake."
        Labels = @("technical-task", "component-security", "effort-xl")
    },
    @{
        Title = "Tests de sécurité et validation"
        Body = "Créer et exécuter une suite complète de tests de sécurité pour valider l'implémentation RLS."
        Labels = @("technical-task", "component-security", "effort-l")
    }
)

foreach ($Issue in $Issues) {
    New-GitHubIssue -Title $Issue.Title -Body $Issue.Body -Labels $Issue.Labels -Milestone $Milestone1.number
}

# Epic 2: Documentation du Modèle de Données
$Epic2Body = @"
## 🎯 Vue d'ensemble de l'Epic

Créer une documentation complète et professionnelle du modèle de données SAP IDoc pour faciliter la compréhension et l'utilisation du data product.

### Phase de la Roadmap
- **Phase**: Phase 1 - Sécurité et Gouvernance
- **Priorité**: Élevée

## 📊 Valeur Métier

### Problème à Résoudre
Le modèle de données actuel manque de documentation claire et structurée, rendant difficile l'onboarding et l'utilisation par les partenaires.

### Valeur Apportée
- Amélioration de l'expérience développeur
- Réduction du temps d'intégration
- Meilleure gouvernance des données

### Métriques de Succès
- Documentation complète à 100%
- Temps d'onboarding réduit de 50%
- 0 question récurrente sur le modèle

## 🛠️ Scope Technique

### Composants Impactés
- [x] Documentation technique
- [x] Schémas de données
- [x] Diagrammes ERD
- [x] Glossaire métier
"@

New-GitHubIssue -Title "[EPIC] Documentation du Modèle de Données" -Body $Epic2Body -Labels @("epic", "documentation", "priority-high") -Milestone $Milestone1.number

# Issues de l'Epic 2
$Issues2 = @(
    @{
        Title = "Cartographie des entités de données existantes"
        Body = "Identifier et cataloguer toutes les entités de données présentes dans le système."
        Labels = @("documentation", "effort-m")
    },
    @{
        Title = "Documentation du schéma de données business"
        Body = "Créer la documentation détaillée des schémas de données avec définitions métier."
        Labels = @("documentation", "effort-l")
    },
    @{
        Title = "Diagrammes ERD et relations"
        Body = "Concevoir les diagrammes Entity-Relationship et documenter les relations entre entités."
        Labels = @("documentation", "effort-m")
    },
    @{
        Title = "Glossaire métier et définitions"
        Body = "Créer un glossaire complet des termes métier et définitions techniques."
        Labels = @("documentation", "effort-s")
    }
)

foreach ($Issue in $Issues2) {
    New-GitHubIssue -Title $Issue.Title -Body $Issue.Body -Labels $Issue.Labels -Milestone $Milestone1.number
}

# Epic 3: APIs REST Complètes
$Epic3Body = @"
## 🎯 Vue d'ensemble de l'Epic

Développer des APIs REST complètes avec opérations CRUD pour offrir un accès moderne et standardisé aux données SAP IDoc.

### Phase de la Roadmap
- **Phase**: Phase 2 - APIs et Accès aux Données
- **Priorité**: Critique

## 📊 Valeur Métier

### Problème à Résoudre
L'accès aux données est actuellement limité à GraphQL. Les partenaires demandent des APIs REST standards pour faciliter l'intégration.

### Valeur Apportée
- Accès standardisé via REST
- Support CRUD complet
- Intégration facilitée pour les partenaires

### Métriques de Succès
- APIs REST fonctionnelles 100%
- < 100ms latence moyenne
- Documentation OpenAPI complète
"@

New-GitHubIssue -Title "[EPIC] APIs REST Complètes" -Body $Epic3Body -Labels @("epic", "component-api", "priority-critical") -Milestone $Milestone2.number

# Epic 4: Matérialisation de l'Accès API dans Purview
$Epic4Body = @"
## 🎯 Vue d'ensemble de l'Epic

Intégrer et référencer toutes les APIs (GraphQL et REST) dans Microsoft Purview pour une gouvernance centralisée.

### Phase de la Roadmap
- **Phase**: Phase 2 - APIs et Accès aux Données
- **Priorité**: Élevée

## 📊 Valeur Métier

### Problème à Résoudre
Les APIs ne sont pas référencées dans le catalogue de données, limitant la découvrabilité et la gouvernance.

### Valeur Apportée
- Catalogue unifié des APIs
- Métadonnées d'accès centralisées
- Monitoring et gouvernance améliorés
"@

New-GitHubIssue -Title "[EPIC] Matérialisation de l'Accès API dans Purview" -Body $Epic4Body -Labels @("epic", "component-purview", "priority-high") -Milestone $Milestone2.number

# Epic 5: Agent Opérationnel RTI
$Epic5Body = @"
## 🎯 Vue d'ensemble de l'Epic

Développer un agent RTI (Real-Time Intelligence) pour automatiser les cas d'usage métier et l'analyse opérationnelle.

### Phase de la Roadmap
- **Phase**: Phase 3 - Intelligence Opérationnelle
- **Priorité**: Élevée

## 📊 Valeur Métier

### Problème à Résoudre
Les analyses opérationnelles sont majoritairement manuelles, limitant la réactivité et l'efficacité.

### Valeur Apportée
- Automatisation des analyses
- Détection proactive d'anomalies
- Insights temps réel pour les opérations
"@

New-GitHubIssue -Title "[EPIC] Agent Opérationnel RTI" -Body $Epic5Body -Labels @("epic", "component-fabric", "priority-high") -Milestone $Milestone3.number

# Epic 6: Data Contracts dans Purview
$Epic6Body = @"
## 🎯 Vue d'ensemble de l'Epic

Implémenter des contrats de données formalisés dans Microsoft Purview pour garantir la qualité et la conformité.

### Phase de la Roadmap
- **Phase**: Phase 4 - Contrats de Données et Gouvernance Avancée
- **Priorité**: Critique

## 📊 Valeur Métier

### Problème à Résoudre
Absence de contrats formalisés pour garantir la qualité et la conformité des données.

### Valeur Apportée
- Qualité des données garantie
- Conformité automatisée
- SLA de données formalisés
"@

New-GitHubIssue -Title "[EPIC] Data Contracts dans Purview" -Body $Epic6Body -Labels @("epic", "component-purview", "priority-critical") -Milestone $Milestone4.number

Write-Host "`n🎉 Création des issues terminée!" -ForegroundColor Green
Write-Host "📊 Accédez à votre projet GitHub pour voir toutes les issues créées." -ForegroundColor Cyan
Write-Host "🔗 https://github.com/$Owner/$Repository/issues" -ForegroundColor Blue