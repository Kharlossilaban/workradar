# 🧪 TESTING KEAMANAN BASIS DATA PART 1 (Minggu 2-5)

## 📋 Daftar Pengujian

| No | Fitur | Endpoint/File | Status |
|----|-------|---------------|--------|
| 1 | Audit Logging System | `/api/security/audit-logs` | 🧪 |
| 2 | Threat Monitoring & Detection | Login endpoint | 🧪 |
| 3 | Security Event Logging | `/api/security/events` | 🧪 |
| 4 | MFA/2FA Implementation | `/api/auth/mfa/*` | 🧪 |
| 5 | Password Policy | `/api/auth/register` | 🧪 |
| 6 | Account Lockout Policy | Login endpoint | 🧪 |
| 7 | Database SSL/TLS | Connection test | 🧪 |
| 8 | Field-Level Encryption | Database check | 🧪 |
| 9 | HTTPS/TLS Enforcement | Server connection | 🧪 |
| 10 | Security Headers | Response headers | 🧪 |

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

### 2. Base URL
```powershell
$baseUrl = "http://localhost:3000"
```

### 3. Helper Functions
```powershell
# Function untuk pretty print JSON
function Format-Json {
    param([string]$json)
    $json | ConvertFrom-Json | ConvertTo-Json -Depth 10
}

# Function untuk test endpoint
function Test-Endpoint {
    param(
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )
    
    $params = @{
        Method = $Method
        Uri = $Url
        Headers = $Headers
        ContentType = "application/json"
    }
    
    if ($Body) {
        $params.Body = $Body
    }
    
    try {
        $response = Invoke-RestMethod @params
        return @{ Success = $true; Data = $response }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Response; Message = $_.Exception.Message }
    }
}
```

---

## 📝 TEST 1: AUDIT LOGGING SYSTEM

### 1.1 Test Audit Log Creation (Otomatis saat operasi)

#### Langkah Pengujian:
1. Login untuk mendapatkan token
2. Buat task baru (akan generate audit log)
3. Cek audit logs

#### Test Script:
```powershell
# Step 1: Register user baru
$registerBody = @{
    name = "Test User Audit"
    email = "testaudit@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$registerResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
    -ContentType "application/json" -Body $registerBody

Write-Host "Register Result:" -ForegroundColor Cyan
$registerResult | ConvertTo-Json

# Step 2: Login
$loginBody = @{
    email = "testaudit@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$loginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
    -ContentType "application/json" -Body $loginBody

$token = $loginResult.data.access_token
Write-Host "Token: $token" -ForegroundColor Green

# Step 3: Create Task (generates audit log)
$taskBody = @{
    title = "Test Task for Audit"
    description = "Testing audit logging"
    priority = "high"
    date = "2026-01-07"
    category_id = "1"
} | ConvertTo-Json

$headers = @{ Authorization = "Bearer $token" }
$taskResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
    -Headers $headers -ContentType "application/json" -Body $taskBody

Write-Host "Task Created:" -ForegroundColor Cyan
$taskResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Task created successfully",
  "data": {
    "id": "uuid-task-id",
    "title": "Test Task for Audit",
    "description": "Testing audit logging",
    "priority": "high",
    "date": "2026-01-07",
    "is_completed": false,
    "created_at": "2026-01-06T12:00:00Z"
  }
}
```

**Audit Log yang tercatat di database:**
```sql
SELECT * FROM audit_logs WHERE table_name = 'tasks' ORDER BY created_at DESC LIMIT 1;
```
```
+--------------------------------------+---------+--------+------------+-----------+------+------------------+-------------+
| id                                   | user_id | action | table_name | record_id | ... | new_value        | ip_address  |
+--------------------------------------+---------+--------+------------+-----------+------+------------------+-------------+
| a1b2c3d4-e5f6-7890-abcd-ef1234567890 | user-id | CREATE | tasks      | task-id   | ... | {"title":"..."} | 127.0.0.1   |
+--------------------------------------+---------+--------+------------+-----------+------+------------------+-------------+
```

