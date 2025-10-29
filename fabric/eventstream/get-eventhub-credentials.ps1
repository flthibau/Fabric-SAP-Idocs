# Script pour récupérer les informations Event Hub nécessaires à la configuration Fabric

Write-Host "🔑 Récupération des informations Event Hub" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$rg = "rg-idoc-fabric-dev"
$ns = "eh-idoc-flt8076"
$eh = "idoc-events"

Write-Host "`n📋 Configuration Event Hub:" -ForegroundColor Yellow
Write-Host "  Resource Group    : $rg" -ForegroundColor White
Write-Host "  Namespace         : $ns" -ForegroundColor White
Write-Host "  Event Hub         : $eh" -ForegroundColor White
Write-Host "  Consumer Group    : fabric-consumer" -ForegroundColor White

# Récupérer la clé d'accès partagée
Write-Host "`n🔐 Récupération de la clé d'accès (Shared Access Key)..." -ForegroundColor Yellow

try {
    $key = az eventhubs eventhub authorization-rule keys list `
        --resource-group $rg `
        --namespace-name $ns `
        --eventhub-name $eh `
        --name simulator-send `
        --query primaryKey -o tsv 2>$null

    if ($LASTEXITCODE -eq 0 -and $key) {
        Write-Host "✅ Clé récupérée avec succès!" -ForegroundColor Green
        Write-Host "`n📝 Informations pour la configuration Fabric:" -ForegroundColor Cyan
        Write-Host "=" * 60 -ForegroundColor Cyan
        
        Write-Host "`n🔹 Connection Settings:" -ForegroundColor Yellow
        Write-Host "  Event Hubs namespace  : $ns.servicebus.windows.net" -ForegroundColor White
        Write-Host "  Event hub             : $eh" -ForegroundColor White
        
        Write-Host "`n🔹 Connection Credentials:" -ForegroundColor Yellow
        Write-Host "  Connection name       : eh-sap-idoc-connection" -ForegroundColor White
        Write-Host "  Authentication kind   : Shared Access Key" -ForegroundColor White
        Write-Host "  Shared Access Key Name: simulator-send" -ForegroundColor White
        Write-Host "  Shared Access Key     : $key" -ForegroundColor Green
        
        Write-Host "`n🔹 Stream Details:" -ForegroundColor Yellow
        Write-Host "  Consumer group        : fabric-consumer" -ForegroundColor White
        Write-Host "  Data format           : JSON" -ForegroundColor White
        
        Write-Host "`n📋 Copiez la clé ci-dessus pour la configuration Fabric" -ForegroundColor Cyan
        
        # Copier dans le presse-papiers (si disponible)
        try {
            $key | Set-Clipboard
            Write-Host "✅ Clé copiée dans le presse-papiers!" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Impossible de copier dans le presse-papiers (copiez manuellement)" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "❌ Erreur: Impossible de récupérer la clé" -ForegroundColor Red
        Write-Host "Vérifiez que la règle d'autorisation 'simulator-send' existe" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Erreur lors de la récupération de la clé:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Afficher les autres informations utiles
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan

Write-Host "`n🌐 Liens utiles:" -ForegroundColor Cyan
Write-Host "  Fabric Portal : https://app.fabric.microsoft.com" -ForegroundColor White
Write-Host "  Azure Portal  : https://portal.azure.com" -ForegroundColor White
Write-Host "  Workspace     : SAP-IDoc-Fabric" -ForegroundColor White
Write-Host "  Eventstream   : SAPIdocIngest" -ForegroundColor White

Write-Host "`n📚 Documentation:" -ForegroundColor Cyan
Write-Host "  Guide manuel  : .\fabric\eventstream\MANUAL_CONFIGURATION_GUIDE.md" -ForegroundColor White
Write-Host "  Options auto  : .\fabric\eventstream\AUTOMATION_OPTIONS.md" -ForegroundColor White

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
