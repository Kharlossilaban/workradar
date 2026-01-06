# 📊 POINT-POINT PENTING KEAMANAN BASIS DATA
## Presentasi Manajemen Risiko Keamanan Basis Data - WorkRadar

---

# 🎯 SLIDE 1: COVER

**Judul:** Manajemen Risiko Keamanan Basis Data - WorkRadar

**Subtitle:** Implementasi Keamanan Database Komprehensif

**Tim PBL:** [Nama Tim]

**Tanggal:** [Tanggal Presentasi]

---

# 📋 SLIDE 2: DAFTAR ISI / OVERVIEW

**WorkRadar mengimplementasikan keamanan basis data dalam 3 fase utama:**

| Fase | Minggu | Fokus Keamanan |
|------|--------|----------------|
| **Part 1** | Minggu 2-5 | Foundational Security (Dasar) |
| **Part 2** | Minggu 6-10 | Advanced Security (Lanjutan) |
| **Part 3** | Minggu 11-13 | Enterprise Security (Profesional) |

**Total Implementasi:**
- ✅ 22+ fitur keamanan
- ✅ 24+ permission granular
- ✅ 8 security views
- ✅ 10 automated security tasks

---

# 🔐 PART 1: FOUNDATIONAL SECURITY (MINGGU 2-5)

---

## 📝 SLIDE 3: AUDIT LOGGING SYSTEM

### Mengapa Penting?
WorkRadar memiliki **Audit Logging System** untuk mencatat semua aktivitas yang terjadi pada database. Sistem ini penting karena dapat melacak **siapa melakukan apa, kapan, dan dari mana** - memungkinkan investigasi jika terjadi insiden keamanan.

### Fitur Utama:
| Aktivitas Dicatat | Informasi yang Disimpan |
|-------------------|------------------------|
| CREATE, UPDATE, DELETE | user_id, timestamp |
| READ (data sensitif) | table_name, record_id |
| LOGIN (sukses/gagal) | ip_address, user_agent |
| Security Events | old_value, new_value |

### Potongan Kode:
```go
// server/internal/models/audit.go
type AuditLog struct {
    ID          string    `gorm:"type:varchar(36);primaryKey"`
    UserID      string    `gorm:"type:varchar(36);index"`
    Action      string    `gorm:"type:varchar(50)"`  // CREATE, UPDATE, DELETE, READ, LOGIN
    TableName   string    `gorm:"type:varchar(100)"`
    RecordID    string    `gorm:"type:varchar(36)"`
    OldValue    *string   `gorm:"type:text"`         // JSON sebelum perubahan
    NewValue    *string   `gorm:"type:text"`         // JSON setelah perubahan
    IPAddress   string    `gorm:"type:varchar(45)"`
    UserAgent   string    `gorm:"type:text"`
    CreatedAt   time.Time `gorm:"index"`
}
```

```go
// server/internal/services/audit_service.go - Contoh penggunaan
auditService.LogUpdate(userID, "users", userID, oldUser, newUser, ip, userAgent, path, 200, duration)
```

---

## 🚨 SLIDE 4: THREAT MONITORING & DETECTION

### Mengapa Penting?
WorkRadar memiliki **Threat Monitoring & Detection** untuk mendeteksi serangan secara real-time. Sistem ini dapat mengidentifikasi pola serangan seperti **brute force, SQL injection, dan akses anomali** sebelum menyebabkan kerusakan.

### Mekanisme Deteksi:
| Ancaman | Mitigasi | Threshold |
|---------|----------|-----------|
| Brute Force Attack | Auto-lock account | 5 gagal dalam 15 menit |
| SQL Injection | Pattern detection | Block + log |
| Anomaly Access | Alert admin | Akses unusual hours |

### Potongan Kode:
```go
// server/internal/middleware/threat_detection.go
func BruteForceProtectionMiddleware(auditService *services.AuditService) fiber.Handler {
    return func(c *fiber.Ctx) error {
        ip := c.IP()
        email := c.FormValue("email")
        
        // Check jika IP atau email sudah di-block
        isBlocked, blockedUntil := auditService.CheckBruteForce(ip, email)
        if isBlocked {
            return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
                "error": "Terlalu banyak percobaan gagal",
                "blocked_until": blockedUntil,
            })
        }
        return c.Next()
    }
}
```

```go
// Konfigurasi threat detection
type ThreatDetectionConfig struct {
    MaxFailedAttempts  int           // Max 5 percobaan
    WindowDuration     time.Duration // Dalam 15 menit
    BlockDuration      time.Duration // Block selama 30 menit
}
```

---

