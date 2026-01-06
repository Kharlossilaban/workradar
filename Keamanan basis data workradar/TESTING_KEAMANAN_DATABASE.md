# 🧪 Tutorial Testing Keamanan Basis Data Workradar

## 📋 Daftar Isi

1. [Persiapan Environment](#1-persiapan-environment)
2. [Testing Minggu 2: Audit & Threat Detection](#2-testing-minggu-2-audit--threat-detection)
3. [Testing Minggu 3: Autentikasi & Otorisasi](#3-testing-minggu-3-autentikasi--otorisasi)
4. [Testing Minggu 4: Enkripsi & Perlindungan Data](#4-testing-minggu-4-enkripsi--perlindungan-data)
5. [Testing Minggu 5: Access Control](#5-testing-minggu-5-access-control)
6. [Testing Phase 4: Monitoring & Maintenance](#6-testing-phase-4-monitoring--maintenance)

---

## 1. Persiapan Environment

### 1.1 Environment Variables

Buat file `.env` di folder `server/`:

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=workradar_admin
DB_PASSWORD=your_password
DB_NAME=workradar

# Database SSL (Optional untuk local)
DB_SSL_ENABLED=false

# Encryption (WAJIB untuk testing enkripsi)
ENCRYPTION_KEY=your-32-character-minimum-key-here-for-aes256

# JWT
JWT_SECRET=your-jwt-secret-key-minimum-32-chars

# TLS/HTTPS (Optional untuk local)
TLS_ENABLED=false

# Multi-User Database (untuk testing access control)
DB_MULTI_USER_ENABLED=true
DB_USER_READ=workradar_read
DB_PASSWORD_READ=read_password
DB_USER_APP=workradar_app
DB_PASSWORD_APP=app_password
DB_USER_ADMIN=workradar_admin
DB_PASSWORD_ADMIN=admin_password
```

### 1.2 Setup Database

```sql
-- 1. Buat database
CREATE DATABASE IF NOT EXISTS workradar;
USE workradar;

-- 2. Jalankan migrations
-- File: server/internal/database/migrations/001_security_users_and_views.sql

-- 3. Buat test user untuk database
CREATE USER IF NOT EXISTS 'workradar_read'@'%' IDENTIFIED BY 'read_password';
CREATE USER IF NOT EXISTS 'workradar_app'@'%' IDENTIFIED BY 'app_password';
CREATE USER IF NOT EXISTS 'workradar_admin'@'%' IDENTIFIED BY 'admin_password';

GRANT SELECT ON workradar.* TO 'workradar_read'@'%';
GRANT SELECT, INSERT, UPDATE ON workradar.* TO 'workradar_app'@'%';
GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'%';

FLUSH PRIVILEGES;
```

### 1.3 Start Server

```powershell
cd c:\myradar\server
go run cmd/main.go
```

Server akan berjalan di `http://localhost:8080`

### 1.4 Tools yang Dibutuhkan

- **Postman** atau **cURL** untuk API testing
- **MySQL Workbench** untuk database verification
- **Google Authenticator** app untuk MFA testing

---

## 2. Testing Minggu 2: Audit & Threat Detection

### 2.1 Test Audit Logging

#### A. Register User Baru

```powershell
# PowerShell
$body = @{
    name = "Test User"
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/register" -Method POST -Body $body -ContentType "application/json"
```

#### B. Verifikasi Audit Log di Database

```sql
-- Cek audit logs
SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 10;

-- Harus ada entry dengan action = 'CREATE' untuk user baru
```

#### C. Login User

```powershell
$body = @{
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
$token = $response.data.access_token
Write-Host "Token: $token"
```

#### D. Verifikasi Login Audit

```sql
-- Cek login attempts
SELECT * FROM login_attempts WHERE email = 'testuser@example.com' ORDER BY created_at DESC;

-- Harus ada entry dengan success = TRUE
```

### 2.2 Test Threat Detection - Brute Force

#### A. Simulasi Brute Force Attack (5x login gagal)

```powershell
# Loop 6x dengan password salah
for ($i = 1; $i -le 6; $i++) {
    $body = @{
        email = "testuser@example.com"
        password = "WrongPassword$i"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
    } catch {
        Write-Host "Attempt $i : $($_.Exception.Response.StatusCode)"
    }
    Start-Sleep -Seconds 1
}
```

#### B. Verifikasi Account Locked

```sql
-- Cek user locked
SELECT id, email, failed_login_attempts, locked_until FROM users WHERE email = 'testuser@example.com';

-- failed_login_attempts harus = 5
-- locked_until harus berisi waktu di masa depan

-- Cek security events
SELECT * FROM security_events WHERE event_type = 'ACCOUNT_LOCKED' ORDER BY created_at DESC LIMIT 5;
```

#### C. Verifikasi IP Blocked

```sql
-- Cek blocked IPs
SELECT * FROM blocked_ips ORDER BY created_at DESC LIMIT 5;
```

### 2.3 Test SQL Injection Detection

```powershell
# Kirim payload SQL injection di login
$body = @{
    email = "admin' OR '1'='1"
    password = "anything"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode)"
    # Expected: 400 Bad Request atau 403 Forbidden
}
```

```sql
-- Verifikasi security event logged
SELECT * FROM security_events WHERE event_type = 'SQL_INJECTION_ATTEMPT' ORDER BY created_at DESC;
```

### 2.4 Test Get Security Events

```powershell
# Dengan token admin
$headers = @{
    Authorization = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:8080/api/security/events" -Headers $headers
```

---

## 3. Testing Minggu 3: Autentikasi & Otorisasi

### 3.1 Reset Test Account

```sql
-- Unlock account untuk testing selanjutnya
UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE email = 'testuser@example.com';

-- Hapus IP block
DELETE FROM blocked_ips;
```

### 3.2 Test Password Policy

#### A. Test Password Lemah

```powershell
$body = @{
    name = "Weak Password User"
    email = "weakpwd@example.com"
    password = "12345678"  # Password tanpa huruf besar, simbol
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:8080/api/auth/register" -Method POST -Body $body -ContentType "application/json"
} catch {
    $_.Exception.Response  # Expected: 400 dengan pesan password policy
}
```

#### B. Test Password Kuat

```powershell
$body = @{
    name = "Strong Password User"
    email = "strongpwd@example.com"
    password = "MyStr0ng@Pass123!"  # Memenuhi semua kriteria
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/register" -Method POST -Body $body -ContentType "application/json"
# Expected: 201 Created
```

#### C. Validasi Password via API

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$body = @{
    password = "test123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/security/validate-password" -Method POST -Headers $headers -Body $body -ContentType "application/json"
Write-Host ($response | ConvertTo-Json)
# Response akan menunjukkan strength score dan issues
```

### 3.3 Test Multi-Factor Authentication (MFA)

#### A. Login untuk dapat token

```powershell
$body = @{
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
$token = $response.data.access_token
```

#### B. Check MFA Status

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/mfa/status" -Headers $headers
# Expected: { "mfa_enabled": false }
```

#### C. Enable MFA

```powershell
$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/mfa/enable" -Method POST -Headers $headers
Write-Host "Secret: $($response.data.secret)"
Write-Host "QR URL: $($response.data.qr_code)"
# Simpan secret ini untuk Google Authenticator
```

**Manual Step:** 
1. Buka Google Authenticator app
2. Tambah akun manual dengan secret yang diberikan
3. Atau scan QR code jika tersedia

#### D. Verify MFA

```powershell
# Dapatkan kode 6 digit dari Google Authenticator
$code = Read-Host "Masukkan kode 6 digit dari Authenticator"

$body = @{
    code = $code
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/mfa/verify" -Method POST -Headers $headers -Body $body -ContentType "application/json"
# Expected: { "success": true, "message": "MFA enabled successfully" }
```

#### E. Test Login dengan MFA

```powershell
# Login normal - akan dapat MFA token
$body = @{
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
# Expected: { "requires_mfa": true, "mfa_token": "..." }

$mfaToken = $response.data.mfa_token

# Verify MFA untuk complete login
$code = Read-Host "Masukkan kode MFA"
$body = @{
    mfa_token = $mfaToken
    code = $code
} | ConvertTo-Json

$finalResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/mfa/verify-login" -Method POST -Body $body -ContentType "application/json"
$token = $finalResponse.data.access_token
Write-Host "Login berhasil dengan MFA! Token: $token"
```

#### F. Disable MFA

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$code = Read-Host "Masukkan kode MFA untuk disable"
$body = @{
    code = $code
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/mfa/disable" -Method POST -Headers $headers -Body $body -ContentType "application/json"
```

### 3.4 Test Account Lockout Policy

```sql
-- Verifikasi struktur
DESCRIBE users;
-- Harus ada kolom: failed_login_attempts, locked_until

-- Setelah test brute force sebelumnya
SELECT email, failed_login_attempts, locked_until FROM users WHERE email = 'testuser@example.com';
```

---

## 4. Testing Minggu 4: Enkripsi & Perlindungan Data

### 4.1 Test Field-Level Encryption

#### A. Buat User Baru

```powershell
$body = @{
    name = "Encrypted User"
    email = "encrypted@example.com"
    password = "Encrypt@123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/auth/register" -Method POST -Body $body -ContentType "application/json"
```

#### B. Verifikasi Enkripsi di Database

```sql
-- Cek data user
SELECT id, name, email, encrypted_email, email_hash, phone, encrypted_phone 
FROM users 
WHERE email = 'encrypted@example.com' OR name = 'Encrypted User';

-- email: mungkin plaintext atau masked
-- encrypted_email: HARUS berisi ciphertext (base64 encoded)
-- email_hash: HARUS berisi SHA-256 hash
```

**Expected:**
- `encrypted_email` berisi string panjang seperti: `AES256:xyzabc123...==`
- `email_hash` berisi hash 64 karakter hex

#### C. Test Email Masking via API

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

# Get profile (email harus masked untuk non-owner)
Invoke-RestMethod -Uri "http://localhost:8080/api/profile" -Headers $headers
# Email harus ditampilkan dengan format: enc***@example.com
```

### 4.2 Test Encryption Service Langsung

```powershell
# Test via vulnerability detection endpoint (menggunakan sanitize)
$headers = @{
    Authorization = "Bearer $token"
}

$body = @{
    input = "test@example.com"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/detect" -Method POST -Headers $headers -Body $body -ContentType "application/json"
Write-Host ($response | ConvertTo-Json)
```

### 4.3 Test Database SSL Connection (Jika diaktifkan)

```sql
-- Di MySQL, cek status SSL
SHOW STATUS LIKE 'Ssl_cipher';
SHOW STATUS LIKE 'Ssl_version';

-- Jika kosong, SSL tidak aktif
-- Jika ada nilai (misal: TLS_AES_256_GCM_SHA384), SSL aktif
```

### 4.4 Test HTTPS (Jika diaktifkan)

```powershell
# Dengan TLS_ENABLED=true dan certificates

# Test HTTPS
Invoke-RestMethod -Uri "https://localhost:8080/api/health" -SkipCertificateCheck

# Test HTTP redirect (jika HTTPS_REDIRECT_ENABLED=true)
Invoke-RestMethod -Uri "http://localhost:8080/api/health"
# Expected: Redirect ke HTTPS
```

### 4.5 Test Key Manager

```sql
-- Key manager menyimpan metadata, bukan key sebenarnya
-- Verifikasi bahwa ENCRYPTION_KEY tidak tersimpan di database
SELECT * FROM audit_logs WHERE action LIKE '%KEY%';
```

---

## 5. Testing Minggu 5: Access Control

### 5.1 Test Database User Roles

#### A. Test Read-Only User

```powershell
# Connect ke MySQL dengan read user
mysql -u workradar_read -p

# Coba SELECT (HARUS BERHASIL)
USE workradar;
SELECT * FROM users LIMIT 1;

# Coba INSERT (HARUS GAGAL)
INSERT INTO users (id, name, email) VALUES ('test', 'Test', 'test@test.com');
# Error: INSERT command denied

# Coba DELETE (HARUS GAGAL)
DELETE FROM users WHERE id = 'test';
# Error: DELETE command denied
```

#### B. Test App User

```powershell
mysql -u workradar_app -p

USE workradar;

# SELECT (BERHASIL)
SELECT * FROM users LIMIT 1;

# INSERT (BERHASIL)
# UPDATE (BERHASIL)

# DELETE on users (HARUS GAGAL - jika dikonfigurasi)
DELETE FROM users WHERE id = 'test-id';
# Error: DELETE command denied
```

### 5.2 Test Column-Level Permissions

```powershell
# Dengan read user
mysql -u workradar_read -p

USE workradar;

# Coba akses kolom sensitif (HARUS GAGAL)
SELECT password_hash FROM users LIMIT 1;
# Error: SELECT command denied for column 'password_hash'

SELECT mfa_secret FROM users LIMIT 1;
# Error: SELECT command denied

# Kolom non-sensitif (BERHASIL)
SELECT id, name, email, user_type FROM users LIMIT 1;
```

### 5.3 Test Security Views

```sql
-- Connect dengan read user
mysql -u workradar_read -p

USE workradar;

-- Test view public profiles (email masked)
SELECT * FROM v_user_public_profiles LIMIT 5;
-- email_masked harus seperti: tes***@example.com

-- Test view dashboard
SELECT * FROM v_user_dashboard LIMIT 5;

-- Test view security events
SELECT * FROM v_security_events_dashboard LIMIT 10;

-- Test view blocked IPs
SELECT * FROM v_blocked_ips_active;
```

### 5.4 Test Stored Procedures

```sql
-- Connect dengan admin user
mysql -u workradar_admin -p

USE workradar;

-- Test sp_get_user_security_status
CALL sp_get_user_security_status('user-id-here');

-- Test sp_lock_account
SET @success = FALSE;
CALL sp_lock_account('user-id', 'Test lock', DATE_ADD(NOW(), INTERVAL 30 MINUTE), @success);
SELECT @success;

-- Test sp_unlock_account
SET @success = FALSE;
CALL sp_unlock_account('user-id', 'admin-user-id', @success);
SELECT @success;

-- Test sp_cleanup_expired_data
CALL sp_cleanup_expired_data(30);
```

### 5.5 Test Access Control via API

#### A. Test Admin Endpoints (tanpa permission)

```powershell
# Login sebagai user biasa
$body = @{
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
$userToken = $response.data.access_token

# Coba akses admin endpoint
$headers = @{
    Authorization = "Bearer $userToken"
}

try {
    Invoke-RestMethod -Uri "http://localhost:8080/api/admin/security/stats" -Headers $headers
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode)"
    # Expected: 403 Forbidden
}
```

#### B. Buat Admin User

```sql
-- Upgrade user ke admin untuk testing
UPDATE users SET user_type = 'admin' WHERE email = 'testuser@example.com';
```

#### C. Test Admin Endpoints (dengan permission)

```powershell
# Login ulang setelah upgrade
$body = @{
    email = "testuser@example.com"
    password = "Test@123456"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -Body $body -ContentType "application/json"
$adminToken = $response.data.access_token

$headers = @{
    Authorization = "Bearer $adminToken"
}

# Test security stats
Invoke-RestMethod -Uri "http://localhost:8080/api/admin/security/stats" -Headers $headers

# Test security events dashboard
Invoke-RestMethod -Uri "http://localhost:8080/api/admin/security/events" -Headers $headers

# Test public profiles view
Invoke-RestMethod -Uri "http://localhost:8080/api/admin/views/public-profiles" -Headers $headers
```

---

## 6. Testing Phase 4: Monitoring & Maintenance

### 6.1 Test Health Check Endpoints

```powershell
# Basic health check (no auth)
Invoke-RestMethod -Uri "http://localhost:8080/api/health"

# Kubernetes probes (no auth)
Invoke-RestMethod -Uri "http://localhost:8080/api/ready"
Invoke-RestMethod -Uri "http://localhost:8080/api/live"

# Detailed health check (auth required)
$headers = @{
    Authorization = "Bearer $adminToken"
}
Invoke-RestMethod -Uri "http://localhost:8080/api/health/detailed" -Headers $headers

# Metrics
Invoke-RestMethod -Uri "http://localhost:8080/api/metrics" -Headers $headers
```

### 6.2 Test Security Audit

```powershell
$headers = @{
    Authorization = "Bearer $adminToken"
}

# Run security audit
$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/audit/run" -Method POST -Headers $headers
Write-Host "Audit Score: $($response.data.overall_score)%"
Write-Host "Status: $($response.data.overall_status)"
Write-Host "Findings: $($response.data.findings | ConvertTo-Json)"

# Get last audit report
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/audit/report" -Headers $headers

# Get audit history
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/audit/history" -Headers $headers
```

### 6.3 Test Vulnerability Scanner

```powershell
$headers = @{
    Authorization = "Bearer $adminToken"
}

# Quick scan
$body = @{
    scan_type = "QUICK"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/scan" -Method POST -Headers $headers -Body $body -ContentType "application/json"
Write-Host "Risk Level: $($response.data.risk_level)"
Write-Host "Vulnerabilities: $($response.data.vulnerabilities | ConvertTo-Json)"

# Full scan
$body = @{
    scan_type = "FULL"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/scan" -Method POST -Headers $headers -Body $body -ContentType "application/json"

# Get last scan report
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/report" -Headers $headers
```

### 6.4 Test SQL Injection/XSS Detection

```powershell
$headers = @{
    Authorization = "Bearer $adminToken"
}

# Test SQL injection detection
$body = @{
    input = "1'; DROP TABLE users; --"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/detect" -Method POST -Headers $headers -Body $body -ContentType "application/json"
Write-Host "SQL Injection Detected: $($response.data.sql_injection.detected)"
Write-Host "Patterns: $($response.data.sql_injection.matched_patterns)"

# Test XSS detection
$body = @{
    input = "<script>alert('xss')</script>"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/vulnerability/detect" -Method POST -Headers $headers -Body $body -ContentType "application/json"
Write-Host "XSS Detected: $($response.data.xss.detected)"
Write-Host "Sanitized: $($response.data.sanitized)"
```

### 6.5 Test Security Dashboard

```powershell
$headers = @{
    Authorization = "Bearer $adminToken"
}

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/dashboard" -Headers $headers
Write-Host "Overall Security Score: $($response.data.overall_security_score)%"
Write-Host "Overall Status: $($response.data.overall_status)"
Write-Host ($response.data | ConvertTo-Json -Depth 5)
```

### 6.6 Test Scheduler

```powershell
$headers = @{
    Authorization = "Bearer $adminToken"
}

# Get scheduler status
$response = Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/scheduler/status" -Headers $headers
Write-Host "Scheduler Running: $($response.data.is_running)"
Write-Host "Tasks:"
$response.data.tasks | ForEach-Object {
    Write-Host "  - $($_.name): $($_.status) (Next: $($_.next_run))"
}

# Run task immediately
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/scheduler/task/SECURITY_AUDIT/run" -Method POST -Headers $headers

# Disable task
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/scheduler/task/VULNERABILITY_SCAN/disable" -Method POST -Headers $headers

# Enable task
Invoke-RestMethod -Uri "http://localhost:8080/api/monitoring/scheduler/task/VULNERABILITY_SCAN/enable" -Method POST -Headers $headers
```

---

## 📊 Checklist Testing

### Minggu 2: Audit & Threat Detection
- [ ] Audit log tercatat untuk register
- [ ] Audit log tercatat untuk login
- [ ] Login attempts tercatat
- [ ] Brute force terdeteksi (5x gagal → lock)
- [ ] IP blocked setelah brute force
- [ ] SQL injection attempt terdeteksi dan di-log
- [ ] Security events dapat dilihat via API

### Minggu 3: Autentikasi & Otorisasi
- [ ] Password lemah ditolak
- [ ] Password kuat diterima
- [ ] Password validation API bekerja
- [ ] MFA dapat diaktifkan
- [ ] MFA verification bekerja
- [ ] Login dengan MFA memerlukan kode
- [ ] MFA dapat dinonaktifkan
- [ ] Account lockout bekerja (5x gagal)

### Minggu 4: Enkripsi
- [ ] Email terenkripsi di database
- [ ] Phone terenkripsi di database
- [ ] Email hash tersimpan untuk search
- [ ] Decryption bekerja saat read
- [ ] Email masking bekerja
- [ ] SSL database (jika enabled)
- [ ] HTTPS (jika enabled)

### Minggu 5: Access Control
- [ ] Read user tidak bisa INSERT/UPDATE/DELETE
- [ ] App user tidak bisa DELETE users
- [ ] Column-level permission bekerja
- [ ] Security views menampilkan data masked
- [ ] Stored procedures bekerja
- [ ] Admin endpoints blocked untuk non-admin
- [ ] Admin endpoints accessible untuk admin

### Phase 4: Monitoring
- [ ] Health check endpoints bekerja
- [ ] Kubernetes probes bekerja
- [ ] Security audit dapat dijalankan
- [ ] Vulnerability scan dapat dijalankan
- [ ] SQL injection detection bekerja
- [ ] XSS detection bekerja
- [ ] Security dashboard menampilkan data
- [ ] Scheduler berjalan
- [ ] Tasks dapat di-run manual
- [ ] Tasks dapat di-enable/disable

---

## 🔧 Troubleshooting

### Error: "ENCRYPTION_KEY not set"
```bash
# Set environment variable
$env:ENCRYPTION_KEY = "your-32-character-minimum-key-here"
```

### Error: "Database connection refused"
```bash
# Pastikan MySQL berjalan
net start MySQL80

# Atau check service
Get-Service -Name MySQL*
```

### Error: "Access denied for user"
```sql
-- Grant ulang permissions
GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'%';
FLUSH PRIVILEGES;
```

### Error: "MFA verification failed"
- Pastikan waktu di server dan device sinkron
- Kode TOTP hanya valid 30 detik
- Gunakan kode baru dari Authenticator

### Error: "Certificate not found" (HTTPS)
```bash
# Generate self-signed cert untuk testing
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

---

## 📝 Catatan Penting

1. **Jangan gunakan data production untuk testing**
2. **Reset database setelah testing** jika diperlukan
3. **Backup database** sebelum testing stored procedures
4. **Gunakan password kuat** untuk database users
5. **ENCRYPTION_KEY harus dijaga kerahasiaannya**
6. **Monitor logs** selama testing untuk debug

---

## 🎉 Selesai!

Jika semua checklist di atas berhasil, implementasi keamanan basis data Part 1 telah berfungsi dengan baik.

Langkah selanjutnya:
1. Lakukan penetration testing dengan tools seperti OWASP ZAP
2. Review code dengan security scanner
3. Setup monitoring di production
4. Dokumentasikan semua credentials dengan aman
