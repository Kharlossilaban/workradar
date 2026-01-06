# 🧪 TESTING KEAMANAN BASIS DATA PART 3 (Minggu 11-13 & MITM)

## 📋 Daftar Pengujian

| No | Fitur | Endpoint/File | Status |
|----|-------|---------------|--------|
| 1 | Multi-User Database Connection | Database roles | 🧪 |
| 2 | Permission Management System | Access control | 🧪 |
| 3 | Access Control Middleware | Protected routes | 🧪 |
| 4 | Database Views (Row-Level Security) | SQL views | 🧪 |
| 5 | Field-Level Encryption | AES-256-GCM | 🧪 |
| 6 | Key Management Service | Key rotation | 🧪 |
| 7 | Comprehensive Audit Logging | Audit service | 🧪 |
| 8 | Security Audit Service | Audit checks | 🧪 |
| 9 | Vulnerability Scanner | Security scan | 🧪 |
| 10 | Security Monitoring Dashboard | Dashboard API | 🧪 |
| 11 | Security Scheduler | Automated tasks | 🧪 |
| 12 | HTTPS/TLS Server | TLS configuration | 🧪 |
| 13 | Certificate Pinning | Flutter client | 🧪 |
| 14 | Security Headers | Response headers | 🧪 |

---

## 🔧 PERSIAPAN TESTING

### 1. Jalankan Server
```powershell
cd c:\myradar\server
$env:GO_ENV="development"
$env:JWT_SECRET="test-jwt-secret-key-minimum-32-chars"
$env:ENCRYPTION_KEY="test-encryption-key-32-characters"
$env:DB_MULTI_USER_ENABLED="true"
$env:DB_USER_READ="workradar_read"
$env:DB_PASSWORD_READ="read_password"
$env:DB_USER_APP="workradar_app"
$env:DB_PASSWORD_APP="app_password"
$env:DB_USER_ADMIN="workradar_admin"
$env:DB_PASSWORD_ADMIN="admin_password"
go run cmd/main.go
```

### 2. Setup Test Users
```powershell
$baseUrl = "http://localhost:3000"

# Register regular user
$userBody = @{
    name = "Regular User"
    email = "user@example.com"
    password = "User@123456"
} | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" -ContentType "application/json" -Body $userBody

# Login sebagai user
$userLogin = @{ email = "user@example.com"; password = "User@123456" } | ConvertTo-Json
$userResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" -ContentType "application/json" -Body $userLogin
$userToken = $userResult.data.access_token

# Login sebagai admin (assume admin exists)
$adminLogin = @{ email = "admin@example.com"; password = "Admin@123456" } | ConvertTo-Json
$adminResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" -ContentType "application/json" -Body $adminLogin
$adminToken = $adminResult.data.access_token

# Headers
$userHeaders = @{ Authorization = "Bearer $userToken" }
$adminHeaders = @{ Authorization = "Bearer $adminToken" }
```

---

## 📝 TEST 1: MULTI-USER DATABASE CONNECTION

### 1.1 Test Database Roles Isolation

#### Langkah Testing (MySQL CLI):
```sql
-- Connect sebagai read user
mysql -u workradar_read -p workradar

-- Test 1: SELECT should work
SELECT id, email, user_type FROM users LIMIT 5;

-- Test 2: INSERT should FAIL
INSERT INTO users (id, name, email) VALUES ('test', 'Test', 'test@test.com');

-- Test 3: UPDATE should FAIL
UPDATE users SET name = 'Hacked' WHERE id = 'some-id';

-- Test 4: DELETE should FAIL
DELETE FROM users WHERE id = 'some-id';
```

#### ✅ HASIL YANG BENAR (Read User):

**SELECT (Success):**
```
+--------------------------------------+------------------+-----------+
| id                                   | email            | user_type |
+--------------------------------------+------------------+-----------+
| uuid-1                               | user1@test.com   | regular   |
| uuid-2                               | user2@test.com   | vip       |
+--------------------------------------+------------------+-----------+
2 rows in set (0.00 sec)
```

**INSERT (Denied):**
```
ERROR 1142 (42000): INSERT command denied to user 'workradar_read'@'localhost' for table 'users'
```

**UPDATE (Denied):**
```
ERROR 1142 (42000): UPDATE command denied to user 'workradar_read'@'localhost' for table 'users'
```

**DELETE (Denied):**
```
ERROR 1142 (42000): DELETE command denied to user 'workradar_read'@'localhost' for table 'users'
```

#### ❌ HASIL YANG ERROR:
```
Query OK, 1 row affected (0.01 sec)
```
**Masalah:** Read user seharusnya tidak bisa INSERT/UPDATE/DELETE.

---

### 1.2 Test App User Restrictions

#### Langkah Testing (MySQL CLI):
```sql
-- Connect sebagai app user
mysql -u workradar_app -p workradar

-- Test: DELETE on users should FAIL
DELETE FROM users WHERE id = 'test-id';

-- Test: DELETE on tasks should WORK
DELETE FROM tasks WHERE id = 'test-task-id';

-- Test: UPDATE user_type should FAIL (role change)
UPDATE users SET user_type = 'admin' WHERE id = 'some-id';
```

#### ✅ HASIL YANG BENAR (App User):

**DELETE users (Denied):**
```
ERROR 1142 (42000): DELETE command denied to user 'workradar_app'@'localhost' for table 'users'
```

**DELETE tasks (Success):**
```
Query OK, 1 row affected (0.01 sec)
```

**UPDATE user_type (Denied):**
```
ERROR 1143 (42000): UPDATE command denied to user 'workradar_app'@'localhost' for column 'user_type' in table 'users'
```

---

### 1.3 Test Connection Manager via API