## 🔑 SLIDE 5: MULTI-FACTOR AUTHENTICATION (MFA/2FA)

### Mengapa Penting?
WorkRadar mengimplementasikan **Multi-Factor Authentication (MFA)** menggunakan TOTP (Time-based One-Time Password). MFA memberikan lapisan keamanan tambahan sehingga **password saja tidak cukup** untuk mengakses akun - pengguna harus memverifikasi dengan kode 6 digit dari aplikasi authenticator.

### Alur MFA:
1. User enable MFA → Generate QR Code
2. Scan dengan Google Authenticator/Authy
3. Login → Input password + kode 6 digit
4. Kode valid 30 detik saja

### Potongan Kode:
```go
// server/internal/services/mfa_service.go
type MFAService struct {
    secretKey []byte
}

// Generate TOTP secret untuk user baru
func (s *MFAService) GenerateSecret(userID string) (secret string, qrCodeURL string, err error) {
    // Generate random 32-byte secret
    secret = base32.StdEncoding.EncodeToString(generateRandomBytes(20))
    
    // Generate QR code URL untuk authenticator app
    qrCodeURL = fmt.Sprintf("otpauth://totp/WorkRadar:%s?secret=%s&issuer=WorkRadar", 
        userID, secret)
    
    return secret, qrCodeURL, nil
}

// Verifikasi kode TOTP dari user
func (s *MFAService) VerifyTOTP(secret string, code string) bool {
    // Generate expected code berdasarkan waktu saat ini
    expectedCode := s.generateTOTP(secret, time.Now().Unix()/30)
    return code == expectedCode
}
```

```dart
// client/lib/features/auth/screens/mfa_verify_screen.dart (Flutter)
class MFAVerifyScreen extends StatelessWidget {
  Future<void> _verifyMFA(String code) async {
    final response = await mfaService.verifyTOTP(code);
    if (response.success) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
```

---

## 🔒 SLIDE 6: PASSWORD POLICY & SESSION TIMEOUT

### Mengapa Penting?
WorkRadar menerapkan **Password Policy yang ketat** untuk mencegah penggunaan password lemah. Ditambah dengan **Session Timeout Management** yang otomatis logout user setelah tidak aktif - melindungi dari serangan jika device tertinggal/dicuri.

### Password Policy:
| Requirement | Spesifikasi |
|-------------|-------------|
| Minimal Panjang | 8 karakter |
| Huruf Besar | Minimal 1 (A-Z) |
| Huruf Kecil | Minimal 1 (a-z) |
| Angka | Minimal 1 (0-9) |
| Simbol | Minimal 1 (!@#$%^&*) |
| Password History | 3 password terakhir tidak boleh dipakai |
| Password Expiry | 60 hari |

### Potongan Kode:
```go
// server/internal/services/password_policy_service.go
func ValidatePassword(password string) (bool, []string) {
    var errors []string
    
    if len(password) < 8 {
        errors = append(errors, "Password minimal 8 karakter")
    }
    if !regexp.MustCompile(`[A-Z]`).MatchString(password) {
        errors = append(errors, "Harus ada huruf besar")
    }
    if !regexp.MustCompile(`[a-z]`).MatchString(password) {
        errors = append(errors, "Harus ada huruf kecil")
    }
    if !regexp.MustCompile(`[0-9]`).MatchString(password) {
        errors = append(errors, "Harus ada angka")
    }
    if !regexp.MustCompile(`[!@#$%^&*]`).MatchString(password) {
        errors = append(errors, "Harus ada simbol")
    }
    
    return len(errors) == 0, errors
}
```

```dart
// client/lib/core/services/session_service.dart (Flutter)
class SessionService {
    final Duration _sessionTimeout = Duration(minutes: 15);
    final Duration _warningBefore = Duration(minutes: 1);
    
    void _expireSession() {
        // Auto logout setelah 15 menit tidak aktif
        onSessionExpired?.call();
        _clearTokens();
    }
}
```

---

## 🔐 SLIDE 7: DATABASE SSL/TLS & FIELD-LEVEL ENCRYPTION

### Mengapa Penting?
WorkRadar mengamankan data dengan **dua lapisan enkripsi**: (1) **SSL/TLS** untuk mengenkripsi koneksi antara aplikasi dan database, dan (2) **Field-Level Encryption (AES-256-GCM)** untuk mengenkripsi data sensitif seperti email dan nomor telepon di dalam database.

### Manfaat:
| Layer | Melindungi Dari |
|-------|-----------------|
| SSL/TLS Connection | Man-in-the-Middle attack |
| Field Encryption (AES-256) | Data breach (database bocor) |

### Potongan Kode:
```go
// server/internal/database/database.go - SSL/TLS Connection
func configureTLS() error {
    tlsConfig := &tls.Config{
        MinVersion: tls.VersionTLS12,  // Minimum TLS 1.2
    }
    
    // Load CA certificate
    caCert, _ := os.ReadFile(caCertPath)
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)
    tlsConfig.RootCAs = caCertPool
    
    mysql.RegisterTLSConfig("custom", tlsConfig)
    return nil
}
```

```go
// server/internal/services/encryption_service.go - AES-256-GCM Encryption
type EncryptionService struct {
    key []byte
    gcm cipher.AEAD
}

