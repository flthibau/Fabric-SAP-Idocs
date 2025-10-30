Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  3PL PARTNER API DEMO" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Starting server on http://localhost:8000..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray

Start-Sleep -Seconds 1
Start-Process "http://localhost:8000"

python -m http.server 8000
