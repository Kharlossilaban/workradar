# 🧪 TESTING KEAMANAN BASIS DATA PART 2 (Minggu 6-10)

## 📋 Daftar Pengujian

| No | Fitur | Endpoint/File | Status |
|----|-------|---------------|--------|
| 1 | SQL Injection Prevention | Input sanitization | 🧪 |
| 2 | XSS Prevention | Input sanitization | 🧪 |
| 3 | Input Validation | Validator middleware | 🧪 |
| 4 | Progressive Delay | Login endpoint | 🧪 |
| 5 | Session Management | Sessions API | 🧪 |
| 6 | Password Complexity | Register/Change password | 🧪 |
| 7 | Certificate Pinning | Flutter client | 🧪 |
| 8 | Failed Login Tracking | Security logs | 🧪 |
| 9 | Security Alerts | Alert system | 🧪 |
| 10 | Attack Pattern Detection | Automatic detection | 🧪 |

---

## 🔧 PERSIAPAN TESTING

### 1. Jalankan Server
```powershell
cd c:\myradar\server
$env:GO_ENV="development"
$env:JWT_SECRET="test-jwt-secret-key-minimum-32-chars"
$env:ENCRYPTION_KEY="test-encryption-key-32-characters"
go run cmd/main.go
```

### 2. Base URL dan Token
```powershell
$baseUrl = "http://localhost:3000"

# Login untuk mendapatkan token
$loginBody = @{
    email = "admin@example.com"
    password = "Admin@123456"
} | ConvertTo-Json

$loginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
    -ContentType "application/json" -Body $loginBody
$token = $loginResult.data.access_token
$headers = @{ Authorization = "Bearer $token" }
```

---

## 📝 TEST 1: SQL INJECTION PREVENTION

### 1.1 Test Basic SQL Injection Patterns

#### Test Script:
```powershell
Write-Host "=== SQL INJECTION PREVENTION TESTS ===" -ForegroundColor Yellow

# Test berbagai SQL injection patterns
$sqlInjectionTests = @(
    @{ input = "admin' OR '1'='1"; name = "Basic OR injection" },
    @{ input = "admin'--"; name = "Comment injection" },
    @{ input = "'; DROP TABLE users;--"; name = "DROP TABLE injection" },
    @{ input = "1' UNION SELECT * FROM users--"; name = "UNION injection" },
    @{ input = "admin' AND 1=1--"; name = "AND injection" },
    @{ input = "1; DELETE FROM users WHERE 1=1;"; name = "DELETE injection" },
    @{ input = "' OR ''='"; name = "Empty string injection" },
    @{ input = "admin%27%20OR%20%271%27%3D%271"; name = "URL encoded injection" },
    @{ input = "admin' WAITFOR DELAY '0:0:5'--"; name = "Time-based blind injection" },
    @{ input = "1' AND (SELECT SLEEP(5))--"; name = "Sleep injection" }
)

foreach ($test in $sqlInjectionTests) {
    Write-Host "`nTest: $($test.name)" -ForegroundColor Cyan
    Write-Host "Input: $($test.input)" -ForegroundColor Gray
    
    $loginBody = @{
        email = $test.input
        password = "anything"
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
            -ContentType "application/json" -Body $loginBody
        Write-Host "Result: UNEXPECTED SUCCESS - Injection not blocked!" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        
        if ($statusCode -eq 403 -and $errorBody.error -eq "threat_detected") {
            Write-Host "Result: BLOCKED ✅ - $($errorBody.message)" -ForegroundColor Green
        } elseif ($statusCode -eq 400) {
            Write-Host "Result: VALIDATION ERROR ✅ - $($errorBody.message)" -ForegroundColor Green
        } else {
            Write-Host "Result: Status $statusCode - $($errorBody.message)" -ForegroundColor Yellow
        }
    }
}
```

#### ✅ HASIL YANG BENAR (Threat Detected):
```json
{
  "success": false,
  "message": "Potential security threat detected",
  "error": "threat_detected",
  "threat_type": "SQL_INJECTION",
  "patterns_matched": ["OR injection", "comment sequence"],
  "request_id": "req-uuid-here"
}
```
**HTTP Status:** `403 Forbidden`

#### ✅ HASIL YANG BENAR (Validation Error):
```json
{
  "success": false,
  "message": "Invalid email format",
  "error": "validation_error",
  "field": "email"
}
```
**HTTP Status:** `400 Bad Request`

#### ❌ HASIL YANG ERROR (Injection tidak terdeteksi):
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials"
}
```
**Masalah:** Request melewati validasi dan sampai ke authentication logic.

