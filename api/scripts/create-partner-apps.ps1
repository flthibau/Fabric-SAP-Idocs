################################################################################
# Script: create-partner-apps.ps1
# Description: Cree 3 Service Principals Azure AD pour les partenaires B2B
#              - CARRIER-FEDEX (Transporteur)
#              - WAREHOUSE-EAST (Entrepot)
#              - CUSTOMER-ACME (Client)
#
# Usage: .\create-partner-apps.ps1
################################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "38de1b20-8309-40ba-9584-5d9fcb7203b4",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "partner-apps-credentials.json"
)

$ErrorActionPreference = "Stop"

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  CREATION DES SERVICE PRINCIPALS PARTENAIRES B2B" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# Verifier la connexion Azure AD
Write-Host "Verification de la connexion Azure AD..." -ForegroundColor Yellow
try {
    $currentContext = az account show 2>&1 | ConvertFrom-Json
    if ($currentContext.tenantId -ne $TenantId) {
        Write-Host "  Connexion au tenant $TenantId..." -ForegroundColor Gray
        az login --tenant $TenantId --only-show-errors | Out-Null
    }
    Write-Host "  OK Connecte au tenant: $($currentContext.name)" -ForegroundColor Green
} catch {
    Write-Host "  Connexion Azure requise..." -ForegroundColor Yellow
    az login --tenant $TenantId --only-show-errors | Out-Null
}

# Definition des 3 partenaires
$partners = @(
    @{
        Name = "CARRIER-FEDEX-API"
        DisplayName = "FedEx Carrier Partner API"
        Description = "Service Principal for FedEx carrier partner - access to shipments only"
        Role = "CARRIER-FEDEX"
        Scope = "Shipments tracking and status updates"
    },
    @{
        Name = "WAREHOUSE-EAST-API"
        DisplayName = "Warehouse East Partner API"
        Description = "Service Principal for East warehouse partner - access to warehouse movements"
        Role = "WAREHOUSE-EAST"
        Scope = "Warehouse inventory movements and stock management"
    },
    @{
        Name = "CUSTOMER-ACME-API"
        DisplayName = "ACME Corp Customer API"
        Description = "Service Principal for ACME customer - access to orders, shipments, and invoices"
        Role = "CUSTOMER-ACME"
        Scope = "Customer orders, shipment tracking, and invoice data"
    }
)

$results = @()

foreach ($partner in $partners) {
    Write-Host "`n---------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Creation: $($partner.DisplayName)" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------------------------------" -ForegroundColor Gray
    
    # Verifier si l'app existe deja
    Write-Host "  Verification de l'existence de l'app..." -ForegroundColor Gray
    $existingApp = az ad app list --display-name $partner.DisplayName --query "[0]" 2>$null | ConvertFrom-Json
    
    if ($existingApp) {
        Write-Host "  App deja existante: $($existingApp.appId)" -ForegroundColor Yellow
        Write-Host "  Voulez-vous la reutiliser ? (O/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -ne "O" -and $response -ne "o") {
            Write-Host "  Suppression de l'ancienne app..." -ForegroundColor Gray
            az ad app delete --id $existingApp.appId 2>$null
            $existingApp = $null
        }
    }
    
    if (-not $existingApp) {
        # Creer l'App Registration
        Write-Host "  Creation de l'App Registration..." -ForegroundColor Yellow
        $app = az ad app create `
            --display-name $partner.DisplayName `
            --sign-in-audience "AzureADMyOrg" `
            --query "{appId:appId,objectId:id}" `
            | ConvertFrom-Json
        
        Write-Host "    OK App ID: $($app.appId)" -ForegroundColor Green
        
        # Creer le Service Principal
        Write-Host "  Creation du Service Principal..." -ForegroundColor Yellow
        $sp = az ad sp create --id $app.appId --query "{objectId:id}" | ConvertFrom-Json
        Write-Host "    OK Service Principal ID: $($sp.objectId)" -ForegroundColor Green
        
        # Creer un client secret
        Write-Host "  Generation du client secret..." -ForegroundColor Yellow
        $secretName = "$($partner.Role)-secret-$(Get-Date -Format 'yyyyMMdd')"
        $secret = az ad app credential reset `
            --id $app.appId `
            --append `
            --display-name $secretName `
            --years 2 `
            --query "{value:password}" `
            | ConvertFrom-Json
        
        Write-Host "    OK Secret cree (expire dans 2 ans)" -ForegroundColor Green
        
        $appId = $app.appId
        $spObjectId = $sp.objectId
        $clientSecret = $secret.value
    } else {
        # Reutiliser l'app existante
        $appId = $existingApp.appId
        
        # Recuperer le Service Principal
        $sp = az ad sp show --id $appId --query "{objectId:id}" | ConvertFrom-Json
        $spObjectId = $sp.objectId
        
        # Generer un nouveau secret
        Write-Host "  Generation d'un nouveau client secret..." -ForegroundColor Yellow
        $secretName = "$($partner.Role)-secret-$(Get-Date -Format 'yyyyMMdd')"
        $secret = az ad app credential reset `
            --id $appId `
            --append `
            --display-name $secretName `
            --years 2 `
            --query "{value:password}" `
            | ConvertFrom-Json
        
        $clientSecret = $secret.value
        Write-Host "    OK Nouveau secret cree" -ForegroundColor Green
    }
    
    # Stocker les resultats
    $results += @{
        Name = $partner.Name
        DisplayName = $partner.DisplayName
        Role = $partner.Role
        AppId = $appId
        ServicePrincipalObjectId = $spObjectId
        ClientSecret = $clientSecret
        TenantId = $TenantId
        CreatedDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Description = $partner.Description
        Scope = $partner.Scope
    }
    
    Write-Host "`n  RESUME:" -ForegroundColor Cyan
    Write-Host "    Nom: $($partner.DisplayName)" -ForegroundColor White
    Write-Host "    Role: $($partner.Role)" -ForegroundColor White
    Write-Host "    App ID: $appId" -ForegroundColor White
    Write-Host "    Service Principal ID: $spObjectId" -ForegroundColor White
    Write-Host "    Portee d'acces: $($partner.Scope)" -ForegroundColor Gray
}