#### Test Script:
```powershell
Write-Host "=== MULTI-CONNECTION MANAGER TEST ===" -ForegroundColor Yellow

# Check database stats (requires admin)
$dbStats = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/health/detailed" -Headers $adminHeaders

Write-Host "Database Connection Stats:" -ForegroundColor Cyan
$dbStats.data.database | ConvertTo-Json -Depth 3
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "database": {
      "status": "healthy",
      "connections": {
        "read": {
          "status": "connected",
          "open_connections": 5,
          "in_use": 1,
          "idle": 4,
          "max_open": 10
        },
        "app": {
          "status": "connected",
          "open_connections": 10,
          "in_use": 3,
          "idle": 7,
          "max_open": 100
        },
        "admin": {
          "status": "connected",
          "open_connections": 2,
          "in_use": 0,
          "idle": 2,
          "max_open": 10
        }
      },
      "multi_user_enabled": true
    }
  }
}
```

#### ❌ HASIL YANG ERROR (Multi-user disabled):
```json
{
  "data": {
    "database": {
      "status": "healthy",
      "connections": {
        "default": {
          "status": "connected",
          "open_connections": 15
        }
      },
      "multi_user_enabled": false
    }
  }
}
```

---

## 📝 TEST 2: PERMISSION MANAGEMENT SYSTEM

### 2.1 Test Role Permissions

#### Test Script:
```powershell
Write-Host "=== PERMISSION MANAGEMENT TEST ===" -ForegroundColor Yellow

# Test user permissions
Write-Host "`n1. Regular User Permissions:" -ForegroundColor Cyan

# User should be able to create tasks
$taskBody = @{
    title = "User Task"
    description = "Test"
    priority = "high"
    date = "2026-01-07"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
        -Headers $userHeaders -ContentType "application/json" -Body $taskBody
    Write-Host "Create Task: ALLOWED ✅" -ForegroundColor Green
} catch {
    Write-Host "Create Task: DENIED ❌" -ForegroundColor Red
}

# User should NOT be able to access admin endpoints
Write-Host "`n2. Admin Endpoint Access (as regular user):" -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/monitoring/dashboard" -Headers $userHeaders
    Write-Host "Access Monitoring: ALLOWED (SHOULD BE DENIED) ❌" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "Access Monitoring: DENIED ✅" -ForegroundColor Green
    } else {
        Write-Host "Access Monitoring: Status $statusCode" -ForegroundColor Yellow
    }
}

# Admin should be able to access admin endpoints
Write-Host "`n3. Admin Endpoint Access (as admin):" -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/monitoring/dashboard" -Headers $adminHeaders
    Write-Host "Access Monitoring: ALLOWED ✅" -ForegroundColor Green
} catch {
    Write-Host "Access Monitoring: DENIED (SHOULD BE ALLOWED) ❌" -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```
1. Regular User Permissions:
Create Task: ALLOWED ✅

2. Admin Endpoint Access (as regular user):
Access Monitoring: DENIED ✅

3. Admin Endpoint Access (as admin):
Access Monitoring: ALLOWED ✅
```

---

### 2.2 Test Permission Hierarchy

#### Test Script:
```powershell
Write-Host "=== PERMISSION HIERARCHY TEST ===" -ForegroundColor Yellow

# Get current user permissions
$permissions = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/profile/permissions" -Headers $userHeaders

Write-Host "User Permissions:" -ForegroundColor Cyan
$permissions.data.permissions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

# Get admin permissions
$adminPermissions = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/profile/permissions" -Headers $adminHeaders

Write-Host "`nAdmin Permissions:" -ForegroundColor Cyan
$adminPermissions.data.permissions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
```

#### ✅ HASIL YANG BENAR:

**Regular User Permissions:**
```json
{
  "success": true,
  "data": {
    "user_id": "user-uuid",
    "role": "user",
    "permissions": [
      "task:read",
      "task:create",
      "task:update",
      "task:delete",
      "category:read",
      "category:create",
      "category:update",
      "category:delete",
      "user:read",
      "user:update"
    ]
  }
}
```

**Admin Permissions:**
```json
{
  "success": true,
  "data": {
    "user_id": "admin-uuid",
    "role": "admin",
    "permissions": [
      "task:read", "task:create", "task:update", "task:delete",
      "category:read", "category:create", "category:update", "category:delete",
      "user:read", "user:create", "user:update", "user:delete",
      "user:upgrade", "user:lock", "user:unlock",
      "audit:read",
      "security:read", "security:manage",
      "payment:read", "payment:process"
    ]
  }
}
```

---

## 📝 TEST 3: ACCESS CONTROL MIDDLEWARE

### 3.1 Test Resource Owner Check

#### Test Script:
```powershell
Write-Host "=== RESOURCE OWNER CHECK ===" -ForegroundColor Yellow

# Create task as user
$taskBody = @{
    title = "My Task"
    description = "Owner test"
    priority = "medium"
    date = "2026-01-07"
} | ConvertTo-Json

$createResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
    -Headers $userHeaders -ContentType "application/json" -Body $taskBody
$taskId = $createResult.data.id

Write-Host "Task created with ID: $taskId" -ForegroundColor Green

# User should be able to update their own task
Write-Host "`n1. Owner updating own task:" -ForegroundColor Cyan
$updateBody = @{ title = "Updated My Task" } | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/tasks/$taskId" `
        -Headers $userHeaders -ContentType "application/json" -Body $updateBody
    Write-Host "Update Own Task: ALLOWED ✅" -ForegroundColor Green
} catch {
    Write-Host "Update Own Task: DENIED ❌" -ForegroundColor Red
}

# Another user should NOT be able to update this task
Write-Host "`n2. Another user updating someone else's task:" -ForegroundColor Cyan

# Register another user
$otherUserBody = @{
    name = "Other User"
    email = "other_$(Get-Random)@example.com"
    password = "Other@123456"
} | ConvertTo-Json
$otherResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
    -ContentType "application/json" -Body $otherUserBody
