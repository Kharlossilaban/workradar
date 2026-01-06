# Workradar Backend API - Testing Script (PowerShell)

# Test 1: Health Check
Write-Host "=== Test 1: Health Check ===" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8080/api/health" -Method GET
    Write-Host "✅ Health check passed" -ForegroundColor Green
    $health | ConvertTo-Json
} catch {
    Write-Host "❌ Health check failed: $_" -ForegroundColor Red
}

# Test 2: User Registration
Write-Host "`n=== Test 2: User Registration ===" -ForegroundColor Cyan
try {
    $registerBody = @{
        email = "testuser@gmail.com"
        username = "Test User"
        password = "password123"
    } | ConvertTo-Json
    
    $registerResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/register" -Method POST -Headers @{"Content-Type"="application/json"} -Body $registerBody
    Write-Host "✅ Registration successful" -ForegroundColor Green
    $token = $registerResponse.token
    $registerResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Registration failed: $_" -ForegroundColor Red
}

# Test 3: User Login
Write-Host "`n=== Test 3: User Login ===" -ForegroundColor Cyan
try {
    $loginBody = @{
        email = "testuser@gmail.com"
        password = "password123"
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Headers @{"Content-Type"="application/json"} -Body $loginBody
    Write-Host "✅ Login successful" -ForegroundColor Green
    $token = $loginResponse.token
    $loginResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Login failed: $_" -ForegroundColor Red
}

# Test 4: Get Profile
Write-Host "`n=== Test 4: Get Profile ===" -ForegroundColor Cyan
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $token"
    }
    $profileResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/profile" -Method GET -Headers $headers
    Write-Host "✅ Get profile successful" -ForegroundColor Green
    $profileResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Get profile failed: $_" -ForegroundColor Red
}

# Test 5: Update Work Hours
Write-Host "`n=== Test 5: Update Work Hours ===" -ForegroundColor Cyan
try {
    $workHoursBody = @{
        work_days = @{
            "0" = @{ start = "09:00"; end = "17:00"; is_work_day = $true }
            "1" = @{ start = "09:00"; end = "17:00"; is_work_day = $true }
            "2" = @{ start = "09:00"; end = "17:00"; is_work_day = $true }
            "3" = @{ start = "09:00"; end = "17:00"; is_work_day = $true }
            "4" = @{ start = "09:00"; end = "17:00"; is_work_day = $true }
            "5" = @{ start = $null; end = $null; is_work_day = $false }
            "6" = @{ start = $null; end = $null; is_work_day = $false }
        }
    } | ConvertTo-Json -Depth 5
    
    $workHoursResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/profile/work-hours" -Method PUT -Headers $headers -Body $workHoursBody
    Write-Host "✅ Work hours updated" -ForegroundColor Green
    $workHoursResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Work hours update failed: $_" -ForegroundColor Red
}

# Test 6: Get Categories
Write-Host "`n=== Test 6: Get Categories ===" -ForegroundColor Cyan
try {
    $categoriesResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/categories" -Method GET -Headers $headers
    Write-Host "✅ Get categories successful" -ForegroundColor Green
    $categoriesResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Get categories failed: $_" -ForegroundColor Red
}

# Test 7: Get Holidays
Write-Host "`n=== Test 7: Get Holidays ===" -ForegroundColor Cyan
try {
    $holidaysResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/holidays" -Method GET -Headers $headers
    Write-Host "✅ Get holidays successful" -ForegroundColor Green
    Write-Host "Total holidays: $($holidaysResponse.holidays.Count)" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Get holidays failed: $_" -ForegroundColor Red
}

# Test 8: Create Personal Holiday
Write-Host "`n=== Test 8: Create Personal Holiday ===" -ForegroundColor Cyan
try {
    $holidayBody = @{
        name = "Cuti Pribadi Test"
        date = "2026-03-15"
        description = "Test personal holiday"
    } | ConvertTo-Json
    
    $createHolidayResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/holidays/personal" -Method POST -Headers $headers -Body $holidayBody
    Write-Host "✅ Personal holiday created" -ForegroundColor Green
    $createHolidayResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Create personal holiday failed: $_" -ForegroundColor Red
}

# Test 9: Create Leave
Write-Host "`n=== Test 9: Create Leave ===" -ForegroundColor Cyan
try {
    $leaveBody = @{
        date = "2026-04-10"
        reason = "Sakit"
    } | ConvertTo-Json
    
    $createLeaveResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/leaves" -Method POST -Headers $headers -Body $leaveBody
    Write-Host "✅ Leave created" -ForegroundColor Green
    $createLeaveResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Create leave failed: $_" -ForegroundColor Red
}

# Test 10: Get Leaves
Write-Host "`n=== Test 10: Get Leaves ===" -ForegroundColor Cyan
try {
    $leavesResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/leaves" -Method GET -Headers $headers
    Write-Host "✅ Get leaves successful" -ForegroundColor Green
    $leavesResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Get leaves failed: $_" -ForegroundColor Red
}

# Test 11: Get Bot Messages
Write-Host "`n=== Test 11: Get Bot Messages ===" -ForegroundColor Cyan
try {
    $messagesResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/messages" -Method GET -Headers $headers
    Write-Host "✅ Get messages successful" -ForegroundColor Green
    $messagesResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Get messages failed: $_" -ForegroundColor Red
}

# Test 12: Get Workload
Write-Host "`n=== Test 12: Get Workload (Daily) ===" -ForegroundColor Cyan
try {
    $workloadResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/workload?period=daily" -Method GET -Headers $headers
    Write-Host "✅ Get workload successful" -ForegroundColor Green
    $workloadResponse | ConvertTo-Json
} catch {
    Write-Host "❌ Get workload failed: $_" -ForegroundColor Red
}

Write-Host "`n=== Testing Complete ===" -ForegroundColor Green