#### ❌ HASIL YANG ERROR (Tanpa Token):
```powershell
# Request tanpa authorization header
$taskResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
    -ContentType "application/json" -Body $taskBody
```

**Response Error:**
```json
{
  "success": false,
  "message": "Unauthorized",
  "error": "missing_token"
}
```
**HTTP Status:** `401 Unauthorized`

---

### 1.2 Test Get Audit Logs

#### Test Script:
```powershell
# Get audit logs (requires authentication)
$headers = @{ Authorization = "Bearer $token" }
$auditLogs = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/security/audit-logs?limit=10" `
    -Headers $headers

Write-Host "Audit Logs:" -ForegroundColor Cyan
$auditLogs | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "user_id": "user-uuid",
        "action": "CREATE",
        "table_name": "tasks",
        "record_id": "task-uuid",
        "old_value": null,
        "new_value": "{\"title\":\"Test Task\",\"priority\":\"high\"}",
        "ip_address": "127.0.0.1",
        "user_agent": "PowerShell/7.0",
        "request_path": "/api/tasks",
        "status_code": 201,
        "duration_ms": 45,
        "created_at": "2026-01-06T12:00:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "limit": 10
  }
}
```

#### ❌ HASIL YANG ERROR (Token Invalid):
```powershell
$headers = @{ Authorization = "Bearer invalid-token-here" }
$auditLogs = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/security/audit-logs" -Headers $headers
```

**Response Error:**
```json
{
  "success": false,
  "message": "Invalid token",
  "error": "token_invalid"
}
```
**HTTP Status:** `401 Unauthorized`

---

## 📝 TEST 2: THREAT MONITORING & DETECTION

### 2.1 Test Brute Force Detection

#### Langkah Pengujian:
1. Coba login dengan password salah 5+ kali
2. Sistem harus mendeteksi sebagai brute force attempt
3. IP akan di-block sementara

#### Test Script:
```powershell
# Simulasi brute force attack (5+ failed attempts)
$wrongLoginBody = @{
    email = "testaudit@example.com"
    password = "WrongPassword123"
} | ConvertTo-Json

Write-Host "=== BRUTE FORCE SIMULATION ===" -ForegroundColor Yellow

for ($i = 1; $i -le 6; $i++) {
    Write-Host "`nAttempt $i:" -ForegroundColor Cyan
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
            -ContentType "application/json" -Body $wrongLoginBody
        Write-Host "Success (unexpected)" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Status: $statusCode" -ForegroundColor Yellow
        Write-Host "Message: $($errorBody.message)" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 500
}
```

#### ✅ HASIL YANG BENAR (Attempt 1-4):
```json
{
  "success": false,
  "message": "Invalid email or password",
  "error": "invalid_credentials",
  "remaining_attempts": 4
}
```
**HTTP Status:** `401 Unauthorized`

#### ✅ HASIL YANG BENAR (Attempt 5 - Account Locked):
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

#### ✅ HASIL YANG BENAR (Attempt 6+ - Still Locked):
```json
{
  "success": false,
  "message": "Account is locked. Please try again later",
  "error": "account_locked",
  "locked_until": "2026-01-06T12:30:00Z",
  "remaining_seconds": 1750
}
```
**HTTP Status:** `429 Too Many Requests`

---

### 2.2 Test SQL Injection Detection

#### Test Script:
```powershell
# SQL Injection attempt in login
$sqlInjectionBody = @{
    email = "admin'--"
    password = "anything"
} | ConvertTo-Json