---

### 1.2 Test SQL Injection di Query Parameters

#### Test Script:
```powershell
Write-Host "`n=== SQL INJECTION IN QUERY PARAMS ===" -ForegroundColor Yellow

# Test injection di query parameter
$injectionParams = @(
    "?search='; DROP TABLE tasks;--",
    "?id=1 OR 1=1",
    "?filter=admin' UNION SELECT * FROM users--",
    "?sort=name; DELETE FROM tasks WHERE 1=1",
    "?page=1%27%20OR%20%271%27%3D%271"
)

foreach ($param in $injectionParams) {
    Write-Host "`nTest: GET /api/tasks$param" -ForegroundColor Cyan
    
    try {
        $result = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/tasks$param" `
            -Headers $headers
        Write-Host "Result: UNEXPECTED SUCCESS - Check if injection filtered" -ForegroundColor Yellow
        Write-Host "Tasks returned: $($result.data.Count)" -ForegroundColor Gray
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        
        if ($statusCode -eq 403) {
            Write-Host "Result: BLOCKED ✅" -ForegroundColor Green
        } else {
            Write-Host "Result: Status $statusCode - $($errorBody.message)" -ForegroundColor Yellow
        }
    }
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": false,
  "message": "Malicious input detected in query parameters",
  "error": "threat_detected",
  "threat_type": "SQL_INJECTION",
  "parameter": "search"
}
```
**HTTP Status:** `403 Forbidden`

---

### 1.3 Test SQL Injection di Request Body

#### Test Script:
```powershell
Write-Host "`n=== SQL INJECTION IN REQUEST BODY ===" -ForegroundColor Yellow

$taskBody = @{
    title = "Normal Task"
    description = "'); DELETE FROM tasks WHERE ('1'='1"
    priority = "high"
    date = "2026-01-07"
} | ConvertTo-Json

Write-Host "Creating task with malicious description..." -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
        -Headers $headers -ContentType "application/json" -Body $taskBody
    Write-Host "Result: Task created - Check if description was sanitized" -ForegroundColor Yellow
    Write-Host "Description: $($result.data.description)" -ForegroundColor Gray
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Result: BLOCKED ✅ - Status $statusCode" -ForegroundColor Green
    $errorBody | ConvertTo-Json
}
```

#### ✅ HASIL YANG BENAR (Blocked):
```json
{
  "success": false,
  "message": "Potential SQL injection detected in request body",
  "error": "threat_detected",
  "threat_type": "SQL_INJECTION",
  "field": "description"
}
```
**HTTP Status:** `403 Forbidden`

#### ✅ HASIL YANG BENAR (Sanitized):
```json
{
  "success": true,
  "message": "Task created successfully",
  "data": {
    "id": "task-uuid",
    "title": "Normal Task",
    "description": " DELETE FROM tasks WHERE 1=1",
    "priority": "high"
  }
}
```
**Catatan:** Karakter berbahaya (`'`, `)`, `;`) di-strip.

---

## 📝 TEST 2: XSS PREVENTION

### 2.1 Test XSS Patterns

