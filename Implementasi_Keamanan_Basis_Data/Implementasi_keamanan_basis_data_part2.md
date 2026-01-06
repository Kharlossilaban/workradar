# 🔐 IMPLEMENTASI KEAMANAN BASIS DATA PART 2 (Minggu 6-10)

## 📊 STATUS IMPLEMENTASI

| Minggu | Fokus | Status | File Utama |
|--------|-------|--------|------------|
| Minggu 6 | SQL Injection Prevention & Input Validation | ✅ DONE | `sanitize.go`, `validator.go`, `input_sanitization.go` |
| Minggu 7 | Authentication & Authorization Enhancement | ✅ DONE | `progressive_delay_service.go`, `failed_login_tracker.go` |
| Minggu 8 | Data Encryption & Secure Communication | ✅ DONE | `certificate_pinning.dart`, `database.go` |
| Minggu 9 | Access Control & Security Headers | ✅ DONE (dari Part 1) | `security.go`, `audit_service.go` |
| Minggu 10 | Brute Force Prevention & Security Monitoring | ✅ DONE | `failed_login_tracker.go`, `progressive_delay_service.go` |

---

## 🔐 MINGGU 6 - SQL Injection Prevention & Input Validation ✅ COMPLETE

### Yang Sudah Ada (dari Part 1) ✅
- GORM dengan parameterized queries (`Where("user_id = ?", userID)`)
- Semua repository menggunakan placeholder `?`

### Yang Ditambahkan ✅

#### 1. Input Sanitization Layer
**File:** `server/pkg/utils/sanitize.go`

```go
// Fungsi utama yang tersedia:
ContainsSQLInjection(input string) (bool, []string)  // Deteksi SQL injection
ContainsXSS(input string) (bool, []string)           // Deteksi XSS
ContainsPathTraversal(input string) (bool, []string) // Deteksi path traversal
ContainsCmdInjection(input string) (bool, []string)  // Deteksi command injection

SanitizeString(input string, config SanitizationConfig) string
SanitizeEmail(email string) (string, error)
SanitizeName(name string) (string, error)
SanitizePhone(phone string) (string, error)
SanitizeURL(url string) (string, error)
SanitizeFilename(filename string) string
SanitizeHTML(input string) string
```

**SQL Injection Patterns yang dideteksi:**
- Basic SQL keywords (SELECT, INSERT, UPDATE, DELETE, DROP, UNION, etc.)
- SQL comments (`--`, `#`, `/*`, `*/`)
- Hex encoding (`0x...`)
- CHAR/CHR functions
- Time-based blind injection (SLEEP, WAITFOR, BENCHMARK)
- Union-based injection

**XSS Patterns yang dideteksi:**
- Script tags
- Event handlers (onclick, onload, onerror, etc.)
- JavaScript/VBScript protocols
- Data URIs
- SVG/Iframe/Object/Embed tags

#### 2. Input Length Validation
**File:** `server/pkg/utils/validator.go`

```go
// InputValidator - Chainable validator
v := utils.NewInputValidator()
v.ValidateName(name, "name")
  .ValidateEmail(email, "email")
  .ValidatePassword(password, "password")
  .ValidateMaxLength(description, "description", 5000)

if !v.IsValid() {
    return v.GetErrors()
}

// Pre-defined validators
ValidateRegisterRequest(name, email, password)
ValidateLoginRequest(email, password)
ValidateTaskRequest(title, description, status)
ValidateProfileUpdateRequest(name, phone)
ValidateChangePasswordRequest(oldPwd, newPwd, confirmPwd)
```

**Field Configurations:**
| Field | Min | Max | Pattern |
|-------|-----|-----|---------|
| Email | 5 | 254 | RFC 5322 |
| Name | 2 | 100 | Letters, spaces, hyphens |
| Password | 8 | 128 | Complexity rules |
| Phone | 7 | 15 | E.164 format |
| Title | 1 | 200 | - |
| Description | 0 | 5000 | - |

#### 3. Input Sanitization Middleware
**File:** `server/internal/middleware/input_sanitization.go`

```go
// Gunakan di main.go
app.Use(middleware.InputSanitizationMiddleware())
app.Use(middleware.StrictInputValidationMiddleware())

// Middleware ini akan:
// - Check query parameters untuk injection
// - Check path parameters untuk injection
// - Check request body untuk SQL injection & XSS
// - Log semua detected threats ke audit log
// - Block request jika threat terdeteksi
```

