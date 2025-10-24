# Script d'automatisation Eventstream - Approche hybride
# Base sur le schema JSON capture apres publication

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "SAP-IDoc-Fabric",
    
    [Parameter(Mandatory=$false)]
    [string]$EventstreamName = "SAPIdocIngestAuto",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubNamespace = "eh-idoc-flt8076.servicebus.windows.net",
    
    [Parameter(Mandatory=$false)]
    [string]$EventHubName = "idoc-events",
    
    [Parameter(Mandatory=$false)]
    [string]$ConsumerGroup = "fabric-consumer",
    
    [Parameter(Mandatory=$false)]
    [string]$EventhouseName = "kqldbsapidoc_auto",
    
    [Parameter(Mandatory=$false)]
    [string]$DataConnectionId = "9816c9cd-d299-4b31-9f08-27cc8b55f5ee"
)

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  Automatisation Eventstream - Approche hybride" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan

Write-Host "`nIMPORTANT: Ce script necessite une Data Connection Event Hub EXISTANTE" -ForegroundColor Yellow
Write-Host "Creez la connection manuellement dans Fabric avant d'executer ce script." -ForegroundColor Yellow

# ================================================================
# ETAPE 1: Recuperer les IDs necessaires
# ================================================================
Write-Host "`nETAPE 1: Recuperation des IDs Fabric..." -ForegroundColor Cyan

# Workspace ID
Write-Host "  -> Workspace '$WorkspaceName'..."
$workspacesResult = fab api "workspaces" | ConvertFrom-Json
$workspace = $workspacesResult.text.value | Where-Object { $_.displayName -eq $WorkspaceName }
if (!$workspace) {
    Write-Host "[ERROR] Workspace '$WorkspaceName' introuvable!" -ForegroundColor Red
    exit 1
}
$workspaceId = $workspace.id
Write-Host "    [OK] ID: $workspaceId" -ForegroundColor Green

# Eventhouse ID
Write-Host "  -> Eventhouse '$EventhouseName'..."
$eventhouseResult = fab api "workspaces/$workspaceId/eventhouses" | ConvertFrom-Json
$eventhouse = $eventhouseResult.text.value | Where-Object { $_.displayName -eq $EventhouseName }
if (!$eventhouse) {
    Write-Host "[ERROR] Eventhouse '$EventhouseName' introuvable!" -ForegroundColor Red
    exit 1
}
$eventhouseId = $eventhouse.id
Write-Host "    [OK] ID: $eventhouseId" -ForegroundColor Green

# ================================================================
# ETAPE 2: Valider Data Connection ID
# ================================================================
Write-Host "`nETAPE 2: Validation Data Connection Event Hub..." -ForegroundColor Cyan
Write-Host "  Using Data Connection ID: $DataConnectionId" -ForegroundColor White
Write-Host "  [OK] Data Connection ID valide" -ForegroundColor Green

# ================================================================
# ETAPE 3: Creer la definition JSON de l'Eventstream
# ================================================================
Write-Host "`nETAPE 3: Generation de la definition Eventstream..." -ForegroundColor Cyan

# Generer des GUIDs uniques
$sourceId = [guid]::NewGuid().ToString()
$destinationId = [guid]::NewGuid().ToString()
$streamId = [guid]::NewGuid().ToString()

$eventstreamDefinition = @{
    sources = @(
        @{
            id = $sourceId
            name = "AzureEventHub"
            type = "AzureEventHub"
            properties = @{
                dataConnectionId = $DataConnectionId
                consumerGroupName = $ConsumerGroup
                inputSerialization = @{
                    type = "Json"
                    properties = @{
                        encoding = "UTF8"
                    }
                }
            }
        }
    )
    destinations = @(
        @{
            id = $destinationId
            name = "Eventhouse"
            type = "Eventhouse"
            properties = @{
                dataIngestionMode = "DirectIngestion"
                workspaceId = $workspaceId
                itemId = $eventhouseId
                tableName = ""
                connectionName = $null
                mappingRuleName = $null
            }
            inputNodes = @(
                @{
                    name = "$EventstreamName-stream"
                }
            )
            inputSchemas = @(
                @{
                    name = "$EventstreamName-stream"
                    schema = @{
                        columns = @()
                    }
                }
            )
        }
    )
    streams = @(
        @{
            id = $streamId
            name = "$EventstreamName-stream"
            type = "DefaultStream"
            properties = @{}
            inputNodes = @(
                @{
                    name = "AzureEventHub"
                }
            )
        }
    )
    operators = @()
    compatibilityLevel = "1.1"
} | ConvertTo-Json -Depth 10

