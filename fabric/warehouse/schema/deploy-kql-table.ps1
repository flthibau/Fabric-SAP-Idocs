<#
.SYNOPSIS
    Crée la table KQL idoc_raw dans la base de données Kusto

.DESCRIPTION
    Exécute le script create-idoc-raw-table.kql via l'API Kusto pour créer:
    - La table idoc_raw avec son schéma
    - La politique de streaming ingestion
    - Le mapping JSON
    - La politique de rétention
    - Les fonctions helper

.PARAMETER ClusterUri
    URI du cluster Kusto (ex: https://kqldbsapidoc-xxxx.kusto.fabric.microsoft.com)

.PARAMETER DatabaseName
    Nom de la base de données KQL (défaut: kqldbsapidoc)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterUri,
    [string]$DatabaseName = "kqldbsapidoc"
)

$ErrorActionPreference = "Stop"

Write-Host "`n===================================================================" -ForegroundColor Cyan
Write-Host "  CREATION TABLE KQL - idoc_raw" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan

# ============================================================================
# ETAPE 1: Lecture du script KQL
# ============================================================================
Write-Host "`nETAPE 1: Lecture du script KQL..." -ForegroundColor Yellow

$scriptPath = Join-Path $PSScriptRoot "create-idoc-raw-table.kql"
if (-not (Test-Path $scriptPath)) {
    Write-Host "  [ERROR] Script non trouvé: $scriptPath" -ForegroundColor Red
    exit 1
}

$kqlScript = Get-Content $scriptPath -Raw
Write-Host "  [OK] Script chargé ($($kqlScript.Length) caractères)" -ForegroundColor Green

# ============================================================================
# ETAPE 2: Récupération du token d'authentification
# ============================================================================
Write-Host "`nETAPE 2: Récupération du token..." -ForegroundColor Yellow

# Utiliser le resource spécifique au cluster Kusto Fabric
# Extraire le hostname du cluster URI pour le resource
$clusterHost = ([System.Uri]$ClusterUri).Host

# Pour Fabric Kusto, utiliser l'URL du cluster comme resource
$tokenResponse = az account get-access-token --resource "https://$clusterHost" --output json | ConvertFrom-Json

if (-not $tokenResponse.accessToken) {
    Write-Host "  [ERROR] Impossible de récupérer le token" -ForegroundColor Red
    exit 1
}

$token = $tokenResponse.accessToken
Write-Host "  [OK] Token obtenu pour $clusterHost" -ForegroundColor Green

# ============================================================================
# ETAPE 3: Normalisation du Cluster URI
# ============================================================================
Write-Host "`nETAPE 3: Validation du Cluster URI..." -ForegroundColor Yellow

# S'assurer que l'URI se termine sans /
$ClusterUri = $ClusterUri.TrimEnd('/')
Write-Host "  Cluster: $ClusterUri" -ForegroundColor Cyan
Write-Host "  Database: $DatabaseName" -ForegroundColor Cyan

# ============================================================================
# ETAPE 4: Exécution du script KQL
# ============================================================================
Write-Host "`nETAPE 4: Exécution du script KQL..." -ForegroundColor Yellow

# Diviser le script en commandes individuelles
# Les commandes KQL commencent par . (dot commands) ou sont du KQL query
$lines = $kqlScript -split "`n"
$commands = @()
$currentCommand = ""

foreach ($line in $lines) {
    $trimmedLine = $line.Trim()
    
    # Ignorer les commentaires et lignes vides
    if ($trimmedLine.StartsWith("//") -or $trimmedLine -eq "") {
        # Si on a une commande en cours, on la sauvegarde
        if ($currentCommand.Trim() -ne "") {
            $commands += $currentCommand.Trim()
            $currentCommand = ""
        }
        continue
    }
    
    # Si la ligne commence par un dot command et qu'on a déjà une commande
    if ($trimmedLine.StartsWith(".") -and $currentCommand.Trim() -ne "") {
        $commands += $currentCommand.Trim()
        $currentCommand = $line
    }
    else {
        $currentCommand += "`n$line"
    }
}

# Ajouter la dernière commande
if ($currentCommand.Trim() -ne "") {
    $commands += $currentCommand.Trim()
}

$commandCount = $commands.Count
Write-Host "  Nombre de commandes à exécuter: $commandCount" -ForegroundColor Cyan

$successCount = 0
$failCount = 0

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

foreach ($command in $commands) {
    $trimmedCommand = $command.Trim()
    
    # Ignorer les commentaires
    if ($trimmedCommand.StartsWith("//") -or $trimmedCommand -eq "") {
        continue
    }
    
    # Extraire la première ligne pour affichage
    $firstLine = ($trimmedCommand -split "`n")[0]
    if ($firstLine.Length -gt 60) {
        $firstLine = $firstLine.Substring(0, 60) + "..."
    }
    
    Write-Host "  Exécution: $firstLine" -ForegroundColor Gray
    
    # Construire le payload pour l'API Kusto
    $body = @{
        db = $DatabaseName
        csl = $trimmedCommand
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$ClusterUri/v1/rest/mgmt" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop
        
        Write-Host "    [OK]" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "    [WARNING] $($_.Exception.Message)" -ForegroundColor Yellow
        # Continuer même en cas d'erreur (ex: table déjà existante)
        $failCount++
    }
    
    Start-Sleep -Milliseconds 200
}

# ============================================================================
# ETAPE 5: Vérification de la table créée
# ============================================================================
Write-Host "`nETAPE 5: Vérification de la table..." -ForegroundColor Yellow

$verifyQuery = ".show tables | where TableName == 'idoc_raw'"
$body = @{
    db = $DatabaseName
    csl = $verifyQuery
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "$ClusterUri/v1/rest/query" `
        -Method Post `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    if ($response.Tables[0].Rows.Count -gt 0) {
        Write-Host "  [OK] Table 'idoc_raw' créée avec succès" -ForegroundColor Green
        Write-Host "`n  Détails de la table:" -ForegroundColor Cyan
        Write-Host "    Nom: idoc_raw" -ForegroundColor White
        Write-Host "    Base de données: $DatabaseName" -ForegroundColor White
    }
    else {
        Write-Host "  [WARNING] Table 'idoc_raw' non trouvée" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  [ERROR] Erreur lors de la vérification: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================================
# RESUME
# ============================================================================
Write-Host "`n===================================================================" -ForegroundColor Cyan
Write-Host "  RESUME" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "  Database: $DatabaseName" -ForegroundColor White
Write-Host "  Cluster: $ClusterUri" -ForegroundColor White
Write-Host "  Commandes réussies: $successCount/$commandCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Commandes échouées: $failCount (normal si ressources déjà existantes)" -ForegroundColor Yellow
}
Write-Host "`n  [SUCCESS] Script terminé!" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Cyan