#### 4. SQL Injection Testing
**File:** `server/test/security_test.go`

```bash
# Run tests
cd server
go test ./test/security_test.go -v

# Test cases include:
# - Basic SQL injection patterns
# - Advanced SQL injection (blind, time-based, union)
# - XSS patterns (script, events, protocols)
# - Path traversal patterns
# - Password complexity validation
# - Input sanitization
```

---

## 🔑 MINGGU 7 - Authentication & Authorization Enhancement ✅ COMPLETE

### Yang Sudah Ada (dari Part 1) ✅
- Bcrypt password hashing
- JWT access & refresh tokens
- Google OAuth integration
- Token blacklist untuk logout
- User type (regular/vip) authorization
- Account Lockout Mechanism (di `user.go`)
- MFA/2FA Implementation (di `mfa_service.go`)

### Yang Ditambahkan ✅

#### 1. Progressive Delay System (Exponential Backoff)
**File:** `server/internal/services/progressive_delay_service.go`

```go
// Configuration
config := DefaultProgressiveDelayConfig()
// BaseDelaySeconds: 1.0
// MaxDelaySeconds: 60.0
// DelayMultiplier: 2.0
// ResetAfter: 15 minutes
// LockoutThreshold: 5
// LockoutDuration: 30 minutes

service := NewProgressiveDelayService(db, auditService, config)

// Record failed attempt
delay, isLocked, lockUntil := service.RecordFailedAttempt(email, ip)
// 1st fail: 1s delay
// 2nd fail: 2s delay
// 3rd fail: 4s delay
// 4th fail: 8s delay
// 5th fail: LOCKED for 30 minutes

// Check if locked before attempting login
isLocked, lockUntil, remainingDelay := service.CheckIfLocked(email, ip)

// On successful login, reset counters
service.RecordSuccessfulLogin(email, ip)
```

#### 2. Session Management
**File:** `server/internal/services/progressive_delay_service.go`

```go
// Database model: ActiveSession
type ActiveSession struct {
    ID           string    `gorm:"type:varchar(36);primaryKey"`
    UserID       string    `gorm:"type:varchar(36);index"`
    TokenHash    string    `gorm:"type:varchar(64);uniqueIndex"` // SHA-256 of token
    DeviceInfo   string    `gorm:"type:varchar(255)"`
    IPAddress    string    `gorm:"type:varchar(45)"`
    UserAgent    string    `gorm:"type:text"`
    CreatedAt    time.Time
    LastActivity time.Time
    ExpiresAt    time.Time
}

// Service
sessionService := NewSessionManagementService(db, auditService, maxSessions)

// Create session on login
session, err := sessionService.CreateSession(userID, tokenHash, deviceInfo, ip, userAgent, ttl)

// Get all sessions for user
sessions, err := sessionService.GetUserSessions(userID, currentTokenHash)

// Logout from specific device
err := sessionService.InvalidateSession(userID, sessionID)

// Logout from all devices
err := sessionService.InvalidateAllSessions(userID, exceptCurrentToken)

// Validate session
session, err := sessionService.ValidateSession(tokenHash)
```

#### 3. Password Complexity Requirements
**File:** `server/pkg/utils/sanitize.go`

```go
// Configuration
config := DefaultPasswordConfig()
// MinLength: 8
// MaxLength: 128
// RequireUppercase: true
// RequireLowercase: true
// RequireDigit: true
// RequireSpecial: true
// DisallowCommon: true (checks against 20+ common passwords)

// Validate
result := ValidatePasswordComplexity(password)
if !result.IsValid {
    // result.Errors contains list of validation failures
}

// Calculate strength score (0-100)
score := CalculatePasswordStrength(password)
// 0-30: Weak
// 31-60: Medium
// 61-80: Good
// 81-100: Strong
```

---

## 🔒 MINGGU 8 - Data Encryption & Secure Communication ✅ COMPLETE

### Yang Sudah Ada (dari Part 1) ✅
- Flutter Secure Storage
- Password hashing (bcrypt)
- JWT token signing
- HTTPS ready configuration
- MySQL SSL/TLS Connection (`database.go`)
- Field-Level Encryption (`encryption_service.go`)
- Secure Key Management (`key_manager.go`)