# Sauvegarder les credentials dans un fichier JSON
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  SAUVEGARDE DES CREDENTIALS" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

$outputData = @{
    TenantId = $TenantId
    CreatedDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Partners = $results
    OneLakeRLS = @{
        Note = "Ces Service Principal IDs doivent etre utilises dans onelake-rls-config.json"
        CarrierFedEx = $results[0].ServicePrincipalObjectId
        WarehouseEast = $results[1].ServicePrincipalObjectId
        CustomerAcme = $results[2].ServicePrincipalObjectId
    }
}

$outputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "  OK Credentials sauvegardees dans: $OutputPath" -ForegroundColor Green

# Afficher le resume final
Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host "  SERVICE PRINCIPALS CREES AVEC SUCCES!" -ForegroundColor Green
Write-Host "===============================================================================`n" -ForegroundColor Green

Write-Host "APPLICATIONS CREEES:" -ForegroundColor Cyan
foreach ($result in $results) {
    Write-Host "`n  $($result.DisplayName)" -ForegroundColor Yellow
    Write-Host "    App ID (Client ID): $($result.AppId)" -ForegroundColor White
    Write-Host "    Service Principal ID: $($result.ServicePrincipalObjectId)" -ForegroundColor White
    Write-Host "    Role RLS: $($result.Role)" -ForegroundColor Gray
}

Write-Host "`nIMPORTANT - SECURITE:" -ForegroundColor Red
Write-Host "  Le fichier $OutputPath contient les secrets!" -ForegroundColor Yellow
Write-Host "  Ne PAS commiter ce fichier dans Git!" -ForegroundColor Yellow
Write-Host "  Stockez les secrets dans Azure Key Vault en production." -ForegroundColor Yellow

Write-Host "`nPROCHAINES ETAPES:" -ForegroundColor Cyan
Write-Host "`n  1. METTRE A JOUR onelake-rls-config.json" -ForegroundColor Yellow
Write-Host "     Remplacer les <service-principal-id-xxx> avec les IDs ci-dessus" -ForegroundColor Gray

Write-Host "`n  2. CONFIGURER RLS DANS FABRIC PORTAL" -ForegroundColor Yellow
Write-Host "     Eventhouse > OneLake Security > Row-Level Security" -ForegroundColor Gray
Write-Host "     Creer les 3 roles et assigner les Service Principals" -ForegroundColor Gray

Write-Host "`n  3. TESTER LE RLS VIA GRAPHQL" -ForegroundColor Yellow
Write-Host "     Utiliser les credentials pour tester l'acces filtre" -ForegroundColor Gray

Write-Host "`n  4. DEPLOYER APIM AVEC MANAGED IDENTITY" -ForegroundColor Yellow
Write-Host "     .\deploy-apim.ps1 -ResourceGroup 'rg-3pl-api' ..." -ForegroundColor Gray

Write-Host "`n===============================================================================`n" -ForegroundColor Green

# Creer un fichier .gitignore s'il n'existe pas
$gitignorePath = Join-Path (Split-Path $OutputPath -Parent) ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    $gitignoreContent = @"
# Partner credentials - DO NOT COMMIT
partner-apps-credentials.json
*.secret.json
*.credentials.json
"@
    $gitignoreContent | Out-File -FilePath $gitignorePath -Encoding UTF8
    Write-Host "  OK Fichier .gitignore cree pour proteger les secrets`n" -ForegroundColor Green
}
