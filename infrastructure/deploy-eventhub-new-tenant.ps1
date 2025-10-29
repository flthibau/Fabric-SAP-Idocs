# Deploy Event Hub pour Fabric - Nouveau Tenant
# Script complet avec auth par cle autorisee

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-idoc-fabric-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westeurope",
    
    [Parameter(Mandatory=$false)]
    [string]$NamespacePrefix = "eh-idoc-flt",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubName = "idoc-events"
)

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  Deployment Event Hub pour Fabric Eventstream" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "`n[IMPORTANT] Ce script deploie Event Hub avec auth par cle AUTORISEE" -ForegroundColor Yellow
Write-Host "Requis pour Fabric Eventstream (ne supporte pas encore Entra ID)" -ForegroundColor Yellow

# Generer nom unique
$namespace = "$NamespacePrefix$(Get-Random -Maximum 9999)"

Write-Host "`nParametres:" -ForegroundColor Cyan
Write-Host "  Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "  Location       : $Location" -ForegroundColor White
Write-Host "  Namespace      : $namespace" -ForegroundColor White
Write-Host "  Event Hub      : $EventHubName" -ForegroundColor White

$confirmation = Read-Host "`nContinuer? (Y/N)"
if ($confirmation -ne 'Y') {
    Write-Host "Annule." -ForegroundColor Yellow
    exit 0
}

# ================================================================
# ETAPE 1: Resource Group
# ================================================================
Write-Host "`n[1/8] Creation Resource Group..." -ForegroundColor Cyan

$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "  [OK] Resource Group existe deja" -ForegroundColor Green
} else {
    az group create --name $ResourceGroup --location $Location --output table
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Resource Group cree" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Echec creation Resource Group" -ForegroundColor Red
        exit 1
    }
}

# ================================================================
# ETAPE 2: Event Hub Namespace (AUTH PAR CLE AUTORISEE)
# ================================================================
Write-Host "`n[2/8] Creation Event Hub Namespace..." -ForegroundColor Cyan
Write-Host "  [IMPORTANT] disable-local-auth = false" -ForegroundColor Yellow

az eventhubs namespace create `
  --name $namespace `
  --resource-group $ResourceGroup `
  --location $Location `
  --sku Standard `
  --capacity 2 `
  --disable-local-auth false `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Echec creation namespace" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Namespace cree avec auth par cle autorisee" -ForegroundColor Green

# ================================================================
# ETAPE 3: Event Hub
# ================================================================
Write-Host "`n[3/8] Creation Event Hub..." -ForegroundColor Cyan

az eventhubs eventhub create `
  --name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --partition-count 4 `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Echec creation Event Hub" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Event Hub cree" -ForegroundColor Green

# ================================================================
# ETAPE 4: Consumer Group pour Fabric
# ================================================================
Write-Host "`n[4/8] Creation Consumer Group 'fabric-consumer'..." -ForegroundColor Cyan

az eventhubs eventhub consumer-group create `
  --name fabric-consumer `
  --eventhub-name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Echec creation consumer group" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Consumer group cree" -ForegroundColor Green

# ================================================================
# ETAPE 5: Authorization Rule pour Fabric (Listen)
# ================================================================
Write-Host "`n[5/8] Creation Authorization Rule 'fabric-listen'..." -ForegroundColor Cyan

az eventhubs eventhub authorization-rule create `
  --name fabric-listen `
  --eventhub-name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --rights Listen `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Echec creation auth rule Fabric" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Auth rule Fabric creee" -ForegroundColor Green

# ================================================================
# ETAPE 6: Authorization Rule pour Simulateur (Send)
# ================================================================
Write-Host "`n[6/8] Creation Authorization Rule 'simulator-send'..." -ForegroundColor Cyan

az eventhubs eventhub authorization-rule create `
  --name simulator-send `
  --eventhub-name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --rights Send `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Echec creation auth rule simulateur" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Auth rule simulateur creee" -ForegroundColor Green

# ================================================================
# ETAPE 7: Recuperer Connection Strings
# ================================================================
Write-Host "`n[7/8] Recuperation Connection Strings..." -ForegroundColor Cyan

$fabricConnStr = az eventhubs eventhub authorization-rule keys list `
  --name fabric-listen `
  --eventhub-name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --query primaryConnectionString -o tsv

$simulatorConnStr = az eventhubs eventhub authorization-rule keys list `
  --name simulator-send `
  --eventhub-name $EventHubName `
  --namespace-name $namespace `
  --resource-group $ResourceGroup `
  --query primaryConnectionString -o tsv

Write-Host "  [OK] Connection strings recuperees" -ForegroundColor Green

# ================================================================
# ETAPE 8: Sauvegarder Configuration
# ================================================================
Write-Host "`n[8/8] Sauvegarde configuration..." -ForegroundColor Cyan

