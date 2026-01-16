# Script untuk capture logs dari Android device
# Gunakan ini untuk debug force close issue

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WORKRADAR - LOG CAPTURE TOOL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if device connected
Write-Host "Checking connected devices..." -ForegroundColor Yellow
adb devices
Write-Host ""

# Check if authorized
$devices = adb devices | Select-String "device$"
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No authorized device found!" -ForegroundColor Red
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "  1. Connect your Android device via USB" -ForegroundColor Yellow
    Write-Host "  2. Enable USB Debugging in Developer Options" -ForegroundColor Yellow
    Write-Host "  3. Authorize the connection on your device" -ForegroundColor Yellow
    exit 1
}

Write-Host "Device found! Starting log capture..." -ForegroundColor Green
Write-Host ""
Write-Host "INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host "  1. This will clear old logs and start fresh" -ForegroundColor White
Write-Host "  2. Perform your test on the device:" -ForegroundColor White
Write-Host "     - Open app" -ForegroundColor White
Write-Host "     - Login with Google" -ForegroundColor White
Write-Host "     - Force close app (swipe from recent apps)" -ForegroundColor White
Write-Host "     - Reopen app" -ForegroundColor White
Write-Host "  3. Press Ctrl+C here when done" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to start capturing logs..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# Clear old logs
Write-Host "Clearing old logs..." -ForegroundColor Yellow
adb logcat -c

# Start capturing logs with filters
Write-Host "Capturing logs (Press Ctrl+C to stop)..." -ForegroundColor Green
Write-Host "Looking for: AUTH CHECK, Token saved, Error, flutter, workradar" -ForegroundColor Cyan
Write-Host ""

# Capture logs and filter
adb logcat | Select-String -Pattern "AUTH CHECK|Token saved|Error saving|isLoggedIn|flutter|workradar|SecureStorage|GoogleAuth" -CaseSensitive:$false