#### Test Script:
```powershell
Write-Host "=== XSS PREVENTION TESTS ===" -ForegroundColor Yellow

$xssTests = @(
    @{ input = "<script>alert('XSS')</script>"; name = "Script tag" },
    @{ input = "<img src=x onerror=alert('XSS')>"; name = "IMG onerror" },
    @{ input = "<svg onload=alert('XSS')>"; name = "SVG onload" },
    @{ input = "javascript:alert('XSS')"; name = "JavaScript protocol" },
    @{ input = "<iframe src='javascript:alert(1)'>"; name = "Iframe injection" },
    @{ input = "<body onload=alert('XSS')>"; name = "Body onload" },
    @{ input = "&#60;script&#62;alert('XSS')&#60;/script&#62;"; name = "HTML encoded" },
    @{ input = "<img src=""x"" onerror=""alert('XSS')"">"; name = "Double quotes" },
    @{ input = "<div style=""background:url(javascript:alert('XSS'))"">"; name = "CSS injection" },
    @{ input = "'-alert('XSS')-'"; name = "Template literal injection" }
)

foreach ($test in $xssTests) {
    Write-Host "`nTest: $($test.name)" -ForegroundColor Cyan
    Write-Host "Input: $($test.input)" -ForegroundColor Gray
    
    $taskBody = @{
        title = $test.input
        description = "Test XSS"
        priority = "low"
        date = "2026-01-07"
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
            -Headers $headers -ContentType "application/json" -Body $taskBody
        
        # Check if XSS was sanitized
        $sanitizedTitle = $result.data.title
        if ($sanitizedTitle -match "<script|onerror|onload|javascript:") {
            Write-Host "Result: XSS NOT SANITIZED! ❌" -ForegroundColor Red
            Write-Host "Stored: $sanitizedTitle" -ForegroundColor Red
        } else {
            Write-Host "Result: SANITIZED ✅" -ForegroundColor Green
            Write-Host "Stored as: $sanitizedTitle" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        
        if ($statusCode -eq 403 -and $errorBody.threat_type -eq "XSS") {
            Write-Host "Result: BLOCKED ✅" -ForegroundColor Green
        } else {
            Write-Host "Result: Status $statusCode - $($errorBody.message)" -ForegroundColor Yellow
        }
    }
}
```

#### ✅ HASIL YANG BENAR (Blocked):
```json
{
  "success": false,
  "message": "Potential XSS attack detected",
  "error": "threat_detected",
  "threat_type": "XSS",
  "patterns_matched": ["script_tag", "event_handler"],
  "field": "title"
}
```
**HTTP Status:** `403 Forbidden`

#### ✅ HASIL YANG BENAR (Sanitized):
```json
{
  "success": true,
  "data": {
    "title": "alert('XSS')",
    "description": "Test XSS"
  }
}
```
**Catatan:** Tag `<script>` dan `</script>` di-remove.

#### ❌ HASIL YANG ERROR (XSS tidak terfilter):
```json
{
  "success": true,
  "data": {
    "title": "<script>alert('XSS')</script>",
    "description": "Test XSS"
  }
}
```
**Masalah:** XSS tersimpan di database dan bisa dieksekusi saat ditampilkan.

---

## 📝 TEST 3: INPUT VALIDATION

### 3.1 Test Field Length Validation

#### Test Script:
```powershell
Write-Host "=== INPUT LENGTH VALIDATION ===" -ForegroundColor Yellow

# Test title terlalu panjang (max 200)
$longTitle = "A" * 250
$taskBody = @{
    title = $longTitle
    description = "Test"
    priority = "high"
    date = "2026-01-07"
} | ConvertTo-Json

Write-Host "`nTest: Title too long (250 chars, max 200)" -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
        -Headers $headers -ContentType "application/json" -Body $taskBody
    Write-Host "Result: UNEXPECTED SUCCESS - Length not validated" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Result: VALIDATED ✅ - $($errorBody.message)" -ForegroundColor Green
}

# Test description terlalu panjang (max 5000)
$longDescription = "B" * 6000
$taskBody = @{
    title = "Normal Title"
    description = $longDescription
    priority = "high"
    date = "2026-01-07"
} | ConvertTo-Json

Write-Host "`nTest: Description too long (6000 chars, max 5000)" -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
        -Headers $headers -ContentType "application/json" -Body $taskBody
    Write-Host "Result: UNEXPECTED SUCCESS - Length not validated" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Result: VALIDATED ✅ - $($errorBody.message)" -ForegroundColor Green
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": false,
  "message": "Validation failed",
  "error": "validation_error",
  "validation_errors": [
    {
      "field": "title",
      "message": "Title must be at most 200 characters",
      "actual_length": 250,
      "max_length": 200
    }
  ]
}
```
**HTTP Status:** `400 Bad Request`

#### ❌ HASIL YANG ERROR:
```json
{
  "success": true,
  "data": {
    "title": "AAAAAAA... (250 chars)",
    "description": "Test"
  }
}
```
**Masalah:** Data tersimpan tanpa validasi panjang.

---

### 3.2 Test Email Format Validation

#### Test Script:
```powershell
Write-Host "=== EMAIL FORMAT VALIDATION ===" -ForegroundColor Yellow