### Yang Ditambahkan ✅

#### 1. Certificate Pinning (Flutter)
**File:** `client/lib/core/network/certificate_pinning.dart`

```dart
// Configuration
class CertificatePinningConfig {
  // SHA-256 hashes of trusted certificate public keys
  static const List<String> pinnedCertificateHashes = [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ];
  
  // Enable only in production
  static bool get isEnabled => AppConfig.isProduction;
  
  // Domains to pin
  static const List<String> pinnedDomains = [
    'api.workradar.com',
    '*.workradar.com',
  ];
}

// Usage
final secureClient = SecureApiClient();
final response = await secureClient.dio.get('/api/users');
```

**Features:**
- Certificate hash validation
- Domain matching with wildcards
- Security headers validation
- Request timestamp & nonce for replay attack prevention
- Automatic security logging

#### 2. Secrets Management
**Environment Variables yang diperlukan:**

```bash
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=workradar_app
DB_PASSWORD=<secure_password>
DB_NAME=workradar
DB_SSL_ENABLED=true
DB_SSL_CA=/path/to/ca-cert.pem

# Encryption
ENCRYPTION_KEY=<32_character_minimum_key>

# JWT
JWT_SECRET=<secure_jwt_secret>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# API Keys (jangan hardcode!)
MIDTRANS_SERVER_KEY=<midtrans_key>
MIDTRANS_CLIENT_KEY=<midtrans_client_key>
FIREBASE_CREDENTIALS=/path/to/firebase-creds.json

# TLS
TLS_ENABLED=true
TLS_CERT_FILE=/path/to/cert.pem
TLS_KEY_FILE=/path/to/key.pem
```

---

## 🛡️ MINGGU 9 - Access Control & Security Headers ✅ COMPLETE

### Yang Sudah Ada (dari Part 1) ✅
- Comprehensive security headers (X-Frame-Options, CSP, HSTS, dll)
- CORS configuration
- Request ID tracking
- Audit Logging (`audit_service.go`)
- Access Control Middleware (`access_control.go`)
- CSRF protection untuk OAuth

### Status
Semua fitur utama Minggu 9 sudah diimplementasikan di Part 1:
- Security headers middleware
- CORS configuration
- Audit logging service
- IP-based rate limiting

---

## 🚨 MINGGU 10 - Brute Force Prevention & Security Monitoring ✅ COMPLETE

### Yang Sudah Ada (dari Part 1) ✅
- Sophisticated rate limiting (login, register, VIP/regular users)
- Per-user dan per-IP tracking
- Request cleanup

### Yang Ditambahkan ✅

#### 1. Failed Login Tracking
**File:** `server/internal/services/failed_login_tracker.go`

```go
// Database model
type FailedLoginAttempt struct {
    ID          string    `gorm:"type:varchar(36);primaryKey"`
    Email       string    `gorm:"type:varchar(255);index"`
    IPAddress   string    `gorm:"type:varchar(45);index"`
    UserAgent   string    `gorm:"type:text"`
    Reason      string    `gorm:"type:varchar(100)"` // wrong_password, account_locked
    AttemptedAt time.Time `gorm:"index"`
}

// Service
tracker := NewFailedLoginTracker(db, auditService, alertService)

// Record failed attempt
tracker.RecordFailedLogin(email, ip, userAgent, "wrong_password")

// Get statistics
stats, err := tracker.GetStats()
// stats.TotalAttempts
// stats.Last24Hours
// stats.TopAttackedEmails
// stats.TopAttackerIPs
// stats.HourlyDistribution

// Cleanup old records
tracker.CleanupOldRecords(30 * 24 * time.Hour)
```

#### 2. Security Alert Service
**File:** `server/internal/services/failed_login_tracker.go`

