# Add CORS Policy to all APIM APIs
# This allows browser-based applications to call the APIs

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-3pl-partner-api",
    
    [Parameter(Mandatory=$false)]
    [string]$ApimName = "apim-3pl-flt"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ADD CORS TO APIM APIS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "APIM Instance: $ApimName`n" -ForegroundColor Gray

# List of APIs to add CORS to
$apis = @(
    "graphql-api",
    "shipments-api", 
    "orders-api",
    "warehouse-api",
    "sla-api",
    "revenue-api"
)

Write-Host "Adding CORS policy to $($apis.Count) APIs...`n" -ForegroundColor Yellow

foreach ($apiId in $apis) {
    Write-Host "Processing API: $apiId" -ForegroundColor Cyan
    
    # CORS Policy XML
    $corsPolicy = @"
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

    try {
        # Set the policy
        az apim api policy create `
            --resource-group $ResourceGroup `
            --service-name $ApimName `
            --api-id $apiId `
            --xml-policy $corsPolicy `
            --output none
        
        Write-Host "  ✅ CORS policy added to $apiId" -ForegroundColor Green
        
    } catch {
        Write-Host "  ⚠️  Failed to add CORS to $apiId : $_" -ForegroundColor Yellow
        Write-Host "     This API may not exist yet" -ForegroundColor Gray
    }
    
    Write-Host ""
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CORS CONFIGURATION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Allowed origins:" -ForegroundColor Yellow
Write-Host "  - http://localhost:8000" -ForegroundColor White
Write-Host "  - http://127.0.0.1:8000" -ForegroundColor White
Write-Host "  - http://localhost:3000" -ForegroundColor White

Write-Host "`nAllowed methods: GET, POST, OPTIONS" -ForegroundColor Yellow
Write-Host "Allowed headers: *" -ForegroundColor Yellow
Write-Host "Credentials: Allowed`n" -ForegroundColor Yellow

Write-Host "You can now make API calls from the browser!`n" -ForegroundColor Green
