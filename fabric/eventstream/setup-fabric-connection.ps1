# Script de configuration pour la connexion Fabric → Event Hub
# Ce script crée le consumer group et vérifie les permissions

param(
    [string]$ResourceGroup = "rg-idoc-fabric-dev",
    [string]$Namespace = "eh-idoc-flt8076",
    [string]$EventHub = "idoc-events",
    [string]$ConsumerGroup = "fabric-consumer"
)

Write-Host "🚀 Configuration Fabric Eventstream pour Event Hub" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier la connexion Azure
Write-Host "Vérification de la connexion Azure..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "❌ Non connecté à Azure. Connexion..." -ForegroundColor Red
    az login
    $account = az account show | ConvertFrom-Json
}

Write-Host "✅ Connecté : $($account.user.name)" -ForegroundColor Green
Write-Host "   Subscription : $($account.name)" -ForegroundColor Gray
Write-Host ""

# Étape 1 : Créer le consumer group pour Fabric
Write-Host "📦 Étape 1 : Création du consumer group '$ConsumerGroup'..." -ForegroundColor Yellow

$consumerGroupExists = az eventhubs eventhub consumer-group show `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --eventhub-name $EventHub `
    --name $ConsumerGroup `
    2>$null

if ($consumerGroupExists) {
    Write-Host "   ℹ️  Consumer group existe déjà" -ForegroundColor Gray
} else {
    az eventhubs eventhub consumer-group create `
        --resource-group $ResourceGroup `
        --namespace-name $Namespace `
        --eventhub-name $EventHub `
        --name $ConsumerGroup `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Consumer group créé avec succès" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Erreur lors de la création du consumer group" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Étape 2 : Vérifier les permissions RBAC actuelles
Write-Host "🔐 Étape 2 : Vérification des permissions RBAC..." -ForegroundColor Yellow

$userId = az ad signed-in-user show --query id -o tsv
Write-Host "   User Object ID : $userId" -ForegroundColor Gray

$eventHubScope = "/subscriptions/f79d4407-99c6-4d64-88fc-848fb05d5476/resourceGroups/$ResourceGroup/providers/Microsoft.EventHub/namespaces/$Namespace/eventhubs/$EventHub"

# Vérifier si le rôle Data Receiver est assigné
$roleAssignments = az role assignment list `
    --assignee $userId `
    --scope $eventHubScope `
    --query "[?roleDefinitionName=='Azure Event Hubs Data Receiver']" `
    | ConvertFrom-Json

if ($roleAssignments.Count -gt 0) {
    Write-Host "   ✅ Rôle 'Azure Event Hubs Data Receiver' déjà assigné" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Rôle 'Azure Event Hubs Data Receiver' non trouvé" -ForegroundColor Yellow
    Write-Host "   📝 Assignation du rôle..." -ForegroundColor Yellow
    
    az role assignment create `
        --assignee $userId `
        --role "Azure Event Hubs Data Receiver" `
        --scope $eventHubScope `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Rôle assigné avec succès" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Erreur lors de l'assignation du rôle" -ForegroundColor Red
    }
}
Write-Host ""

# Étape 3 : Lister tous les consumer groups
Write-Host "📋 Étape 3 : Consumer groups disponibles..." -ForegroundColor Yellow
az eventhubs eventhub consumer-group list `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --eventhub-name $EventHub `
    --output table
Write-Host ""

# Étape 4 : Afficher les informations de connexion pour Fabric
Write-Host "📝 Informations de connexion pour Fabric Eventstream" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration à utiliser dans Fabric :" -ForegroundColor White
Write-Host ""
Write-Host "   Connection type    : Azure Event Hubs" -ForegroundColor Gray
Write-Host "   Authentication     : Organizational account (Entra ID)" -ForegroundColor Gray
Write-Host "   Namespace          : $Namespace.servicebus.windows.net" -ForegroundColor White
Write-Host "   Event Hub          : $EventHub" -ForegroundColor White
Write-Host "   Consumer group     : $ConsumerGroup" -ForegroundColor White
Write-Host "   Data format        : JSON" -ForegroundColor Gray
Write-Host ""

# Étape 5 : Vérifier qu'il y a des messages dans Event Hub
Write-Host "📊 Étape 5 : Statistiques de l'Event Hub..." -ForegroundColor Yellow
$ehDetails = az eventhubs eventhub show `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --name $EventHub `
    | ConvertFrom-Json

Write-Host "   Partitions         : $($ehDetails.partitionCount)" -ForegroundColor Gray
Write-Host "   Retention (heures) : $($ehDetails.messageRetentionInDays * 24)" -ForegroundColor Gray
Write-Host "   Status             : $($ehDetails.status)" -ForegroundColor Gray
Write-Host ""

# Étape 6 : Tester la lecture avec le CLI
Write-Host "🧪 Étape 6 : Test de lecture (optionnel)..." -ForegroundColor Yellow
Write-Host "   Pour tester la connexion, exécutez :" -ForegroundColor Gray
Write-Host "   cd ..\simulator" -ForegroundColor White
Write-Host "   python read_eventhub.py --max 5" -ForegroundColor White
Write-Host ""

Write-Host "✅ Configuration terminée avec succès !" -ForegroundColor Green
Write-Host ""
Write-Host "📖 Prochaines étapes :" -ForegroundColor Cyan
Write-Host "   1. Ouvrez Microsoft Fabric" -ForegroundColor White
Write-Host "   2. Créez un Eventstream : evs-sap-idoc-ingest" -ForegroundColor White
Write-Host "   3. Ajoutez une source Azure Event Hub avec les paramètres ci-dessus" -ForegroundColor White
Write-Host "   4. Consultez : .\EVENTSTREAM_SETUP.md pour le guide complet" -ForegroundColor White
Write-Host ""
