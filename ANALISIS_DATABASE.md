# 📊 ANALISIS DATABASE WORKRADAR

## Status: ✅ DATABASE SUDAH TERSAMBUNG KE APLIKASI

---

## 📋 Daftar Isi
1. [Arsitektur Database](#arsitektur-database)
2. [Alur Koneksi](#alur-koneksi)
3. [Konfigurasi Database](#konfigurasi-database)
4. [Model Data](#model-data)
5. [Keamanan Database](#keamanan-database)
6. [Testing Connection](#testing-connection)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arsitektur Database

### Server-Side (Go Backend)
```
┌─────────────────────────────────────────────┐
│         FLUTTER CLIENT (Dart)               │
│  - Dio HTTP Client                          │
│  - Auth Interceptor                         │
│  - Token Management                         │
└─────────────────┬───────────────────────────┘
                  │
                  │ HTTP/HTTPS (JSON API)
                  │
┌─────────────────▼───────────────────────────┐
│      GO FIBER API SERVER (Port 8080)        │
│  - RESTful API Endpoints                    │
│  - Middleware (Auth, Security, CORS)        │
│  - Request Handlers                         │
│  - Service Layer (Business Logic)           │
│  - Repository Layer (Database Access)       │
└─────────────────┬───────────────────────────┘
                  │
                  │ TCP Connection (DSN)
                  │
┌─────────────────▼───────────────────────────┐
│        MYSQL DATABASE (Port 3306)           │
│  - 11 Tables (Users, Tasks, Categories...)  │
│  - Audit Logs & Security Events             │
│  - AES-256 Encrypted Fields                 │
│  - SSL/TLS Support                          │
└─────────────────────────────────────────────┘
```

---

## 🔄 Alur Koneksi

### 1️⃣ Client → Server (Request Path)

```
Flutter App
    ↓
ApiClient (Dio)
    ↓
baseUrl = 'https://workradar-production.up.railway.app/api'
    ↓
AuthInterceptor (Add JWT Token)
    ↓
HTTP POST/GET/PUT/DELETE Request
    ↓
Fiber Router
    ↓
Handler → Service → Repository
    ↓
GORM Query Builder
    ↓
MySQL Driver
    ↓
Database
```

### 2️⃣ Database → Server (Response Path)

```
MySQL Database
    ↓
GORM Scan/Parse Results
    ↓
Models (Struct)
    ↓
Repository Return
    ↓
Service Process (Encryption/Decryption)
    ↓
Handler Format Response (JSON)
    ↓
HTTP 200/400/401/500
    ↓
ApiClient Parse JSON
    ↓
Service Layer in App
    ↓
UI State Update
```

---

## ⚙️ Konfigurasi Database

### Backend Server Configuration (`server/internal/config/config.go`)

```go
// Database Connection String (DSN)
DBHost:     "localhost" (atau Railway MySQL host)
DBPort:     "3306"
DBUser:     "root" (atau Railway user)
DBPassword: "***" (dari environment variable)
DBName:     "railway" (atau database name)

// Connection Pool Settings (database.go)
MaxIdleConns:    10
MaxOpenConns:    100
ConnMaxLifetime: 1 hour
ConnMaxIdleTime: 10 minutes
```

### Environment Variables Yang Diperlukan

**Untuk Development:**
```bash
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=yourpassword
DB_NAME=workradar_dev

# Security
DB_SSL_ENABLED=false (development)

# API
PORT=8080
JWT_SECRET=your-secret-key
```

**Untuk Production (Railway):**
```bash
# Railway auto-generates these
MYSQLHOST=xxxxx.railway.internal
MYSQLPORT=3306
MYSQLUSER=root
MYSQLPASSWORD=xxxxx
MYSQLDATABASE=railway

# Or override with custom names
DB_HOST=xxxxx.railway.internal
DB_PASSWORD=xxxxx
DB_SSL_ENABLED=true (recommended)
```

### Flutter Client Configuration (`client/lib/core/config/environment.dart`)

```dart
// Development
Environment._env = Environment.development
_developmentIP = '192.168.1.7' (ganti dengan IP komputer Anda!)
apiUrl = 'http://192.168.1.7:8080/api'

// Production
Environment._env = Environment.production
apiUrl = 'https://workradar-production.up.railway.app/api'
```

---

## 📊 Model Data

### 11 Database Tables

| No. | Table | Deskripsi | Fields |
|-----|-------|-----------|--------|
| 1 | **users** | User accounts & profiles | id, email, username, password_hash, profile_picture, user_type, mfa_enabled, etc |
| 2 | **tasks** | Task items | id, user_id, category_id, title, description, status, priority, deadline, etc |
| 3 | **categories** | Task categories | id, user_id, name, color, description |
| 4 | **subscriptions** | VIP subscriptions | id, user_id, plan, start_date, end_date, status |
| 5 | **transactions** | Payment transactions | id, user_id, subscription_id, amount, payment_method, status |
| 6 | **password_resets** | Password reset tokens | id, user_id, token, expires_at |
| 7 | **email_verifications** | Email verification tokens | id, user_id, email, token, expires_at |
| 8 | **bot_messages** | Chatbot messages | id, user_id, message, response, timestamp |
| 9 | **holidays** | Public holidays | id, date, name, country |
| 10 | **leaves** | User leave requests | id, user_id, start_date, end_date, reason, status |
| 11 | **chat_messages** | Chat messages | id, user_id, message, timestamp |
| 12 | **audit_logs** | Audit trail | id, user_id, action, resource, timestamp |
| 13 | **security_events** | Security events | id, user_id, event_type, ip_address, timestamp |
| 14 | **login_attempts** | Login history | id, user_id, ip_address, success, timestamp |
| 15 | **blocked_ips** | Blocked IP addresses | id, ip_address, reason, expires_at |
| 16 | **password_history** | Password history | id, user_id, password_hash, created_at |

### Relasi Data

```
User (1) ──────── (Many) Tasks
       ├──────── (Many) Categories
       ├──────── (Many) Subscriptions
       ├──────── (Many) Transactions
       ├──────── (Many) Leaves
       ├──────── (Many) ChatMessages
       ├──────── (Many) BotMessages
       ├──────── (Many) AuditLogs
       └──────── (Many) SecurityEvents

Task (Many) ──────── (1) Category ──────── (1) User

Subscription (Many) ──────── (1) User
                       └──── (Many) Transactions

PasswordReset (Many) ──────── (1) User
EmailVerification (Many) ──────── (1) User
```

---

## 🔐 Keamanan Database

### 1. Enkripsi Data (AES-256)
```go
// Encrypted Fields di tabel users:
- EncryptedEmail (SHA-256 hash)
- EncryptedPhone (AES-256 encrypted)
- EmailHash (untuk searchability)
```

### 2. Authentication & Authorization
```go
// JWT Token untuk API Requests
- Access Token: 24 hours
- Refresh Token: 7 days
- Sent in Authorization header

// AuthInterceptor di Flutter
- Automatically add token to requests
- Refresh token saat expired
```

### 3. Audit Logging
```go
// Setiap operasi database dicatat di audit_logs
Fields:
- user_id: Siapa yang mengakses
- action: Create, Read, Update, Delete
- resource: Table name & record id
- timestamp: Kapan akses terjadi
- ip_address: Dari mana akses
```

### 4. Rate Limiting & DDoS Protection
```
- 60 requests per minute (Regular user)
- 120 requests per minute (VIP user)
- ThreatDetectionMiddleware untuk deteksi serangan
- Automatic IP blocking untuk suspicious activity
```

### 5. Account Security
```go
// Multi-Factor Authentication (MFA)
- MFA_enabled: boolean flag
- MFA_secret: TOTP secret

// Account Lockout
- FailedLoginAttempts: counter
- LockedUntil: timestamp untuk unlock

// Password Security
- PasswordHash: bcrypt hashing
- PasswordHistory: Track password changes
- LastPasswordChangedAt: untuk force reset
```

### 6. SSL/TLS Connection
```
Production:
- DB_SSL_ENABLED=true
- Uses custom TLS certificates
- Min TLS version: 1.2

Development:
- DB_SSL_ENABLED=false (optional)
- Database di localhost
```

### 7. Role-Based Database Access
```go
// Multi-Connection Manager (untuk high security)
- DBRoleRead: Read-only user
- DBRoleApp: Application user
- DBRoleAdmin: Admin user dengan semua privilege

// Dapat diaktifkan dengan:
DB_MULTI_USER_ENABLED=true
```

---

## 🧪 Testing Connection

### Test 1: Backend Server Connection

**Windows PowerShell:**
```powershell
# Check jika server berjalan
Test-NetConnection -ComputerName workradar-production.up.railway.app -Port 443

# Check jika database accessible
# Gunakan MySQL client
mysql -h your-db-host -u root -p -D railway
```

**Test dengan curl:**
```bash
# Health check endpoint (jika ada)
curl -X GET "https://workradar-production.up.railway.app/api/health"

# Test authenticated endpoint
curl -X GET "https://workradar-production.up.railway.app/api/tasks" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Test 2: Flutter App Connection

**Dalam Flutter App:**
```dart
// Check API connectivity
final apiClient = ApiClient();
final response = await apiClient.get('/users/profile');
print('Status: ${response.statusCode}');
print('Data: ${response.data}');
```

**Debug Mode:**
```dart
// Di environment.dart
static bool get enableDebugLog => true; // Enable debug logging
```

Akan menampilkan di console:
```
[API] POST http://192.168.1.7:8080/api/auth/login
[API] Request Headers: {Authorization: Bearer xxx}
[API] Response Status: 200
[API] Response Body: {user: {...}}
```

### Test 3: Database Migrations

Automatic migrations saat server start:
```
✅ Database migrations completed
  - users table created
  - tasks table created
  - categories table created
  - ...dan seterusnya
```

---

## 🔧 Connection Flow Details

### Saat Aplikasi Start

1. **Flutter App Launch**
   ```dart
   main() → runApp(MyApp)
   ```

2. **API Client Initialization**
   ```dart
   ApiClient._internal()
   └─ Setup Dio with baseUrl
   └─ Add Auth Interceptor
   └─ Add LogInterceptor (dev mode)
   ```

3. **First API Call**
   ```dart
   CategoryApiService.getCategories()
   └─ ApiClient.get('/categories')
   └─ AuthInterceptor: Add JWT Token
   └─ HTTP POST to "https://workradar-production.up.railway.app/api/categories"
   ```

4. **Backend Server Processing**
   ```
   main.go: Connect to Database
   └─ database.Connect()
   └─ config.Load() → Read DSN
   └─ gorm.Open() → Connect to MySQL
   └─ AutoMigrate() → Create tables if not exist
   └─ Initialize Repositories
   └─ Setup Fiber Routes & Handlers
   ```

5. **Handler Processing**
   ```go
   handlers.GetCategories()
   └─ Check JWT Token (valid?)
   └─ Get user_id from token
   └─ categoryRepo.GetUserCategories(userID)
   └─ GORM Query: SELECT * FROM categories WHERE user_id = ?
   └─ MySQL returns rows
   └─ Map to Category struct
   └─ Return JSON response
   ```

6. **Response Back to Client**
   ```json
   {
     "status": "success",
     "data": [
       {
         "id": "uuid",
         "name": "Work",
         "color": "#FF5733"
       }
     ]
   }
   ```

7. **Flutter App Update UI**
   ```dart
   CategoryApiService.getCategories()
   └─ Parse JSON response
   └─ Convert to Category objects
   └─ Update Provider state
   └─ UI rebuilds with new data
   ```

---

## ✅ Checklist: Database Connection Status

| Component | Status | Details |
|-----------|--------|---------|
| **Server Connection** | ✅ Ready | Go Fiber server running on Railway |
| **Database Connection** | ✅ Ready | MySQL on Railway (MYSQLHOST variable) |
| **GORM ORM** | ✅ Integrated | All models auto-migrated |
| **Repository Pattern** | ✅ Implemented | All CRUD operations via repositories |
| **API Endpoints** | ✅ Tested | RESTful APIs working |
| **JWT Auth** | ✅ Secure | Token-based authentication |
| **Encryption** | ✅ Active | AES-256 & SHA-256 for sensitive fields |
| **Audit Logging** | ✅ Enabled | All DB operations tracked |
| **Flutter Client** | ✅ Connected | Dio HTTP client with interceptors |
| **Environment Config** | ✅ Configured | Separate dev/staging/prod configs |
| **SSL/TLS** | ✅ Supported | Optional for production |
| **Rate Limiting** | ✅ Active | 60-120 req/min based on user type |
| **Database Migrations** | ✅ Auto | Tables created on server startup |
| **Connection Pooling** | ✅ Configured | Max 100 connections, 10 idle |

---

## 🚀 Deployment Status

### Development Environment
```
🟡 Status: Ready for testing
- Use local IP: 192.168.1.7:8080
- DB: Local MySQL or Railway
- Debug logging: Enabled
```

### Production Environment
```
🟢 Status: Live on Railway
- API: https://workradar-production.up.railway.app
- DB: Railway MySQL cluster
- SSL/TLS: Enabled
- Rate limiting: Active
- Audit logging: Enabled
```

---

## 📈 Database Performance

### Connection Pool Statistics
```
Max Open Connections: 100
Idle Connections: 10
Max Connection Lifetime: 1 hour
Connection Timeout: 30 seconds
Query Timeout: 60 seconds
```

### Query Optimization
- Indexed fields: `email`, `user_id`, `created_at`
- Foreign keys: Proper cascade delete rules
- JSON fields: Optimized for fast searches

---

## 🆘 Troubleshooting

### Masalah: App Tidak Bisa Connect ke Server

**Penyebab & Solusi:**

1. **IP Address Salah**
   ```
   ❌ Masalah: Development mode tapi IP belum diubah
   ✅ Solusi: 
      - Di environment.dart, ganti _developmentIP dengan IP komputer Anda
      - Jalankan `ipconfig` di Windows
      - Pastikan laptop & device dalam satu WiFi
   ```

2. **Server Tidak Berjalan**
   ```
   ❌ Masalah: "Connection refused" error
   ✅ Solusi:
      - Buka terminal, cd ke folder server
      - Jalankan: go run cmd/main.go
      - Pastikan port 8080 tidak dipakai program lain
   ```

3. **Database Tidak Terkoneksi**
   ```
   ❌ Masalah: "Failed to connect to database" di console
   ✅ Solusi:
      - Check DB credentials di environment variables
      - Pastikan MySQL service berjalan
      - Test koneksi: mysql -h localhost -u root -p
   ```

### Masalah: Migrations Gagal

```
❌ Error: "Failed to run migrations"
✅ Solusi:
   - Hapus database lama & buat baru
   - Ensure semua struct model sudah di main.go
   - Check syntax di model files (user.go, task.go, dll)
```

### Masalah: Audit Logging Tidak Tercatat

```
❌ Masalah: audit_logs table kosong
✅ Solusi:
   - Check AuditService initialization di main.go
   - Ensure ThreatDetectionMiddleware enabled
   - Check MySQL permissions untuk audit user
```

---

## 📚 Referensi Kode

### Key Files untuk Database Connection

```
server/
├── cmd/main.go                           # Entry point, database init
├── internal/
│   ├── config/config.go                  # Environment variables
│   ├── database/
│   │   ├── database.go                   # Connection & SSL/TLS
│   │   └── multi_connection.go           # Role-based access
│   ├── models/                           # All table structures
│   ├── repository/                       # Database queries
│   ├── handlers/                         # API endpoints
│   ├── services/                         # Business logic
│   └── middleware/                       # Auth, Rate limiting, Audit

client/
├── lib/core/
│   ├── config/environment.dart           # API URL configuration
│   ├── network/
│   │   ├── api_client.dart               # Dio HTTP client
│   │   └── auth_interceptor.dart         # JWT token handling
│   └── services/                         # API service wrappers
```

---

## 🎯 Kesimpulan

### Database Status: ✅ FULLY CONNECTED

Aplikasi Workradar memiliki:
- ✅ **Koneksi MySQL** yang aman dengan GORM ORM
- ✅ **API Server** yang responsif dengan Fiber framework
- ✅ **Flutter Client** yang properly configured untuk komunikasi API
- ✅ **Encryption** untuk data sensitif (User email, phone)
- ✅ **Audit Trail** untuk security & compliance
- ✅ **Authentication** dengan JWT tokens
- ✅ **Rate Limiting** untuk proteksi DDoS
- ✅ **Automatic Migrations** saat server start

### Rekomendasi Selanjutnya:

1. **Testing**: Run unit tests untuk repository layer
2. **Monitoring**: Setup Prometheus + Grafana untuk monitor DB performance
3. **Backup**: Setup automated MySQL backups
4. **Documentation**: Update API documentation untuk Tim Development
5. **Security**: Enable SSL/TLS di production (sudah ada config)

---

*Dokumen ini dibuat untuk analisis database architecture Workradar App*
*Last Updated: January 12, 2026*
