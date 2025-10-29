# ================================================================
# Script de configuration automatique d'Eventstream Fabric
# Configure la source Event Hub et la destination KQL Database
# ================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceId = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64",
    
    [Parameter(Mandatory=$false)]
    [string]$EventstreamId = "cb23a2a2-ad04-4b46-9616-d76e59a9a665",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubNamespace = "eh-idoc-flt8076.servicebus.windows.net",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubName = "idoc-events",
    
    [Parameter(Mandatory=$false)]
    [string]$ConsumerGroup = "fabric-consumer",
    
    [Parameter(Mandatory=$false)]
    [string]$KQLDatabaseName = "kqldbsapidoc"
)

Write-Host "🚀 Configuration automatique de l'Eventstream Fabric" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# ================================================================
# ÉTAPE 1: Créer la définition JSON avec source Event Hub
# ================================================================
Write-Host "`n📝 ÉTAPE 1: Création de la définition Eventstream avec source Event Hub..." -ForegroundColor Yellow

# Définition complète de l'Eventstream avec Event Hub source
$eventstreamDefinition = @{
    sources = @(
        @{
            name = "EventHub-SAP-IDocs"
            type = "AzureEventHub"
            properties = @{
                namespace = $EventHubNamespace
                eventHub = $EventHubName
                consumerGroup = $ConsumerGroup
                authenticationMode = "EntraID"
                dataFormat = "Json"
            }
        }
    )
    destinations = @(
        @{
            name = "KQL-SAP-Analysis"
            type = "KQLDatabase"
            properties = @{
                workspace = $WorkspaceId
                database = $KQLDatabaseName
                table = "idoc_raw"
                ingestionMode = "DirectIngestion"
                mappingName = "idoc_json_mapping"
            }
        }
    )
    streams = @(
        @{
            name = "DefaultStream"
            sourceRef = "EventHub-SAP-IDocs"
            destinationRef = "KQL-SAP-Analysis"
        }
    )
    operators = @()
    compatibilityLevel = "1.0"
} | ConvertTo-Json -Depth 10

Write-Host "✅ Définition JSON créée" -ForegroundColor Green

# ================================================================
# ÉTAPE 2: Encoder en Base64 pour l'API
# ================================================================
Write-Host "`n🔐 ÉTAPE 2: Encodage Base64 de la définition..." -ForegroundColor Yellow

$eventstreamJsonBytes = [System.Text.Encoding]::UTF8.GetBytes($eventstreamDefinition)
$eventstreamBase64 = [Convert]::ToBase64String($eventstreamJsonBytes)

# Propriétés de l'Eventstream
$propertiesJson = @{
    retentionTimeInDays = 1
    eventThroughputLevel = "Low"
} | ConvertTo-Json

$propertiesBytes = [System.Text.Encoding]::UTF8.GetBytes($propertiesJson)
$propertiesBase64 = [Convert]::ToBase64String($propertiesBytes)

# Platform metadata
$platformJson = @{
    '$schema' = "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json"
    metadata = @{
        type = "Eventstream"
        displayName = "SAPIdocIngest"
        description = "Eventstream for SAP IDoc ingestion from Azure Event Hub"
    }
    config = @{
        version = "2.0"
        logicalId = "00000000-0000-0000-0000-000000000000"
    }
} | ConvertTo-Json -Depth 10

$platformBytes = [System.Text.Encoding]::UTF8.GetBytes($platformJson)
$platformBase64 = [Convert]::ToBase64String($platformBytes)

Write-Host "✅ Encodage terminé" -ForegroundColor Green

# ================================================================
# ÉTAPE 3: Préparer le payload API
# ================================================================
Write-Host "`n📦 ÉTAPE 3: Préparation du payload API..." -ForegroundColor Yellow

$apiPayload = @{
    definition = @{
        parts = @(
            @{
                path = "eventstream.json"
                payload = $eventstreamBase64
                payloadType = "InlineBase64"
            },
            @{
                path = "eventstreamProperties.json"
                payload = $propertiesBase64
                payloadType = "InlineBase64"
            },
            @{
                path = ".platform"
                payload = $platformBase64
                payloadType = "InlineBase64"
            }
        )
    }
} | ConvertTo-Json -Depth 10

# Sauvegarder le payload pour debug
$debugPath = ".\fabric\eventstream\api-payload.json"
$apiPayload | Out-File -FilePath $debugPath -Encoding UTF8
Write-Host "✅ Payload sauvegardé dans: $debugPath" -ForegroundColor Green

# ================================================================
# ÉTAPE 4: Appel à l'API Fabric REST
# ================================================================
Write-Host "`n🌐 ÉTAPE 4: Mise à jour de l'Eventstream via API Fabric..." -ForegroundColor Yellow

$endpoint = "workspaces/$WorkspaceId/eventstreams/$EventstreamId/updateDefinition?updateMetadata=true"

Write-Host "Endpoint: $endpoint" -ForegroundColor Gray
Write-Host "Exécution de la commande fab api..." -ForegroundColor Gray

try {
    # Utiliser fab CLI pour faire l'appel API
    $tempPayloadPath = [System.IO.Path]::GetTempFileName()
    $apiPayload | Out-File -FilePath $tempPayloadPath -Encoding UTF8
    
    $result = fab api $endpoint -X POST -i $tempPayloadPath 2>&1
    
    Remove-Item -Path $tempPayloadPath -Force
    
    Write-Host "`nRésultat de l'API:" -ForegroundColor Cyan
    Write-Host $result
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ SUCCESS: Eventstream configuré avec succès!" -ForegroundColor Green
        Write-Host "`n📊 Prochaines étapes:" -ForegroundColor Cyan
        Write-Host "  1. Ouvrir le portail Fabric: https://app.fabric.microsoft.com" -ForegroundColor White
        Write-Host "  2. Naviguer vers le workspace 'SAP-IDoc-Fabric'" -ForegroundColor White
        Write-Host "  3. Ouvrir l'Eventstream 'SAPIdocIngest'" -ForegroundColor White
        Write-Host "  4. Cliquer sur 'Publish' pour activer le flux" -ForegroundColor White
        Write-Host "  5. Tester avec: cd simulator; python main.py" -ForegroundColor White
    } else {
        Write-Host "`n❌ ERREUR: La mise à jour a échoué" -ForegroundColor Red
        Write-Host "Code de sortie: $LASTEXITCODE" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n❌ ERREUR lors de l'appel API:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nVoir le payload de debug dans: $debugPath" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Configuration terminée" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
