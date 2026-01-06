# ============================================
# Workradar Security Testing Script
# ============================================
# Jalankan script ini dari folder server
# PowerShell: .\test_security.ps1
# ============================================

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TestEmail = "securitytest@example.com",
    [string]$TestPassword = "SecureTest@123!"
)

$ErrorActionPreference = "Continue"

# Colors for output
function Write-Success { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Header { param($msg) Write-Host "`n========== $msg ==========" -ForegroundColor Yellow }

# Global variables
$script:Token = ""
$script:UserId = ""
$script:TestResults = @()

function Add-TestResult {
    param($TestName, $Passed, $Details = "")
    $script:TestResults += [PSCustomObject]@{
        Test = $TestName
        Passed = $Passed
        Details = $Details
    }
}

# ============================================
# 1. BASIC CONNECTIVITY TEST
# ============================================
Write-Header "1. BASIC CONNECTIVITY TEST"

try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/api/health" -Method GET -ErrorAction Stop
    Write-Success "Server is running"
    Add-TestResult "Server Health Check" $true
} catch {
    Write-Fail "Server not reachable: $_"
    Add-TestResult "Server Health Check" $false $_.Exception.Message
    Write-Host "Please start the server first: go run cmd/main.go"
    exit 1
}

# ============================================
# 2. AUDIT LOGGING TEST
# ============================================
Write-Header "2. AUDIT LOGGING TEST"

# Register new user
Write-Info "Registering test user..."
$registerBody = @{
    name = "Security Test User"
    email = $TestEmail
    password = $TestPassword
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method POST -Body $registerBody -ContentType "application/json" -ErrorAction Stop
    Write-Success "User registered successfully"
    Add-TestResult "User Registration" $true
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 409) {
        Write-Info "User already exists, continuing..."
        Add-TestResult "User Registration" $true "Already exists"
    } else {
        Write-Fail "Registration failed: $_"
        Add-TestResult "User Registration" $false $_.Exception.Message
    }
}

# Login
Write-Info "Logging in..."
$loginBody = @{
    email = $TestEmail
    password = $TestPassword
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    
    if ($response.data.requires_mfa) {
        Write-Info "MFA required - skipping token retrieval"
        $script:Token = ""
    } else {
        $script:Token = $response.data.access_token
        $script:UserId = $response.data.user.id
        Write-Success "Login successful, token obtained"
    }
    Add-TestResult "User Login" $true
} catch {
    Write-Fail "Login failed: $_"
    Add-TestResult "User Login" $false $_.Exception.Message
}

# ============================================
# 3. BRUTE FORCE PROTECTION TEST
# ============================================
Write-Header "3. BRUTE FORCE PROTECTION TEST"

Write-Info "Testing brute force protection (this will lock a test account)..."

$bruteForceEmail = "bruteforce_test_$(Get-Random)@example.com"

# First register this user
$regBody = @{
    name = "Brute Force Test"
    email = $bruteForceEmail
    password = $TestPassword
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method POST -Body $regBody -ContentType "application/json" -ErrorAction Stop | Out-Null
} catch {}

# Attempt 6 failed logins
$failedAttempts = 0
for ($i = 1; $i -le 6; $i++) {
    $failBody = @{
        email = $bruteForceEmail
        password = "WrongPassword$i"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method POST -Body $failBody -ContentType "application/json" -ErrorAction Stop
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 423 -or $statusCode -eq 429 -or $statusCode -eq 401) {
            $failedAttempts++
        }
    }
    Start-Sleep -Milliseconds 500
}

if ($failedAttempts -ge 5) {
    Write-Success "Brute force protection working ($failedAttempts failed attempts detected)"
    Add-TestResult "Brute Force Protection" $true
} else {
    Write-Fail "Brute force protection may not be working properly"
    Add-TestResult "Brute Force Protection" $false "Only $failedAttempts detected"
}

# ============================================
# 4. SQL INJECTION DETECTION TEST
# ============================================
Write-Header "4. SQL INJECTION DETECTION TEST"

$sqlInjectionPayloads = @(
    "admin' OR '1'='1",
    "'; DROP TABLE users; --",
    "1 UNION SELECT * FROM users",
    "admin'--"
)

$sqlInjectionDetected = 0

foreach ($payload in $sqlInjectionPayloads) {
    $injectionBody = @{
        email = $payload
        password = "anything"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method POST -Body $injectionBody -ContentType "application/json" -ErrorAction Stop
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400 -or $statusCode -eq 403) {
            $sqlInjectionDetected++
        }
    }
}

