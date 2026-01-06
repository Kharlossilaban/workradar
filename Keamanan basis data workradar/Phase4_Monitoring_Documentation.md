# Workradar - Database Security Phase 4: Monitoring & Maintenance

## Overview

Phase 4 menambahkan sistem monitoring dan maintenance otomatis untuk keamanan basis data. Fase ini mencakup:

1. **Security Audit Service** - Audit keamanan otomatis dengan 10 jenis pemeriksaan
2. **Vulnerability Scanner Service** - Pemindaian kerentanan termasuk deteksi SQL injection dan XSS
3. **Security Scheduler Service** - Penjadwalan tugas keamanan otomatis
4. **Monitoring Handler** - API endpoints untuk dashboard dan health checks
5. **Health Check Endpoints** - Kubernetes-compatible health probes

## Components

### 1. Security Audit Service

File: `server/internal/services/security_audit_service.go`

#### Jenis Pemeriksaan (10 Check Types):

| Check Type | Description | Severity |
|------------|-------------|----------|
| PASSWORD_POLICY | Memastikan kebijakan password diterapkan | HIGH |
| MFA_ADOPTION | Tingkat adopsi Multi-Factor Authentication | MEDIUM |
| FAILED_LOGINS | Deteksi percobaan login gagal berlebihan | HIGH |
| INACTIVE_ACCOUNTS | Akun tidak aktif >6 bulan | LOW |
| PRIVILEGE_ESCALATION | Deteksi perubahan privilege mencurigakan | CRITICAL |
| DATA_ACCESS | Pola akses data yang tidak biasa | MEDIUM |
| SESSION_SECURITY | Keamanan sesi pengguna | MEDIUM |
| ENCRYPTION | Status enkripsi data sensitif | CRITICAL |
| DATABASE_HEALTH | Kesehatan koneksi database | MEDIUM |
| API_USAGE | Pola penggunaan API | LOW |

#### API Usage:

```go
// Get singleton instance
auditService := services.GetSecurityAuditService()

// Run full audit
report, err := auditService.RunFullAudit()

// Get last report
lastReport := auditService.GetLastReport()

// Get audit history
history := auditService.GetAuditHistory()
```

### 2. Vulnerability Scanner Service

File: `server/internal/services/vulnerability_scanner_service.go`

#### Deteksi Kerentanan:

- **SQL Injection**: 10 pola regex untuk deteksi
- **XSS (Cross-Site Scripting)**: 9 pola regex untuk deteksi
- **Brute Force**: Monitoring percobaan login
- **Insecure Configuration**: Pemeriksaan konfigurasi
- **Weak Cryptography**: Validasi enkripsi

#### Scan Components:

| Component | Description |
|-----------|-------------|
| Authentication | Pemeriksaan keamanan autentikasi |
| Encryption | Status dan kekuatan enkripsi |
| Security Events | Analisis event keamanan |
| Database | Kesehatan dan keamanan database |
| API Endpoints | Keamanan API |
| Configuration | Konfigurasi sistem |
| Network | Keamanan jaringan |

#### API Usage:

```go
// Get singleton instance
scanner := services.GetVulnerabilityScannerService()

// Quick scan
result, err := scanner.RunQuickScan()

// Full scan
result, err := scanner.RunFullScan()

// Detect SQL injection
detected, patterns := scanner.DetectSQLInjection(input)

// Detect XSS
detected, patterns := scanner.DetectXSS(input)

// Sanitize input
sanitized := services.SanitizeInput(input)
```

### 3. Security Scheduler Service

File: `server/internal/services/security_scheduler_service.go`

#### Scheduled Tasks:

| Task | Default Interval | Description |
|------|-----------------|-------------|
| SECURITY_AUDIT | 24 hours | Full security audit |
| VULNERABILITY_SCAN | 12 hours | Vulnerability scanning |
| SESSION_CLEANUP | 1 hour | Clean expired sessions |
| TOKEN_CLEANUP | 6 hours | Clean expired tokens |
| AUDIT_LOG_CLEANUP | 7 days | Archive old audit logs |
| BLOCKED_IP_CLEANUP | 6 hours | Remove expired IP blocks |
| PASSWORD_EXPIRY | 24 hours | Check expired passwords |
| INACTIVE_ACCOUNTS | 7 days | Check inactive accounts |
| DATABASE_OPTIMIZE | 7 days | Optimize database tables |
| SECURITY_REPORT | 7 days | Generate weekly report |

#### Environment Variables:

