# Script PowerShell pour activer l'API GraphQL dans Fabric Lakehouse
# Ce script active l'API GraphQL native de Fabric sur les tables Gold du Data Product

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64",
    
    [Parameter(Mandatory=$false)]
    [string]$LakehouseName = "lh_3pl_logistics_gold",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Tables = @(
        "idoc_orders_gold",
        "idoc_shipments_gold",
        "idoc_warehouse_gold",
        "idoc_invoices_gold"
    )
)

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  ACTIVATION API GRAPHQL DANS FABRIC LAKEHOUSE" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# Vérifier la connexion Azure
Write-Host "Vérification de la connexion Azure..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Write-Host "❌ Pas connecté à Azure. Connexion en cours..." -ForegroundColor Red
    Connect-AzAccount
    $context = Get-AzContext
}
Write-Host "✓ Connecté en tant que: $($context.Account.Id)`n" -ForegroundColor Green

# Obtenir le token Fabric/Power BI
Write-Host "Obtention du token Fabric..." -ForegroundColor Yellow
$token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token
Write-Host "✓ Token obtenu`n" -ForegroundColor Green

# Récupérer la liste des Lakehouses dans le workspace
Write-Host "Récupération des Lakehouses dans le workspace..." -ForegroundColor Yellow
$lakehousesResponse = Invoke-RestMethod `
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/lakehouses" `
    -Method GET `
    -Headers @{ 
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    }

$lakehouse = $lakehousesResponse.value | Where-Object { $_.displayName -eq $LakehouseName }

if (-not $lakehouse) {
    Write-Host "❌ Lakehouse '$LakehouseName' introuvable dans le workspace" -ForegroundColor Red
    Write-Host "`nLakehouses disponibles:" -ForegroundColor Yellow
    $lakehousesResponse.value | ForEach-Object {
        Write-Host "  - $($_.displayName) (ID: $($_.id))" -ForegroundColor White
    }
    exit 1
}

$lakehouseId = $lakehouse.id
Write-Host "✓ Lakehouse trouvé: $LakehouseName" -ForegroundColor Green
Write-Host "  ID: $lakehouseId`n" -ForegroundColor Gray

# Note: L'API GraphQL native de Fabric n'est pas encore disponible via REST API public
# Elle doit être activée via le Fabric Portal
Write-Host "⚠️  IMPORTANT: L'API GraphQL de Fabric doit être activée manuellement" -ForegroundColor Yellow
Write-Host "`n" -ForegroundColor Yellow

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS MANUELLES - ACTIVATION GRAPHQL API" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "1️⃣  Ouvrir le Lakehouse dans Fabric Portal:" -ForegroundColor Yellow
$lakehouseUrl = "https://msit.powerbi.com/groups/$WorkspaceId/lakehouses/$lakehouseId"
Write-Host "   $lakehouseUrl`n" -ForegroundColor White

Write-Host "2️⃣  Cliquer sur le menu 'Settings' (⚙️) en haut à droite`n" -ForegroundColor Yellow

Write-Host "3️⃣  Aller dans l'onglet 'API'`n" -ForegroundColor Yellow

Write-Host "4️⃣  Activer 'Enable GraphQL endpoint'`n" -ForegroundColor Yellow

Write-Host "5️⃣  Sélectionner les tables à exposer:" -ForegroundColor Yellow
foreach ($table in $Tables) {
    Write-Host "   ☑️  $table" -ForegroundColor Green
}
Write-Host ""

Write-Host "6️⃣  Configurer les options:" -ForegroundColor Yellow
Write-Host "   ☑️  Enable filtering: Oui" -ForegroundColor Green
Write-Host "   ☑️  Enable sorting: Oui" -ForegroundColor Green
Write-Host "   ☑️  Enable pagination: Oui (max 1000 records)" -ForegroundColor Green
Write-Host "   ☐  Enable mutations: Non (read-only pour partners)`n" -ForegroundColor Red

Write-Host "7️⃣  Copier l'URL de l'endpoint GraphQL:" -ForegroundColor Yellow
Write-Host "   Format: https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/graphql`n" -ForegroundColor White

Write-Host "8️⃣  Sauvegarder les paramètres`n" -ForegroundColor Yellow

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION ROW-LEVEL SECURITY (RLS)" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Après activation GraphQL, configurer RLS:" -ForegroundColor Yellow
Write-Host "`n1. Aller dans Lakehouse → Security → Row-Level Security`n" -ForegroundColor Yellow

Write-Host "2. Créer 3 rôles RLS:`n" -ForegroundColor Yellow