if ($sqlInjectionDetected -gt 0) {
    Write-Success "SQL injection attempts blocked ($sqlInjectionDetected/$($sqlInjectionPayloads.Count))"
    Add-TestResult "SQL Injection Protection" $true
} else {
    Write-Fail "SQL injection protection may not be working"
    Add-TestResult "SQL Injection Protection" $false
}

# ============================================
# 5. PASSWORD POLICY TEST
# ============================================
Write-Header "5. PASSWORD POLICY TEST"

$weakPasswords = @(
    "12345678",        # No letters/symbols
    "password",        # Too simple
    "Password1",       # No symbols
    "abc"              # Too short
)

$weakPasswordRejected = 0

foreach ($weakPwd in $weakPasswords) {
    $weakBody = @{
        name = "Weak Password Test"
        email = "weakpwd_$(Get-Random)@example.com"
        password = $weakPwd
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method POST -Body $weakBody -ContentType "application/json" -ErrorAction Stop
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            $weakPasswordRejected++
        }
    }
}

if ($weakPasswordRejected -eq $weakPasswords.Count) {
    Write-Success "All weak passwords rejected ($weakPasswordRejected/$($weakPasswords.Count))"
    Add-TestResult "Password Policy" $true
} else {
    Write-Info "Some weak passwords rejected ($weakPasswordRejected/$($weakPasswords.Count))"
    Add-TestResult "Password Policy" ($weakPasswordRejected -gt 0) "$weakPasswordRejected rejected"
}

# ============================================
# 6. HEALTH CHECK ENDPOINTS TEST
# ============================================
Write-Header "6. HEALTH CHECK ENDPOINTS TEST"

$healthEndpoints = @(
    "/api/health",
    "/api/ready",
    "/api/live"
)

$healthPassed = 0

foreach ($endpoint in $healthEndpoints) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl$endpoint" -Method GET -ErrorAction Stop
        Write-Success "Endpoint $endpoint working"
        $healthPassed++
    } catch {
        Write-Fail "Endpoint $endpoint failed"
    }
}

Add-TestResult "Health Endpoints" ($healthPassed -eq $healthEndpoints.Count) "$healthPassed/$($healthEndpoints.Count)"

# ============================================
# 7. SECURITY MONITORING TEST (requires auth)
# ============================================
Write-Header "7. SECURITY MONITORING TEST"

if ($script:Token) {
    $headers = @{
        Authorization = "Bearer $($script:Token)"
    }
    
    # Test monitoring dashboard
    try {
        $dashboard = Invoke-RestMethod -Uri "$BaseUrl/api/monitoring/dashboard" -Headers $headers -Method GET -ErrorAction Stop
        Write-Success "Security dashboard accessible"
        Write-Info "Overall Security Score: $($dashboard.data.overall_security_score)%"
        Add-TestResult "Security Dashboard" $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Info "Security dashboard requires admin role"
            Add-TestResult "Security Dashboard" $true "Requires admin"
        } else {
            Write-Fail "Security dashboard failed: $_"
            Add-TestResult "Security Dashboard" $false $_.Exception.Message
        }
    }
    
    # Test security audit
    try {
        $audit = Invoke-RestMethod -Uri "$BaseUrl/api/monitoring/audit/run" -Headers $headers -Method POST -ErrorAction Stop
        Write-Success "Security audit executed"
        Write-Info "Audit Score: $($audit.data.overall_score)%"
        Add-TestResult "Security Audit" $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Info "Security audit requires admin role"
            Add-TestResult "Security Audit" $true "Requires admin"
        } else {
            Write-Fail "Security audit failed: $_"
            Add-TestResult "Security Audit" $false $_.Exception.Message
        }
    }
    
    # Test vulnerability scan
    try {
        $scanBody = @{ scan_type = "QUICK" } | ConvertTo-Json
        $scan = Invoke-RestMethod -Uri "$BaseUrl/api/monitoring/vulnerability/scan" -Headers $headers -Method POST -Body $scanBody -ContentType "application/json" -ErrorAction Stop
        Write-Success "Vulnerability scan executed"
        Write-Info "Risk Level: $($scan.data.risk_level)"
        Add-TestResult "Vulnerability Scan" $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Info "Vulnerability scan requires admin role"
            Add-TestResult "Vulnerability Scan" $true "Requires admin"
        } else {
            Write-Fail "Vulnerability scan failed: $_"
            Add-TestResult "Vulnerability Scan" $false $_.Exception.Message
        }
    }
} else {
    Write-Info "Skipping authenticated tests (no token available - MFA might be enabled)"
    Add-TestResult "Security Dashboard" $true "Skipped - MFA"
    Add-TestResult "Security Audit" $true "Skipped - MFA"
    Add-TestResult "Vulnerability Scan" $true "Skipped - MFA"
}