Write-Host "=== SQL INJECTION TEST ===" -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
        -ContentType "application/json" -Body $sqlInjectionBody
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Status: $statusCode" -ForegroundColor Yellow
    $errorBody | ConvertTo-Json
}
```

#### ✅ HASIL YANG BENAR (Threat Detected):
```json
{
  "success": false,
  "message": "Potential security threat detected",
  "error": "threat_detected",
  "threat_type": "SQL_INJECTION",
  "request_id": "req-uuid-here"
}
```
**HTTP Status:** `403 Forbidden`

**Security Event yang tercatat:**
```sql
SELECT * FROM security_events WHERE event_type = 'SQL_INJECTION_ATTEMPT' ORDER BY created_at DESC LIMIT 1;
```
```
+--------------------------------------+------------------------+----------+---------+-------------+----------------------------------+
| id                                   | event_type             | severity | user_id | ip_address  | details                          |
+--------------------------------------+------------------------+----------+---------+-------------+----------------------------------+
| uuid-here                            | SQL_INJECTION_ATTEMPT  | CRITICAL | NULL    | 127.0.0.1   | {"pattern":"admin'--","field":..}|
+--------------------------------------+------------------------+----------+---------+-------------+----------------------------------+
```

#### ❌ HASIL YANG ERROR (Jika threat detection tidak aktif):
```json
{
  "success": false,
  "message": "Invalid email format",
  "error": "validation_error"
}
```
**Catatan:** Ini berarti validasi biasa yang menangkap, bukan threat detection. Security event tidak tercatat.

---

## 📝 TEST 3: SECURITY EVENT LOGGING

### 3.1 Test Get Security Events

#### Test Script:
```powershell
$headers = @{ Authorization = "Bearer $token" }

# Get security events
$events = Invoke-RestMethod -Method GET `
    -Uri "$baseUrl/api/security/events?limit=10&severity=HIGH" `
    -Headers $headers

Write-Host "Security Events:" -ForegroundColor Cyan
$events | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "id": "event-uuid",
        "event_type": "FAILED_LOGIN",
        "severity": "WARNING",
        "user_id": "user-uuid",
        "ip_address": "127.0.0.1",
        "user_agent": "PowerShell/7.0",
        "details": "{\"email\":\"testaudit@example.com\",\"reason\":\"wrong_password\"}",
        "is_resolved": false,
        "created_at": "2026-01-06T12:00:00Z"
      },
      {
        "id": "event-uuid-2",
        "event_type": "ACCOUNT_LOCKED",
        "severity": "HIGH",
        "user_id": "user-uuid",
        "ip_address": "127.0.0.1",
        "details": "{\"reason\":\"brute_force_detected\",\"locked_until\":\"...\"}",
        "is_resolved": false,
        "created_at": "2026-01-06T12:05:00Z"
      }
    ],
    "total": 2,
    "page": 1,
    "limit": 10
  }
}
```

#### ❌ HASIL YANG ERROR (Tidak punya akses):
```json
{
  "success": false,
  "message": "Access denied. Required permission: security:read",
  "error": "forbidden"
}
```
**HTTP Status:** `403 Forbidden`

---

### 3.2 Test Resolve Security Event

#### Test Script:
```powershell
$headers = @{ Authorization = "Bearer $adminToken" }  # Harus admin token
$eventId = "event-uuid-here"

$resolveResult = Invoke-RestMethod -Method POST `
    -Uri "$baseUrl/api/security/events/$eventId/resolve" `
    -Headers $headers

Write-Host "Resolve Result:" -ForegroundColor Cyan
$resolveResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Security event resolved",
  "data": {
    "id": "event-uuid",
    "is_resolved": true,
    "resolved_at": "2026-01-06T12:30:00Z",
    "resolved_by": "admin-user-id"
  }
}
```

#### ❌ HASIL YANG ERROR (Event tidak ditemukan):
```json
{
  "success": false,
  "message": "Security event not found",
  "error": "not_found"
}
```
**HTTP Status:** `404 Not Found`

---

## 📝 TEST 4: MFA/2FA IMPLEMENTATION

### 4.1 Test Enable MFA

#### Test Script:
```powershell
$headers = @{ Authorization = "Bearer $token" }

# Enable MFA - Get QR Code
$mfaEnable = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/mfa/enable" -Headers $headers

