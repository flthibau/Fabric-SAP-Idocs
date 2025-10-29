# ================================================================
# Script: Mise à jour extraction items warehouse (E1WHC10)
# ================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "  MISE À JOUR EXTRACTION ITEMS WAREHOUSE (E1WHC10)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# Chemin du fichier KQL
$kqlFile = "c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\fabric\warehouse\schema\update-warehouse-items-extraction.kql"

# URL Eventhouse
$eventouseUrl = "https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/f91aaea3-7889-4415-851c-f4258a2fff6b/query"

Write-Host "OBJECTIF:" -ForegroundColor Yellow
Write-Host "  Éclater les items du segment E1WHC10 pour avoir une ligne" -ForegroundColor White
Write-Host "  par item avec material_id, quantity, batch_number, etc." -ForegroundColor White
Write-Host ""

Write-Host "MODIFICATIONS:" -ForegroundColor Yellow
Write-Host "  • Colonnes ajoutées: item_number, material_description, batch_number," -ForegroundColor Green
Write-Host "    storage_location, bin_location, target_quantity, variance_quantity" -ForegroundColor Green
Write-Host "  • Fonction ExtractWarehouseData: filtre E1WHC10 et retourne items array" -ForegroundColor Green
Write-Host "  • Update policy: mv-expand items pour créer une ligne par item" -ForegroundColor Green
Write-Host ""

Write-Host "ÉTAPE 1: Copie du script KQL dans le clipboard..." -ForegroundColor Yellow
Get-Content $kqlFile -Raw | Set-Clipboard
Write-Host "  ✓ Script copié!" -ForegroundColor Green
Write-Host ""

Write-Host "ÉTAPE 2: Ouvrir Eventhouse Portal..." -ForegroundColor Yellow
Start-Process $eventouseUrl
Write-Host "  ✓ Portal ouvert dans le navigateur" -ForegroundColor Green
Write-Host ""

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS - EXÉCUTION DANS FABRIC PORTAL" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Dans l'Eventhouse Query Editor:" -ForegroundColor Yellow
Write-Host "   • Collez le script (Ctrl+V)" -ForegroundColor White
Write-Host "   • Sélectionnez tout (Ctrl+A)" -ForegroundColor White
Write-Host "   • Exécutez (F5 ou clic 'Run')" -ForegroundColor White
Write-Host ""
Write-Host "2. Attendez la fin de l'exécution (tous les ✓)" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. REVENEZ ICI et tapez 'terminé' pour continuer" -ForegroundColor Yellow
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# Attendre confirmation
$response = Read-Host "Tapez 'terminé' quand le script KQL est exécuté"

if ($response -eq "terminé" -or $response -eq "termine") {
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host "  ÉTAPE SUIVANTE: PURGE ET RÉGÉNÉRATION" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Maintenant, il faut:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. DÉSACTIVER MIRRORING sur idoc_warehouse_silver" -ForegroundColor Yellow
    Write-Host "   (Dans Eventhouse Portal ou via script)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. PURGER la table:" -ForegroundColor Yellow
    Write-Host "   .clear table idoc_warehouse_silver data" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. GÉNÉRER nouveaux IDocs:" -ForegroundColor Yellow
    Write-Host "   cd simulator" -ForegroundColor Gray
    Write-Host "   python main.py --count 100" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. VALIDER les données:" -ForegroundColor Yellow
    Write-Host "   Vérifier que material_id, quantity, batch_number sont remplis" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. RÉACTIVER MIRRORING" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Voulez-vous continuer automatiquement? (y/n)" -ForegroundColor Yellow
    $continue = Read-Host
    
    if ($continue -eq "y" -or $continue -eq "o" -or $continue -eq "yes" -or $continue -eq "oui") {
        Write-Host ""
        Write-Host "Lancement du processus de purge/régénération..." -ForegroundColor Cyan
        
        # TODO: Ajouter les commandes pour désactiver mirroring, purger, etc.
        Write-Host ""
        Write-Host "⚠️  ATTENTION: Exécutez les commandes suivantes MANUELLEMENT:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Dans Eventhouse Portal:" -ForegroundColor Cyan
        Write-Host ".alter table idoc_warehouse_silver policy mirroring '{`"IsEnabled`": false}'" -ForegroundColor White
        Write-Host ".clear table idoc_warehouse_silver data" -ForegroundColor White
        Write-Host ""
        Write-Host "Puis dans PowerShell:" -ForegroundColor Cyan
        Write-Host "cd simulator" -ForegroundColor White
        Write-Host "python main.py --count 100" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "Opération annulée. Exécutez le script KQL d'abord." -ForegroundColor Red
    Write-Host ""
}