$emailTests = @(
    @{ email = "valid@example.com"; expected = "valid" },
    @{ email = "invalid"; expected = "invalid" },
    @{ email = "no@domain"; expected = "invalid" },
    @{ email = "@nodomain.com"; expected = "invalid" },
    @{ email = "spaces in@email.com"; expected = "invalid" },
    @{ email = "double@@at.com"; expected = "invalid" },
    @{ email = "valid.email+tag@example.com"; expected = "valid" },
    @{ email = "a@b.c"; expected = "invalid" }
)

foreach ($test in $emailTests) {
    Write-Host "`nTest email: $($test.email)" -ForegroundColor Cyan
    Write-Host "Expected: $($test.expected)" -ForegroundColor Gray
    
    $registerBody = @{
        name = "Test User"
        email = $test.email
        password = "Test@123456"
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
            -ContentType "application/json" -Body $registerBody
        
        if ($test.expected -eq "valid") {
            Write-Host "Result: ACCEPTED ✅" -ForegroundColor Green
        } else {
            Write-Host "Result: SHOULD BE REJECTED ❌" -ForegroundColor Red
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        
        if ($test.expected -eq "invalid") {
            Write-Host "Result: REJECTED ✅ - $($errorBody.message)" -ForegroundColor Green
        } else {
            Write-Host "Result: SHOULD BE ACCEPTED ❌ - $($errorBody.message)" -ForegroundColor Red
        }
    }
}
```

#### ✅ HASIL YANG BENAR (Invalid email):
```json
{
  "success": false,
  "message": "Invalid email format",
  "error": "validation_error",
  "field": "email",
  "hint": "Please enter a valid email address (e.g., user@example.com)"
}
```
**HTTP Status:** `400 Bad Request`

---

## 📝 TEST 4: PROGRESSIVE DELAY (Exponential Backoff)

### 4.1 Test Delay Increases with Failed Attempts

#### Test Script:
```powershell
Write-Host "=== PROGRESSIVE DELAY TEST ===" -ForegroundColor Yellow

# Gunakan email baru untuk test ini
$testEmail = "progressivedelay_$(Get-Random)@test.com"

# Register user
$registerBody = @{
    name = "Delay Test User"
    email = $testEmail
    password = "Test@123456"
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
    -ContentType "application/json" -Body $registerBody | Out-Null

Write-Host "User registered: $testEmail" -ForegroundColor Green

# Test failed logins dengan timing
$wrongLoginBody = @{
    email = $testEmail
    password = "WrongPassword"
} | ConvertTo-Json

for ($i = 1; $i -le 5; $i++) {
    $startTime = Get-Date
    
    Write-Host "`nAttempt $i:" -ForegroundColor Cyan
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
            -ContentType "application/json" -Body $wrongLoginBody
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        
        Write-Host "Status: $statusCode" -ForegroundColor Yellow
        Write-Host "Response Time: $([math]::Round($duration, 2)) seconds" -ForegroundColor Gray
        
        if ($errorBody.delay_seconds) {
            Write-Host "Delay Applied: $($errorBody.delay_seconds) seconds" -ForegroundColor Yellow
        }
        if ($errorBody.remaining_attempts) {
            Write-Host "Remaining Attempts: $($errorBody.remaining_attempts)" -ForegroundColor Yellow
        }
        if ($errorBody.locked_until) {
            Write-Host "Locked Until: $($errorBody.locked_until)" -ForegroundColor Red
        }
    }
}
```

#### ✅ HASIL YANG BENAR:

**Attempt 1:**
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials",
  "remaining_attempts": 4,
  "delay_seconds": 1
}
```
**Response Time:** ~1 second

**Attempt 2:**
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials",
  "remaining_attempts": 3,
  "delay_seconds": 2
}
```
**Response Time:** ~2 seconds

**Attempt 3:**
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials",
  "remaining_attempts": 2,
  "delay_seconds": 4
}
```
**Response Time:** ~4 seconds

