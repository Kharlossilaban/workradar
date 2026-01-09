Workradar - Remaining Work & Bug Analysis

## ✅ COMPLETED IMPLEMENTATIONS

### OTP Email Verification Flow (Registrasi)
**Status: ✅ COMPLETED**
**Date: January 10, 2026**

#### Breaking Change Notice:
User yang baru registrasi **TIDAK** akan langsung masuk ke dashboard. Mereka harus:
1. Mengisi form registrasi
2. Menerima kode OTP di email (6 digit)
3. Memasukkan kode OTP untuk verifikasi
4. Diarahkan ke halaman login
5. Login dengan kredensial yang baru dibuat

#### Flow Perubahan:
- **SEBELUM:** Register → Auto Login → Dashboard
- **SEKARANG:** Register → Kirim OTP → Verify OTP → Navigate ke Login Screen

#### Files Modified:

**Backend (Golang):**
- `server/internal/models/user.go` - Added `EmailVerified` field
- `server/internal/models/email_verification.go` - NEW: Model for OTP storage
- `server/internal/repository/email_verification_repository.go` - NEW: Repository
- `server/internal/repository/user_repository.go` - Added `VerifyEmail` method
- `server/internal/services/auth_service.go` - Modified Register, added OTP methods
- `server/internal/handlers/auth_handler.go` - Modified Register, added handlers
- `server/cmd/main.go` - Added new routes and repository initialization

**New API Endpoints:**
- `POST /api/auth/register` - Returns `requires_verification: true`, no token
- `POST /api/auth/verify-email` - Verify OTP code
- `POST /api/auth/resend-otp` - Resend verification OTP

**Frontend (Flutter):**
- `client/lib/core/services/auth_api_service.dart` - Added `RegisterResponse`, new methods
- `client/lib/features/auth/screens/registration_otp_screen.dart` - NEW: OTP screen
- `client/lib/features/auth/screens/register_screen.dart` - Navigate to OTP screen

#### Notes:
- OTP codes expire after 15 minutes
- In dev mode (SMTP not configured), OTP code is returned in response
- Users with unverified email cannot login
- Google OAuth users are auto-verified (no OTP needed)

---

📊 Status Overview
Category	Status	Priority
Core Functionality	✅ 95% Done	-
Frontend-Backend Integration	✅ 85% Done	HIGH
VIP Feature Restrictions	🔴 60% Done	CRITICAL
Production Readiness	🔴 40% Done	HIGH
Testing & QA	🔴 20% Done	MEDIUM
🔴 CRITICAL BUGS & ISSUES
1. Payment Flow - Hardcoded User Data
Files: 
subscription_screen.dart
, 
profile_screen.dart
 Issue: User ID, email, name hardcoded as 'USER_ID'

userId: 'USER_ID', // TODO: Get from auth provider
userEmail: 'user@gmail.com', // TODO: Get from profile provider
Impact: Payment flow will fail in production Fix: Get real user data from 
SecureStorage
 or 
ProfileProvider

2. VIP Feature Restrictions Not Enforced in Frontend
Issue: User Regular dapat mengakses fitur VIP karena validasi hanya di backend

Missing Frontend Restrictions:

Feature	Should Restrict	Current Status
Weekly/Monthly Charts	VIP Only	❌ Not checked
Repeat End Date Setting	VIP Only	❌ Not checked
Custom Reminder Time	VIP Only (Regular: only 10min)	❌ Not checked
Weather Feature	VIP Only	✅ Checked
Fix: Add VIP checks before showing these features

3. Forgot Password - Email Not Implemented
File: 
auth_service.go
 line 119

// TODO: Send email with code (for now return code)
Impact: User cannot actually reset password via email Fix: Integrate SMTP service (Gmail/SendGrid/Mailgun)

4. Hardcoded Development URLs
Files:

environment.dart
 → 192.168.1.7:8080
midtrans_service.dart
 → 192.168.1.7:8080
Impact: App won't work when deployed Fix: Use environment-based configuration

