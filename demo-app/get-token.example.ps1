param([string]$ServicePrincipal = 'fedex')

# IMPORTANT: Copy this file to get-token.ps1 and replace the secrets with your actual Service Principal secrets

$sp = @{
    fedex = @{ Name = "FedEx"; AppId = "94a9edcc-7a22-4d89-b001-799e8414711a"; Secret = "YOUR_FEDEX_SECRET_HERE" }
    warehouse = @{ Name = "Warehouse"; AppId = "1de3dcee-f7eb-4701-8cd9-ed65f3792fe0"; Secret = "YOUR_WAREHOUSE_SECRET_HERE" }
    acme = @{ Name = "ACME"; AppId = "a3e88682-8bef-4712-9cc5-031d109cefca"; Secret = "YOUR_ACME_SECRET_HERE" }
}[$ServicePrincipal]

$tenant = "38de1b20-8309-40ba-9584-5d9fcb7203b4"
$resource = "https://analysis.windows.net/powerbi/api"

Write-Host "`nGetting token for $($ServicePrincipal)..." -ForegroundColor Cyan

# Get Fabric token
$body = @{
    grant_type = "client_credentials"
    client_id = $sp.AppId
    client_secret = $sp.Secret
    scope = "$resource/.default"
}

try {
    $response = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" `
        -Body $body `
        -ErrorAction Stop

    $token = $response.access_token
    
    Write-Host "Token acquired successfully!" -ForegroundColor Green
    Write-Host "Expires in: $($response.expires_in) seconds" -ForegroundColor Gray
    Write-Host "Token copied to clipboard" -ForegroundColor Yellow
    
    # Copy to clipboard
    Set-Clipboard -Value $token
    
    Write-Host "`nToken ready to paste in browser!" -ForegroundColor Cyan

} catch {
    Write-Host "Error getting token: $_" -ForegroundColor Red
}