```env
# Scheduler intervals (optional)
SECURITY_AUDIT_INTERVAL=24h
VULNERABILITY_SCAN_INTERVAL=12h

# Data retention
AUDIT_LOG_RETENTION_DAYS=90
PASSWORD_MAX_AGE_DAYS=90
INACTIVE_ACCOUNT_MONTHS=6
DATA_RETENTION_DAYS=30
```

#### API Usage:

```go
// Get singleton instance
scheduler := services.GetSecuritySchedulerService()

// Start scheduler
scheduler.Start()

// Stop scheduler
scheduler.Stop()

// Get status
status := scheduler.GetSchedulerStatus()

// Run task immediately
scheduler.RunTaskNow(services.SecurityTaskAudit)

// Enable/disable tasks
scheduler.EnableTask(services.SecurityTaskAudit)
scheduler.DisableTask(services.SecurityTaskAudit)
```

### 4. Monitoring Handler

File: `server/internal/handlers/monitoring_handler.go`

#### API Endpoints:

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/health` | Basic health check | No |
| GET | `/api/health/detailed` | Detailed health check | Yes |
| GET | `/api/ready` | Kubernetes readiness probe | No |
| GET | `/api/live` | Kubernetes liveness probe | No |
| GET | `/api/metrics` | System metrics | Yes |
| POST | `/api/monitoring/audit/run` | Run security audit | Yes |
| GET | `/api/monitoring/audit/report` | Get last audit report | Yes |
| GET | `/api/monitoring/audit/history` | Get audit history | Yes |
| POST | `/api/monitoring/vulnerability/scan` | Run vulnerability scan | Yes |
| GET | `/api/monitoring/vulnerability/report` | Get last scan result | Yes |
| POST | `/api/monitoring/vulnerability/detect` | Detect vulnerabilities | Yes |
| GET | `/api/monitoring/dashboard` | Security dashboard | Yes |
| GET | `/api/monitoring/scheduler/status` | Scheduler status | Yes |
| POST | `/api/monitoring/scheduler/task/:type/run` | Run task | Yes |
| POST | `/api/monitoring/scheduler/task/:type/enable` | Enable task | Yes |
| POST | `/api/monitoring/scheduler/task/:type/disable` | Disable task | Yes |

## API Response Examples

### Health Check Response

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "database": {
    "status": "connected",
    "open_connections": 5,
    "in_use": 2,
    "idle": 3
  }
}
```

### Security Audit Report

```json
{
  "success": true,
  "data": {
    "id": "audit_1705312200",
    "started_at": "2024-01-15T10:30:00Z",
    "completed_at": "2024-01-15T10:30:05Z",
    "duration": "5.123s",
    "overall_score": 85,
    "overall_status": "HEALTHY",
    "total_checks": 10,
    "passed_checks": 8,
    "failed_checks": 2,
    "findings": [
      {
        "id": "pwd_1705312200",
        "check_type": "PASSWORD_POLICY",
        "severity": "MEDIUM",
        "title": "Users with Weak Passwords",
        "description": "3 users have passwords that don't meet policy requirements",
        "remediation": "Enforce password change for affected users",
        "count": 3
      }
    ],
    "summary": {
      "critical_count": 0,
      "high_count": 0,
      "medium_count": 1,
      "low_count": 1,
      "info_count": 0
    }
  }
}
```

### Vulnerability Scan Result

```json
{
  "success": true,
  "data": {
    "id": "scan_1705312200",
    "scan_type": "QUICK",
    "started_at": "2024-01-15T10:30:00Z",
    "completed_at": "2024-01-15T10:30:02Z",
    "risk_score": 25.5,
    "risk_level": "LOW",
    "vulnerabilities": [
      {
        "id": "AUTH_1705312200",
        "type": "BRUTE_FORCE",
        "severity": "MEDIUM",
        "title": "Multiple Failed Login Attempts",
        "description": "15 failed login attempts detected in the last hour",
        "remediation": "Review blocked IPs and strengthen rate limiting",
        "cvss": 5.3
      }
    ],
    "summary": "Scan completed with 1 vulnerability found",
    "recommended_actions": [
      "Review and verify blocked IP addresses",
      "Consider implementing additional authentication measures"
    ]
  }
}
```