🟡 HIGH PRIORITY - Missing Integrations
5. ✅ Google OAuth - Mobile Flow COMPLETED
Backend: ✅ Implemented (GET /api/auth/google) Frontend: ✅ Fully Integrated

Completed:

 Add google_sign_in Flutter package
 Created GoogleAuthService with backend integration
 Created GoogleSignInButton reusable widget
 Implemented full OAuth flow in 
login_screen.dart
 Error handling for cancelled sign-in, network errors
 Welcome message for new vs returning users
 JWT token storage after successful authentication
Tested: ✅ Working on Android emulator

6. Firebase FCM - Flutter Setup Missing
Backend: ✅ Implemented (NotificationService) Frontend: ❌ Not integrated

Missing:

 Add firebase_messaging Flutter package
 Configure Firebase in Android/iOS
 Register FCM token on login
 Handle incoming notifications
7. Weather API - Frontend Integration
Backend: ✅ Implemented (GET /api/weather/current) Frontend: 🟡 Partial (VipWeatherScreen exists but may not use API)

Verify: Check if VipWeatherScreen calls actual API

8. AI Chatbot - Frontend to Backend Connection
Backend: ✅ Implemented (POST /api/ai/chat) Frontend: ❓ Need to verify chat screen uses API

🟢 MEDIUM PRIORITY - Enhancements
9. VIP Annual Plan - UI Missing
Issue: Only Monthly plan visible, Annual (100k) not shown Fix: Add Annual plan option in subscription screen

10. Health Recommendation Notifications
Requirement:

Notify when tasks > 15/day OR work hours > 12/day
"Beban tugasmu sangat sibuk hari ini, jangan lupa minum air putih"
Status: Backend service exists, need trigger integration

11. Weather-Based Notifications
Requirement:

Notify VIP users about bad weather
"Hujan hari ini, sebaiknya bawa payung"
Status: Backend service exists, need scheduler

🔧 PRODUCTION CHECKLIST
Environment Configuration
 Create .env.production with real credentials
 Set MIDTRANS_IS_PRODUCTION=true
 Configure real SMTP for emails
 Set production API URLs
Database
 Run all migrations on production DB
 Seed Indonesian holidays 2026-2027
 Create database backups
Security
 Change JWT secret to strong random value
 Enable HTTPS on backend
 Validate all user inputs
 Rate limiting on APIs
Mobile Build
 Update API base URL
 Configure signing keys
 Build release APK
 Test on real device

---

## 🔐 DATABASE SECURITY IMPLEMENTATION (Keamanan Basis Data - Minggu 2-5)

### 🔴 MINGGU 2: Keamanan Dasar & Ancaman Database

#### 1. Audit Logging System
**Prioritas: CRITICAL**
**Lokasi: Backend (Golang)**

Implementasi yang diperlukan:
- [ ] Buat tabel `audit_logs` di MySQL untuk mencatat semua aktivitas
  - Kolom: `id`, `user_id`, `action`, `table_name`, `record_id`, `old_value`, `new_value`, `ip_address`, `user_agent`, `timestamp`
- [ ] Implementasi middleware audit di `server/internal/middleware/audit.go`
  - Log semua operasi CREATE, UPDATE, DELETE
  - Track login attempts (sukses & gagal)
  - Track akses ke data sensitif (payment, profile)
- [ ] Buat service `AuditService` di `server/internal/services/audit_service.go`
  - Method: `LogCreate`, `LogUpdate`, `LogDelete`, `LogAccess`, `LogLogin`

#### 2. Threat Monitoring & Detection
**Prioritas: HIGH**
**Lokasi: Backend (Golang)**

Implementasi yang diperlukan:
- [ ] Deteksi brute force attack di `server/internal/handlers/auth_handler.go`
  - Hitung failed login attempts per IP (max 5x dalam 15 menit)
  - Auto-block IP yang mencurigakan (temporary ban 30 menit)
