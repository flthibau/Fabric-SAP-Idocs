# Monitor Eventstream Status
# Verifie le statut de l'Eventstream et affiche les metriques

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "SAP-IDoc-Fabric",
    
    [Parameter(Mandatory=$false)]
    [string]$EventstreamName = "SAPIdocIngestAuto",
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshSeconds = 5,
    
    [Parameter(Mandatory=$false)]
    [switch]$Continuous
)

function Get-EventstreamStatus {
    param($WorkspaceId, $EventstreamId)
    
    try {
        $result = fab api "workspaces/$WorkspaceId/eventstreams/$EventstreamId" | ConvertFrom-Json
        return $result.text
    } catch {
        Write-Host "Erreur recuperation status: $_" -ForegroundColor Red
        return $null
    }
}

function Show-Status {
    param($Status)
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  Eventstream Status - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    if ($Status) {
        Write-Host "`nEventstream:" -ForegroundColor Yellow
        Write-Host "  Name: $($Status.displayName)" -ForegroundColor White
        Write-Host "  ID: $($Status.id)" -ForegroundColor White
        Write-Host "  Type: $($Status.type)" -ForegroundColor White
        Write-Host "  Description: $($Status.description)" -ForegroundColor White
    } else {
        Write-Host "`n[ERROR] Impossible de recuperer le status" -ForegroundColor Red
    }
    
    Write-Host "`nPour voir les details complets dans le portal:" -ForegroundColor Cyan
    Write-Host "  https://app.fabric.microsoft.com" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceName" -ForegroundColor White
    Write-Host "  Eventstream: $EventstreamName" -ForegroundColor White
}

# Main
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  Monitoring Eventstream" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan

# Get Workspace ID
Write-Host "`nRecuperation Workspace ID..." -ForegroundColor Cyan
$workspacesResult = fab api "workspaces" | ConvertFrom-Json
$workspace = $workspacesResult.text.value | Where-Object { $_.displayName -eq $WorkspaceName }

if (!$workspace) {
    Write-Host "[ERROR] Workspace '$WorkspaceName' introuvable!" -ForegroundColor Red
    exit 1
}
$workspaceId = $workspace.id
Write-Host "  [OK] Workspace ID: $workspaceId" -ForegroundColor Green

# Get Eventstream ID
Write-Host "Recuperation Eventstream ID..." -ForegroundColor Cyan
$eventstreamResult = fab api "workspaces/$workspaceId/eventstreams" | ConvertFrom-Json
$eventstream = $eventstreamResult.text.value | Where-Object { $_.displayName -eq $EventstreamName }

if (!$eventstream) {
    Write-Host "[ERROR] Eventstream '$EventstreamName' introuvable!" -ForegroundColor Red
    exit 1
}
$eventstreamId = $eventstream.id
Write-Host "  [OK] Eventstream ID: $eventstreamId" -ForegroundColor Green

if ($Continuous) {
    Write-Host "`nMode continu active (Ctrl+C pour arreter)" -ForegroundColor Yellow
    Write-Host "Refresh toutes les $RefreshSeconds secondes" -ForegroundColor Yellow
    
    while ($true) {
        $status = Get-EventstreamStatus -WorkspaceId $workspaceId -EventstreamId $eventstreamId
        Show-Status -Status $status
        
        Write-Host "`nProchaine mise a jour dans $RefreshSeconds secondes..." -ForegroundColor Gray
        Start-Sleep -Seconds $RefreshSeconds
        Clear-Host
    }
} else {
    $status = Get-EventstreamStatus -WorkspaceId $workspaceId -EventstreamId $eventstreamId
    Show-Status -Status $status
    
    Write-Host "`n[INFO] Utilisez -Continuous pour monitoring en temps reel" -ForegroundColor Cyan
}

Write-Host "`n" -NoNewline