**Attempt 4:**
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials",
  "remaining_attempts": 1,
  "delay_seconds": 8
}
```
**Response Time:** ~8 seconds

**Attempt 5 (Locked):**
```json
{
  "success": false,
  "message": "Account temporarily locked due to multiple failed login attempts",
  "error": "account_locked",
  "locked_until": "2026-01-06T12:30:00Z",
  "retry_after_seconds": 1800
}
```
**HTTP Status:** `429 Too Many Requests`

#### ❌ HASIL YANG ERROR (No delay):
Jika semua response langsung (< 0.5 second), progressive delay tidak aktif.

---

### 4.2 Test Delay Reset on Successful Login

#### Test Script:
```powershell
Write-Host "`n=== DELAY RESET ON SUCCESS ===" -ForegroundColor Yellow

# Login dengan password benar
$correctLoginBody = @{
    email = $testEmail
    password = "Test@123456"
} | ConvertTo-Json

# Tunggu lockout expired (atau reset manual di database)
Write-Host "Attempting login with correct password..." -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
        -ContentType "application/json" -Body $correctLoginBody
    
    Write-Host "Login successful!" -ForegroundColor Green
    Write-Host "Failed attempts reset to: 0" -ForegroundColor Green
} catch {
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Still locked: $($errorBody.message)" -ForegroundColor Yellow
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "failed_login_attempts": 0
    },
    "access_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

## 📝 TEST 5: SESSION MANAGEMENT

### 5.1 Test Get Active Sessions

#### Test Script:
```powershell
Write-Host "=== SESSION MANAGEMENT ===" -ForegroundColor Yellow

# Login dari beberapa "device" (multiple tokens)
$sessions = @()

for ($i = 1; $i -le 3; $i++) {
    $loginBody = @{
        email = "testuser@example.com"
        password = "Test@123456"
    } | ConvertTo-Json
    
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
        -ContentType "application/json" -Body $loginBody `
        -Headers @{ "User-Agent" = "Device$i/1.0" }
    
    $sessions += @{
        device = "Device$i"
        token = $result.data.access_token
    }
    
    Write-Host "Logged in from Device$i" -ForegroundColor Green
}

# Get all sessions
$headers = @{ Authorization = "Bearer $($sessions[0].token)" }
$activeSessions = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/auth/sessions" -Headers $headers

Write-Host "`nActive Sessions:" -ForegroundColor Cyan
$activeSessions | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "id": "session-uuid-1",
        "device_info": "Device1/1.0",
        "ip_address": "127.0.0.1",
        "last_activity": "2026-01-06T12:00:00Z",
        "created_at": "2026-01-06T11:50:00Z",
        "is_current": true
      },
      {
        "id": "session-uuid-2",
        "device_info": "Device2/1.0",
        "ip_address": "127.0.0.1",
        "last_activity": "2026-01-06T12:01:00Z",
        "created_at": "2026-01-06T11:51:00Z",
        "is_current": false
      },
      {
        "id": "session-uuid-3",
        "device_info": "Device3/1.0",
        "ip_address": "127.0.0.1",
        "last_activity": "2026-01-06T12:02:00Z",
        "created_at": "2026-01-06T11:52:00Z",
        "is_current": false
      }
    ],
    "total": 3,
    "max_sessions": 5
  }
}
```

---

### 5.2 Test Logout from Specific Device

#### Test Script:
```powershell
Write-Host "`n=== LOGOUT FROM DEVICE ===" -ForegroundColor Yellow

$sessionId = "session-uuid-2"  # Session dari Device2
$headers = @{ Authorization = "Bearer $($sessions[0].token)" }

$logoutResult = Invoke-RestMethod -Method DELETE `
    -Uri "$baseUrl/api/auth/sessions/$sessionId" `
    -Headers $headers

Write-Host "Logout Result:" -ForegroundColor Cyan
$logoutResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Session terminated successfully",
  "data": {
    "terminated_session": "session-uuid-2",
    "remaining_sessions": 2
  }
}
```

#### Test using terminated session token:
```powershell
# Coba gunakan token dari Device2 yang sudah di-logout
$headers2 = @{ Authorization = "Bearer $($sessions[1].token)" }
$result = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/profile" -Headers $headers2
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": false,
  "message": "Session has been terminated",
  "error": "session_invalid"
}
```
**HTTP Status:** `401 Unauthorized`

---

### 5.3 Test Logout from All Devices

#### Test Script:
```powershell
Write-Host "`n=== LOGOUT FROM ALL DEVICES ===" -ForegroundColor Yellow