- [ ] Deteksi SQL Injection attempts
  - Monitor query patterns yang mencurigakan
  - Log & alert jika detect injection attempt
- [ ] Deteksi access pattern anomaly
  - Alert jika user mengakses banyak record dalam waktu singkat
  - Track unusual access hours

#### 3. Security Event Logging
**Prioritas: MEDIUM**
**Lokasi: Backend (Golang)**

Implementasi yang diperlukan:
- [ ] Buat `security_events` table
  - Kolom: `id`, `event_type`, `severity`, `user_id`, `ip_address`, `details`, `timestamp`
- [ ] Log event types:
  - `FAILED_LOGIN` (severity: WARNING)
  - `ACCOUNT_LOCKED` (severity: CRITICAL)
  - `SUSPICIOUS_ACTIVITY` (severity: HIGH)
  - `UNAUTHORIZED_ACCESS` (severity: CRITICAL)

---

### 🟡 MINGGU 3: Autentikasi & Otorisasi

#### 4. Multi-Factor Authentication (MFA/2FA)
**Prioritas: HIGH**
**Lokasi: Backend + Frontend**

Backend Implementation (`server/internal/handlers/mfa_handler.go`):
- [ ] Generate TOTP (Time-based One-Time Password) secret
- [ ] Endpoint `/api/auth/mfa/enable` - Generate QR code
- [ ] Endpoint `/api/auth/mfa/verify` - Verify TOTP code
- [ ] Endpoint `/api/auth/mfa/disable` - Disable MFA
- [ ] Tambah kolom `mfa_enabled`, `mfa_secret` di tabel `users`
- [ ] Modify login flow: jika MFA enabled, minta TOTP code

Flutter Implementation:
- [ ] Install package `qr_flutter` dan `otp`
- [ ] Buat screen `MFASetupScreen` di `client/lib/features/auth/presentation/screens/`
- [ ] Show QR code untuk scan dengan Google Authenticator
- [ ] Buat screen `MFAVerifyScreen` untuk input 6-digit code saat login
- [ ] Update `AuthProvider` untuk handle MFA flow

#### 5. Password Policy Enhancement
**Prioritas: HIGH**
**Lokasi: Backend + Frontend**