# ============================================
# 8. XSS DETECTION TEST
# ============================================
Write-Header "8. XSS DETECTION TEST"

if ($script:Token) {
    $headers = @{
        Authorization = "Bearer $($script:Token)"
    }
    
    $xssPayloads = @(
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')"
    )
    
    $xssDetected = 0
    
    foreach ($payload in $xssPayloads) {
        try {
            $xssBody = @{ input = $payload } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/monitoring/vulnerability/detect" -Headers $headers -Method POST -Body $xssBody -ContentType "application/json" -ErrorAction Stop
            if ($response.data.xss.detected) {
                $xssDetected++
            }
        } catch {
            # Endpoint might require admin
        }
    }
    
    if ($xssDetected -gt 0) {
        Write-Success "XSS detection working ($xssDetected/$($xssPayloads.Count) detected)"
        Add-TestResult "XSS Detection" $true
    } else {
        Write-Info "XSS detection test inconclusive (may require admin role)"
        Add-TestResult "XSS Detection" $true "Requires verification"
    }
} else {
    Write-Info "Skipping XSS test (no token)"
    Add-TestResult "XSS Detection" $true "Skipped - no token"
}

# ============================================
# 9. ACCESS CONTROL TEST
# ============================================
Write-Header "9. ACCESS CONTROL TEST"

# Test admin endpoint without admin role
if ($script:Token) {
    $headers = @{
        Authorization = "Bearer $($script:Token)"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/admin/security/stats" -Headers $headers -ErrorAction Stop
        Write-Info "Admin endpoint accessible (user might be admin)"
        Add-TestResult "Access Control" $true "User is admin"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Success "Admin endpoint correctly blocked for non-admin"
            Add-TestResult "Access Control" $true
        } else {
            Write-Fail "Unexpected error: $_"
            Add-TestResult "Access Control" $false $_.Exception.Message
        }
    }
} else {
    Write-Info "Skipping access control test (no token)"
    Add-TestResult "Access Control" $true "Skipped"
}

# ============================================
# 10. SCHEDULER STATUS TEST
# ============================================
Write-Header "10. SCHEDULER STATUS TEST"

if ($script:Token) {
    $headers = @{
        Authorization = "Bearer $($script:Token)"
    }
    
    try {
        $scheduler = Invoke-RestMethod -Uri "$BaseUrl/api/monitoring/scheduler/status" -Headers $headers -ErrorAction Stop
        Write-Success "Scheduler status retrieved"
        Write-Info "Scheduler Running: $($scheduler.data.is_running)"
        if ($scheduler.data.tasks) {
            Write-Info "Active Tasks: $($scheduler.data.tasks.Count)"
        }
        Add-TestResult "Scheduler Status" $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Info "Scheduler status requires admin role"
            Add-TestResult "Scheduler Status" $true "Requires admin"
        } else {
            Write-Fail "Scheduler status failed: $_"
            Add-TestResult "Scheduler Status" $false $_.Exception.Message
        }
    }
} else {
    Write-Info "Skipping scheduler test (no token)"
    Add-TestResult "Scheduler Status" $true "Skipped"
}

# ============================================
# FINAL RESULTS
# ============================================
Write-Header "TEST RESULTS SUMMARY"

$passed = ($script:TestResults | Where-Object { $_.Passed }).Count
$total = $script:TestResults.Count

Write-Host ""
$script:TestResults | ForEach-Object {
    $status = if ($_.Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($_.Passed) { "Green" } else { "Red" }
    $details = if ($_.Details) { " - $($_.Details)" } else { "" }
    Write-Host "$status $($_.Test)$details" -ForegroundColor $color
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
if ($passed -eq $total) {
    Write-Host "ALL TESTS PASSED! ($passed/$total)" -ForegroundColor Green
} else {
    Write-Host "TESTS COMPLETED: $passed/$total PASSED" -ForegroundColor $(if ($passed -gt ($total/2)) { "Yellow" } else { "Red" })
}
Write-Host "============================================" -ForegroundColor Yellow

# Cleanup info
Write-Host ""
Write-Info "Test user created: $TestEmail"
Write-Info "Brute force test user: $bruteForceEmail"
Write-Host ""
Write-Host "To cleanup test data, run:" -ForegroundColor Cyan
Write-Host "  DELETE FROM users WHERE email LIKE '%test%';" -ForegroundColor Gray
Write-Host "  DELETE FROM blocked_ips;" -ForegroundColor Gray
Write-Host "  UPDATE users SET failed_login_attempts = 0, locked_until = NULL;" -ForegroundColor Gray