$configPath = ".\NEW_TENANT_CONFIG.md"

$configContent = @"
# Configuration Event Hub - Nouveau Tenant

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Ressources Deployees

- **Resource Group:** $ResourceGroup
- **Location:** $Location
- **Namespace:** $namespace
- **Event Hub:** $EventHubName
- **Consumer Group:** fabric-consumer

## Connection Strings

### Fabric Eventstream (Listen)

``````
$fabricConnStr
``````

**Utilisation:**
1. Fabric Portal → Workspace Settings → Connections
2. New connection → Azure Event Hubs
3. Connection String: (copier ci-dessus)
4. Event Hub Name: $EventHubName
5. Consumer Group: fabric-consumer

### Simulateur Python (Send)

``````
$simulatorConnStr
``````

**Utilisation:**
Mettre a jour ``simulator/config/config.yaml``:

``````yaml
event_hub:
  connection_string: "$simulatorConnStr"
  eventhub_name: "$EventHubName"
``````

## Verification

``````powershell
# Verifier namespace
az eventhubs namespace show \`
  --name $namespace \`
  --resource-group $ResourceGroup \`
  --query disableLocalAuth

# Devrait retourner: false (auth par cle autorisee)

# Verifier Event Hub
az eventhubs eventhub show \`
  --name $EventHubName \`
  --namespace-name $namespace \`
  --resource-group $ResourceGroup

# Lister consumer groups
az eventhubs eventhub consumer-group list \`
  --eventhub-name $EventHubName \`
  --namespace-name $namespace \`
  --resource-group $ResourceGroup \`
  --output table
``````

## Prochaines Etapes

1. **Creer Data Connection dans Fabric:**
   - Utiliser connection string Fabric ci-dessus
   - Copier le GUID de la connection creee

2. **Mettre a jour simulateur:**
   - Editer ``simulator/config/config.yaml``
   - Utiliser connection string Simulateur ci-dessus

3. **Re-executer script Eventstream:**
   ``````powershell
   cd fabric\eventstream
   .\create-eventstream-hybrid.ps1 \`
     -EventHubNamespace "$namespace.servicebus.windows.net" \`
     -DataConnectionId "<guid-de-la-data-connection>"
   ``````

4. **Publier et tester:**
   - Publier Eventstream dans portal
   - Configurer table KQL 'idoc_raw'
   - Tester avec simulateur

## Cleanup (si necessaire)

``````powershell
# Supprimer tout
az group delete --name $ResourceGroup --yes --no-wait
``````

---

**Status:** Deploye avec succes  
**Auth Method:** Shared Access Key (compatible Fabric Eventstream)
"@

$configContent | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "  [OK] Configuration sauvegardee: $configPath" -ForegroundColor Green

# ================================================================
# RESUME
# ================================================================
Write-Host "`n" -NoNewline
Write-Host ("=" * 80) -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Green

Write-Host "`nRessources creees:" -ForegroundColor Cyan
Write-Host "  Resource Group      : $ResourceGroup" -ForegroundColor White
Write-Host "  Namespace           : $namespace" -ForegroundColor White
Write-Host "  Event Hub           : $EventHubName" -ForegroundColor White
Write-Host "  Consumer Group      : fabric-consumer" -ForegroundColor White
Write-Host "  Auth Rules          : fabric-listen, simulator-send" -ForegroundColor White
Write-Host "  Local Auth Disabled : false (cles autorisees)" -ForegroundColor Green

Write-Host "`nConnection Strings:" -ForegroundColor Cyan
Write-Host "`n1. FABRIC EVENTSTREAM (Listen):" -ForegroundColor Yellow
Write-Host $fabricConnStr -ForegroundColor White

Write-Host "`n2. SIMULATEUR PYTHON (Send):" -ForegroundColor Yellow
Write-Host $simulatorConnStr -ForegroundColor White

Write-Host "`nConfiguration sauvegardee dans:" -ForegroundColor Cyan
Write-Host "  $configPath" -ForegroundColor White

Write-Host "`nProchaines etapes:" -ForegroundColor Yellow
Write-Host "1. Creer Data Connection dans Fabric avec connection string #1" -ForegroundColor White
Write-Host "2. Mettre a jour simulator/config/config.yaml avec connection string #2" -ForegroundColor White
Write-Host "3. Re-executer create-eventstream-hybrid.ps1 avec nouveau Data Connection ID" -ForegroundColor White
Write-Host "4. Publier Eventstream et tester" -ForegroundColor White

Write-Host "`nPortal Azure:" -ForegroundColor Cyan
Write-Host "  https://portal.azure.com/#@/resource/subscriptions/..." -ForegroundColor White

Write-Host "`n" -NoNewline
