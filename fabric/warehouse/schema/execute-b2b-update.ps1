# ===================================================================
# Script PowerShell - Mise à jour B2B des schémas Eventhouse
# ===================================================================
# Ce script guide l'exécution des mises à jour de schéma dans l'ordre

Write-Host ""
Write-Host "=========================================="  -ForegroundColor Cyan
Write-Host "  MISE À JOUR B2B - SCHÉMAS EVENTHOUSE"  -ForegroundColor Cyan
Write-Host "=========================================="  -ForegroundColor Cyan
Write-Host ""

# Définir le chemin de base
$basePath = "c:\Users\flthibau\Desktop\Fabric+SAP+Idocs"
$schemaPath = "$basePath\fabric\warehouse\schema"

# URLs Fabric Portal
$eventHouseUrl = "https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/f91aaea3-7889-4415-851c-f4258a2fff6b/query"
$lakehouseUrl = "https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/lakehouses/f48a3e6d-d9a5-44fa-b89b-4e8b0f0a5e3c"

Write-Host "📋 ORDRE D'EXÉCUTION:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1️⃣  Mettre à jour IDocSummary (Eventhouse)" -ForegroundColor White
Write-Host "  2️⃣  Mettre à jour tables Silver (Eventhouse)" -ForegroundColor White
Write-Host "  3️⃣  Mettre à jour vues Gold (Lakehouse)" -ForegroundColor White
Write-Host "  4️⃣  Régénérer les données IDoc" -ForegroundColor White
Write-Host ""

# ===================================================================
# ÉTAPE 1 : IDocSummary
# ===================================================================

Write-Host "=========================================="  -ForegroundColor Green
Write-Host "  ÉTAPE 1: Mise à jour IDocSummary"  -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""

$step1File = "$schemaPath\add-b2b-partner-columns.kql"

if (Test-Path $step1File) {
    Write-Host "✓ Fichier trouvé: add-b2b-partner-columns.kql" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "  1. Le fichier KQL va s'ouvrir dans VS Code" -ForegroundColor White
    Write-Host "  2. Copiez TOUT le contenu (Ctrl+A, Ctrl+C)" -ForegroundColor White
    Write-Host "  3. Ouvrez Fabric Eventhouse Portal (le lien va s'ouvrir)" -ForegroundColor White
    Write-Host "  4. Collez dans Query Editor et exécutez (F5)" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Appuyez sur [ENTRÉE] pour ouvrir le fichier et le portail"
    
    # Ouvrir le fichier dans VS Code
    code $step1File
    Start-Sleep -Seconds 2
    
    # Ouvrir Fabric Portal
    Start-Process $eventHouseUrl
    
    Write-Host ""
    Write-Host "⏳ En attente de l'exécution..." -ForegroundColor Yellow
    $completed = Read-Host "Tapez 'ok' quand l'exécution est terminée avec succès"
    
    if ($completed -eq "ok") {
        Write-Host "✓ Étape 1 terminée!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Réponse inattendue. Continuez quand même? (o/n)" -ForegroundColor Yellow
        $continue = Read-Host
        if ($continue -ne "o") {
            Write-Host "❌ Script interrompu." -ForegroundColor Red
            exit
        }
    }
} else {
    Write-Host "❌ Fichier non trouvé: $step1File" -ForegroundColor Red
    exit
}

Write-Host ""

# ===================================================================
# ÉTAPE 2 : Tables Silver
# ===================================================================

Write-Host "=========================================="  -ForegroundColor Green
Write-Host "  ÉTAPE 2: Mise à jour tables Silver"  -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""

$step2File = "$schemaPath\update-silver-tables-b2b.kql"

