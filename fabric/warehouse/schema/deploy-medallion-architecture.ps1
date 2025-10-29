# ===================================================================
# DEPLOY MEDALLION ARCHITECTURE TO FABRIC EVENTHOUSE
# ===================================================================
# This script deploys all Silver and Gold layer components
# Usage: Run this in PowerShell after tables are created

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  MEDALLION ARCHITECTURE DEPLOYMENT" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$eventhouseUrl = "https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/f91aaea3-7889-4415-851c-f4258a2fff6b/query"

Write-Host "`n✅ PROGRESS SO FAR:" -ForegroundColor Green
Write-Host "   - Bronze layer: idoc_raw (existing)" -ForegroundColor White
Write-Host "   - Silver tables created (4 tables):" -ForegroundColor White
Write-Host "     • idoc_orders_silver" -ForegroundColor Gray
Write-Host "     • idoc_shipments_silver" -ForegroundColor Gray
Write-Host "     • idoc_warehouse_silver" -ForegroundColor Gray
Write-Host "     • idoc_invoices_silver" -ForegroundColor Gray

Write-Host "`n📋 NEXT STEPS - Manual Deployment:" -ForegroundColor Yellow
Write-Host "`nDue to the complexity of update policies and functions," -ForegroundColor White
Write-Host "you need to execute the following KQL scripts in Fabric Portal:" -ForegroundColor White

Write-Host "`n[1] COMPLETE SILVER LAYER CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   Open each file and execute in Fabric Query Editor:" -ForegroundColor White
Write-Host "   - create-silver-orders.kql (retention, function, update policy)" -ForegroundColor Gray
Write-Host "   - create-silver-shipments.kql" -ForegroundColor Gray
Write-Host "   - create-silver-warehouse.kql" -ForegroundColor Gray
Write-Host "   - create-silver-invoices.kql" -ForegroundColor Gray

Write-Host "`n[2] DEPLOY GOLD LAYER (Materialized Views):" -ForegroundColor Cyan
Write-Host "   Execute each Gold layer script:" -ForegroundColor White
Write-Host "   - create-gold-orders-summary.kql" -ForegroundColor Gray
Write-Host "   - create-gold-shipments-transit.kql" -ForegroundColor Gray
Write-Host "   - create-gold-warehouse-productivity.kql" -ForegroundColor Gray
Write-Host "   - create-gold-revenue-realtime.kql" -ForegroundColor Gray
Write-Host "   - create-gold-sla-performance.kql" -ForegroundColor Gray

Write-Host "`n[3] OPEN FABRIC PORTAL:" -ForegroundColor Cyan
Write-Host "   $eventhouseUrl" -ForegroundColor White

Write-Host "`n📂 DEPLOYMENT ORDER:" -ForegroundColor Yellow
Write-Host "`nExecute scripts in this exact order:" -ForegroundColor White

$scripts = @(
    "1. create-silver-orders.kql       (Skip table creation - already done)",
    "2. create-silver-shipments.kql    (Skip table creation - already done)",
    "3. create-silver-warehouse.kql    (Skip table creation - already done)",
    "4. create-silver-invoices.kql     (Skip table creation - already done)",
    "5. create-gold-orders-summary.kql",
    "6. create-gold-shipments-transit.kql",
    "7. create-gold-warehouse-productivity.kql",
    "8. create-gold-revenue-realtime.kql",
    "9. create-gold-sla-performance.kql"
)

foreach ($script in $scripts) {
    Write-Host "   $script" -ForegroundColor Gray
}

Write-Host "`n[!] IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "   - Tables are already created - skip .create table commands" -ForegroundColor White
Write-Host "   - Execute only: retention policies, functions, update policies" -ForegroundColor White
Write-Host "   - For Silver: Execute sections 2-5 of each script" -ForegroundColor White
Write-Host "   - For Gold: Execute complete scripts (materialized views)" -ForegroundColor White
Write-Host "   - Check for errors after each script execution" -ForegroundColor White

Write-Host "`n[>] QUICK START OPTION:" -ForegroundColor Cyan
Write-Host "`nOpen all scripts at once:" -ForegroundColor White

$scriptPath = "c:\Users\flthibau\Desktop\Fabric+SAP+Idocs\fabric\warehouse\schema"

Write-Host "`nOpening all KQL files..." -ForegroundColor Gray
code "$scriptPath\create-silver-orders.kql"
code "$scriptPath\create-silver-shipments.kql"
code "$scriptPath\create-silver-warehouse.kql"
code "$scriptPath\create-silver-invoices.kql"
code "$scriptPath\create-gold-orders-summary.kql"
code "$scriptPath\create-gold-shipments-transit.kql"
code "$scriptPath\create-gold-warehouse-productivity.kql"
code "$scriptPath\create-gold-revenue-realtime.kql"
code "$scriptPath\create-gold-sla-performance.kql"

Write-Host "`n[OK] All scripts opened in VS Code" -ForegroundColor Green
Write-Host "     Copy content to Fabric Portal and execute" -ForegroundColor White

Write-Host "`n[WEB] Opening Fabric Portal..." -ForegroundColor Gray
Start-Process $eventhouseUrl

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  READY TO DEPLOY!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "`nAfter deployment, verify with:" -ForegroundColor White
Write-Host "  .show tables | count    // Should show 10 tables" -ForegroundColor Gray
Write-Host "  .show materialized-views | count  // Should show 5 views" -ForegroundColor Gray
Write-Host "`n" -ForegroundColor White