$headers = @{ Authorization = "Bearer $($sessions[0].token)" }

# Logout semua kecuali session saat ini
$logoutAllResult = Invoke-RestMethod -Method POST `
    -Uri "$baseUrl/api/auth/logout-all?except_current=true" `
    -Headers $headers

Write-Host "Logout All Result:" -ForegroundColor Cyan
$logoutAllResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "All other sessions terminated",
  "data": {
    "terminated_count": 2,
    "current_session_preserved": true
  }
}
```

---

## 📝 TEST 6: PASSWORD COMPLEXITY

### 6.1 Test Password Strength Calculator

#### Test Script:
```powershell
Write-Host "=== PASSWORD STRENGTH TEST ===" -ForegroundColor Yellow

$passwords = @(
    @{ password = "123456"; expected_score = "0-20"; strength = "Very Weak" },
    @{ password = "password"; expected_score = "10-30"; strength = "Weak" },
    @{ password = "Password1"; expected_score = "30-50"; strength = "Fair" },
    @{ password = "Password1!"; expected_score = "50-70"; strength = "Good" },
    @{ password = "P@ssw0rd123!"; expected_score = "70-85"; strength = "Strong" },
    @{ password = "X9#kL2$mN8@pQ4!"; expected_score = "85-100"; strength = "Very Strong" }
)

foreach ($test in $passwords) {
    Write-Host "`nPassword: $($test.password)" -ForegroundColor Cyan
    Write-Host "Expected: $($test.expected_score) ($($test.strength))" -ForegroundColor Gray
    
    $body = @{
        password = $test.password
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/security/validate-password" `
            -Headers $headers -ContentType "application/json" -Body $body
        
        Write-Host "Score: $($result.data.score)" -ForegroundColor Yellow
        Write-Host "Strength: $($result.data.strength)" -ForegroundColor Yellow
        Write-Host "Valid: $($result.data.is_valid)" -ForegroundColor $(if($result.data.is_valid){"Green"}else{"Red"})
        
        if ($result.data.suggestions) {
            Write-Host "Suggestions:" -ForegroundColor Gray
            $result.data.suggestions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Host "Error validating password" -ForegroundColor Red
    }
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "score": 75,
    "strength": "Strong",
    "is_valid": true,
    "checks": {
      "length": true,
      "uppercase": true,
      "lowercase": true,
      "digit": true,
      "special": true,
      "not_common": true
    },
    "suggestions": []
  }
}
```

#### ✅ HASIL YANG BENAR (Weak password):
```json
{
  "success": true,
  "data": {
    "score": 15,
    "strength": "Weak",
    "is_valid": false,
    "checks": {
      "length": false,
      "uppercase": false,
      "lowercase": true,
      "digit": false,
      "special": false,
      "not_common": false
    },
    "suggestions": [
      "Password must be at least 8 characters",
      "Add at least one uppercase letter",
      "Add at least one digit",
      "Add at least one special character (!@#$%^&*)",
      "Avoid common passwords like 'password', '123456'"
    ]
  }
}
```

---

## 📝 TEST 7: CERTIFICATE PINNING (Flutter)

### 7.1 Test Certificate Pinning (Manual)

#### Flutter Test Code:
```dart
// test/certificate_pinning_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workradar/core/network/certificate_pinning.dart';

void main() {
  group('Certificate Pinning Tests', () {
    late SecureApiClient client;

    setUp(() {
      client = SecureApiClient();
    });

    test('should connect to valid server', () async {
      // Test dengan server yang memiliki certificate valid
      final response = await client.dio.get('/api/health');
      expect(response.statusCode, 200);
    });

    test('should reject invalid certificate', () async {
      // Mock invalid certificate
      // Ini akan di-reject oleh certificate pinning
      try {
        await client.dio.get('https://invalid-cert-server.com/api/health');
        fail('Should have thrown exception');
      } catch (e) {
        expect(e.toString(), contains('Certificate'));
      }
    });

    test('should validate security headers', () async {
      final response = await client.dio.get('/api/health');
      
      expect(response.headers['x-content-type-options'], isNotNull);
      expect(response.headers['x-frame-options'], isNotNull);
    });
  });
}
```

#### Run Flutter Tests:
```powershell
cd c:\myradar\client
flutter test test/certificate_pinning_test.dart
```

#### ✅ HASIL YANG BENAR:
```
00:02 +3: All tests passed!
```

#### ❌ HASIL YANG ERROR:
```
00:01 +0 -1: Certificate Pinning Tests should reject invalid certificate [E]
  Expected: exception containing 'Certificate'
  Actual: no exception thrown