Write-Host "MFA Enable Result:" -ForegroundColor Cyan
$mfaEnable | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "MFA setup initiated",
  "data": {
    "secret": "JBSWY3DPEHPK3PXP",
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "backup_codes": [
      "ABC123DEF456",
      "GHI789JKL012",
      "MNO345PQR678",
      "STU901VWX234",
      "YZA567BCD890"
    ],
    "issuer": "Workradar",
    "account": "testaudit@example.com"
  }
}
```

#### ❌ HASIL YANG ERROR (MFA sudah aktif):
```json
{
  "success": false,
  "message": "MFA is already enabled for this account",
  "error": "mfa_already_enabled"
}
```
**HTTP Status:** `400 Bad Request`

---

### 4.2 Test Verify MFA Setup

#### Test Script:
```powershell
$headers = @{ Authorization = "Bearer $token" }

# Verify MFA dengan TOTP code (6 digit dari authenticator app)
$verifyBody = @{
    code = "123456"  # Ganti dengan code dari authenticator app
} | ConvertTo-Json

$mfaVerify = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/mfa/verify" `
    -Headers $headers -ContentType "application/json" -Body $verifyBody

Write-Host "MFA Verify Result:" -ForegroundColor Cyan
$mfaVerify | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "MFA enabled successfully",
  "data": {
    "mfa_enabled": true,
    "enabled_at": "2026-01-06T12:00:00Z"
  }
}
```

#### ❌ HASIL YANG ERROR (Code salah):
```json
{
  "success": false,
  "message": "Invalid MFA code",
  "error": "invalid_mfa_code",
  "hint": "Please enter the 6-digit code from your authenticator app"
}
```
**HTTP Status:** `400 Bad Request`

#### ❌ HASIL YANG ERROR (Code expired):
```json
{
  "success": false,
  "message": "MFA code has expired",
  "error": "mfa_code_expired",
  "hint": "TOTP codes are valid for 30 seconds"
}
```
**HTTP Status:** `400 Bad Request`

---

### 4.3 Test Login with MFA

#### Test Script:
```powershell
# Step 1: Login (akan return mfa_required jika MFA enabled)
$loginBody = @{
    email = "testaudit@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$loginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
    -ContentType "application/json" -Body $loginBody

Write-Host "Login Result:" -ForegroundColor Cyan
$loginResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR (MFA Required):
```json
{
  "success": true,
  "message": "MFA verification required",
  "data": {
    "mfa_required": true,
    "mfa_token": "temp-mfa-token-uuid",
    "expires_in": 300
  }
}
```

#### Test MFA Login Verification:
```powershell
# Step 2: Verify MFA untuk login
$mfaLoginBody = @{
    mfa_token = "temp-mfa-token-uuid"
    code = "654321"  # Code dari authenticator app
} | ConvertTo-Json

$mfaLoginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/mfa/verify-login" `
    -ContentType "application/json" -Body $mfaLoginBody

Write-Host "MFA Login Result:" -ForegroundColor Cyan
$mfaLoginResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "user-uuid",
      "name": "Test User Audit",
      "email": "testaudit@example.com",
      "mfa_enabled": true
    },
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 900
  }
}
```

#### ❌ HASIL YANG ERROR (MFA Token expired):
```json
{
  "success": false,
  "message": "MFA session expired. Please login again",
  "error": "mfa_token_expired"
}
```
**HTTP Status:** `401 Unauthorized`

---

## 📝 TEST 5: PASSWORD POLICY

### 5.1 Test Password Validation on Register

#### Test Script - Password Terlalu Pendek:
```powershell
$registerBody = @{
    name = "Test User"
    email = "test1@example.com"
    password = "weak"  # Terlalu pendek
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
        -ContentType "application/json" -Body $registerBody
} catch {
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Error:" -ForegroundColor Red
    $errorBody | ConvertTo-Json
}
```

#### ❌ HASIL YANG ERROR (Password lemah):
```json
{
  "success": false,
  "message": "Password does not meet security requirements",
  "error": "weak_password",
  "validation_errors": [
    "Password must be at least 8 characters long",
    "Password must contain at least one uppercase letter",
    "Password must contain at least one digit",
    "Password must contain at least one special character (!@#$%^&*)"
  ]
}
```
**HTTP Status:** `400 Bad Request`

---

### 5.2 Test Password Strength Variations

#### Test Script:
```powershell
# Test berbagai password
$passwords = @(
    @{ password = "12345678"; expected = "fail"; reason = "no letters" },
    @{ password = "password"; expected = "fail"; reason = "no uppercase, digits, special" },
    @{ password = "Password1"; expected = "fail"; reason = "no special character" },
    @{ password = "Password1!"; expected = "pass"; reason = "meets all requirements" },
    @{ password = "P@ssw0rd123!"; expected = "pass"; reason = "strong password" }
)