$otherToken = $otherResult.data.access_token
$otherHeaders = @{ Authorization = "Bearer $otherToken" }

try {
    $result = Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/tasks/$taskId" `
        -Headers $otherHeaders -ContentType "application/json" -Body $updateBody
    Write-Host "Update Other's Task: ALLOWED (SHOULD BE DENIED) ❌" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 404) {
        Write-Host "Update Other's Task: DENIED ✅" -ForegroundColor Green
    }
}

# Admin should be able to update any task
Write-Host "`n3. Admin updating any task:" -ForegroundColor Cyan
try {
    $result = Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/tasks/$taskId" `
        -Headers $adminHeaders -ContentType "application/json" -Body $updateBody
    Write-Host "Admin Update Any Task: ALLOWED ✅" -ForegroundColor Green
} catch {
    Write-Host "Admin Update Any Task: DENIED ❌" -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```
Task created with ID: task-uuid-123

1. Owner updating own task:
Update Own Task: ALLOWED ✅

2. Another user updating someone else's task:
Update Other's Task: DENIED ✅

3. Admin updating any task:
Admin Update Any Task: ALLOWED ✅
```

---

### 3.2 Test Multiple Permissions Required

#### Test Script:
```powershell
Write-Host "=== MULTIPLE PERMISSIONS CHECK ===" -ForegroundColor Yellow

# Test endpoint that requires multiple permissions
Write-Host "Attempting to delete user (requires user:delete + admin:full):" -ForegroundColor Cyan

$testUserId = "some-user-id"

# Regular user (should fail)
try {
    $result = Invoke-RestMethod -Method DELETE `
        -Uri "$baseUrl/api/admin/users/$testUserId" `
        -Headers $userHeaders
    Write-Host "Regular User: ALLOWED ❌" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Regular User: DENIED ✅ - $($errorBody.message)" -ForegroundColor Green
}

# Admin without superadmin (should fail)
try {
    $result = Invoke-RestMethod -Method DELETE `
        -Uri "$baseUrl/api/admin/users/$testUserId" `
        -Headers $adminHeaders
    Write-Host "Admin: ALLOWED ❌ (needs superadmin)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "Admin: DENIED ✅ (requires superadmin)" -ForegroundColor Green
    } else {
        Write-Host "Admin: Status $statusCode" -ForegroundColor Yellow
    }
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": false,
  "message": "Access denied. Required permissions: user:delete, admin:full",
  "error": "forbidden",
  "missing_permissions": ["admin:full"]
}
```
**HTTP Status:** `403 Forbidden`

---

## 📝 TEST 4: DATABASE VIEWS (Row-Level Security)

### 4.1 Test View Data Masking

#### Test di MySQL CLI:
```sql
-- Test v_user_public_profiles (email masked)
SELECT * FROM v_user_public_profiles LIMIT 5;
```

#### ✅ HASIL YANG BENAR:
```
+--------------------------------------+-------------+---------------------+------------------+---------------+-----------+-------------+---------------------+
| id                                   | username    | email_masked        | profile_picture  | auth_provider | user_type | mfa_enabled | created_at          |
+--------------------------------------+-------------+---------------------+------------------+---------------+-----------+-------------+---------------------+
| uuid-1                               | john_doe    | joh***@example.com  | /images/john.jpg | local         | regular   | 1           | 2026-01-01 10:00:00 |
| uuid-2                               | jane_smith  | jan***@example.com  | NULL             | google        | vip       | 0           | 2026-01-02 11:00:00 |
+--------------------------------------+-------------+---------------------+------------------+---------------+-----------+-------------+---------------------+
```

**Catatan:** Email di-mask menjadi `xxx***@domain.com`

#### ❌ HASIL YANG ERROR (Email tidak masked):
```
+--------------------------------------+-------------+----------------------+
| id                                   | username    | email_masked         |
+--------------------------------------+-------------+----------------------+
| uuid-1                               | john_doe    | john.doe@example.com |
+--------------------------------------+-------------+----------------------+
```

---

### 4.2 Test Audit Logs View

#### Test di MySQL CLI:
```sql
-- Test v_audit_logs_summary (user email masked)
SELECT * FROM v_audit_logs_summary ORDER BY created_at DESC LIMIT 5;
```

#### ✅ HASIL YANG BENAR:
```
+--------------------------------------+--------+------------+-----------+-------------+---------------------+-----------+---------------------+
| id                                   | action | table_name | record_id | ip_address  | created_at          | user_name | user_email_masked   |
+--------------------------------------+--------+------------+-----------+-------------+---------------------+-----------+---------------------+
| uuid-1                               | CREATE | tasks      | task-uuid | 127.0.0.1   | 2026-01-06 12:00:00 | John Doe  | joh***@example.com  |
| uuid-2                               | UPDATE | users      | user-uuid | 192.168.1.1 | 2026-01-06 11:55:00 | Jane S.   | jan***@example.com  |
+--------------------------------------+--------+------------+-----------+-------------+---------------------+-----------+---------------------+
```

---

### 4.3 Test Security Events Dashboard View

#### Test di MySQL CLI:
```sql
-- Test v_security_events_dashboard (aggregated last 30 days)
SELECT * FROM v_security_events_dashboard ORDER BY event_date DESC LIMIT 7;
```

#### ✅ HASIL YANG BENAR:
```
+------------+---------------------+----------+-------------+
| event_date | event_type          | severity | event_count |
+------------+---------------------+----------+-------------+
| 2026-01-06 | FAILED_LOGIN        | WARNING  | 15          |
| 2026-01-06 | ACCOUNT_LOCKED      | HIGH     | 3           |
| 2026-01-06 | SQL_INJECTION_ATTEMPT| CRITICAL| 1           |
| 2026-01-05 | FAILED_LOGIN        | WARNING  | 8           |
| 2026-01-05 | SUSPICIOUS_ACTIVITY | MEDIUM   | 2           |
+------------+---------------------+----------+-------------+
```

---

## 📝 TEST 5: FIELD-LEVEL ENCRYPTION (AES-256-GCM)

### 5.1 Test Data Encryption at Rest

#### Test Script:
```powershell
Write-Host "=== FIELD-LEVEL ENCRYPTION TEST ===" -ForegroundColor Yellow

# Register user dengan email yang akan dienkripsi
$encryptTestBody = @{
    name = "Encrypt Test User"
    email = "encrypt_test_$(Get-Random)@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$encryptResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/register" `
    -ContentType "application/json" -Body $encryptTestBody

$userId = $encryptResult.data.user.id
$email = $encryptResult.data.user.email

Write-Host "User registered: $email" -ForegroundColor Green
Write-Host "User ID: $userId" -ForegroundColor Green
```

#### Check di Database:
```sql
SELECT id, email, encrypted_email, email_hash 
FROM users 
WHERE id = 'user-id-here';
```

#### ✅ HASIL YANG BENAR:
```
+--------------------------------------+----------------------------------+------------------------------------------------------------------+------------------------------------------------------------------+
| id                                   | email                            | encrypted_email                                                  | email_hash                                                       |
+--------------------------------------+----------------------------------+------------------------------------------------------------------+------------------------------------------------------------------+
| uuid-here                            | encrypt_test_123@example.com     | AES256GCM:nonce:ciphertext_base64_encoded_string_here...        | a7f3c2b1e5d4f6a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1 |
+--------------------------------------+----------------------------------+------------------------------------------------------------------+------------------------------------------------------------------+
```

**Penjelasan:**
- `email` = Plaintext (backward compatibility)
- `encrypted_email` = Format: `AES256GCM:nonce(base64):ciphertext(base64)`
- `email_hash` = SHA-256 hash untuk pencarian

#### ❌ HASIL YANG ERROR (Encryption disabled):
```
+--------------------------------------+----------------------------------+------------------+------------+
| id                                   | email                            | encrypted_email  | email_hash |
+--------------------------------------+----------------------------------+------------------+------------+
| uuid-here                            | encrypt_test_123@example.com     | NULL             | NULL       |
+--------------------------------------+----------------------------------+------------------+------------+
```

---

### 5.2 Test Decryption on Read

#### Test Script:
```powershell
# API harus mengembalikan email yang sudah di-decrypt
$encryptToken = $encryptResult.data.access_token
$encryptHeaders = @{ Authorization = "Bearer $encryptToken" }

$profile = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/profile" -Headers $encryptHeaders

Write-Host "`nProfile from API:" -ForegroundColor Cyan
Write-Host "Email: $($profile.data.email)" -ForegroundColor Green

if ($profile.data.email -eq $email) {
    Write-Host "Decryption: SUCCESS ✅" -ForegroundColor Green
} else {
    Write-Host "Decryption: FAILED ❌" -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "id": "user-uuid",
    "name": "Encrypt Test User",
    "email": "encrypt_test_123@example.com",
    "user_type": "regular"
  }
}
```

---

### 5.3 Test Search by Encrypted Field

#### Test Script:
```powershell
# Search menggunakan email_hash (bukan decrypt semua record)
Write-Host "`nTest: Find user by email (uses hash):" -ForegroundColor Cyan