### Security Dashboard

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-01-15T10:30:00Z",
    "overall_security_score": 82,
    "overall_status": "HEALTHY",
    "audit": {
      "last_run": "2024-01-15T06:00:00Z",
      "score": 85,
      "status": "HEALTHY",
      "findings": 2,
      "is_running": false
    },
    "vulnerability": {
      "last_run": "2024-01-15T10:00:00Z",
      "risk_score": 25.5,
      "risk_level": "LOW",
      "vulnerabilities": 1,
      "is_scanning": false
    },
    "database": {
      "pool_usage_percent": 40,
      "open_connections": 4,
      "in_use": 2,
      "wait_count": 0
    },
    "encryption": {
      "enabled": true
    }
  }
}
```

## Integration in main.go

```go
// Initialize security scheduler service
securitySchedulerService := services.NewSecuritySchedulerService(database.DB)
securitySchedulerService.Start()
defer securitySchedulerService.Stop()

// Initialize monitoring handler
monitoringHandler := handlers.NewMonitoringHandler()

// Health check routes
api.Get("/health", monitoringHandler.HealthCheck)
api.Get("/health/detailed", middleware.AuthMiddleware(), monitoringHandler.DetailedHealthCheck)
api.Get("/ready", monitoringHandler.ReadinessCheck)
api.Get("/live", monitoringHandler.LivenessCheck)
api.Get("/metrics", middleware.AuthMiddleware(), monitoringHandler.GetMetrics)

// Monitoring routes (protected)
monitoring := api.Group("/monitoring", middleware.AuthMiddleware())
monitoring.Post("/audit/run", monitoringHandler.RunSecurityAudit)
monitoring.Get("/audit/report", monitoringHandler.GetLastAuditReport)
monitoring.Get("/audit/history", monitoringHandler.GetAuditHistory)
monitoring.Post("/vulnerability/scan", monitoringHandler.RunVulnerabilityScan)
monitoring.Get("/vulnerability/report", monitoringHandler.GetLastVulnerabilityReport)
monitoring.Post("/vulnerability/detect", monitoringHandler.DetectVulnerabilities)
monitoring.Get("/dashboard", monitoringHandler.GetSecurityDashboard)
monitoring.Get("/scheduler/status", monitoringHandler.GetSchedulerStatus)
monitoring.Post("/scheduler/task/:type/run", monitoringHandler.RunScheduledTask)
monitoring.Post("/scheduler/task/:type/enable", monitoringHandler.EnableScheduledTask)
monitoring.Post("/scheduler/task/:type/disable", monitoringHandler.DisableScheduledTask)
```

## Database Additions

Phase 4 menggunakan tabel yang sudah ada dari phase sebelumnya:

- `audit_logs` - Log aktivitas sistem
- `security_events` - Event keamanan
- `login_attempts` - Percobaan login
- `blocked_ips` - IP yang diblokir
- `password_histories` - Riwayat password

## Security Considerations

1. **Access Control**: Semua endpoint monitoring memerlukan autentikasi
2. **Rate Limiting**: Mencegah abuse pada endpoint scanning
3. **Audit Logging**: Semua operasi monitoring dicatat
4. **Data Retention**: Log dan event dihapus sesuai kebijakan retensi
5. **Sensitive Data**: Hasil audit tidak mengekspos data sensitif

## Best Practices

1. **Regular Audits**: Jalankan audit keamanan minimal setiap 24 jam
2. **Monitor Alerts**: Pantau event dengan severity HIGH/CRITICAL
3. **Review Reports**: Review laporan mingguan secara rutin
4. **Update Patterns**: Update pola deteksi SQL injection/XSS secara berkala
5. **Retention Policy**: Sesuaikan kebijakan retensi dengan compliance requirements

## Kubernetes Deployment

```yaml
apiVersion: v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: workradar
        livenessProbe:
          httpGet:
            path: /api/live
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

## Files Modified/Created

### New Files:
- `server/internal/services/security_audit_service.go`
- `server/internal/services/vulnerability_scanner_service.go`
- `server/internal/services/security_scheduler_service.go`
- `server/internal/handlers/monitoring_handler.go`

### Modified Files:
- `server/cmd/main.go` - Added monitoring routes and scheduler initialization
- `server/internal/services/audit_service.go` - Added singleton pattern
- `server/internal/database/database.go` - Added GetDBStatsStruct()

## Summary

Phase 4 menyelesaikan implementasi keamanan basis data dengan menambahkan:

✅ Automated security audits (10 check types)
✅ Vulnerability scanning (SQL injection, XSS detection)
✅ Scheduled security tasks (10 task types)
✅ Monitoring dashboard and metrics
✅ Kubernetes-compatible health probes
✅ Weekly security report generation
