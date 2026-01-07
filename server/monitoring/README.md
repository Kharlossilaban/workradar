# Workradar Monitoring Setup Guide
# Prometheus + Grafana untuk Production Monitoring

## 📋 Overview

Setup ini menggunakan:
- **Prometheus** - Metrics collection & storage
- **Grafana** - Visualization & dashboards
- **Alertmanager** - Alert routing (optional)
- **Node Exporter** - System metrics (optional)
- **MySQL Exporter** - Database metrics (optional)

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose installed
- Workradar API server running
- Valid JWT token untuk authenticated metrics

### 1. Setup Token File

Buat file untuk authentication ke `/api/metrics`:

```powershell
# Generate JWT token dari Workradar API (login sebagai admin)
# Simpan token ke file
echo "YOUR_JWT_TOKEN_HERE" > monitoring/workradar_token.txt
```

### 2. Start Monitoring Stack

```powershell
cd c:\myradar\server\monitoring

# Start basic stack (Prometheus + Grafana)
docker-compose -f docker-compose.monitoring.yml up -d

# Start with alerting
docker-compose -f docker-compose.monitoring.yml --profile alerting up -d

# Start with all exporters
docker-compose -f docker-compose.monitoring.yml --profile exporters up -d

# Start everything
docker-compose -f docker-compose.monitoring.yml --profile alerting --profile exporters up -d
```

### 3. Access Dashboards

- **Grafana**: http://localhost:3000
  - Username: `admin`
  - Password: `workradar_grafana_2024`
  
- **Prometheus**: http://localhost:9090

- **Alertmanager** (if enabled): http://localhost:9093

## 📊 Available Metrics

### Workradar API Metrics (dari /api/metrics)

| Metric | Description |
|--------|-------------|
| `up{job="workradar-api"}` | API server status (1=up, 0=down) |
| `http_requests_total` | Total HTTP requests |
| `http_request_duration_seconds` | Request latency histogram |
| `workradar_failed_logins_total` | Failed login attempts |
| `workradar_account_lockouts_total` | Account lockouts |
| `workradar_security_events_total` | Security events by type |
| `workradar_blocked_ips_current` | Currently blocked IPs |
| `workradar_db_open_connections` | Open DB connections |
| `workradar_db_in_use_connections` | In-use DB connections |
| `workradar_db_idle_connections` | Idle DB connections |
| `workradar_db_max_connections` | Max DB connections |
| `workradar_db_wait_count` | Connection wait count |

### Health Check Endpoints

| Endpoint | Description | Auth Required |
|----------|-------------|---------------|
| `/api/health` | Basic health check | No |
| `/api/health/detailed` | Detailed health with services | Yes |
| `/api/ready` | Kubernetes readiness probe | No |
| `/api/live` | Kubernetes liveness probe | No |
| `/api/metrics` | Prometheus metrics | Yes |

## 🔧 Configuration

### Update Prometheus Targets

Edit `prometheus.yml` untuk mengubah target:

```yaml
scrape_configs:
  - job_name: 'workradar-api'
    static_configs:
      - targets: ['your-api-host:8080']  # Ubah ke host production
```

### Update Grafana Password

Ubah password di `docker-compose.monitoring.yml`:

```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
```

### Configure Alertmanager

Edit `alertmanager.yml` untuk setup notification channels:

1. Update SMTP settings dengan credentials Mailgun Anda
2. Update email recipients
3. Optional: Add Slack/Discord webhooks

## 📈 Grafana Dashboards

Dashboard tersedia di folder `grafana/dashboards/`:

1. **Workradar - Main Dashboard** (`workradar-main.json`)
   - API Status
   - Request Rate & Latency
   - Security Metrics
   - Database Connections

### Import Custom Dashboard

1. Login ke Grafana
2. Go to Dashboards > Import
3. Upload JSON file atau paste dashboard JSON

## 🚨 Alert Rules

Alert rules di `alert_rules.yml`:

### Server Alerts
- `WorkradarAPIDown` - API server tidak bisa diakses
- `HighResponseTime` - Response time > 2s
- `HighErrorRate` - Error rate > 5%

### Security Alerts
- `HighFailedLogins` - > 50 failed logins/hour
- `SuspiciousActivity` - SQL injection attempts
- `HighAccountLockouts` - > 20 lockouts/hour

### Database Alerts
- `DatabaseConnectionPoolExhausted` - Pool > 80%
- `HighSlowQueries` - > 10 slow queries/second
- `MySQLDown` - Database tidak bisa diakses

### Resource Alerts
- `HighCPUUsage` - CPU > 80%
- `HighMemoryUsage` - Memory > 85%
- `LowDiskSpace` - Disk < 10%

## 🛠️ Troubleshooting

### Prometheus tidak bisa scrape metrics

1. Pastikan Workradar API running
2. Check token di `workradar_token.txt` valid
3. Verify endpoint accessible:
   ```powershell
   curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/metrics
   ```

### Grafana tidak bisa connect ke Prometheus

1. Check Prometheus running: `docker ps`
2. Verify network connectivity
3. Check datasource config di Grafana

### Alerts tidak terkirim

1. Verify Alertmanager running
2. Check SMTP credentials di `alertmanager.yml`
3. Test email config:
   ```bash
   docker exec -it workradar-alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
   ```

## 📝 Production Checklist

- [ ] Change default Grafana password
- [ ] Update SMTP credentials untuk Alertmanager
- [ ] Configure proper retention period di Prometheus
- [ ] Setup backup untuk Prometheus data
- [ ] Configure firewall (block 9090, 3000 from public)
- [ ] Setup reverse proxy dengan SSL untuk Grafana
- [ ] Add monitoring untuk semua production services
- [ ] Test alert notifications
- [ ] Create runbooks untuk setiap alert
- [ ] Setup on-call rotation

## 📚 Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