```

---

## 📝 TEST 8: FAILED LOGIN TRACKING

### 8.1 Test Get Failed Login Statistics

#### Test Script:
```powershell
Write-Host "=== FAILED LOGIN TRACKING ===" -ForegroundColor Yellow

# Generate beberapa failed logins terlebih dahulu
for ($i = 1; $i -le 3; $i++) {
    $wrongLogin = @{
        email = "tracking_test@example.com"
        password = "WrongPass$i"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
            -ContentType "application/json" -Body $wrongLogin
    } catch {
        # Expected to fail
    }
}

# Get statistics (requires admin)
$adminHeaders = @{ Authorization = "Bearer $adminToken" }
$stats = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/security/failed-logins/stats" `
    -Headers $adminHeaders

Write-Host "Failed Login Statistics:" -ForegroundColor Cyan
$stats | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "total_attempts": 156,
    "last_24_hours": 23,
    "last_hour": 5,
    "top_attacked_emails": [
      { "email": "admin@example.com", "attempts": 15 },
      { "email": "tracking_test@example.com", "attempts": 8 },
      { "email": "user@example.com", "attempts": 5 }
    ],
    "top_attacker_ips": [
      { "ip": "192.168.1.100", "attempts": 20 },
      { "ip": "10.0.0.50", "attempts": 12 },
      { "ip": "127.0.0.1", "attempts": 8 }
    ],
    "hourly_distribution": {
      "00": 2, "01": 1, "02": 0, "03": 0,
      "08": 5, "09": 10, "10": 15, "11": 8,
      "12": 12, "13": 7, "14": 3
    },
    "attack_patterns": {
      "brute_force_detected": 3,
      "distributed_attack_detected": 1,
      "account_attacks": 5
    }
  }
}
```

---

## 📝 TEST 9: SECURITY ALERTS

### 9.1 Test Get Recent Alerts

#### Test Script:
```powershell
Write-Host "=== SECURITY ALERTS ===" -ForegroundColor Yellow

$adminHeaders = @{ Authorization = "Bearer $adminToken" }
$alerts = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/security/alerts?limit=10" `
    -Headers $adminHeaders

Write-Host "Recent Security Alerts:" -ForegroundColor Cyan
$alerts | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "alerts": [
      {
        "id": "alert-uuid-1",
        "type": "BRUTE_FORCE",
        "severity": "HIGH",
        "title": "Brute Force Attack Detected",
        "message": "Multiple failed login attempts from IP: 192.168.1.100",
        "ip_address": "192.168.1.100",
        "user_id": null,
        "is_acknowledged": false,
        "created_at": "2026-01-06T12:00:00Z",
        "data": {
          "attempts": 15,
          "timeframe_minutes": 5,
          "targeted_emails": ["admin@example.com"]
        }
      },
      {
        "id": "alert-uuid-2",
        "type": "ACCOUNT_LOCKED",
        "severity": "MEDIUM",
        "title": "Account Locked",
        "message": "Account admin@example.com has been locked",
        "user_id": "user-uuid",
        "is_acknowledged": true,
        "acknowledged_by": "admin-uuid",
        "acknowledged_at": "2026-01-06T12:05:00Z",
        "created_at": "2026-01-06T12:00:00Z"
      }
    ],
    "total": 2,
    "unacknowledged": 1
  }
}
```

---

### 9.2 Test Acknowledge Alert

#### Test Script:
```powershell
$alertId = "alert-uuid-1"
$adminHeaders = @{ Authorization = "Bearer $adminToken" }

$ackResult = Invoke-RestMethod -Method POST `
    -Uri "$baseUrl/api/security/alerts/$alertId/acknowledge" `
    -Headers $adminHeaders