# Login dengan email yang sama
$loginBody = @{
    email = $email
    password = "Test@123456"
} | ConvertTo-Json

try {
    $loginResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/auth/login" `
        -ContentType "application/json" -Body $loginBody
    Write-Host "Login with encrypted email: SUCCESS ✅" -ForegroundColor Green
} catch {
    Write-Host "Login with encrypted email: FAILED ❌" -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "email": "encrypt_test_123@example.com"
    },
    "access_token": "..."
  }
}
```

---

## 📝 TEST 6: KEY MANAGEMENT SERVICE

### 6.1 Test Key Rotation

#### Test Script (Internal - Server Logs):
```powershell
# Trigger key rotation (admin only)
$rotateBody = @{
    key_type = "encryption"
    new_key = "new-32-character-encryption-key!"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/admin/keys/rotate" `
        -Headers $adminHeaders -ContentType "application/json" -Body $rotateBody
    Write-Host "Key Rotation Result:" -ForegroundColor Cyan
    $result | ConvertTo-Json
} catch {
    $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Error: $($errorBody.message)" -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Key rotated successfully",
  "data": {
    "key_type": "encryption",
    "key_id": "primary_encryption",
    "rotated_at": "2026-01-06T12:00:00Z",
    "old_key_archived": true,
    "re_encryption_status": "pending",
    "affected_records": 150
  }
}
```

#### Check Server Logs:
```
2026/01/06 12:00:00 🔑 Key rotation initiated for: encryption
2026/01/06 12:00:00 📦 Old key archived with ID: key_backup_20260106
2026/01/06 12:00:00 🔄 Re-encrypting 150 user records...
2026/01/06 12:00:05 ✅ Re-encryption completed successfully
```

---

### 6.2 Test Key Expiration Check

#### Test Script:
```powershell
# Get key status
$keyStatus = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/admin/keys/status" -Headers $adminHeaders

Write-Host "Key Status:" -ForegroundColor Cyan
$keyStatus.data | ConvertTo-Json -Depth 3
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "keys": [
      {
        "id": "primary_encryption",
        "type": "encryption",
        "created_at": "2026-01-01T00:00:00Z",
        "expires_at": "2026-04-01T00:00:00Z",
        "is_active": true,
        "days_until_expiry": 85,
        "status": "healthy"
      },
      {
        "id": "jwt_signing",
        "type": "jwt",
        "created_at": "2025-12-01T00:00:00Z",
        "expires_at": "2026-02-01T00:00:00Z",
        "is_active": true,
        "days_until_expiry": 26,
        "status": "expiring_soon"
      }
    ],
    "warnings": [
      "JWT signing key expires in 26 days. Consider rotating."
    ]
  }
}
```

---

## 📝 TEST 7: COMPREHENSIVE AUDIT LOGGING

### 7.1 Test All Audit Log Types

#### Test Script:
```powershell
Write-Host "=== AUDIT LOGGING TEST ===" -ForegroundColor Yellow

