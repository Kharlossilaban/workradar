# Test API dan Database Connection
# Script untuk memverifikasi apakah task benar-benar tersimpan di database

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WORKRADAR - DATABASE CONNECTION TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check Railway Server Status
Write-Host "Test 1: Checking Railway Server..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://workradar-production.up.railway.app/api/health" -Method GET
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Railway Server is ONLINE" -ForegroundColor Green
        Write-Host "   Response: $($response.Content)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Railway Server is OFFLINE or unreachable" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Check Local Server Status
Write-Host "Test 2: Checking Local Server..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/health" -Method GET
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Local Server is RUNNING" -ForegroundColor Green
        Write-Host "   Response: $($response.Content)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Local Server is NOT RUNNING" -ForegroundColor Red
    Write-Host "   (This is OK if you're using Railway production)" -ForegroundColor Gray
}
Write-Host ""

# Test 3: Check Environment Configuration
Write-Host "Test 3: Checking Flutter Environment Config..." -ForegroundColor Yellow
$envFile = "client\lib\core\config\environment.dart"
if (Test-Path $envFile) {
    $content = Get-Content $envFile -Raw
    if ($content -match "static const Environment _env = Environment\.(\w+);") {
        $env = $matches[1]
        Write-Host "✅ Environment Configuration Found" -ForegroundColor Green
        Write-Host "   Current Environment: $env" -ForegroundColor Cyan
        
        if ($env -eq "production") {
            Write-Host "   📍 API URL: https://workradar-production.up.railway.app/api" -ForegroundColor Gray
            Write-Host "   📦 Database: Railway MySQL (Cloud)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "⚠️  WARNING: Data saved to RAILWAY database, NOT local phpMyAdmin!" -ForegroundColor Yellow
        } elseif ($env -eq "development") {
            Write-Host "   📍 API URL: http://192.168.x.x:8080/api (or localhost)" -ForegroundColor Gray
            Write-Host "   📦 Database: Local MySQL (phpMyAdmin)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "❌ Environment file not found" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SUMMARY & RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Jika Environment = production:" -ForegroundColor White
Write-Host "   • Task tersimpan di Railway MySQL (cloud)" -ForegroundColor Gray
Write-Host "   • Task TIDAK akan muncul di local phpMyAdmin" -ForegroundColor Gray
Write-Host "   • Untuk melihat data: Connect ke Railway MySQL" -ForegroundColor Gray
Write-Host ""
Write-Host "📋 Jika Environment = development:" -ForegroundColor White
Write-Host "   • Task tersimpan di Local MySQL" -ForegroundColor Gray
Write-Host "   • Task AKAN muncul di local phpMyAdmin" -ForegroundColor Gray
Write-Host "   • Pastikan local server running" -ForegroundColor Gray
Write-Host ""
Write-Host "🔧 Untuk test dengan local phpMyAdmin:" -ForegroundColor Cyan
Write-Host "   1. Edit client\lib\core\config\environment.dart" -ForegroundColor Gray
Write-Host "   2. Change: Environment.production -> Environment.development" -ForegroundColor Gray
Write-Host "   3. Run local server: cd server; go run cmd/main.go" -ForegroundColor Gray
Write-Host "   4. Restart Flutter app" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 Untuk akses Railway MySQL:" -ForegroundColor Cyan
Write-Host "   1. Login ke https://railway.app" -ForegroundColor Gray
Write-Host "   2. Select project: workradar-production" -ForegroundColor Gray
Write-Host "   3. Open MySQL service" -ForegroundColor Gray
Write-Host "   4. Go to 'Data' tab or use MySQL client" -ForegroundColor Gray
Write-Host ""