foreach ($test in $passwords) {
    $registerBody = @{
        name = "Test User"
        email = "test_$(Get-Random)@example.com"
        password = $test.password
    } | ConvertTo-Json
    
    Write-Host "`nTesting: $($test.password)" -ForegroundColor Cyan
    Write-Host "Expected: $($test.expected) - $($test.reason)" -ForegroundColor Gray
    
    try {
        $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
            -ContentType "application/json" -Body $registerBody
        Write-Host "Result: PASS - User registered" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Result: FAIL - Status $statusCode" -ForegroundColor Red
    }
}
```

#### ✅ HASIL YANG BENAR (Password kuat):
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": "new-user-uuid",
      "name": "Test User",
      "email": "test@example.com"
    },
    "access_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

## 📝 TEST 6: ACCOUNT LOCKOUT POLICY

### 6.1 Test Account Gets Locked

(Sudah diuji di Test 2.1 - Brute Force Detection)

### 6.2 Test Account Auto-Unlock After Timeout

#### Test Script:
```powershell
# Tunggu 30 menit atau set timeout lebih pendek untuk testing
# Kemudian coba login lagi

Write-Host "Waiting for lockout to expire (simulated)..." -ForegroundColor Yellow

$loginBody = @{
    email = "testaudit@example.com"
    password = "Test@123456"  # Password benar
} | ConvertTo-Json

$loginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
    -ContentType "application/json" -Body $loginBody

Write-Host "Login after lockout:" -ForegroundColor Cyan
$loginResult | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR (Setelah lockout expired):
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "user-uuid",
      "name": "Test User Audit",
      "email": "testaudit@example.com",
      "failed_login_attempts": 0
    },
    "access_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

#### ❌ HASIL YANG ERROR (Lockout masih aktif):
```json
{
  "success": false,
  "message": "Account is locked. Please try again in 25 minutes",
  "error": "account_locked",
  "locked_until": "2026-01-06T12:30:00Z",
  "remaining_seconds": 1500
}
```
**HTTP Status:** `429 Too Many Requests`

---

## 📝 TEST 7: DATABASE SSL/TLS CONNECTION

### 7.1 Test Database Connection dengan SSL

#### Test Script (Check dari server logs):
```powershell
# Jalankan server dengan SSL enabled
$env:DB_SSL_ENABLED = "true"
$env:DB_SSL_CA = "C:\path\to\ca-cert.pem"

cd c:\myradar\server
go run cmd/main.go
```

#### ✅ HASIL YANG BENAR (Server Logs):
```
2026/01/06 12:00:00 🔐 Database SSL/TLS enabled
2026/01/06 12:00:00 📜 CA Certificate loaded from: C:\path\to\ca-cert.pem
2026/01/06 12:00:00 ✅ Database connected successfully with TLS
2026/01/06 12:00:00 🚀 Starting server on port 3000
```

#### ❌ HASIL YANG ERROR (Certificate tidak ditemukan):
```
2026/01/06 12:00:00 ⚠️ DB_SSL_CA file not found: C:\path\to\ca-cert.pem
2026/01/06 12:00:00 ⚠️ Falling back to non-SSL connection
2026/01/06 12:00:00 ✅ Database connected successfully (without TLS)
```