```go
// Alert types
AlertTypeBruteForce        // Multiple failed logins from same IP
AlertTypeAccountAttack     // Multiple failed logins for same email
AlertTypeDistributedAttack // Multiple IPs attacking same account
AlertTypeNewDevice         // Login from new device
AlertTypeSuspiciousLogin   // Unusual login pattern
AlertTypeAccountLocked     // Account has been locked

// Alert severities
AlertSeverityLow
AlertSeverityMedium
AlertSeverityHigh
AlertSeverityCritical

// Service
alertService := NewSecurityAlertService(db, auditService)

// Register handler (e.g., email, Slack, webhook)
alertService.RegisterHandler(func(alert SecurityAlert) error {
    // Send email to admin
    return sendEmailAlert(alert)
})

// Send alert
alertService.SendAlert(SecurityAlert{
    Type:     AlertTypeBruteForce,
    Severity: AlertSeverityHigh,
    Title:    "Brute Force Attack Detected",
    Message:  "Multiple failed login attempts from IP: " + ip,
    Data: map[string]interface{}{
        "ip_address": ip,
        "attempts":   count,
    },
})

// Get recent alerts
alerts := alertService.GetRecentAlerts(20)
```

#### 3. Attack Pattern Detection

```go
// Automatic detection in FailedLoginTracker:

// 1. Brute Force Detection
// Triggers alert if >10 failed attempts per minute from same IP

// 2. Account Attack Detection
// Triggers alert if >5 failed attempts in 5 minutes for same email

// 3. Distributed Attack Detection
// Triggers alert if multiple IPs (>3) attack same account in 1 minute
```

---

## 📁 FILE-FILE YANG DIBUAT/DIMODIFIKASI

### Minggu 6
| File | Status | Deskripsi |
|------|--------|-----------|
| `server/pkg/utils/sanitize.go` | ✅ NEW | Input sanitization & SQL injection detection |
| `server/pkg/utils/validator.go` | ✅ NEW | Input validation & password complexity |
| `server/internal/middleware/input_sanitization.go` | ✅ NEW | Request sanitization middleware |
| `server/test/security_test.go` | ✅ NEW | Security test cases |

### Minggu 7
| File | Status | Deskripsi |
|------|--------|-----------|
| `server/internal/services/progressive_delay_service.go` | ✅ NEW | Progressive delay & session management |

### Minggu 8
| File | Status | Deskripsi |
|------|--------|-----------|
| `client/lib/core/network/certificate_pinning.dart` | ✅ NEW | Certificate pinning for Flutter |

### Minggu 10
| File | Status | Deskripsi |
|------|--------|-----------|
| `server/internal/services/failed_login_tracker.go` | ✅ NEW | Failed login tracking & alerts |

---

## 🧪 TESTING

### Run Security Tests
```bash
cd server
go test ./test/security_test.go -v
```

### Test Cases
- SQL Injection detection (25+ patterns)
- XSS detection (15+ patterns)
- Path traversal detection
- Password complexity validation
- Input sanitization
- Middleware integration

### Benchmark Tests
```bash
go test ./test/security_test.go -bench=.
```

---

## 📋 CHECKLIST IMPLEMENTASI

### ✅ Minggu 6 - SQL Injection Prevention
- [x] Input Sanitization Layer (`sanitize.go`)
- [x] SQL Injection Pattern Detection
- [x] XSS Pattern Detection
- [x] Path Traversal Detection
- [x] Input Length Validation (`validator.go`)
- [x] Password Complexity Validator
- [x] Sanitization Middleware (`input_sanitization.go`)
- [x] Security Test Cases (`security_test.go`)

### ✅ Minggu 7 - Authentication Enhancement
- [x] Progressive Delay (Exponential Backoff)
- [x] Session Management Service
- [x] Password Complexity Requirements
- [x] Device Fingerprinting
- [x] Account Lockout (dari Part 1)
- [x] MFA/2FA (dari Part 1)

### ✅ Minggu 8 - Data Encryption
- [x] MySQL SSL/TLS (dari Part 1)
- [x] Field-Level Encryption (dari Part 1)
- [x] Certificate Pinning (Flutter)
- [x] Secrets Management (env vars)

### ✅ Minggu 9 - Access Control
- [x] Security Headers (dari Part 1)
- [x] CORS Configuration (dari Part 1)
- [x] Audit Logging (dari Part 1)
- [x] Rate Limiting (dari Part 1)

### ✅ Minggu 10 - Security Monitoring
- [x] Failed Login Tracking
- [x] Security Alert Service
- [x] Attack Pattern Detection
- [x] Real-time Alerts
- [x] Progressive Delay System

---

## 🔗 REFERENSI

- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
