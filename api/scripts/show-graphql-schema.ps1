<#
.SYNOPSIS
    Show all types in the GraphQL schema
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$GraphQLEndpoint = "https://ad53e54723dc46b0ab5f2acbaf0eec64.zad.graphql.fabric.microsoft.com/v1/workspaces/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/graphqlapis/2c0b9eba-4d4a-4a4b-b1c9-a49f0c14fc3f/graphql"
)

$ErrorActionPreference = "Stop"

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  SCHEMA GRAPHQL FABRIC - TYPES DISPONIBLES" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# Get token
$tokenResponse = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv

if ([string]::IsNullOrEmpty($tokenResponse)) {
    Write-Host "Failed to get token. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $tokenResponse"
    "Content-Type" = "application/json"
}

# Introspection query
$introspectionQueryText = 'query IntrospectionQuery { __schema { queryType { name } types { name kind description fields { name type { name kind } } } } }'

$introspectionQuery = @{
    query = $introspectionQueryText
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri $GraphQLEndpoint -Method Post -Headers $headers -Body $introspectionQuery
    
    if ($response.errors) {
        Write-Host "GraphQL errors:" -ForegroundColor Red
        $response.errors | ForEach-Object {
            Write-Host "  $($_.message)" -ForegroundColor Red
        }
        exit 1
    }
    
    $schema = $response.data.__schema
    $types = $schema.types
    
    Write-Host "Query Type: $($schema.queryType.name)" -ForegroundColor Yellow
    Write-Host "Total Types: $($types.Count)`n" -ForegroundColor Yellow
    
    Write-Host "OBJECT TYPES (Tables):" -ForegroundColor Cyan
    $objectTypes = $types | Where-Object { $_.kind -eq "OBJECT" -and $_.name -notlike "__*" } | Sort-Object name
    
    if ($objectTypes.Count -eq 0) {
        Write-Host "  AUCUNE TABLE EXPOSEE!" -ForegroundColor Red
    } else {
        $objectTypes | ForEach-Object {
            $fieldCount = if ($_.fields) { ($_.fields | Measure-Object).Count } else { 0 }
            Write-Host "  $($_.name) ($fieldCount fields)" -ForegroundColor Green
            
            if ($_.fields -and $fieldCount -gt 0) {
                $_.fields | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    - $($_.name): $($_.type.name)" -ForegroundColor Gray
                }
                if ($fieldCount -gt 5) {
                    Write-Host "    ... and $($fieldCount - 5) more fields" -ForegroundColor DarkGray
                }
            }
            Write-Host ""
        }
    }
    
    Write-Host "`nAUTRES TYPES:" -ForegroundColor Cyan
    $otherTypes = $types | Where-Object { $_.kind -ne "OBJECT" -and $_.name -notlike "__*" } | Sort-Object kind,name
    
    $otherTypes | Group-Object kind | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) types" -ForegroundColor Yellow
        $_.Group | ForEach-Object {
            Write-Host "    - $($_.name)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "RECHERCHE DES TABLES SILVER:" -ForegroundColor Yellow
    Write-Host "===============================================================================`n" -ForegroundColor Cyan
    
    $expectedTables = @("idoc_orders_silver", "idoc_shipments_silver", "idoc_warehouse_silver", "idoc_invoices_silver")
    $allTypeNames = $types | Select-Object -ExpandProperty name
    
    foreach ($table in $expectedTables) {
        $found = $allTypeNames -contains $table
        if ($found) {
            Write-Host "  $table TROUVE!" -ForegroundColor Green
        } else {
            Write-Host "  $table MANQUANT" -ForegroundColor Red
        }
    }
    
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "DIAGNOSTIC:" -ForegroundColor Yellow
    Write-Host "===============================================================================`n" -ForegroundColor Cyan
    
    if ($objectTypes.Count -eq 0) {
        Write-Host "AUCUNE table n'est exposee dans l'API GraphQL!" -ForegroundColor Red
        Write-Host "`nAction requise:" -ForegroundColor Yellow
        Write-Host "  1. Ouvrir Fabric Portal -> Workspace MngEnvMCAP396311" -ForegroundColor White
        Write-Host "  2. Ouvrir l'API GraphQL '3PL Partner API'" -ForegroundColor White
        Write-Host "  3. Aller dans Settings -> Data sources" -ForegroundColor White
        Write-Host "  4. Ajouter les 4 tables SILVER depuis l'Eventhouse" -ForegroundColor White
    } else {
        $foundCount = 0
        foreach ($table in $expectedTables) {
            if ($allTypeNames -contains $table) { $foundCount++ }
        }
        
        if ($foundCount -eq 4) {
            Write-Host "TOUTES les tables sont exposees!" -ForegroundColor Green
        } else {
            Write-Host "Seulement $foundCount/4 tables trouvees" -ForegroundColor Yellow
            Write-Host "Verifier la configuration dans Fabric Portal" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n===============================================================================`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
