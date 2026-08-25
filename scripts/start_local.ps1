Write-Host "[Start] Starting Jugaad App Local Dev Environment" -ForegroundColor Cyan

# Start Redis
Write-Host "[Redis] Starting Redis..." -ForegroundColor Green
docker compose -f "$PSScriptRoot\..\infrastructure\docker\docker-compose.yml" up -d

# Wait for Redis
Start-Sleep -Seconds 2

# Start FastAPI
Write-Host "[FastAPI] Starting FastAPI on port 8000..." -ForegroundColor Yellow
Set-Location -Path "$PSScriptRoot\..\apps\backend"
pip install -r requirements.txt -q

# Run python main.py in the background
$process = Start-Process python -ArgumentList "main.py" -NoNewWindow -PassThru

Write-Host ""
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host "[OK] Jugaad Local Dev Ready!" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host "  API:           http://localhost:8000"
Write-Host "  API Docs:      http://localhost:8000/docs"
Write-Host "  Health Check:  http://localhost:8000/health"
Write-Host "  Redis UI:      http://localhost:8081"
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host "  Flutter: Run with Android Emulator"
Write-Host "  Base URL set to: http://10.0.2.2:8000"
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C in this terminal or terminate the process to stop."

try {
    # Keep script open and wait for process or Ctrl+C
    $process | Wait-Process
} catch {
    Write-Host "Shutting down backend process..." -ForegroundColor Red
    Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
}