# CREATE operation
Write-Host "`n1. Testing CREATE audit:" -ForegroundColor Cyan
$taskBody = @{
    title = "Audit Test Task"
    description = "Testing audit logging"
    priority = "high"
    date = "2026-01-07"
} | ConvertTo-Json
$createResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/tasks" `
    -Headers $userHeaders -ContentType "application/json" -Body $taskBody
$taskId = $createResult.data.id
Write-Host "Task created: $taskId" -ForegroundColor Green

# UPDATE operation
Write-Host "`n2. Testing UPDATE audit:" -ForegroundColor Cyan
$updateBody = @{ title = "Updated Audit Test Task" } | ConvertTo-Json
$updateResult = Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/tasks/$taskId" `
    -Headers $userHeaders -ContentType "application/json" -Body $updateBody
Write-Host "Task updated" -ForegroundColor Green

# DELETE operation
Write-Host "`n3. Testing DELETE audit:" -ForegroundColor Cyan
$deleteResult = Invoke-RestMethod -Method DELETE -Uri "$baseUrl/api/tasks/$taskId" `
    -Headers $userHeaders
Write-Host "Task deleted" -ForegroundColor Green

# Fetch audit logs for this task
Write-Host "`n4. Fetching audit logs:" -ForegroundColor Cyan
$auditLogs = Invoke-RestMethod -Method GET `
    -Uri "$baseUrl/api/security/audit-logs?record_id=$taskId&limit=10" `
    -Headers $adminHeaders

$auditLogs.data.logs | ForEach-Object {
    Write-Host "  - $($_.action) at $($_.created_at)" -ForegroundColor Gray
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "audit-uuid-1",
        "user_id": "user-uuid",
        "action": "CREATE",
        "table_name": "tasks",
        "record_id": "task-uuid",
        "old_value": null,
        "new_value": "{\"title\":\"Audit Test Task\",\"priority\":\"high\"}",
        "ip_address": "127.0.0.1",
        "duration_ms": 15,
        "created_at": "2026-01-06T12:00:00Z"
      },
      {
        "id": "audit-uuid-2",
        "user_id": "user-uuid",
        "action": "UPDATE",
        "table_name": "tasks",
        "record_id": "task-uuid",
        "old_value": "{\"title\":\"Audit Test Task\"}",
        "new_value": "{\"title\":\"Updated Audit Test Task\"}",
        "ip_address": "127.0.0.1",
        "duration_ms": 12,
        "created_at": "2026-01-06T12:00:05Z"
      },
      {
        "id": "audit-uuid-3",
        "user_id": "user-uuid",
        "action": "DELETE",
        "table_name": "tasks",
        "record_id": "task-uuid",
        "old_value": "{\"title\":\"Updated Audit Test Task\",\"priority\":\"high\"}",
        "new_value": null,
        "ip_address": "127.0.0.1",
        "duration_ms": 10,
        "created_at": "2026-01-06T12:00:10Z"
      }
    ],
    "total": 3
  }
}
```

---

## 📝 TEST 8: SECURITY AUDIT SERVICE

### 8.1 Test Run Full Security Audit

#### Test Script:
```powershell
Write-Host "=== SECURITY AUDIT TEST ===" -ForegroundColor Yellow

# Run full security audit
$auditResult = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/monitoring/audit/run" `
    -Headers $adminHeaders

Write-Host "Security Audit Report:" -ForegroundColor Cyan
$auditResult.data | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "audit_id": "audit-uuid",
    "started_at": "2026-01-06T12:00:00Z",
    "completed_at": "2026-01-06T12:00:15Z",
    "overall_score": 78,
    "overall_status": "WARNING",
    "findings": [
      {
        "check_type": "password_policy",
        "severity": "MEDIUM",
        "status": "WARNING",
        "message": "15 users have passwords older than 90 days",
        "affected_count": 15,
        "recommendation": "Enforce password rotation policy"
      },
      {
        "check_type": "mfa_adoption",
        "severity": "HIGH",
        "status": "WARNING",
        "message": "Only 35% of users have MFA enabled",
        "current_value": 35,
        "threshold": 50,
        "recommendation": "Encourage or enforce MFA for all users"
      },
      {
        "check_type": "failed_logins",
        "severity": "MEDIUM",
        "status": "PASS",
        "message": "3 accounts had 3+ failed logins in 24h",
        "affected_count": 3
      },
      {
        "check_type": "encryption",
        "severity": "CRITICAL",
        "status": "PASS",
        "message": "Field encryption is enabled",
        "encrypted_fields": ["email", "phone"]
      }
    ],
    "summary": {
      "total_checks": 10,
      "passed": 7,
      "warnings": 2,
      "failed": 1,
      "critical": 0
    }
  }
}
```

#### ❌ HASIL YANG ERROR (Audit failed):
```json
{
  "success": false,
  "message": "Security audit failed",
  "error": "audit_error",
  "details": "Database connection failed during audit"
}
```

---

### 8.2 Test Individual Audit Checks

#### Test Script:
```powershell
# Run specific audit check
$checkTypes = @("password_policy", "mfa_adoption", "failed_logins", "encryption", "database_health")

