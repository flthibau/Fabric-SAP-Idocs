# Script pour creer un Eventstream dans Microsoft Fabric via l'API REST
# Ce script utilise l'API Fabric pour automatiser la creation de l'Eventstream

param(
    [string]$WorkspaceName = "",
    [string]$WorkspaceId = "",
    [string]$EventstreamName = "evs-sap-idoc-ingest",
    [string]$EventHubNamespace = "eh-idoc-flt8076",
    [string]$EventHubName = "idoc-events",
    [string]$ConsumerGroup = "fabric-consumer"
)

Write-Host "=== Creation Eventstream Microsoft Fabric ===" -ForegroundColor Cyan
Write-Host ""

# Verifier la connexion Azure
Write-Host "[1/5] Verification de la connexion Azure..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "ERROR: Non connecte a Azure. Connexion..." -ForegroundColor Red
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Host "OK - Connecte: $($account.user.name)" -ForegroundColor Green
Write-Host ""

# Recuperer le token d'acces pour l'API Fabric
Write-Host "[2/5] Recuperation du token d'acces Fabric..." -ForegroundColor Yellow
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv

if (-not $token) {
    Write-Host "ERROR: Impossible de recuperer le token" -ForegroundColor Red
    exit 1
}
Write-Host "OK - Token obtenu" -ForegroundColor Green
Write-Host ""

# Lister les workspaces disponibles si WorkspaceId n'est pas fourni
if (-not $WorkspaceId) {
    Write-Host "[3/5] Liste des workspaces Fabric disponibles..." -ForegroundColor Yellow
    
    $workspacesResponse = az rest --method get `
        --url "https://api.fabric.microsoft.com/v1/workspaces" `
        --headers "Authorization=Bearer $token" 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Impossible de recuperer les workspaces" -ForegroundColor Red
        Write-Host "Verifiez que vous avez acces a Microsoft Fabric" -ForegroundColor Yellow
        exit 1
    }
    
    $workspaces = $workspacesResponse | ConvertFrom-Json
    
    if ($workspaces.value.Count -eq 0) {
        Write-Host "ERROR: Aucun workspace trouve" -ForegroundColor Red
        Write-Host "Veuillez creer un workspace dans Fabric d'abord" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "Workspaces disponibles:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $workspaces.value.Count; $i++) {
        Write-Host "  [$i] $($workspaces.value[$i].displayName) (ID: $($workspaces.value[$i].id))" -ForegroundColor White
    }
    Write-Host ""
    
    $selection = Read-Host "Selectionnez le numero du workspace (0-$($workspaces.value.Count - 1))"
    $WorkspaceId = $workspaces.value[[int]$selection].id
    $WorkspaceName = $workspaces.value[[int]$selection].displayName
    
    Write-Host "OK - Workspace selectionne: $WorkspaceName" -ForegroundColor Green
} else {
    Write-Host "[3/5] Utilisation du workspace ID: $WorkspaceId" -ForegroundColor Yellow
}
Write-Host ""

# Creer l'Eventstream
Write-Host "[4/5] Creation de l'Eventstream '$EventstreamName'..." -ForegroundColor Yellow

# Definition de l'Eventstream
$eventstreamDefinition = @{
    displayName = $EventstreamName
    description = "Eventstream for SAP IDoc ingestion from Azure Event Hub"
} | ConvertTo-Json -Depth 10

Write-Host "Payload:" -ForegroundColor Gray
Write-Host $eventstreamDefinition -ForegroundColor Gray
Write-Host ""

# API REST pour creer un Eventstream
$createUrl = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/eventstreams"

try {
    $response = az rest --method post `
        --url $createUrl `
        --headers "Content-Type=application/json" `
        --body $eventstreamDefinition 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $eventstream = $response | ConvertFrom-Json
        Write-Host "OK - Eventstream cree avec succes!" -ForegroundColor Green
        Write-Host "     ID: $($eventstream.id)" -ForegroundColor Gray
        Write-Host "     Name: $($eventstream.displayName)" -ForegroundColor Gray
        
        # Sauvegarder l'ID de l'Eventstream pour la suite
        $eventstreamId = $eventstream.id
    } else {
        Write-Host "ERROR: Echec de creation de l'Eventstream" -ForegroundColor Red
        Write-Host $response -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Exception lors de la creation" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""

# Configuration de la source Event Hub
Write-Host "[5/5] Configuration de la source Event Hub..." -ForegroundColor Yellow
Write-Host ""
Write-Host "INFORMATION: Configuration manuelle requise" -ForegroundColor Yellow
Write-Host ""
Write-Host "L'API Fabric ne supporte pas encore la configuration complete des sources via REST." -ForegroundColor Yellow
Write-Host "Vous devez maintenant:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Ouvrir Fabric: https://app.fabric.microsoft.com" -ForegroundColor White
Write-Host "  2. Aller dans le workspace: $WorkspaceName" -ForegroundColor White
Write-Host "  3. Ouvrir l'Eventstream: $EventstreamName" -ForegroundColor White
Write-Host "  4. Cliquer sur 'Add source' > 'Azure Event Hubs'" -ForegroundColor White
Write-Host "  5. Configurer:" -ForegroundColor White
Write-Host ""
Write-Host "     Namespace          : $EventHubNamespace.servicebus.windows.net" -ForegroundColor Cyan
Write-Host "     Event Hub          : $EventHubName" -ForegroundColor Cyan
Write-Host "     Consumer group     : $ConsumerGroup" -ForegroundColor Cyan
Write-Host "     Authentication     : Organizational account (Entra ID)" -ForegroundColor Cyan
Write-Host "     Data format        : JSON" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder la configuration dans un fichier
$config = @{
    eventstreamId = $eventstreamId
    workspaceId = $WorkspaceId
    workspaceName = $WorkspaceName
    eventstreamName = $EventstreamName
    eventHubConfig = @{
        namespace = "$EventHubNamespace.servicebus.windows.net"
        eventHub = $EventHubName
        consumerGroup = $ConsumerGroup
        authentication = "Organizational account (Entra ID)"
        dataFormat = "JSON"
    }
    createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$configPath = ".\eventstream-config.json"
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "Configuration sauvegardee: $configPath" -ForegroundColor Green
Write-Host ""

Write-Host "=== Eventstream cree avec succes! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Cyan
Write-Host "  1. Ouvrir Fabric et configurer la source Event Hub (voir ci-dessus)" -ForegroundColor White
Write-Host "  2. Ajouter une destination (KQL Database, Lakehouse, etc.)" -ForegroundColor White
Write-Host "  3. Tester avec: cd ..\..\simulator; python main.py" -ForegroundColor White
Write-Host ""