#### ❌ HASIL YANG ERROR (Certificate invalid):
```
2026/01/06 12:00:00 ❌ Failed to configure TLS: x509: certificate signed by unknown authority
2026/01/06 12:00:00 Fatal: Failed to connect to database
```

---

### 7.2 Verify TLS Connection di MySQL

#### Test Script (MySQL CLI):
```sql
-- Check current connection
SHOW STATUS LIKE 'Ssl_cipher';
SHOW STATUS LIKE 'Ssl_version';
```

#### ✅ HASIL YANG BENAR:
```
+---------------+------------------------+
| Variable_name | Value                  |
+---------------+------------------------+
| Ssl_cipher    | TLS_AES_256_GCM_SHA384 |
| Ssl_version   | TLSv1.3                |
+---------------+------------------------+
```

#### ❌ HASIL YANG ERROR (No SSL):
```
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| Ssl_cipher    |       |
| Ssl_version   |       |
+---------------+-------+
```

---

## 📝 TEST 8: FIELD-LEVEL ENCRYPTION

### 8.1 Test Data Encrypted in Database

#### Test Script:
```powershell
# Register user baru
$registerBody = @{
    name = "Encrypted User"
    email = "encrypted@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$registerResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
    -ContentType "application/json" -Body $registerBody

Write-Host "User registered. Check database for encrypted fields." -ForegroundColor Cyan
```

#### Check di Database:
```sql
SELECT id, email, encrypted_email, email_hash 
FROM users 
WHERE email = 'encrypted@example.com' OR email_hash IS NOT NULL
ORDER BY created_at DESC LIMIT 1;
```

#### ✅ HASIL YANG BENAR (Data terenkripsi):
```
+--------------------------------------+------------------------+----------------------------------+------------------------------------------------------------------+
| id                                   | email                  | encrypted_email                  | email_hash                                                       |
+--------------------------------------+------------------------+----------------------------------+------------------------------------------------------------------+
| uuid-here                            | encrypted@example.com  | AES256:iv:ciphertext_base64...   | 5d41402abc4b2a76b9719d911017c592...                              |
+--------------------------------------+------------------------+----------------------------------+------------------------------------------------------------------+
```

**Penjelasan:**
- `email` = Plaintext (untuk backward compatibility)
- `encrypted_email` = AES-256-GCM encrypted
- `email_hash` = SHA-256 hash untuk searchability

#### ❌ HASIL YANG ERROR (Encryption disabled):
```
+--------------------------------------+------------------------+------------------+------------+
| id                                   | email                  | encrypted_email  | email_hash |
+--------------------------------------+------------------------+------------------+------------+
| uuid-here                            | encrypted@example.com  | NULL             | NULL       |
+--------------------------------------+------------------------+------------------+------------+
```

---

### 8.2 Test API Returns Decrypted Data

#### Test Script:
```powershell
$headers = @{ Authorization = "Bearer $token" }
$profile = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/profile" -Headers $headers

Write-Host "Profile (should show decrypted email):" -ForegroundColor Cyan
$profile | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "id": "user-uuid",
    "name": "Encrypted User",
    "email": "encrypted@example.com",
    "profile_picture": null,
    "user_type": "regular",
    "mfa_enabled": false
  }
}
```

**Catatan:** Email ditampilkan dalam bentuk plaintext meskipun disimpan terenkripsi di database.

---

## 📝 TEST 9: HTTPS/TLS ENFORCEMENT

### 9.1 Test Server dengan HTTPS

#### Test Script:
```powershell
# Jalankan server dengan TLS
$env:TLS_ENABLED = "true"
$env:TLS_CERT_FILE = "C:\certs\server.crt"
$env:TLS_KEY_FILE = "C:\certs\server.key"

cd c:\myradar\server
go run cmd/main.go
```

#### ✅ HASIL YANG BENAR (Server Logs):
```
2026/01/06 12:00:00 🔒 TLS enabled
2026/01/06 12:00:00 📜 Certificate: C:\certs\server.crt
2026/01/06 12:00:00 🔑 Key: C:\certs\server.key
2026/01/06 12:00:00 🔒 Starting HTTPS server on port 3000 with TLS
```