func (s *EncryptionService) Encrypt(plaintext string) (string, error) {
    nonce := make([]byte, s.gcm.NonceSize())
    io.ReadFull(rand.Reader, nonce)  // Random nonce setiap enkripsi
    
    ciphertext := s.gcm.Seal(nonce, nonce, []byte(plaintext), nil)
    return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Contoh penggunaan: Enkripsi email user
encryptedEmail, _ := encService.EncryptEmail("user@example.com")
// Hasil: "AES256GCM:randomnonce:encrypteddata=="
```

---

# 🛡️ PART 2: ADVANCED SECURITY (MINGGU 6-10)

---

## 💉 SLIDE 8: SQL INJECTION PREVENTION

### Mengapa Penting?
WorkRadar memiliki **3 lapisan pertahanan** terhadap SQL Injection - salah satu serangan paling berbahaya yang dapat mengekspos seluruh database. Sistem mendeteksi **25+ pola SQL injection** dan memblokir request berbahaya sebelum mencapai database.

### 3 Lapisan Pertahanan:
| Layer | Teknik | Fungsi |
|-------|--------|--------|
| Layer 1 | Input Validation | Validasi format & panjang |
| Layer 2 | Input Sanitization | Deteksi pola berbahaya |
| Layer 3 | Parameterized Queries | Escape karakter otomatis |

### Pola SQL Injection yang Dideteksi:
- `' OR '1'='1` (Classic injection)
- `UNION SELECT` (Union-based)
- `SLEEP(5)` (Time-based blind)
- `--`, `#`, `/**/` (Comment injection)

### Potongan Kode:
```go
// server/pkg/utils/sanitize.go
var sqlInjectionPatterns = []string{
    `(?i)(\%27)|(\')|(\-\-)|(\%23)|(#)`,                           // Comments & quotes
    `(?i)\w*((\%27)|(\'))(\%6F|o)(\%72|r)`,                        // OR injection
    `(?i)(union)(.*)(select)`,                                      // UNION SELECT
    `(?i)(insert|update|delete|drop|truncate|alter)`,              // DML/DDL
    `(?i)(sleep|waitfor|benchmark)`,                                // Time-based
    `(?i)(0x[0-9a-fA-F]+)`,                                        // Hex encoding
}

func ContainsSQLInjection(input string) (bool, []string) {
    var matched []string
    for _, pattern := range sqlInjectionPatterns {
        if regexp.MustCompile(pattern).MatchString(input) {
            matched = append(matched, pattern)
        }
    }
    return len(matched) > 0, matched
}
```

```go
// server/internal/middleware/input_sanitization.go
func InputSanitizationMiddleware() fiber.Handler {
    return func(c *fiber.Ctx) error {
        // Check semua input untuk SQL injection
        if detected, patterns := utils.ContainsSQLInjection(c.Body()); detected {
            auditService.LogSecurityEvent("SQL_INJECTION_ATTEMPT", "HIGH", 
                "", c.IP(), map[string]interface{}{"patterns": patterns})
            return c.Status(403).JSON(fiber.Map{"error": "Forbidden"})
        }
        return c.Next()
    }
}
```

---

## 🕷️ SLIDE 9: XSS (CROSS-SITE SCRIPTING) PREVENTION

### Mengapa Penting?
WorkRadar mendeteksi dan mencegah **XSS (Cross-Site Scripting)** yang dapat menyuntikkan script berbahaya ke aplikasi. Sistem mendeteksi **15+ pola XSS** termasuk script tags, event handlers, dan JavaScript protocols.

### Pola XSS yang Dideteksi:
| Kategori | Contoh |
|----------|--------|
| Script Tags | `<script>alert('XSS')</script>` |
| Event Handlers | `<img onerror="alert('XSS')">` |
| JS Protocols | `javascript:alert('XSS')` |
| Data URIs | `data:text/html,<script>...` |
| SVG/Iframe | `<svg onload="...">`, `<iframe>` |

### Potongan Kode:
```go
// server/pkg/utils/sanitize.go
var xssPatterns = []string{
    `(?i)<script[^>]*>[\s\S]*?</script>`,     // Script tags
    `(?i)<img[^>]+onerror\s*=`,               // Img onerror
    `(?i)<[^>]+(onclick|onload|onerror)\s*=`, // Event handlers
    `(?i)javascript:`,                         // JS protocol
    `(?i)data:text/html`,                      // Data URI
    `(?i)<(iframe|object|embed|svg)`,          // Dangerous tags
}

func ContainsXSS(input string) (bool, []string) {
    var matched []string
    for _, pattern := range xssPatterns {
        if regexp.MustCompile(pattern).MatchString(input) {
            matched = append(matched, pattern)
        }
    }
    return len(matched) > 0, matched
}

// Sanitize HTML - hapus semua tags berbahaya
func SanitizeHTML(input string) string {
    // Remove all script tags
    input = regexp.MustCompile(`(?i)<script[^>]*>[\s\S]*?</script>`).ReplaceAllString(input, "")
    // Remove event handlers
    input = regexp.MustCompile(`(?i)\s*on\w+\s*=\s*["'][^"']*["']`).ReplaceAllString(input, "")
    return input
}
```

---

## ⏱️ SLIDE 10: PROGRESSIVE DELAY SYSTEM

### Mengapa Penting?
WorkRadar mengimplementasikan **Progressive Delay (Exponential Backoff)** untuk mencegah brute force attack. Setiap percobaan login gagal akan menambah delay secara eksponensial - membuat serangan otomatis menjadi **sangat lambat dan tidak praktis**.

### Mekanisme Delay:
| Percobaan Ke- | Delay | Status |
|---------------|-------|--------|
| 1 | 1 detik | ⚠️ Warning |
| 2 | 2 detik | ⚠️ Warning |
| 3 | 4 detik | ⚠️ Warning |
| 4 | 8 detik | ⚠️ Warning |
| 5 | **LOCKED** | 🔒 30 menit |

### Potongan Kode:
```go
// server/internal/services/progressive_delay_service.go
type ProgressiveDelayConfig struct {
    BaseDelaySeconds  float64       // 1.0 detik
    MaxDelaySeconds   float64       // 60.0 detik
    DelayMultiplier   float64       // 2x per kegagalan
    LockoutThreshold  int           // 5 percobaan
    LockoutDuration   time.Duration // 30 menit
}

func (s *ProgressiveDelayService) RecordFailedAttempt(email, ip string) (delay float64, isLocked bool, lockUntil *time.Time) {
    attempts := s.getFailedAttempts(email, ip)
    attempts++
    
    if attempts >= s.config.LockoutThreshold {
        // Lock account selama 30 menit
        lockTime := time.Now().Add(s.config.LockoutDuration)
        s.lockAccount(email, lockTime)
        return 0, true, &lockTime
    }
    
    // Calculate exponential delay: 1s → 2s → 4s → 8s → ...
    delay = s.config.BaseDelaySeconds * math.Pow(s.config.DelayMultiplier, float64(attempts-1))
    if delay > s.config.MaxDelaySeconds {
        delay = s.config.MaxDelaySeconds
    }
    
    return delay, false, nil
}
```

---

## 📱 SLIDE 11: CERTIFICATE PINNING (MOBILE)

### Mengapa Penting?
WorkRadar mengimplementasikan **Certificate Pinning** di aplikasi Flutter untuk mencegah **Man-in-the-Middle (MITM) attack**. Aplikasi hanya mempercayai certificate yang sudah di-"pin" - bukan sembarang certificate yang dikeluarkan oleh CA.

### Cara Kerja:
1. App menyimpan hash certificate server yang valid
2. Saat koneksi, app memverifikasi hash certificate
3. Jika tidak cocok → koneksi ditolak
4. Melindungi dari fake certificate (wifi publik berbahaya)

### Potongan Kode:
```dart
// client/lib/core/network/certificate_pinning.dart
class CertificatePinningConfig {
    // SHA-256 hashes dari certificate yang dipercaya
    static const List<String> pinnedCertificateHashes = [
        'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup
    ];
    
    // Enable hanya di production
    static bool get isEnabled => !kDebugMode;
    
    // Domains yang di-pin
    static const List<String> pinnedDomains = [
        'api.workradar.com',
        '*.workradar.com',
    ];
}

class SecureApiClient {
    Dio get dio {
        return Dio()..httpClientAdapter = IOHttpClientAdapter(
            onHttpClientCreate: (client) {
                client.badCertificateCallback = (cert, host, port) {
                    if (!CertificatePinningConfig.isEnabled) return true;
                    
                    // Verify certificate hash
                    final certHash = sha256.convert(cert.der).toString();
                    return CertificatePinningConfig.pinnedCertificateHashes
                        .contains('sha256/$certHash');
                };
                return client;
            },
        );
    }
}
```

---

## 🚨 SLIDE 12: SECURITY ALERT SERVICE

### Mengapa Penting?
WorkRadar memiliki **Security Alert Service** yang mengirim notifikasi real-time ketika mendeteksi aktivitas mencurigakan. Admin dapat menerima alert melalui email, Slack, atau webhook untuk **respons cepat terhadap serangan**.

### Tipe Alert:
| Alert Type | Severity | Trigger |
|------------|----------|---------|
| BRUTE_FORCE | 🔴 HIGH | >10 failed login dari 1 IP |
| ACCOUNT_ATTACK | 🔴 HIGH | >5 failed login untuk 1 email |
| DISTRIBUTED_ATTACK | 🔴 CRITICAL | Multiple IP menyerang 1 akun |
| NEW_DEVICE | 🟡 MEDIUM | Login dari device baru |
| ACCOUNT_LOCKED | 🔴 HIGH | Akun terkunci |

### Potongan Kode:
```go
// server/internal/services/failed_login_tracker.go
type SecurityAlert struct {
    Type      AlertType
    Severity  AlertSeverity
    Title     string
    Message   string
    Data      map[string]interface{}
    CreatedAt time.Time
}

func (s *SecurityAlertService) SendAlert(alert SecurityAlert) {
    // Log ke database
    s.auditService.LogSecurityEvent(string(alert.Type), string(alert.Severity),
        "", "", alert.Data)
    
    // Kirim ke handlers (email, slack, webhook)
    for _, handler := range s.handlers {
        go handler(alert)  // Async untuk tidak blocking
    }
}

// Contoh: Deteksi brute force attack
if failedAttempts > 10 && withinMinute {
    alertService.SendAlert(SecurityAlert{
        Type:     AlertTypeBruteForce,
        Severity: AlertSeverityHigh,
        Title:    "Brute Force Attack Detected",
        Message:  fmt.Sprintf("IP %s melakukan %d percobaan login gagal", ip, failedAttempts),
        Data:     map[string]interface{}{"ip": ip, "attempts": failedAttempts},
    })
}
```

---

# 🏢 PART 3: ENTERPRISE SECURITY (MINGGU 11-13)

---

## 👥 SLIDE 13: ROLE-BASED ACCESS CONTROL (RBAC)

### Mengapa Penting?
WorkRadar mengimplementasikan **RBAC (Role-Based Access Control)** dengan **24+ permission granular** dan **5 role hierarki**. Setiap user hanya dapat mengakses fitur sesuai perannya - menerapkan **prinsip least privilege** yang ketat.

### Hierarki Role:
| Role | Akses |
|------|-------|
| **user** | Task & Category CRUD, Profile sendiri |
| **vip** | User + Payment Read |
| **moderator** | User Read/Lock, Audit Read |
| **admin** | Semua kecuali Admin Full |
| **superadmin** | 24+ permissions lengkap |

### Potongan Kode:
```go
// server/internal/services/access_control_service.go
const (
    // User Permissions
    PermissionUserRead    Permission = "user:read"
    PermissionUserCreate  Permission = "user:create"
    PermissionUserUpdate  Permission = "user:update"
    PermissionUserDelete  Permission = "user:delete"
    PermissionUserLock    Permission = "user:lock"
    
    // Task Permissions
    PermissionTaskRead    Permission = "task:read"
    PermissionTaskCreate  Permission = "task:create"
    PermissionTaskUpdate  Permission = "task:update"
    PermissionTaskDelete  Permission = "task:delete"
    
    // Security Permissions
    PermissionAuditRead      Permission = "audit:read"
    PermissionSecurityManage Permission = "security:manage"
    
    // Admin Permission
    PermissionAdminFull Permission = "admin:full"
)

// Check permission
func (s *AccessControlService) HasPermission(userID string, permission Permission) bool {
    user, _ := s.getUserByID(userID)
    rolePermissions := s.getRolePermissions(user.Role)
    return contains(rolePermissions, permission)
}
```

```go
// server/internal/middleware/access_control.go
// Penggunaan di route
app.Delete("/api/admin/users/:id",
    middleware.AuthMiddleware(),
    middleware.AccessControlMiddleware(services.PermissionUserDelete),
    handler.DeleteUser)
```

---

## 🗄️ SLIDE 14: MULTI-USER DATABASE CONNECTION

### Mengapa Penting?
WorkRadar menerapkan **prinsip least privilege** pada level database dengan **3 user database terpisah**. Setiap koneksi memiliki privilege berbeda - aplikasi menggunakan user yang hanya bisa SELECT/INSERT/UPDATE, bukan DELETE atau DROP.

### 3 Level Database User:
| User | Privileges | Fungsi |
|------|------------|--------|
| `workradar_read` | SELECT only | Reporting, analytics |
| `workradar_app` | SELECT, INSERT, UPDATE | Operasi normal app |
| `workradar_admin` | ALL PRIVILEGES | Migrasi, maintenance |

### Potongan Kode:
```sql
-- server/internal/database/migrations/001_security_users_and_views.sql

-- Read-Only User (untuk reporting)
CREATE USER 'workradar_read'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT ON workradar.* TO 'workradar_read'@'%';

-- Application User (operasi normal - NO DELETE on users)
CREATE USER 'workradar_app'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE ON workradar.* TO 'workradar_app'@'%';
REVOKE DELETE ON workradar.users FROM 'workradar_app'@'%';

-- Admin User (full access untuk maintenance)
CREATE USER 'workradar_admin'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON workradar.* TO 'workradar_admin'@'%';
```

```go
// server/internal/database/multi_connection.go
connMgr := database.GetConnectionManager()

readDB := connMgr.GetReadDB()   // Untuk SELECT queries saja
appDB := connMgr.GetAppDB()     // Untuk INSERT, UPDATE
adminDB := connMgr.GetAdminDB() // Untuk DELETE, migrations
```

---

## 👁️ SLIDE 15: SECURITY VIEWS & DATA MASKING

### Mengapa Penting?
WorkRadar menggunakan **8 Security Views** untuk membatasi data yang dapat diakses. Email dan data sensitif di-**mask** (disembunyikan sebagian) sehingga bahkan user dengan akses read tidak bisa melihat data lengkap.

### Contoh Data Masking:
| Data Asli | Data Masked |
|-----------|-------------|
| `john@example.com` | `joh***@example.com` |
| `081234567890` | `0812***7890` |

### 8 Security Views:
1. `v_user_public_profiles` - Email ter-mask
2. `v_user_dashboard` - Safe untuk user view
3. `v_task_summaries` - Hide user details
4. `v_audit_logs_summary` - User email ter-mask
5. `v_security_events_dashboard` - Aggregated events
6. `v_blocked_ips_active` - Active blocks only
7. `v_subscription_status` - Health indicator
8. `v_payment_history` - Sanitized payment

### Potongan Kode:
```sql
-- server/internal/database/migrations/001_security_users_and_views.sql

-- View dengan email masking
CREATE VIEW v_user_public_profiles AS
SELECT 
    id, 
    username,
    CONCAT(LEFT(email, 3), '***@', SUBSTRING_INDEX(email, '@', -1)) as email_masked,
    user_type, 
    created_at
FROM users 
WHERE deleted_at IS NULL;

-- View untuk audit log (tanpa data sensitif)
CREATE VIEW v_audit_logs_summary AS
SELECT 
    id, 
    action, 
    table_name, 
    record_id, 
    ip_address, 
    created_at,
    CONCAT(LEFT(user_email, 3), '***') as user_email_masked
FROM audit_logs 
ORDER BY created_at DESC;
```

---

## 🔍 SLIDE 16: VULNERABILITY SCANNER

### Mengapa Penting?
WorkRadar memiliki **Vulnerability Scanner** yang otomatis mendeteksi **12 tipe kerentanan** termasuk SQL injection, XSS, dan konfigurasi tidak aman. Scanner dapat dijalankan secara berkala untuk memastikan sistem tetap aman.

### 12 Tipe Vulnerability:
| Tipe | Severity |
|------|----------|
| SQL_INJECTION | 🔴 CRITICAL |
| XSS | 🔴 HIGH |
| BRUTE_FORCE | 🟡 MEDIUM |
| WEAK_PASSWORD | 🟡 MEDIUM |
| MISSING_ENCRYPTION | 🔴 CRITICAL |
| BROKEN_AUTH | 🔴 HIGH |
| INSECURE_CONFIG | 🟡 MEDIUM |
| DATA_EXPOSURE | 🔴 HIGH |

### Potongan Kode:
```go
// server/internal/services/vulnerability_scanner_service.go
const (
    VulnSQLInjection      VulnerabilityType = "SQL_INJECTION"
    VulnXSS               VulnerabilityType = "XSS"
    VulnBruteForce        VulnerabilityType = "BRUTE_FORCE"
    VulnWeakPassword      VulnerabilityType = "WEAK_PASSWORD"
    VulnMissingEncryption VulnerabilityType = "MISSING_ENCRYPTION"
    VulnBrokenAuth        VulnerabilityType = "BROKEN_AUTH"
    VulnInsecureConfig    VulnerabilityType = "INSECURE_CONFIG"
    VulnDataExposure      VulnerabilityType = "DATA_EXPOSURE"
)

func (s *VulnerabilityScannerService) RunFullScan() (*ScanResult, error) {
    result := &ScanResult{StartedAt: time.Now()}
    
    // Scan semua komponen
    s.scanAuthentication(result)    // MFA status, locked accounts
    s.scanEncryption(result)        // Field encryption, TLS config
    s.scanSecurityEvents(result)    // Recent security events
    s.scanDatabase(result)          // Connection pool, privileges
    s.scanAPIEndpoints(result)      // Rate limits, auth
    s.scanConfiguration(result)     // Security headers, CORS
    
    result.CalculateRiskScore()
    return result, nil
}
```

---

## ⏰ SLIDE 17: SECURITY SCHEDULER (AUTOMATED TASKS)

### Mengapa Penting?
WorkRadar menjalankan **10 automated security tasks** secara berkala untuk menjaga keamanan tanpa intervensi manual. Termasuk security audit harian, vulnerability scan setiap 12 jam, dan session cleanup setiap jam.

### 10 Automated Tasks:
| Task | Interval | Fungsi |
|------|----------|--------|
| Security Audit | 24 jam | Full security audit |
| Vulnerability Scan | 12 jam | Quick vulnerability scan |
| Session Cleanup | 1 jam | Clean expired sessions |
| Blocked IP Cleanup | 6 jam | Remove expired blocks |
| Password Expiry Check | 24 jam | Check password expiration |
| Token Cleanup | 4 jam | Clean blacklisted tokens |
| Audit Log Cleanup | 7 hari | Archive old logs |
| Inactive Accounts | 7 hari | Flag inactive accounts |
| Database Optimize | 7 hari | Optimize tables |
| Security Report | 24 jam | Generate daily report |

### Potongan Kode:
```go
// server/internal/services/security_scheduler_service.go
type SecurityScheduler struct {
    tasks map[string]*ScheduledTask
}

func (s *SecurityScheduler) Start() {
    // Security Audit - setiap 24 jam
    s.scheduleTask("SECURITY_AUDIT", 24*time.Hour, func() {
        auditService.RunFullAudit()
    })
    
    // Vulnerability Scan - setiap 12 jam
    s.scheduleTask("VULNERABILITY_SCAN", 12*time.Hour, func() {
        scanner.RunQuickScan()
    })
    
    // Session Cleanup - setiap 1 jam
    s.scheduleTask("SESSION_CLEANUP", 1*time.Hour, func() {
        sessionService.CleanupExpiredSessions()
    })
    
    // Token Cleanup - setiap 4 jam
    s.scheduleTask("TOKEN_CLEANUP", 4*time.Hour, func() {
        tokenService.CleanupBlacklistedTokens()
    })
}
```

---

## 🔒 SLIDE 18: MITM ATTACK PREVENTION

### Mengapa Penting?
WorkRadar menerapkan **multiple layer protection** terhadap Man-in-the-Middle (MITM) attack. Kombinasi **HTTPS/TLS**, **HSTS header**, dan **Certificate Pinning** memastikan komunikasi antara client dan server tidak dapat disadap atau dimanipulasi.

### Layer Proteksi:
| Layer | Server-Side | Client-Side |
|-------|-------------|-------------|
| Transport | HTTPS/TLS 1.2+ | Certificate Pinning |
| Headers | HSTS, CSP, X-Frame-Options | Security Interceptor |
| Validation | Request signing | Timestamp + Nonce |

### Potongan Kode:
```go
// server/cmd/main.go - HTTPS Server
if config.TLSEnabled {
    log.Fatal(app.ListenTLS(":443", 
        config.TLSCertFile, 
        config.TLSKeyFile))
}

// server/internal/middleware/https_middleware.go
func SecureHeadersMiddleware() fiber.Handler {
    return func(c *fiber.Ctx) error {
        // HSTS - Force HTTPS selama 1 tahun
        c.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        
        // Prevent clickjacking
        c.Set("X-Frame-Options", "DENY")
        
        // Prevent XSS
        c.Set("X-XSS-Protection", "1; mode=block")
        
        // Content Security Policy
        c.Set("Content-Security-Policy", "default-src 'self'")
        
        // Prevent MIME sniffing
        c.Set("X-Content-Type-Options", "nosniff")
        
        return c.Next()
    }
}
```

---

# ✅ SLIDE 19: SUMMARY - TOTAL IMPLEMENTASI

### WorkRadar Database Security Implementation:

| Kategori | Jumlah/Detail |
|----------|---------------|
| **Total Security Features** | 22+ fitur |
| **Granular Permissions** | 24+ permissions |
| **User Roles** | 5 roles (user → superadmin) |
| **Database Users** | 3 level (read, app, admin) |
| **Security Views** | 8 views dengan data masking |
| **Automated Tasks** | 10 scheduled tasks |
| **Vulnerability Types Detected** | 12 tipe |
| **SQL Injection Patterns** | 25+ patterns |
| **XSS Patterns** | 15+ patterns |

### Teknologi yang Digunakan:
| Komponen | Teknologi |
|----------|-----------|
| Backend | Golang + Fiber Framework |
| Frontend | Flutter/Dart |
| Database | MySQL dengan SSL/TLS |
| Enkripsi | AES-256-GCM |
| Hashing | SHA-256, bcrypt |
| Authentication | JWT + TOTP (MFA) |

---

# ✅ SLIDE 20: SECURITY COMPLIANCE CHECKLIST

### WorkRadar memenuhi standar keamanan berikut:

| Security Control | Status | Implementasi |
|------------------|--------|--------------|
| ✅ Authentication | DONE | MFA/2FA dengan TOTP |
| ✅ Authorization | DONE | RBAC dengan 24+ permissions |
| ✅ Encryption at Rest | DONE | AES-256-GCM field encryption |
| ✅ Encryption in Transit | DONE | TLS 1.2+ untuk semua koneksi |
| ✅ Audit Logging | DONE | Comprehensive audit trail |
| ✅ Input Validation | DONE | 3-layer SQL injection prevention |
| ✅ Security Headers | DONE | HSTS, CSP, X-Frame-Options |
| ✅ Vulnerability Scanning | DONE | 12 tipe vulnerability detection |
| ✅ Automated Security Tasks | DONE | 10 scheduled security tasks |
| ✅ Monitoring Dashboard | DONE | Real-time security monitoring |

---

# 🙏 SLIDE 21: PENUTUP

### Kesimpulan:
WorkRadar telah mengimplementasikan **keamanan basis data komprehensif** yang mencakup:

1. **Foundational Security** - Audit logging, MFA, password policy
2. **Advanced Security** - SQL injection prevention, XSS prevention, progressive delay
3. **Enterprise Security** - RBAC, vulnerability scanning, automated monitoring

### Referensi:
- OWASP SQL Injection Prevention Cheat Sheet
- OWASP XSS Prevention Cheat Sheet
- NIST Password Guidelines (SP 800-63B)
- OWASP Authentication Cheat Sheet

---

# 📎 LAMPIRAN: STRUKTUR FILE IMPLEMENTASI

```
server/
├── cmd/main.go                              # HTTPS/TLS server
├── internal/
│   ├── database/
│   │   ├── database.go                      # SSL/TLS connection
│   │   ├── multi_connection.go              # Multi-user DB
│   │   └── migrations/
│   │       └── 001_security_users_views.sql # Security views
│   ├── middleware/
│   │   ├── threat_detection.go              # Brute force protection
│   │   ├── input_sanitization.go            # SQL/XSS prevention
│   │   ├── access_control.go                # RBAC middleware
│   │   └── https_middleware.go              # Security headers
│   ├── services/
│   │   ├── audit_service.go                 # Audit logging
│   │   ├── mfa_service.go                   # MFA/2FA
│   │   ├── encryption_service.go            # AES-256 encryption
│   │   ├── key_manager.go                   # Key management
│   │   ├── password_policy_service.go       # Password validation
│   │   ├── access_control_service.go        # Permission management
│   │   ├── progressive_delay_service.go     # Exponential backoff
│   │   ├── failed_login_tracker.go          # Attack detection
│   │   ├── security_audit_service.go        # Security audit
│   │   ├── vulnerability_scanner_service.go # Vulnerability scan
│   │   └── security_scheduler_service.go    # Automated tasks
│   └── repository/
│       └── secure_user_repository.go        # Encrypted user data
└── pkg/utils/
    ├── sanitize.go                          # Input sanitization
    └── validator.go                         # Input validation

client/lib/
├── core/
│   ├── services/session_service.dart        # Session timeout
│   └── network/certificate_pinning.dart     # Certificate pinning
└── features/auth/screens/
    ├── mfa_setup_screen.dart                # MFA setup UI
    └── mfa_verify_screen.dart               # MFA verify UI
```

---

**© 2026 WorkRadar - Database Security Implementation**