foreach ($checkType in $checkTypes) {
    Write-Host "`nRunning check: $checkType" -ForegroundColor Cyan
    
    $checkBody = @{ check_type = $checkType } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Method POST `
            -Uri "$baseUrl/api/monitoring/audit/check" `
            -Headers $adminHeaders -ContentType "application/json" -Body $checkBody
        
        Write-Host "Status: $($result.data.status)" -ForegroundColor $(if($result.data.status -eq "PASS"){"Green"}else{"Yellow"})
        Write-Host "Message: $($result.data.message)" -ForegroundColor Gray
    } catch {
        Write-Host "Check failed" -ForegroundColor Red
    }
}
```

---

## 📝 TEST 9: VULNERABILITY SCANNER

### 9.1 Test Quick Vulnerability Scan

#### Test Script:
```powershell
Write-Host "=== VULNERABILITY SCANNER TEST ===" -ForegroundColor Yellow

# Run quick scan
$scanResult = Invoke-RestMethod -Method POST `
    -Uri "$baseUrl/api/monitoring/vulnerability/scan?mode=quick" `
    -Headers $adminHeaders

Write-Host "Vulnerability Scan Result:" -ForegroundColor Cyan
$scanResult.data | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "scan_id": "scan-uuid",
    "mode": "quick",
    "started_at": "2026-01-06T12:00:00Z",
    "completed_at": "2026-01-06T12:00:30Z",
    "risk_score": 25,
    "risk_level": "LOW",
    "vulnerabilities": [
      {
        "type": "WEAK_PASSWORD",
        "severity": "MEDIUM",
        "count": 5,
        "description": "5 users have weak passwords",
        "recommendation": "Enforce stronger password policy"
      },
      {
        "type": "MISSING_ENCRYPTION",
        "severity": "LOW",
        "count": 2,
        "description": "2 optional fields are not encrypted",
        "fields": ["address", "bio"],
        "recommendation": "Consider encrypting sensitive optional fields"
      }
    ],
    "components_scanned": [
      "authentication",
      "encryption",
      "security_events"
    ],
    "summary": {
      "critical": 0,
      "high": 0,
      "medium": 1,
      "low": 1,
      "info": 0
    }
  }
}
```

---

### 9.2 Test SQL Injection Detection

#### Test Script:
```powershell
Write-Host "`n=== SQL INJECTION DETECTION TEST ===" -ForegroundColor Yellow

$testInputs = @(
    "admin' OR '1'='1",
    "1; DROP TABLE users;--",
    "' UNION SELECT * FROM users--",
    "Normal text without injection"
)

foreach ($input in $testInputs) {
    Write-Host "`nInput: $input" -ForegroundColor Cyan
    
    $detectBody = @{
        input = $input
        check_types = @("sql_injection", "xss")
    } | ConvertTo-Json
    
    $result = Invoke-RestMethod -Method POST `
        -Uri "$baseUrl/api/monitoring/vulnerability/detect" `
        -Headers $adminHeaders -ContentType "application/json" -Body $detectBody
    
    if ($result.data.threats_detected) {
        Write-Host "Threats: $($result.data.threats -join ', ')" -ForegroundColor Red
        Write-Host "Patterns: $($result.data.patterns_matched -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "No threats detected" -ForegroundColor Green
    }
}
```

#### ✅ HASIL YANG BENAR:
```
Input: admin' OR '1'='1
Threats: SQL_INJECTION
Patterns: or_injection, quote_escape

Input: 1; DROP TABLE users;--
Threats: SQL_INJECTION
Patterns: drop_table, comment_sequence, semicolon_injection

Input: ' UNION SELECT * FROM users--
Threats: SQL_INJECTION
Patterns: union_select, comment_sequence

Input: Normal text without injection
No threats detected
```

---

## 📝 TEST 10: SECURITY MONITORING DASHBOARD

### 10.1 Test Dashboard Endpoint

#### Test Script:
```powershell
Write-Host "=== SECURITY DASHBOARD TEST ===" -ForegroundColor Yellow

$dashboard = Invoke-RestMethod -Method GET `
    -Uri "$baseUrl/api/monitoring/dashboard" `
    -Headers $adminHeaders

Write-Host "Security Dashboard:" -ForegroundColor Cyan
$dashboard.data | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "timestamp": "2026-01-06T12:00:00Z",
    "audit": {
      "last_run": "2026-01-06T00:00:00Z",
      "score": 78,
      "status": "WARNING",
      "findings": 3,
      "is_running": false
    },
    "vulnerability": {
      "last_run": "2026-01-06T06:00:00Z",
      "risk_score": 25,
      "risk_level": "LOW",
      "vulnerabilities": 2,
      "is_scanning": false
    },
    "database": {
      "status": "healthy",
      "pool_usage_percent": 15,
      "connections": {
        "active": 8,
        "idle": 42,
        "max": 100
      }
    },
    "security_events": {
      "last_24h": 45,
      "critical": 0,
      "high": 2,
      "medium": 8,
      "low": 35
    },
    "authentication": {
      "active_sessions": 127,
      "locked_accounts": 3,
      "mfa_enabled_percent": 35
    },
    "threats": {
      "blocked_ips": 5,
      "sql_injection_attempts_24h": 12,
      "xss_attempts_24h": 3
    }
  }
}
```

---

## 📝 TEST 11: SECURITY SCHEDULER

### 11.1 Test Scheduler Status

#### Test Script:
```powershell
Write-Host "=== SECURITY SCHEDULER TEST ===" -ForegroundColor Yellow

$schedulerStatus = Invoke-RestMethod -Method GET `
    -Uri "$baseUrl/api/monitoring/scheduler/status" `
    -Headers $adminHeaders