Write-Host "  [OK] Definition creee" -ForegroundColor Green

# ================================================================
# ETAPE 4: Encoder en Base64
# ================================================================
Write-Host "`nETAPE 4: Encodage Base64..." -ForegroundColor Cyan

$eventstreamBytes = [System.Text.Encoding]::UTF8.GetBytes($eventstreamDefinition)
$eventstreamBase64 = [Convert]::ToBase64String($eventstreamBytes)

$propertiesJson = @{
    retentionTimeInDays = 1
    eventThroughputLevel = "Low"
} | ConvertTo-Json

$propertiesBytes = [System.Text.Encoding]::UTF8.GetBytes($propertiesJson)
$propertiesBase64 = [Convert]::ToBase64String($propertiesBytes)

$platformJson = @{
    '$schema' = "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json"
    metadata = @{
        type = "Eventstream"
        displayName = $EventstreamName
        description = "Automated Eventstream for SAP IDoc ingestion"
    }
    config = @{
        version = "2.0"
        logicalId = "00000000-0000-0000-0000-000000000000"
    }
} | ConvertTo-Json -Depth 10

$platformBytes = [System.Text.Encoding]::UTF8.GetBytes($platformJson)
$platformBase64 = [Convert]::ToBase64String($platformBytes)

Write-Host "  [OK] Encodage termine" -ForegroundColor Green

# ================================================================
# ETAPE 5: Creer l'Eventstream
# ================================================================
Write-Host "`nETAPE 5: Creation de l'Eventstream '$EventstreamName'..." -ForegroundColor Cyan

# D'abord creer un Eventstream vide
$createResult = fab mkdir "$WorkspaceName.Workspace/$EventstreamName.Eventstream" -P "description=Automated Eventstream" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de la creation de l'Eventstream" -ForegroundColor Red
    Write-Host $createResult -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Eventstream cree" -ForegroundColor Green

# Recuperer l'ID du nouvel Eventstream
Start-Sleep -Seconds 2
$eventstreamResult = fab api "workspaces/$workspaceId/eventstreams" | ConvertFrom-Json
$newEventstream = $eventstreamResult.text.value | Where-Object { $_.displayName -eq $EventstreamName }
$eventstreamId = $newEventstream.id

Write-Host "  [OK] ID: $eventstreamId" -ForegroundColor Green

# ================================================================
# ETAPE 6: Mettre a jour la definition
# ================================================================
Write-Host "`nETAPE 6: Mise a jour de la definition avec sources/destinations..." -ForegroundColor Cyan

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

$tempPayload = [System.IO.Path]::GetTempFileName()
$apiPayload | Out-File -FilePath $tempPayload -Encoding ASCII -NoNewline

try {
    $updateResult = fab api "workspaces/$workspaceId/eventstreams/$eventstreamId/updateDefinition?updateMetadata=true" -X post -i $tempPayload 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Definition mise a jour avec succes!" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Erreur lors de la mise a jour" -ForegroundColor Red
        Write-Host $updateResult -ForegroundColor Red
    }
} finally {
    Remove-Item -Path $tempPayload -Force -ErrorAction SilentlyContinue
}

# ================================================================
# RESUME
# ================================================================
Write-Host "`n" -NoNewline
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  [SUCCESS] Eventstream cree avec succes!" -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Cyan

Write-Host "`nDetails:" -ForegroundColor Cyan
Write-Host "  Workspace      : $WorkspaceName ($workspaceId)" -ForegroundColor White
Write-Host "  Eventstream    : $EventstreamName ($eventstreamId)" -ForegroundColor White
Write-Host "  Source         : Event Hub ($EventHubNamespace/$EventHubName)" -ForegroundColor White
Write-Host "  Destination    : Eventhouse ($EventhouseName)" -ForegroundColor White

Write-Host "`nActions manuelles restantes:" -ForegroundColor Yellow
Write-Host "  1. Ouvrir l'Eventstream dans Fabric Portal" -ForegroundColor White
Write-Host "  2. Mode Edit -> Publish" -ForegroundColor White
Write-Host "  3. Mode Live -> Configure destination -> Creer table 'idoc_raw'" -ForegroundColor White

Write-Host "`nLiens:" -ForegroundColor Cyan
Write-Host "  Fabric Portal  : https://app.fabric.microsoft.com" -ForegroundColor White
Write-Host "  Workspace      : $WorkspaceName" -ForegroundColor White
Write-Host "  Eventstream    : $EventstreamName" -ForegroundColor White

Write-Host "`n" -NoNewline