if (Test-Path $step2File) {
    Write-Host "✓ Fichier trouvé: update-silver-tables-b2b.kql" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  ATTENTION:" -ForegroundColor Red
    Write-Host "  Ce script va DROP et recréer les 4 tables Silver:" -ForegroundColor Yellow
    Write-Host "    - idoc_shipments_silver" -ForegroundColor White
    Write-Host "    - idoc_orders_silver" -ForegroundColor White
    Write-Host "    - idoc_warehouse_silver" -ForegroundColor White
    Write-Host "    - idoc_invoices_silver" -ForegroundColor White
    Write-Host ""
    Write-Host "  Les données seront re-matérialisées depuis idoc_raw." -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Confirmer la recréation des tables Silver? (oui/non)"
    
    if ($confirm -eq "oui") {
        Write-Host ""
        Write-Host "📝 INSTRUCTIONS:" -ForegroundColor Yellow
        Write-Host "  1. Copiez TOUT le contenu du fichier (Ctrl+A, Ctrl+C)" -ForegroundColor White
        Write-Host "  2. Collez dans Query Editor Eventhouse" -ForegroundColor White
        Write-Host "  3. Exécutez (F5)" -ForegroundColor White
        Write-Host "  4. Attendez la fin (environ 2 minutes)" -ForegroundColor White
        Write-Host ""
        
        $response = Read-Host "Appuyez sur [ENTRÉE] pour ouvrir le fichier"
        
        # Ouvrir le fichier dans VS Code
        code $step2File
        
        Write-Host ""
        Write-Host "⏳ En attente de l'exécution..." -ForegroundColor Yellow
        $completed = Read-Host "Tapez 'ok' quand l'exécution est terminée avec succès"
        
        if ($completed -eq "ok") {
            Write-Host "✓ Étape 2 terminée!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Problème détecté. Vérifiez les erreurs dans Eventhouse." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Étape 2 annulée." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "❌ Fichier non trouvé: $step2File" -ForegroundColor Red
    exit
}

Write-Host ""

# ===================================================================
# ÉTAPE 3 : Vues Gold
# ===================================================================

Write-Host "=========================================="  -ForegroundColor Green
Write-Host "  ÉTAPE 3: Mise à jour vues Gold"  -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""

Write-Host "📝 INSTRUCTIONS MANUELLES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Il faut modifier le notebook Lakehouse:" -ForegroundColor White
Write-Host "  'Create_Gold_Materialized_Lake_Views'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Modifications à faire:" -ForegroundColor Yellow
Write-Host "  - Ajouter carrier_id, customer_id dans SELECT" -ForegroundColor White
Write-Host "  - Ajouter warehouse_partner_id dans vues warehouse" -ForegroundColor White
Write-Host "  - Ajouter partner_access_scope partout" -ForegroundColor White
Write-Host ""
Write-Host "  📖 Voir le guide détaillé:" -ForegroundColor Yellow
Write-Host "  fabric/warehouse/schema/EXECUTION_GUIDE_B2B.md" -ForegroundColor Cyan
Write-Host "  (Section ÉTAPE 3)" -ForegroundColor Gray
Write-Host ""

$openGuide = Read-Host "Ouvrir le guide d'exécution? (o/n)"

if ($openGuide -eq "o") {
    code "$schemaPath\EXECUTION_GUIDE_B2B.md"
}

Write-Host ""
$openLakehouse = Read-Host "Ouvrir Fabric Lakehouse Portal? (o/n)"

if ($openLakehouse -eq "o") {
    Start-Process $lakehouseUrl
}

Write-Host ""
$completed = Read-Host "Tapez 'ok' quand les vues Gold sont mises à jour"

if ($completed -eq "ok") {
    Write-Host "✓ Étape 3 terminée!" -ForegroundColor Green
}

Write-Host ""

# ===================================================================
# ÉTAPE 4 : Régénération des données
# ===================================================================

Write-Host "=========================================="  -ForegroundColor Green
Write-Host "  ÉTAPE 4: Régénération des données"  -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""

Write-Host "Maintenant que les schémas sont à jour, vous pouvez:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1️⃣  Régénérer les IDocs avec les nouveaux champs B2B" -ForegroundColor White
Write-Host ""
Write-Host "     Commande:" -ForegroundColor Cyan
Write-Host "     cd simulator" -ForegroundColor Gray
Write-Host "     python main.py --count 100" -ForegroundColor Gray
Write-Host ""
Write-Host "  2️⃣  Vérifier l'ingestion dans Eventhouse" -ForegroundColor White
Write-Host ""
Write-Host "     Requête KQL:" -ForegroundColor Cyan
Write-Host "     IDocSummary" -ForegroundColor Gray
Write-Host "     | where timestamp > ago(1h)" -ForegroundColor Gray
Write-Host "     | take 10" -ForegroundColor Gray
Write-Host "     | project carrier_id, customer_id, warehouse_partner_id" -ForegroundColor Gray
Write-Host ""

$regenerate = Read-Host "Lancer la régénération maintenant? (o/n)"

if ($regenerate -eq "o") {
    Write-Host ""
    Write-Host "🚀 Lancement de la régénération des IDocs..." -ForegroundColor Cyan
    Write-Host ""
    
    Set-Location "$basePath\simulator"
    python main.py --count 100
    
    Write-Host ""
    Write-Host "✓ Régénération terminée!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================="  -ForegroundColor Cyan
Write-Host "  ✅ MISE À JOUR B2B TERMINÉE"  -ForegroundColor Cyan
Write-Host "=========================================="  -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. Créer les vues Gold partenaires (gold_partner_carrier_shipments, etc.)" -ForegroundColor White
Write-Host "  2. Créer le Business Domain '3PL Logistics' dans Purview" -ForegroundColor White
Write-Host "  3. Déployer l'API GraphQL pour l'accès partenaires" -ForegroundColor White
Write-Host ""
Write-Host "📖 Documentation:" -ForegroundColor Yellow
Write-Host "  - simulator/B2B_SCHEMA_ENHANCEMENTS.md" -ForegroundColor Cyan
Write-Host "  - governance/3PL_PARTNER_SHARING_USE_CASES.md" -ForegroundColor Cyan
Write-Host ""
