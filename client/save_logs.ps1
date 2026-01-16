# Script untuk save logs ke file (bukan real-time)
# Berguna jika Anda ingin save logs dan share

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WORKRADAR - SAVE LOGS TO FILE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check device
$devices = adb devices | Select-String "device$"
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No device connected!" -ForegroundColor Red
    exit 1
}

# Create logs folder
$logsDir = "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# Generate filename with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$logsDir\workradar_$timestamp.log"

Write-Host "Device connected!" -ForegroundColor Green
Write-Host ""
Write-Host "INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host "  1. Clear old logs and start capturing" -ForegroundColor White
Write-Host "  2. Perform your test (login, force close, reopen)" -ForegroundColor White
Write-Host "  3. Wait 10 seconds after test" -ForegroundColor White
Write-Host "  4. Logs will be saved to: $logFile" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# Clear old logs
Write-Host "Clearing old logs..." -ForegroundColor Yellow
adb logcat -c

Write-Host "Ready! Perform your test now..." -ForegroundColor Green
Write-Host "Waiting 60 seconds for you to complete the test..." -ForegroundColor Yellow
Write-Host ""

# Capture logs for 60 seconds
$job = Start-Job -ScriptBlock {
    param($seconds)
    adb logcat | Select-String -Pattern "AUTH CHECK|Token saved|Error saving|isLoggedIn|flutter|workradar|SecureStorage|GoogleAuth" -CaseSensitive:$false
} -ArgumentList 60

# Wait 60 seconds or until user presses key
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout -and $job.State -eq "Running") {
    Write-Host "`rCapturing... $($timeout - $elapsed) seconds remaining (Press Enter to stop early)" -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    $elapsed++
    
    # Check if Enter pressed
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "Enter") {
            Write-Host ""
            Write-Host "Stopping capture early..." -ForegroundColor Yellow
            break
        }
    }
}

Write-Host ""
Write-Host ""

# Get results
$logs = Receive-Job -Job $job
Stop-Job -Job $job
Remove-Job -Job $job

# Save to file
if ($logs) {
    $logs | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host "✅ Logs saved to: $logFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Found $($logs.Count) relevant log entries" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening log file..." -ForegroundColor Yellow
    Start-Process notepad.exe -ArgumentList $logFile
} else {
    Write-Host "⚠️  No relevant logs found!" -ForegroundColor Yellow
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - App not installed or not running" -ForegroundColor White
    Write-Host "  - Test not performed" -ForegroundColor White
    Write-Host "  - No debug messages generated" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