Write-Host "Scheduler Status:" -ForegroundColor Cyan
$schedulerStatus.data | ConvertTo-Json -Depth 5
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "data": {
    "is_running": true,
    "started_at": "2026-01-06T00:00:00Z",
    "tasks": [
      {
        "type": "SECURITY_AUDIT",
        "interval": "24h",
        "last_run": "2026-01-06T00:00:00Z",
        "next_run": "2026-01-07T00:00:00Z",
        "status": "idle",
        "enabled": true
      },
      {
        "type": "VULNERABILITY_SCAN",
        "interval": "12h",
        "last_run": "2026-01-06T06:00:00Z",
        "next_run": "2026-01-06T18:00:00Z",
        "status": "idle",
        "enabled": true
      },
      {
        "type": "SESSION_CLEANUP",
        "interval": "1h",
        "last_run": "2026-01-06T11:00:00Z",
        "next_run": "2026-01-06T12:00:00Z",
        "status": "running",
        "enabled": true
      },
      {
        "type": "AUDIT_LOG_CLEANUP",
        "interval": "7d",
        "last_run": "2026-01-01T00:00:00Z",
        "next_run": "2026-01-08T00:00:00Z",
        "status": "idle",
        "enabled": true
      }
    ],
    "execution_logs": [
      {
        "task_type": "SESSION_CLEANUP",
        "started_at": "2026-01-06T11:00:00Z",
        "completed_at": "2026-01-06T11:00:05Z",
        "status": "success",
        "details": "Cleaned 23 expired sessions"
      }
    ]
  }
}
```

---

### 11.2 Test Manual Task Execution

#### Test Script:
```powershell
Write-Host "`nManually running SESSION_CLEANUP task:" -ForegroundColor Cyan

$runResult = Invoke-RestMethod -Method POST `
    -Uri "$baseUrl/api/monitoring/scheduler/task/SESSION_CLEANUP/run" `
    -Headers $adminHeaders

Write-Host "Task Execution Result:" -ForegroundColor Cyan
$runResult | ConvertTo-Json -Depth 3
```

#### ✅ HASIL YANG BENAR:
```json
{
  "success": true,
  "message": "Task executed successfully",
  "data": {
    "task_type": "SESSION_CLEANUP",
    "started_at": "2026-01-06T12:05:00Z",
    "completed_at": "2026-01-06T12:05:03Z",
    "duration_ms": 3000,
    "result": {
      "sessions_cleaned": 15,
      "tokens_invalidated": 8
    }
  }
}
```

---

## 📝 TEST 12: HTTPS/TLS SERVER

### 12.1 Test TLS Configuration

#### Test Script:
```powershell
Write-Host "=== HTTPS/TLS TEST ===" -ForegroundColor Yellow

# Start server with TLS
$env:TLS_ENABLED = "true"
$env:TLS_CERT_FILE = "C:\certs\server.crt"
$env:TLS_KEY_FILE = "C:\certs\server.key"

# Test HTTPS endpoint
try {
    $response = Invoke-RestMethod -Uri "https://localhost:3000/api/health" -SkipCertificateCheck
    Write-Host "HTTPS Connection: SUCCESS ✅" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Host "HTTPS Connection: FAILED ❌" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
```

#### ✅ HASIL YANG BENAR:
```json
{
  "status": "OK",
  "message": "Workradar API is running",
  "protocol": "https",
  "tls_version": "TLS 1.3"
}
```

---

### 12.2 Test HTTPS Redirect

#### Test Script:
```powershell
# Test HTTP to HTTPS redirect
$env:HTTPS_REDIRECT_ENABLED = "true"

Write-Host "`nTest HTTP to HTTPS redirect:" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -MaximumRedirection 0
    Write-Host "No redirect (unexpected)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $location = $_.Exception.Response.Headers.Location
    
    if ($statusCode -eq 301 -and $location -match "https://") {
        Write-Host "Redirect to HTTPS: SUCCESS ✅" -ForegroundColor Green
        Write-Host "Location: $location" -ForegroundColor Gray
    } else {
        Write-Host "Status: $statusCode" -ForegroundColor Yellow
    }
}
```

#### ✅ HASIL YANG BENAR:
```
Redirect to HTTPS: SUCCESS ✅
Location: https://localhost:3000/api/health
```
**HTTP Status:** `301 Moved Permanently`

---

## 📝 TEST 13: CERTIFICATE PINNING (Flutter)

### 13.1 Test Certificate Validation

#### Flutter Test Code:
```dart
// test/security/certificate_pinning_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workradar/core/network/certificate_pinning.dart';

void main() {
  group('Certificate Pinning', () {
    test('should validate certificate hash', () {
      final validHash = 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
      final manager = CertificatePinningManager();
      
      manager.pinCertificate('api.workradar.com', validHash);
      
      final pins = manager.getPinnedCertificates('api.workradar.com');
      expect(pins, contains(validHash));
    });

    test('should match wildcard domains', () {
      final client = SecureApiClient();
      
      expect(client._matchesDomain('api.workradar.com', '*.workradar.com'), isTrue);
      expect(client._matchesDomain('sub.api.workradar.com', '*.workradar.com'), isTrue);
      expect(client._matchesDomain('other.com', '*.workradar.com'), isFalse);
    });

    test('security interceptor adds headers', () async {
      final interceptor = SecurityInterceptor();
      final options = RequestOptions(path: '/test');
      
      // Mock handler
      interceptor.onRequest(options, MockHandler());
      
      expect(options.headers['X-Request-Timestamp'], isNotNull);
      expect(options.headers['X-Request-Nonce'], isNotNull);
    });
  });
}
```

#### Run Tests:
```powershell
cd c:\myradar\client
flutter test test/security/certificate_pinning_test.dart -v
```

#### ✅ HASIL YANG BENAR:
```
00:03 +3: All tests passed!
```

---

## 📝 TEST 14: SECURITY HEADERS

### 14.1 Test All Security Headers Present

#### Test Script:
```powershell
Write-Host "=== SECURITY HEADERS TEST ===" -ForegroundColor Yellow

