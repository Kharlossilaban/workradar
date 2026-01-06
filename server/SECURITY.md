# 🔐 Workradar - Database Security Implementation Guide

## 📋 Security Checklist

### ✅ Layer 1: Database Credentials Security

- [x] Database password stored in `.env` file (not committed to Git)
- [x] `.env` added to `.gitignore`
- [x] Separate `.env.production.example` for production setup
- [ ] **TODO:** Generate strong JWT secret (min 64 chars) untuk production
- [ ] **TODO:** Create production database dengan strong password (min 16 chars)
- [ ] **TODO:** Setup database user dengan least privilege principle

**Action Items:**
```bash
# Generate strong JWT secret
openssl rand -hex 32

# Generate strong database password
openssl rand -base64 24
```

---

### ✅ Layer 2: SQL Injection Prevention

- [x] Using GORM ORM (parameterized queries)
- [x] Input validation middleware created
- [x] SQL injection detection middleware created
- [ ] **TODO:** Enable `SQLInjectionProtectionMiddleware()` di main.go

**GORM Protection (Already Active):**
```go
// ✅ Safe - Parameterized query
db.Where("email = ?", userEmail).First(&user)

// ❌ NEVER DO THIS - Vulnerable to SQL injection
db.Where("email = '" + userEmail + "'").First(&user)
```

---

### ✅ Layer 3: Data Encryption

- [x] Password hashing dengan bcrypt (already implemented)
- [x] AES-256-GCM encryption service created
- [ ] **TODO:** Encrypt sensitive fields di database:
  - `users.fcm_token` (optional - already not exposed in JSON)
  - Payment transaction details (if storing card info - NOT RECOMMENDED)
  - Personal holiday notes (optional)

**Usage Example:**
```go
encryptionService, _ := services.NewEncryptionService("your-32-byte-encryption-key-here")
encrypted, _ := encryptionService.Encrypt("sensitive data")
```

---

### ✅ Layer 4: Access Control & Audit Logging

- [x] JWT authentication middleware (already implemented)
- [x] VIP middleware for premium features (already implemented)
- [x] Audit log middleware created
- [x] Security headers middleware created
- [ ] **TODO:** Enable audit logging di main.go
- [ ] **TODO:** Setup log rotation (daily/weekly)

**Current Authentication Flow:**
```
Request → AuthMiddleware() → Verify JWT → Extract user_id → Allow/Deny
```

---

### ✅ Layer 5: Database Backup & Recovery

- [x] Automated backup script created (`scripts/backup_database.ps1`)
- [ ] **TODO:** Setup scheduled task untuk automatic backup (daily)
- [ ] **TODO:** Test restore procedure
- [ ] **TODO:** Setup offsite backup (cloud storage)

**Backup Strategy:**
- **Daily backups** dengan 30-day retention
- **Compressed** untuk save storage
- **Automated cleanup** old backups

**Run Backup:**
```powershell
# Manual backup
cd C:\myradar\server
.\scripts\backup_database.ps1

# Scheduled task (run as Administrator)
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
  -Argument "-File C:\myradar\server\scripts\backup_database.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
Register-ScheduledTask -TaskName "WorkradarDailyBackup" `
  -Action $action -Trigger $trigger -Description "Daily database backup"
```

---

## 🚨 Critical Security Warnings

### ⚠️ Before Production Deployment:

1. **CHANGE ALL DEFAULT SECRETS:**
   ```bash
   # Generate new JWT secret
   JWT_SECRET=$(openssl rand -hex 32)
   
   # Generate new encryption key (32 bytes)
   ENCRYPTION_KEY=$(openssl rand -base64 32 | head -c 32)
   ```

2. **Database User Privileges:**
   ```sql
   -- Create dedicated user dengan limited permissions
   CREATE USER 'workradar_app'@'localhost' IDENTIFIED BY 'strong_password_here';
   
   -- Grant only necessary permissions
   GRANT SELECT, INSERT, UPDATE, DELETE ON workradar.* TO 'workradar_app'@'localhost';
   
   -- DO NOT grant:
   -- DROP, CREATE, ALTER, INDEX (hanya untuk migrations)
   ```

3. **Enable HTTPS:**
   - Use nginx/Apache reverse proxy with Let's Encrypt SSL
   - Force HTTPS redirect
   - Enable HSTS headers

4. **Database Connection Security:**
   ```go
   // Enable SSL/TLS for database connections (production only)
   dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local&tls=true",
       user, password, host, port, dbname)
   ```

5. **Rate Limiting:**
   - Already implemented: `middleware.RateLimitMiddleware()`
   - Default: 100 requests per minute per IP
   - Consider stricter limits for production

---

## 🔍 Security Testing Checklist

### Before Going Live:

- [ ] Run SQL injection tests (use sqlmap or manual testing)
- [ ] Test authentication bypass attempts
- [ ] Verify JWT token expiry working correctly
- [ ] Test rate limiting effectiveness
- [ ] Verify CORS configuration (only allow production domains)
- [ ] Test backup and restore procedure
- [ ] Security audit of all API endpoints
- [ ] Check for exposed sensitive data in logs
- [ ] Verify all secrets are in .env (not hardcoded)
- [ ] Test database connection failure scenarios

---

## 📚 Security Best Practices

### 1. Password Policy
- Minimum 8 characters
- Require uppercase, lowercase, number
- Already implemented in auth validation

### 2. JWT Token Management
- Access token: 24 hours expiry ✅
- Refresh token: 7 days expiry ✅
- Token blacklist on logout ✅

### 3. Database Connection Pooling
```go
// Already configured in database.go
db.SetMaxIdleConns(10)
db.SetMaxOpenConns(100)
db.SetConnMaxLifetime(time.Hour)
```

### 4. Error Messages
- ✅ Never expose database errors to client
- ✅ Use generic error messages
- ✅ Log detailed errors server-side only

### 5. Input Validation
- ✅ Validate all user input
- ✅ Sanitize HTML/JavaScript
- ✅ Use GORM for safe queries

---

## 🛠️ Implementation Steps

### Step 1: Update main.go
```go
// Add security middlewares
app.Use(middleware.DatabaseSecurityMiddleware())
app.Use(middleware.AuditLogMiddleware())

// Optional: Enable SQL injection detection (may cause false positives)
// app.Use(middleware.SQLInjectionProtectionMiddleware())
```

### Step 2: Generate Production Secrets
```bash
# Run on your production server
openssl rand -hex 32 > jwt_secret.txt
openssl rand -base64 32 | head -c 32 > encryption_key.txt
```

### Step 3: Setup Database Backup
```bash
# Test manual backup first
.\scripts\backup_database.ps1

# Then setup scheduled task (see Layer 5 above)
```

### Step 4: Review .env.production
- Copy `.env.production.example` to `.env.production`
- Fill in all production credentials
- NEVER commit `.env.production` to Git

### Step 5: Enable HTTPS
```nginx
# Nginx reverse proxy configuration
server {
    listen 443 ssl http2;
    server_name api.workradar.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 📞 Support & Questions

Jika ada pertanyaan tentang security implementation:
1. Review dokumentasi ini
2. Check materi kuliah di `Keamanan basis data workradar/`
3. Consult dengan team security

**Remember:** Security adalah ongoing process, bukan one-time setup!