#### Test HTTPS Connection:
```powershell
# Untuk self-signed certificate, skip verification
$response = Invoke-RestMethod -Uri "https://localhost:3000/api/health" -SkipCertificateCheck
$response | ConvertTo-Json
```

#### ✅ HASIL YANG BENAR:
```json
{
  "status": "OK",
  "message": "Workradar API is running",
  "tls": true,
  "tls_version": "TLS 1.3"
}
```

#### ❌ HASIL YANG ERROR (Certificate file not found):
```
2026/01/06 12:00:00 ⚠️ TLS certificate file not found: C:\certs\server.crt
2026/01/06 12:00:00 🚀 Starting HTTP server on port 3000 (TLS disabled)
```

---

## 📝 TEST 10: SECURITY HEADERS

### 10.1 Test Response Headers

#### Test Script:
```powershell
$response = Invoke-WebRequest -Uri "$baseUrl/api/health" -Method GET

Write-Host "Security Headers:" -ForegroundColor Cyan
$response.Headers | ForEach-Object {
    $key = $_.Key
    $value = $_.Value
    if ($key -match "X-|Content-Security|Strict-Transport|Referrer-Policy|Permissions-Policy") {
        Write-Host "$key`: $value" -ForegroundColor Green
    }
}
```

#### ✅ HASIL YANG BENAR:
```
Security Headers:
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
Referrer-Policy: no-referrer
Permissions-Policy: geolocation=(), camera=(), microphone=()
X-Request-ID: req-uuid-12345
```

#### ❌ HASIL YANG ERROR (Headers missing):
```
Security Headers:
X-Request-ID: req-uuid-12345
```
**Catatan:** Jika hanya X-Request-ID yang muncul, security headers middleware tidak aktif.

---

## 📊 SUMMARY TESTING

### Test Results Template

| No | Test Case | Expected | Actual | Status |
|----|-----------|----------|--------|--------|
| 1.1 | Audit Log Creation | Log tercatat | | ⬜ |
| 1.2 | Get Audit Logs | List logs | | ⬜ |
| 2.1 | Brute Force Detection | Account locked after 5 fails | | ⬜ |
| 2.2 | SQL Injection Detection | Threat blocked | | ⬜ |
| 3.1 | Get Security Events | List events | | ⬜ |
| 3.2 | Resolve Security Event | Event resolved | | ⬜ |
| 4.1 | Enable MFA | QR code generated | | ⬜ |
| 4.2 | Verify MFA Setup | MFA enabled | | ⬜ |
| 4.3 | Login with MFA | Requires MFA code | | ⬜ |
| 5.1 | Password Validation | Weak password rejected | | ⬜ |
| 6.1 | Account Lockout | Account locked | | ⬜ |
| 6.2 | Auto Unlock | Account unlocked after timeout | | ⬜ |
| 7.1 | DB SSL Connection | TLS enabled | | ⬜ |
| 8.1 | Field Encryption | Data encrypted in DB | | ⬜ |
| 8.2 | Data Decryption | API returns plaintext | | ⬜ |
| 9.1 | HTTPS Server | TLS active | | ⬜ |
| 10.1 | Security Headers | All headers present | | ⬜ |

### Legend
- ✅ PASS
- ❌ FAIL
- ⬜ NOT TESTED

---

## 🔧 TROUBLESHOOTING

### Common Issues:

1. **401 Unauthorized**
   - Token expired atau invalid
   - Solution: Login ulang untuk mendapatkan token baru

2. **403 Forbidden**
   - User tidak punya permission
   - Solution: Login dengan admin account

3. **429 Too Many Requests**
   - Rate limit atau account locked
   - Solution: Tunggu sesuai `retry_after_seconds`

4. **500 Internal Server Error**
   - Server error
   - Solution: Check server logs untuk detail error

5. **Connection Refused**
   - Server tidak running
   - Solution: Jalankan `go run cmd/main.go`
