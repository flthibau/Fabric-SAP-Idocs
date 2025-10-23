# Script de configuration pour la connexion Fabric -> Event Hub
# Ce script cree le consumer group et verifie les permissions

param(
    [string]$ResourceGroup = "rg-idoc-fabric-dev",
    [string]$Namespace = "eh-idoc-flt8076",
    [string]$EventHub = "idoc-events",
    [string]$ConsumerGroup = "fabric-consumer"
)

Write-Host "=== Configuration Fabric Eventstream pour Event Hub ===" -ForegroundColor Cyan
Write-Host ""

# Verifier la connexion Azure
Write-Host "[1/6] Verification de la connexion Azure..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "ERROR: Non connecte a Azure. Connexion..." -ForegroundColor Red
    az login
    $account = az account show | ConvertFrom-Json
}

Write-Host "OK - Connecte: $($account.user.name)" -ForegroundColor Green
Write-Host "     Subscription: $($account.name)" -ForegroundColor Gray
Write-Host ""

# Etape 1: Creer le consumer group pour Fabric
Write-Host "[2/6] Creation du consumer group '$ConsumerGroup'..." -ForegroundColor Yellow

$consumerGroupExists = az eventhubs eventhub consumer-group show `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --eventhub-name $EventHub `
    --name $ConsumerGroup `
    2>$null

if ($consumerGroupExists) {
    Write-Host "OK - Consumer group existe deja" -ForegroundColor Gray
} else {
    az eventhubs eventhub consumer-group create `
        --resource-group $ResourceGroup `
        --namespace-name $Namespace `
        --eventhub-name $EventHub `
        --name $ConsumerGroup `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK - Consumer group cree avec succes" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Echec creation consumer group" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Etape 2: Verifier les permissions RBAC actuelles
Write-Host "[3/6] Verification des permissions RBAC..." -ForegroundColor Yellow

$userId = az ad signed-in-user show --query id -o tsv
Write-Host "     User Object ID: $userId" -ForegroundColor Gray

$eventHubScope = "/subscriptions/f79d4407-99c6-4d64-88fc-848fb05d5476/resourceGroups/$ResourceGroup/providers/Microsoft.EventHub/namespaces/$Namespace/eventhubs/$EventHub"

# Verifier si le role Data Receiver est assigne
$roleAssignments = az role assignment list `
    --assignee $userId `
    --scope $eventHubScope `
    --query "[?roleDefinitionName=='Azure Event Hubs Data Receiver']" `
    | ConvertFrom-Json

if ($roleAssignments.Count -gt 0) {
    Write-Host "OK - Role 'Azure Event Hubs Data Receiver' deja assigne" -ForegroundColor Green
} else {
    Write-Host "WARNING: Role 'Azure Event Hubs Data Receiver' non trouve" -ForegroundColor Yellow
    Write-Host "         Assignation du role..." -ForegroundColor Yellow
    
    az role assignment create `
        --assignee $userId `
        --role "Azure Event Hubs Data Receiver" `
        --scope $eventHubScope `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK - Role assigne avec succes" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Echec assignation role" -ForegroundColor Red
    }
}
Write-Host ""

# Etape 3: Lister tous les consumer groups
Write-Host "[4/6] Consumer groups disponibles:" -ForegroundColor Yellow
az eventhubs eventhub consumer-group list `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --eventhub-name $EventHub `
    --output table
Write-Host ""

# Etape 4: Afficher les informations de connexion pour Fabric
Write-Host "[5/6] Informations de connexion pour Fabric Eventstream" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration a utiliser dans Fabric:" -ForegroundColor White
Write-Host ""
Write-Host "   Connection type    : Azure Event Hubs" -ForegroundColor Gray
Write-Host "   Authentication     : Organizational account (Entra ID)" -ForegroundColor Gray
Write-Host "   Namespace          : $Namespace.servicebus.windows.net" -ForegroundColor White
Write-Host "   Event Hub          : $EventHub" -ForegroundColor White
Write-Host "   Consumer group     : $ConsumerGroup" -ForegroundColor White
Write-Host "   Data format        : JSON" -ForegroundColor Gray
Write-Host ""

# Etape 5: Verifier qu'il y a des messages dans Event Hub
Write-Host "[6/6] Statistiques de l'Event Hub:" -ForegroundColor Yellow
$ehDetails = az eventhubs eventhub show `
    --resource-group $ResourceGroup `
    --namespace-name $Namespace `
    --name $EventHub `
    | ConvertFrom-Json

Write-Host "   Partitions         : $($ehDetails.partitionCount)" -ForegroundColor Gray
Write-Host "   Retention (heures) : $($ehDetails.messageRetentionInDays * 24)" -ForegroundColor Gray
Write-Host "   Status             : $($ehDetails.status)" -ForegroundColor Gray
Write-Host ""

# Test de lecture
Write-Host "=== Test de lecture (optionnel) ===" -ForegroundColor Yellow
Write-Host "Pour tester la connexion, executez:" -ForegroundColor Gray
Write-Host "   cd ..\..\simulator" -ForegroundColor White
Write-Host "   python read_eventhub.py --max 5" -ForegroundColor White
Write-Host ""

Write-Host "=== Configuration terminee avec succes! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Cyan
Write-Host "   1. Ouvrez Microsoft Fabric" -ForegroundColor White
Write-Host "   2. Creez un Eventstream: evs-sap-idoc-ingest" -ForegroundColor White
Write-Host "   3. Ajoutez une source Azure Event Hub avec les parametres ci-dessus" -ForegroundColor White
Write-Host "   4. Consultez: .\EVENTSTREAM_SETUP.md pour le guide complet" -ForegroundColor White
Write-Host ""