Write-Host "   📦 Rôle: CARRIER-FEDEX" -ForegroundColor Cyan
Write-Host "      Table: idoc_shipments_gold" -ForegroundColor White
Write-Host "      Filtre: [carrier_id] = 'CARRIER-FEDEX'`n" -ForegroundColor Gray

Write-Host "   📦 Rôle: WAREHOUSE-EAST" -ForegroundColor Cyan
Write-Host "      Table: idoc_warehouse_gold" -ForegroundColor White
Write-Host "      Filtre: [warehouse_partner_id] = 'WAREHOUSE-EAST'`n" -ForegroundColor Gray

Write-Host "   📦 Rôle: CUSTOMER-ACME" -ForegroundColor Cyan
Write-Host "      Tables: idoc_orders_gold, idoc_shipments_gold, idoc_invoices_gold" -ForegroundColor White
Write-Host "      Filtre: [partner_access_scope] LIKE '%CUSTOMER-ACME%'`n" -ForegroundColor Gray

Write-Host "3. Lier les rôles RLS aux Service Principals Azure AD" -ForegroundColor Yellow
Write-Host "   (Créés par le script create-partner-apps.ps1)`n" -ForegroundColor Gray

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  TESTER L'API GRAPHQL" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Après activation, tester avec cURL:`n" -ForegroundColor Yellow

$curlCommand = @"
curl -X POST https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/graphql \
  -H "Authorization: Bearer <FABRIC_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ __schema { types { name } } }"
  }'
"@

Write-Host $curlCommand -ForegroundColor White
Write-Host "`n"

Write-Host "Ou avec PowerShell:`n" -ForegroundColor Yellow

$psCommand = @"
`$token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token
`$body = @{
    query = "{ __schema { types { name } } }"
} | ConvertTo-Json

Invoke-RestMethod ``
    -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/graphql" ``
    -Method POST ``
    -Headers @{ Authorization = "Bearer `$token"; "Content-Type" = "application/json" } ``
    -Body `$body
"@

Write-Host $psCommand -ForegroundColor White
Write-Host "`n"

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  EXEMPLE DE QUERY GRAPHQL" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

$exampleQuery = @"
{
  idoc_shipments_gold(
    filter: {
      status: { eq: "IN_TRANSIT" }
      carrier_id: { eq: "CARRIER-FEDEX" }
    }
    orderBy: [shipment_date_DESC]
    first: 10
  ) {
    shipment_number
    shipment_date
    carrier_id
    carrier_name
    customer_name
    tracking_number
    status
    origin_city
    destination_city
    estimated_delivery
  }
}
"@

Write-Host $exampleQuery -ForegroundColor White
Write-Host "`n"

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  INTROSPECTION DU SCHEMA" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "Pour récupérer le schema complet auto-généré:`n" -ForegroundColor Yellow

$introspectionQuery = @"
query IntrospectionQuery {
  __schema {
    types {
      name
      kind
      fields {
        name
        type {
          name
          kind
          ofType {
            name
            kind
          }
        }
      }
    }
  }
}
"@

Write-Host $introspectionQuery -ForegroundColor White
Write-Host "`n"

Write-Host "Sauvegardé dans: api/graphql/schema/fabric-schema-introspection.graphql" -ForegroundColor Gray
$introspectionQuery | Out-File -FilePath "api\graphql\schema\fabric-schema-introspection.graphql" -Encoding UTF8

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  PROCHAINES ETAPES" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "1. ✅ Activer GraphQL API dans Fabric Portal (manuel)" -ForegroundColor Yellow
Write-Host "2. ✅ Configurer RLS sur les tables Gold (manuel)" -ForegroundColor Yellow
Write-Host "3. ⏸️  Tester l'introspection du schema" -ForegroundColor Yellow
Write-Host "4. ⏸️  Mettre à jour deploy-apim.ps1 avec l'endpoint Fabric" -ForegroundColor Yellow
Write-Host "5. ⏸️  Créer fabric-auth-passthrough.xml policy" -ForegroundColor Yellow
Write-Host "6. ⏸️  Déployer APIM avec le backend Fabric GraphQL" -ForegroundColor Yellow
Write-Host "7. ⏸️  Tester end-to-end avec Postman`n" -ForegroundColor Yellow

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "   fabric/GRAPHQL_API_SETUP.md - Guide complet" -ForegroundColor White
Write-Host "   api/PARTNER_API_IMPLEMENTATION_PLAN.md - Plan implementation`n" -ForegroundColor White

Write-Host "✅ Script termine. Suivez les instructions ci-dessus pour activer GraphQL API.`n" -ForegroundColor Green

# Ouvrir le Fabric Portal dans le navigateur
Write-Host "Ouverture du Lakehouse dans le navigateur..." -ForegroundColor Gray
Start-Process $lakehouseUrl