$response = Invoke-WebRequest -Uri "$baseUrl/api/health" -Method GET

$requiredHeaders = @(
    @{ Name = "X-Content-Type-Options"; Expected = "nosniff" },
    @{ Name = "X-Frame-Options"; Expected = "DENY" },
    @{ Name = "X-XSS-Protection"; Expected = "1; mode=block" },
    @{ Name = "Content-Security-Policy"; Expected = "default-src 'self'" },
    @{ Name = "Referrer-Policy"; Expected = "no-referrer" },
    @{ Name = "Permissions-Policy"; Expected = "*" },  # Contains check
    @{ Name = "X-Request-ID"; Expected = "*" }  # Any value
)

Write-Host "`nSecurity Headers Check:" -ForegroundColor Cyan

foreach ($header in $requiredHeaders) {
    $value = $response.Headers[$header.Name]
    
    if ($null -eq $value) {
        Write-Host "❌ $($header.Name): MISSING" -ForegroundColor Red
    } elseif ($header.Expected -eq "*") {
        Write-Host "✅ $($header.Name): $value" -ForegroundColor Green
    } elseif ($value -contains $header.Expected -or $value -eq $header.Expected) {
        Write-Host "✅ $($header.Name): $value" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $($header.Name): $value (expected: $($header.Expected))" -ForegroundColor Yellow
    }
}

# HSTS check (only for HTTPS)
if ($baseUrl -match "^https://") {
    $hsts = $response.Headers["Strict-Transport-Security"]
    if ($hsts) {
        Write-Host "✅ Strict-Transport-Security: $hsts" -ForegroundColor Green
    } else {
        Write-Host "❌ Strict-Transport-Security: MISSING" -ForegroundColor Red
    }
}
```

#### ✅ HASIL YANG BENAR:
```
Security Headers Check:
✅ X-Content-Type-Options: nosniff
✅ X-Frame-Options: DENY
✅ X-XSS-Protection: 1; mode=block
✅ Content-Security-Policy: default-src 'self'
✅ Referrer-Policy: no-referrer
✅ Permissions-Policy: geolocation=(), camera=(), microphone=()
✅ X-Request-ID: req-uuid-12345
✅ Strict-Transport-Security: max-age=31536000; includeSubDomains
```

#### ❌ HASIL YANG ERROR:
```
Security Headers Check:
✅ X-Content-Type-Options: nosniff
❌ X-Frame-Options: MISSING
❌ Content-Security-Policy: MISSING
✅ X-Request-ID: req-uuid-12345
```

---

## 📊 SUMMARY TESTING PART 3

| No | Test Case | Expected | Actual | Status |
|----|-----------|----------|--------|--------|
| 1.1 | DB Read role isolation | INSERT/UPDATE/DELETE denied | | ⬜ |
| 1.2 | DB App role restrictions | DELETE users denied | | ⬜ |
| 1.3 | Connection manager status | All connections healthy | | ⬜ |
| 2.1 | Role permissions | User/Admin access correct | | ⬜ |
| 2.2 | Permission hierarchy | Roles have correct perms | | ⬜ |
| 3.1 | Resource owner check | Owner can modify, others denied | | ⬜ |
| 3.2 | Multiple permissions | Requires all perms | | ⬜ |
| 4.1 | View data masking | Email masked | | ⬜ |
| 4.2 | Audit logs view | User email masked | | ⬜ |
| 5.1 | Field encryption | Data encrypted in DB | | ⬜ |
| 5.2 | Decryption on read | API returns plaintext | | ⬜ |
| 5.3 | Search encrypted field | Uses hash for search | | ⬜ |
| 6.1 | Key rotation | Keys rotate successfully | | ⬜ |
| 6.2 | Key expiration | Expiring keys warned | | ⬜ |
| 7.1 | Audit all operations | CREATE/UPDATE/DELETE logged | | ⬜ |
| 8.1 | Security audit | Full audit runs | | ⬜ |
| 8.2 | Individual checks | Each check works | | ⬜ |
| 9.1 | Vulnerability scan | Scan completes | | ⬜ |
| 9.2 | SQL injection detection | Patterns detected | | ⬜ |
| 10.1 | Dashboard | All metrics returned | | ⬜ |
| 11.1 | Scheduler status | Tasks listed | | ⬜ |
| 11.2 | Manual task run | Task executes | | ⬜ |
| 12.1 | TLS server | HTTPS works | | ⬜ |
| 12.2 | HTTPS redirect | HTTP redirects to HTTPS | | ⬜ |
| 13.1 | Certificate pinning | Valid cert accepted | | ⬜ |
| 14.1 | Security headers | All headers present | | ⬜ |

### Legend
- ✅ PASS
- ❌ FAIL
- ⬜ NOT TESTED

---

## 🔧 QUICK TEST SCRIPT

### Run All Tests at Once
```powershell
# Simpan sebagai test_security_part3.ps1
$baseUrl = "http://localhost:3000"

Write-Host "======================================" -ForegroundColor Yellow
Write-Host "SECURITY TESTING PART 3" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow

# 1. Test Health
Write-Host "`n[1/14] Testing Health Endpoint..." -ForegroundColor Cyan
$health = Invoke-RestMethod -Uri "$baseUrl/api/health"
if ($health.status -eq "OK") { Write-Host "PASS" -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }

# 2. Test Security Headers
Write-Host "`n[2/14] Testing Security Headers..." -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri "$baseUrl/api/health"
$hasHeaders = $response.Headers["X-Content-Type-Options"] -and $response.Headers["X-Frame-Options"]
if ($hasHeaders) { Write-Host "PASS" -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }

# Continue for all tests...

Write-Host "`n======================================" -ForegroundColor Yellow
Write-Host "TESTING COMPLETE" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
```

---

## 📚 REFERENSI

- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Controls](https://www.cisecurity.org/controls)
