# Deploy Medallion Architecture to Fabric Eventhouse
# Tables are already created, now open scripts for manual execution

$scriptPath = "c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\fabric\warehouse\schema"
$portalUrl = "https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/f91aaea3-7889-4415-851c-f4258a2fff6b/query"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MEDALLION ARCHITECTURE DEPLOYMENT" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nTables Created:" -ForegroundColor Green
Write-Host "  idoc_orders_silver"
Write-Host "  idoc_shipments_silver"
Write-Host "  idoc_warehouse_silver"
Write-Host "  idoc_invoices_silver"

Write-Host "`nOpening KQL scripts..." -ForegroundColor Yellow

code "$scriptPath\create-silver-orders.kql"
code "$scriptPath\create-silver-shipments.kql"
code "$scriptPath\create-silver-warehouse.kql"
code "$scriptPath\create-silver-invoices.kql"
code "$scriptPath\create-gold-orders-summary.kql"
code "$scriptPath\create-gold-shipments-transit.kql"
code "$scriptPath\create-gold-warehouse-productivity.kql"
code "$scriptPath\create-gold-revenue-realtime.kql"
code "$scriptPath\create-gold-sla-performance.kql"

Write-Host "`nOpening Fabric Portal..." -ForegroundColor Yellow
Start-Process $portalUrl

Write-Host "`nDEPLOYMENT INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host "1. Silver Layer: Copy sections 2-5 from each create-silver-*.kql"
Write-Host "2. Gold Layer: Copy complete content from create-gold-*.kql"  
Write-Host "3. Execute in Fabric Portal Query Editor"
Write-Host "4. Verify: .show tables | count (should be 5)"
Write-Host "5. Verify: .show materialized-views | count (should be 5)"
Write-Host "`nDone!" -ForegroundColor Green
