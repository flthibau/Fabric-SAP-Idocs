# Add CORS to GraphQL API via Azure REST API
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-3pl-partner-api",
    
    [Parameter(Mandatory=$false)]
    [string]$ApimName = "apim-3pl-flt",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiId = "graphql-partner-api"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ADD CORS TO GRAPHQL API" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Getting Azure subscription..." -ForegroundColor Yellow
$subscription = az account show --query id -o tsv

Write-Host "Subscription ID: $subscription" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "APIM: $ApimName" -ForegroundColor Gray
Write-Host "API ID: $ApiId`n" -ForegroundColor Gray

# CORS Policy
$policy = @"
<policies>
    <inbound>
        <base />
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>http://localhost:8000</origin>
                <origin>http://127.0.0.1:8000</origin>
                <origin>http://localhost:3000</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>PUT</method>
                <method>DELETE</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
            <expose-headers>
                <header>*</header>
            </expose-headers>
        </cors>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@

# Save to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$policy | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

Write-Host "Applying CORS policy..." -ForegroundColor Yellow

try {
    # Use az rest command
    $result = az rest `
        --method PUT `
        --uri "https://management.azure.com/subscriptions/$subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId/policies/policy?api-version=2021-08-01" `
        --headers "Content-Type=application/json" `
        --body "{`"properties`":{`"value`":`"$($policy -replace '"','\"' -replace "`r`n",'\n')`",`"format`":`"xml`"}}"
    
    Write-Host "`n✅ CORS policy successfully applied to $ApiId!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Failed to apply CORS policy" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    
    Write-Host "`n⚠️  Alternative: Add CORS manually in Azure Portal:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://portal.azure.com" -ForegroundColor White
    Write-Host "2. Navigate to: APIM > APIs > $ApiId > Inbound processing" -ForegroundColor White
    Write-Host "3. Add the CORS policy from the file: $tempFile" -ForegroundColor White
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TESTING CORS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Test from browser console:" -ForegroundColor Yellow
Write-Host @"
fetch('https://apim-3pl-flt.azure-api.net/graphql', {
  method: 'OPTIONS',
  headers: { 'Origin': 'http://localhost:8000' }
}).then(r => console.log('CORS Headers:', r.headers))
"@ -ForegroundColor Gray

Write-Host "`n"
