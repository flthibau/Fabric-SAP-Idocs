# Script PowerShell pour déployer l'API GraphQL via l'extension Microsoft Fabric VS Code
# Utilise les commandes de l'extension fabric.vscode-fabric

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiDefinitionFile = "fabric\.fabric\graphql-api-definition.json"
)

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOIEMENT API GRAPHQL VIA EXTENSION MICROSOFT FABRIC" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# Vérifier si l'extension Fabric est installée
Write-Host "Verification de l'extension Microsoft Fabric..." -ForegroundColor Yellow
$fabricExtension = code --list-extensions | Select-String "fabric.vscode-fabric"

if (-not $fabricExtension) {
    Write-Host "❌ Extension Microsoft Fabric non installee" -ForegroundColor Red
    Write-Host "`nPour installer l'extension:" -ForegroundColor Yellow
    Write-Host "  code --install-extension fabric.vscode-fabric`n" -ForegroundColor White
    exit 1
}
Write-Host "✓ Extension Microsoft Fabric detectee`n" -ForegroundColor Green

# Vérifier le fichier de définition
Write-Host "Verification du fichier de definition..." -ForegroundColor Yellow
if (-not (Test-Path $ApiDefinitionFile)) {
    Write-Host "❌ Fichier de definition introuvable: $ApiDefinitionFile" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Fichier de definition trouve: $ApiDefinitionFile`n" -ForegroundColor Green

# Lire la définition
$definition = Get-Content $ApiDefinitionFile -Raw | ConvertFrom-Json
Write-Host "API GraphQL a deployer:" -ForegroundColor Cyan
Write-Host "  Nom: $($definition.metadata.displayName)" -ForegroundColor White
Write-Host "  Type: $($definition.metadata.type)" -ForegroundColor White
Write-Host "  Tables: $($definition.config.tables.Count)`n" -ForegroundColor White

# Liste des tables
Write-Host "Tables exposees:" -ForegroundColor Cyan
foreach ($table in $definition.config.tables) {
    Write-Host "  • $($table.name)" -ForegroundColor Green
}
Write-Host ""

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  OPTIONS DE DEPLOIEMENT" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "L'extension Microsoft Fabric offre 2 methodes de deploiement:`n" -ForegroundColor Yellow

Write-Host "METHODE 1: Via l'interface VS Code (Recommande)" -ForegroundColor Cyan
Write-Host "  1. Ouvrir la vue Fabric (Ctrl+Shift+F ou icone Fabric dans la sidebar)" -ForegroundColor White
Write-Host "  2. Se connecter au workspace: $WorkspaceId" -ForegroundColor White
Write-Host "  3. Clic droit sur le workspace -> 'Create New Item'" -ForegroundColor White
Write-Host "  4. Selectionner 'GraphQL API'" -ForegroundColor White
Write-Host "  5. Configurer avec les parametres du fichier JSON`n" -ForegroundColor White

Write-Host "METHODE 2: Via Fabric CLI (Si disponible)" -ForegroundColor Cyan
Write-Host "  fabric item create --workspace $WorkspaceId --type GraphQLApi --definition $ApiDefinitionFile`n" -ForegroundColor White

Write-Host "METHODE 3: Via Git Integration (Pour CI/CD)" -ForegroundColor Cyan
Write-Host "  1. Activer Git integration sur le workspace Fabric" -ForegroundColor White
Write-Host "  2. Commiter le fichier .fabric/graphql-api-definition.json" -ForegroundColor White
Write-Host "  3. Push vers Azure DevOps / GitHub" -ForegroundColor White
Write-Host "  4. Fabric synchronise automatiquement`n" -ForegroundColor White

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION MANUELLE DANS FABRIC PORTAL" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Si les methodes automatiques ne fonctionnent pas, configuration manuelle:`n" -ForegroundColor Yellow

Write-Host "1. Ouvrir Fabric Portal:" -ForegroundColor Yellow
$fabricUrl = "https://msit.powerbi.com/groups/$WorkspaceId"
Write-Host "   $fabricUrl`n" -ForegroundColor White

Write-Host "2. Cliquer sur '+ New Item' -> 'GraphQL API'`n" -ForegroundColor Yellow

Write-Host "3. Configurer l'API:" -ForegroundColor Yellow
Write-Host "   Nom: 3PL Partner API" -ForegroundColor White
Write-Host "   Data Source: Lakehouse (lh_3pl_logistics_gold)" -ForegroundColor White
Write-Host "   Tables: idoc_orders_gold, idoc_shipments_gold, idoc_warehouse_gold, idoc_invoices_gold`n" -ForegroundColor White

Write-Host "4. Options:" -ForegroundColor Yellow
Write-Host "   ✓ Enable filtering" -ForegroundColor Green
Write-Host "   ✓ Enable sorting" -ForegroundColor Green
Write-Host "   ✓ Enable pagination (max 1000)" -ForegroundColor Green
Write-Host "   ✗ Enable mutations (read-only)`n" -ForegroundColor Red

Write-Host "5. Security:" -ForegroundColor Yellow
Write-Host "   ✓ Enable Row-Level Security" -ForegroundColor Green
Write-Host "   ✗ Allow anonymous access`n" -ForegroundColor Red

Write-Host "6. Copier l'endpoint GraphQL genere`n" -ForegroundColor Yellow

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION ROW-LEVEL SECURITY (RLS)" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Apres creation de l'API GraphQL, configurer RLS:`n" -ForegroundColor Yellow

Write-Host "1. Aller dans Lakehouse -> SQL Analytics Endpoint -> Security -> Manage Roles`n" -ForegroundColor Yellow

Write-Host "2. Creer 3 roles RLS:`n" -ForegroundColor Yellow

Write-Host "Role 1: CARRIER-FEDEX" -ForegroundColor Cyan
Write-Host "  Table: idoc_shipments_gold" -ForegroundColor White
Write-Host "  DAX Filter: [carrier_id] = ""CARRIER-FEDEX""`n" -ForegroundColor Gray

Write-Host "Role 2: WAREHOUSE-EAST" -ForegroundColor Cyan
Write-Host "  Table: idoc_warehouse_gold" -ForegroundColor White
Write-Host "  DAX Filter: [warehouse_partner_id] = ""WAREHOUSE-EAST""`n" -ForegroundColor Gray

Write-Host "Role 3: CUSTOMER-ACME" -ForegroundColor Cyan
Write-Host "  Tables: idoc_orders_gold, idoc_shipments_gold, idoc_invoices_gold" -ForegroundColor White
Write-Host "  DAX Filter: [partner_access_scope] = ""CUSTOMER-ACME""`n" -ForegroundColor Gray

Write-Host "3. Lier les roles aux Service Principals Azure AD`n" -ForegroundColor Yellow

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  TESTER L'API GRAPHQL" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Apres deploiement, tester avec cette requete:`n" -ForegroundColor Yellow

$testQuery = @"
POST https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/graphqlapis/<api-id>/graphql
Authorization: Bearer <token>
Content-Type: application/json

{
  "query": "{ idoc_shipments_gold(filter: { status: { eq: \"IN_TRANSIT\" } }, first: 5) { shipment_number carrier_id customer_name status } }"
}
"@

Write-Host $testQuery -ForegroundColor White
Write-Host "`n"

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  PROCHAINES ETAPES" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "1. ⏸️  Deployer l'API GraphQL (methode au choix ci-dessus)" -ForegroundColor Yellow
Write-Host "2. ⏸️  Configurer RLS sur les tables Gold" -ForegroundColor Yellow
Write-Host "3. ⏸️  Copier l'endpoint GraphQL genere" -ForegroundColor Yellow
Write-Host "4. ⏸️  Mettre a jour deploy-apim.ps1 avec l'endpoint reel" -ForegroundColor Yellow
Write-Host "5. ⏸️  Tester l'API avec Postman ou curl`n" -ForegroundColor Yellow

Write-Host "Voulez-vous ouvrir:" -ForegroundColor Cyan
Write-Host "  A) Fabric Portal pour creation manuelle" -ForegroundColor Yellow
Write-Host "  B) VS Code Fabric extension view`n" -ForegroundColor Yellow

$choice = Read-Host "Votre choix (A/B)"

if ($choice -eq "A") {
    Write-Host "`nOuverture de Fabric Portal..." -ForegroundColor Gray
    Start-Process $fabricUrl
} elseif ($choice -eq "B") {
    Write-Host "`nOuverture de VS Code Fabric extension..." -ForegroundColor Gray
    code --command workbench.view.extension.fabric
} else {
    Write-Host "`n✅ Script termine. Suivez les instructions ci-dessus.`n" -ForegroundColor Green
}