Write-Host "Acknowledge Result:" -ForegroundColor Cyan
$ackResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Alert acknowledged",
  "data": {
    "id": "alert-uuid-1",
    "is_acknowledged": true,
    "acknowledged_by": "admin-uuid",
    "acknowledged_at": "2026-01-06T12:10:00Z"
  }
}
```

---

## 📝 TEST 10: ATTACK PATTERN DETECTION

### 10.1 Test Distributed Attack Detection

#### Test Script:
```powershell
Write-Host "=== DISTRIBUTED ATTACK DETECTION ===" -ForegroundColor Yellow

# Simulasi distributed attack (multiple IPs targeting same account)
$targetEmail = "distributed_target@example.com"

# Register target
$registerBody = @{
    name = "Target User"
    email = $targetEmail
    password = "Test@123456"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
        -ContentType "application/json" -Body $registerBody | Out-Null
} catch {
    # User might already exist
}

# Simulate attacks from different IPs using X-Forwarded-For
$fakeIPs = @("10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4", "10.0.0.5")

foreach ($ip in $fakeIPs) {
    Write-Host "Attack from IP: $ip" -ForegroundColor Cyan
    
    $wrongLogin = @{
        email = $targetEmail
        password = "WrongPassword"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
            -ContentType "application/json" -Body $wrongLogin `
            -Headers @{ "X-Forwarded-For" = $ip }
    } catch {
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Response: $($errorBody.message)" -ForegroundColor Gray
    }
    
    Start-Sleep -Milliseconds 200
}

# Check if distributed attack alert was generated
Start-Sleep -Seconds 2
$adminHeaders = @{ Authorization = "Bearer $adminToken" }
$alerts = Invoke-RestMethod -Method GET `
    -Uri "$baseUrl/api/security/alerts?type=DISTRIBUTED_ATTACK&limit=1" `
    -Headers $adminHeaders

Write-Host "`nDistributed Attack Alert:" -ForegroundColor Cyan
$alerts | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "alerts": [
      {
        "id": "alert-uuid",
        "type": "DISTRIBUTED_ATTACK",
        "severity": "CRITICAL",
        "title": "Distributed Attack Detected",
        "message": "Multiple IPs attacking account: distributed_target@example.com",
        "created_at": "2026-01-06T12:00:00Z",
        "data": {
          "target_email": "distributed_target@example.com",
          "unique_ips": 5,
          "total_attempts": 5,
          "timeframe_seconds": 60,
          "ips": ["10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4", "10.0.0.5"]
        }
      }
    ]
  }
}
```

#### ❌ HASIL YANG ERROR (Detection tidak aktif):
```json
{
  "success": true,
  "data": {
    "alerts": [],
    "total": 0
  }
}
```
**Masalah:** Distributed attack detection tidak mendeteksi pattern.

---

## 📊 SUMMARY TESTING PART 2

| No | Test Case | Expected | Actual | Status |
|----|-----------|----------|--------|--------|
| 1.1 | SQL Injection - Basic patterns | Blocked/Sanitized | | ⬜ |
| 1.2 | SQL Injection - Query params | Blocked | | ⬜ |
| 1.3 | SQL Injection - Request body | Blocked/Sanitized | | ⬜ |
| 2.1 | XSS - Script tags, events | Blocked/Sanitized | | ⬜ |
| 3.1 | Input length validation | Rejected if too long | | ⬜ |
| 3.2 | Email format validation | Invalid rejected | | ⬜ |
| 4.1 | Progressive delay | Delay increases | | ⬜ |
| 4.2 | Delay reset on success | Counter reset | | ⬜ |
| 5.1 | Get active sessions | List sessions | | ⬜ |
| 5.2 | Logout specific device | Session terminated | | ⬜ |
| 5.3 | Logout all devices | All sessions terminated | | ⬜ |
| 6.1 | Password strength | Score calculated | | ⬜ |
| 7.1 | Certificate pinning | Valid cert accepted | | ⬜ |
| 8.1 | Failed login stats | Statistics returned | | ⬜ |
| 9.1 | Get security alerts | Alerts listed | | ⬜ |
| 9.2 | Acknowledge alert | Alert acknowledged | | ⬜ |
| 10.1 | Distributed attack detection | Alert generated | | ⬜ |

### Legend
- ✅ PASS
- ❌ FAIL
- ⬜ NOT TESTED