Backend Implementation (`server/internal/services/auth_service.go`):
- [ ] Validasi password complexity:
  - Minimal 8 karakter
  - Harus ada huruf besar (A-Z)
  - Harus ada huruf kecil (a-z)
  - Harus ada angka (0-9)
  - Harus ada simbol (!@#$%^&*)
- [ ] Password history (tidak boleh sama dengan 3 password terakhir)
  - Buat tabel `password_history` dengan `user_id`, `password_hash`, `created_at`
- [ ] Password expiry (60 hari) - optional
  - Tambah kolom `password_changed_at` di tabel `users`
  - Notifikasi user untuk ganti password setelah 60 hari

Flutter Implementation:
- [ ] Update `RegisterScreen` dengan password strength indicator
- [ ] Real-time validation saat user mengetik password
- [ ] Visual feedback (warna merah/kuning/hijau) untuk strength
- [ ] Tooltip yang menjelaskan persyaratan password

#### 6. Session Timeout Management
**Prioritas: HIGH**
**Lokasi: Frontend (Flutter)**

Flutter Implementation (`client/lib/core/services/session_service.dart`):
- [ ] Track user activity (tap, scroll, navigation)
- [ ] Auto logout setelah 15 menit inactive
- [ ] Show dialog warning 1 menit sebelum logout
  - "Sesi Anda akan berakhir dalam 1 menit. Lanjutkan aktivitas?"
- [ ] Clear all tokens dan redirect ke login screen
- [ ] Integration dengan `AuthProvider`

#### 7. Account Lockout Policy
**Prioritas: HIGH**
**Lokasi: Backend (Golang)**

Backend Implementation (`server/internal/handlers/auth_handler.go`):
- [ ] Tambah kolom di tabel `users`:
  - `failed_login_attempts` (int)
  - `locked_until` (timestamp)
- [ ] Lock account setelah 5 failed attempts
- [ ] Auto unlock setelah 30 menit
- [ ] Send email notifikasi saat account locked
- [ ] Endpoint `/api/auth/unlock` untuk admin unlock manual

---

### 🔴 MINGGU 4: Enkripsi & Perlindungan Data

#### 8. Database Connection Encryption (MySQL SSL/TLS)
**Prioritas: CRITICAL**
**Lokasi: Backend (Golang)**

Implementation (`server/internal/database/database.go`):
- [ ] Generate SSL certificates untuk MySQL:
  ```bash
  mysql_ssl_rsa_setup --datadir=/var/lib/mysql
  ```
- [ ] Update MySQL DSN dengan SSL parameter:
  ```go
  dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local&tls=custom",
      user, password, host, port, dbname)
  ```
- [ ] Register TLS config:
  ```go
  mysql.RegisterTLSConfig("custom", &tls.Config{
      InsecureSkipVerify: false,
      ServerName: dbHost,
  })
  ```
- [ ] Test koneksi dengan SSL enabled

#### 9. Field-Level Encryption untuk Data Sensitif
**Prioritas: CRITICAL**
**Lokasi: Backend (Golang)**

Implementation (`server/internal/services/encryption_service.go`):
- [ ] Install `crypto/aes` untuk AES-256 encryption
- [ ] Buat encryption service dengan methods:
  - `Encrypt(plaintext string) (string, error)`
  - `Decrypt(ciphertext string) (string, error)`
- [ ] Enkripsi data sensitif SEBELUM save ke DB:
  - Email user (`users.email`)
  - Phone number (`users.phone`)
  - Alamat (`users.address`) - jika ada
  - Payment information (jika store)
- [ ] Decrypt data SETELAH read dari DB
- [ ] Update repository files untuk call encryption service

**PENTING**: Simpan encryption key di environment variable, JANGAN hardcode!

#### 10. HTTPS/TLS Enforcement
**Prioritas: CRITICAL**
**Lokasi: Backend (Golang)**

Implementation (`server/cmd/main.go`):
- [ ] Generate SSL certificate (Let's Encrypt atau self-signed untuk dev)
- [ ] Update server untuk listen HTTPS:
  ```go
  if config.IsProduction {
      log.Fatal(r.RunTLS(":443", "cert.pem", "key.pem"))
  } else {
      r.Run(":8080") // HTTP for development only
  }
  ```
- [ ] Redirect HTTP ke HTTPS di production
- [ ] Update CORS untuk allow HTTPS origins only
- [ ] Enable HSTS header (sudah ada di `security_headers.go`)

Flutter Implementation:
- [ ] Update `environment.dart`:
  ```dart
  static const String baseUrl = kDebugMode 
      ? 'http://192.168.1.7:8080'  // Development
      : 'https://api.workradar.com'; // Production
  ```
- [ ] Test API calls dengan HTTPS

#### 11. API Request/Response Encryption
**Prioritas: MEDIUM**
**Lokasi: Backend + Frontend**

Backend Implementation:
- [ ] Create middleware untuk encrypt response body
- [ ] Decrypt request body sebelum process
- [ ] Use shared secret key (exchanged via Diffie-Hellman atau RSA)

Flutter Implementation:
- [ ] Encrypt sensitive payloads sebelum send
- [ ] Decrypt responses dari server

#### 12. Secure Key Management (Secret Vault)
**Prioritas: HIGH**
**Lokasi: Backend (Golang)**

Implementation Options:

**Option A: HashiCorp Vault** (Recommended for Production)
- [ ] Setup Vault server
- [ ] Store secrets: JWT_SECRET, DB_PASSWORD, MIDTRANS_KEY, ENCRYPTION_KEY
- [ ] Update `config.go` untuk fetch dari Vault

**Option B: AWS Secrets Manager** (if using AWS)
- [ ] Create secrets di AWS Console
- [ ] Use AWS SDK untuk fetch secrets

**Option C: Azure Key Vault** (if using Azure)
- [ ] Similar to AWS approach

**Temporary Solution** (Development):
- [ ] Use `.env.local` yang di-gitignore
- [ ] Never commit `.env` dengan real credentials

---

### 🟡 MINGGU 5: Access Control & Privilege Management

#### 13. Principle of Least Privilege - Database Users
**Prioritas: HIGH**
**Lokasi: Database (MySQL)**

MySQL Implementation:
- [ ] Buat 3 database users dengan role berbeda:

```sql
-- Read-Only User (untuk reporting/analytics)
CREATE USER 'workradar_read'@'localhost' IDENTIFIED BY 'strong_password';
GRANT SELECT ON workradar.* TO 'workradar_read'@'localhost';

-- Write User (untuk aplikasi normal)
CREATE USER 'workradar_app'@'localhost' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE ON workradar.* TO 'workradar_app'@'localhost';
-- JANGAN KASIH DELETE ke app user

-- Admin User (untuk migrations & maintenance)
CREATE USER 'workradar_admin'@'localhost' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'localhost';

FLUSH PRIVILEGES;
```

Backend Implementation:
- [ ] Update `database.go` untuk use `workradar_app` user (bukan root)
- [ ] Buat separate connection untuk admin operations (migrations)

#### 14. Column-Level Permissions
**Prioritas: MEDIUM**
**Lokasi: Database (MySQL)**

Implementation:
- [ ] Revoke access ke kolom sensitif untuk app user:
```sql
-- App user TIDAK boleh baca password_hash langsung
REVOKE SELECT(password_hash) ON workradar.users FROM 'workradar_app'@'localhost';

-- App user TIDAK boleh update role (hanya admin)
REVOKE UPDATE(user_type) ON workradar.users FROM 'workradar_app'@'localhost';
```

- [ ] Buat stored procedures untuk operasi yang butuh akses kolom sensitif:
```sql
DELIMITER $$
CREATE PROCEDURE VerifyPassword(
    IN p_user_id VARCHAR(36),
    IN p_password_plain VARCHAR(255),
    OUT p_is_valid BOOLEAN
)
BEGIN
    DECLARE stored_hash VARCHAR(255);
    SELECT password_hash INTO stored_hash 
    FROM users WHERE id = p_user_id;
    
    -- Verify di aplikasi level, bukan di stored procedure
    -- Return hash untuk verify di Golang dengan bcrypt
END$$
DELIMITER ;
```

#### 15. View-Based Security
**Prioritas: MEDIUM**
**Lokasi: Database (MySQL)**

Implementation:
- [ ] Buat views untuk hide sensitive data:

```sql
-- View untuk public profile (hide sensitive info)
CREATE VIEW user_public_profiles AS
SELECT 
    id,
    name,
    -- email disembunyikan atau dimasking
    CONCAT(LEFT(email, 3), '***@', SUBSTRING_INDEX(email, '@', -1)) as email_masked,
    created_at,
    user_type
FROM users;

-- View untuk task summary (hide personal details)
CREATE VIEW task_summaries AS
SELECT 
    t.id,
    t.title,
    t.status,
    t.date,
    u.name as user_name
    -- TIDAK include description yang mungkin sensitif
FROM tasks t
JOIN users u ON t.user_id = u.id;
```

- [ ] Update repository untuk query dari views instead of tables langsung

#### 16. Stored Procedures untuk Operasi Sensitif
**Prioritas: MEDIUM**
**Lokasi: Database (MySQL)**

Implementation:
- [ ] Password Change Procedure:
```sql
DELIMITER $$
CREATE PROCEDURE ChangeUserPassword(
    IN p_user_id VARCHAR(36),
    IN p_old_password_hash VARCHAR(255),
    IN p_new_password_hash VARCHAR(255),
    OUT p_success BOOLEAN
)
BEGIN
    DECLARE current_hash VARCHAR(255);
    
    SELECT password_hash INTO current_hash 
    FROM users WHERE id = p_user_id;
    
    IF current_hash = p_old_password_hash THEN
        UPDATE users 
        SET password_hash = p_new_password_hash,
            password_changed_at = NOW()
        WHERE id = p_user_id;
        SET p_success = TRUE;
    ELSE
        SET p_success = FALSE;
    END IF;
END$$
DELIMITER ;
```

- [ ] Payment Processing Procedure (untuk ensure atomicity)
- [ ] User Role Change Procedure (dengan audit log)

---

### 📊 SECURITY IMPLEMENTATION PRIORITY

#### FASE 1: CRITICAL SECURITY (Minggu 4) - 4-6 jam
**Harus segera diterapkan sebelum production**
1. HTTPS/TLS Enforcement
2. Database Connection Encryption (MySQL SSL)
3. Field-Level Encryption untuk data sensitif
4. Secure Key Management (move from .env to vault)

#### FASE 2: HIGH SECURITY (Minggu 2 & 3) - 6-8 jam
**Untuk mencegah unauthorized access**
1. Audit Logging System
2. MFA/2FA Implementation
3. Session Timeout Management
4. Password Policy Enhancement
5. Account Lockout Policy
6. Threat Monitoring

#### FASE 3: ACCESS CONTROL (Minggu 5) - 4-5 jam
**Untuk principle of least privilege**
1. Database User Roles (read/write/admin)
2. Column-Level Permissions
3. View-Based Security
4. Stored Procedures untuk operasi sensitif

#### FASE 4: MONITORING & MAINTENANCE - Ongoing
1. Security Event Dashboard
2. Regular security audits
3. Penetration testing
4. Vulnerability scanning

---

### 🎯 ESTIMASI WAKTU TOTAL KEAMANAN BASIS DATA

| Minggu | Fokus | Estimasi | Prioritas |
|--------|-------|----------|-----------|
| Minggu 2 | Audit & Monitoring | 3-4 jam | HIGH |
| Minggu 3 | Auth Enhancement | 4-5 jam | HIGH |
| Minggu 4 | Enkripsi | 5-6 jam | **CRITICAL** |
| Minggu 5 | Access Control | 3-4 jam | MEDIUM |
| **TOTAL** | | **15-19 jam** | |

**⚠️ REKOMENDASI URUTAN IMPLEMENTASI:**
1. **Mulai dari Minggu 4** (Enkripsi) - Paling critical untuk production
2. **Lanjut Minggu 3** (Auth Enhancement) - Prevent unauthorized access
3. **Kemudian Minggu 2** (Audit & Monitoring) - Track security events
4. **Terakhir Minggu 5** (Access Control) - Fine-tune permissions

---

📋 RECOMMENDED ACTION SEQUENCE
Phase 1: Critical Fixes (2-3 hours)
✅ Fix hardcoded user IDs in payment
✅ Implement VIP restrictions in frontend
✅ Fix environment URLs
Phase 2: Integration (0-2 hours)
✅ Implement Google Sign-In for mobile DONE
Setup Firebase FCM in Flutter
Add VIP Annual plan UI
Phase 3: Notifications (3-4 hours)
Create health recommendation scheduler
Create weather notification scheduler
Test notification delivery
Phase 4: Production (2-3 hours)
Configure production environment
Build and test release APK
Documentation & deployment
🎯 Total Estimated Time: 7-12 hours
Recent Completions:

✅ Google OAuth Mobile Integration (saved 4 hours)
✅ JWT Token Extension to 24h (resolved token expiry bug)
✅ VIP Pricing Fixes (15k monthly, 100k annual)
✅ "Tambah Cuti" Button Overflow Fix
Priority Order:

🔴 Fix payment flow (Critical for revenue)
🔴 VIP feature restrictions (User experience)
🟡 Google OAuth mobile (User acquisition)
🟡 FCM notifications (Engagement)
🟢 Production deployment (Launch)