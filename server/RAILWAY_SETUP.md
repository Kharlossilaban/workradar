# Railway Database Setup Guide for Workradar
# MySQL Database Hosting Configuration

## 📋 Overview

Railway adalah platform cloud modern yang sangat cocok untuk hosting database dan aplikasi.

### Kenapa Railway?
- ✅ **Easy Setup** - Deploy database dalam hitungan menit
- ✅ **Generous Free Tier** - $5 credit/bulan (cukup untuk development)
- ✅ **Auto SSL** - Koneksi database terenkripsi
- ✅ **Built-in Monitoring** - Metrics & logs langsung tersedia
- ✅ **Easy Scaling** - Upgrade resources dengan mudah
- ✅ **GitHub Integration** - Auto deploy dari repository

## 💰 Pricing

| Plan | Price | Resources |
|------|-------|-----------|
| **Hobby** | $5/month | 512MB RAM, 1GB disk, $5 usage credit |
| **Pro** | $20/month | Unlimited projects, team features |

> 💡 **Tip**: $5/month sudah cukup untuk database Workradar dengan traffic moderate

## 🚀 Setup Steps

### 1. Buat Akun Railway

1. Kunjungi https://railway.app/
2. Click **Login** → Sign up dengan GitHub (recommended)
3. Verify email jika diperlukan

### 2. Create New Project

1. Di Dashboard, click **+ New Project**
2. Pilih **Provision MySQL**
3. Railway akan otomatis create MySQL instance

### 3. Get Connection Details

Setelah MySQL provisioned:

1. Click pada MySQL service
2. Go to tab **Variables**
3. Anda akan melihat environment variables:

```bash
MYSQL_URL=mysql://root:password@host:port/railway
MYSQLHOST=containers-us-west-xxx.railway.app
MYSQLPORT=6547
MYSQLUSER=root
MYSQLPASSWORD=xxxxxxxxxxxx
MYSQLDATABASE=railway
```

4. Atau go to tab **Connect** untuk copy connection string

### 4. Configure Workradar Backend

Edit file `.env.production`:

```bash
# ========================================
# DATABASE CONFIGURATION - RAILWAY
# ========================================
DB_HOST=containers-us-west-xxx.railway.app  # dari MYSQLHOST
DB_PORT=6547                                  # dari MYSQLPORT (biasanya bukan 3306!)
DB_USER=root                                  # dari MYSQLUSER
DB_PASSWORD=your_railway_password             # dari MYSQLPASSWORD
DB_NAME=railway                               # dari MYSQLDATABASE

# Railway sudah support SSL by default
DB_SSL_ENABLED=true
```

> ⚠️ **PENTING**: Railway menggunakan port BERBEDA dari default 3306! Pastikan copy port yang benar.

### 5. Test Connection

#### Via Terminal (PowerShell):

```powershell
# Test dengan mysql client
mysql -h containers-us-west-xxx.railway.app -P 6547 -u root -p railway
```

#### Via Go Application:

```powershell
cd c:\myradar\server
go run cmd/main.go
# Check logs untuk "✅ Database connected successfully"
```

### 6. Run Database Migrations

Railway database masih kosong. Jalankan migrations:

#### Option A: Via Railway CLI

```powershell
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link project
railway link

# Run migrations via railway shell
railway run go run cmd/main.go
```

#### Option B: Via Go Application (Recommended)

Workradar backend sudah ada AutoMigrate, jadi cukup:

```powershell
# Set environment variables
$env:DB_HOST="containers-us-west-xxx.railway.app"
$env:DB_PORT="6547"
$env:DB_USER="root"
$env:DB_PASSWORD="your_password"
$env:DB_NAME="railway"

# Run server (akan auto migrate)
cd c:\myradar\server
go run cmd/main.go
```

#### Option C: Via phpMyAdmin/TablePlus

1. Download TablePlus (free) atau DBeaver
2. Connect dengan Railway credentials
3. Import SQL files manually

### 7. Seed Initial Data

Setelah tables created, seed holiday data:

```sql
-- Indonesian Holidays 2026-2027
-- Run via database client atau Railway Query tab

INSERT INTO holidays (name, date, description, created_at, updated_at) VALUES
('Tahun Baru 2026', '2026-01-01', 'Tahun Baru Masehi', NOW(), NOW()),
('Isra Miraj', '2026-02-17', 'Isra Miraj Nabi Muhammad SAW', NOW(), NOW()),
('Hari Raya Nyepi', '2026-03-19', 'Tahun Baru Saka', NOW(), NOW()),
('Wafat Isa Almasih', '2026-04-03', 'Jumat Agung', NOW(), NOW()),
('Hari Raya Idul Fitri', '2026-05-17', 'Hari Raya Idul Fitri 1447 H', NOW(), NOW()),
('Hari Raya Idul Fitri', '2026-05-18', 'Hari Raya Idul Fitri 1447 H', NOW(), NOW()),
('Hari Buruh', '2026-05-01', 'Hari Buruh Internasional', NOW(), NOW()),
('Kenaikan Isa Almasih', '2026-05-14', 'Kenaikan Isa Almasih', NOW(), NOW()),
('Hari Lahir Pancasila', '2026-06-01', 'Hari Lahir Pancasila', NOW(), NOW()),
('Hari Raya Idul Adha', '2026-07-24', 'Hari Raya Idul Adha 1447 H', NOW(), NOW()),
('Tahun Baru Islam', '2026-08-14', 'Tahun Baru Islam 1448 H', NOW(), NOW()),
('Hari Kemerdekaan', '2026-08-17', 'Hari Kemerdekaan RI', NOW(), NOW()),
('Maulid Nabi Muhammad', '2026-10-23', 'Maulid Nabi Muhammad SAW', NOW(), NOW()),
('Hari Natal', '2026-12-25', 'Hari Natal', NOW(), NOW());
```

## 🔧 Railway Features

### Built-in Database Viewer

1. Click MySQL service
2. Go to **Data** tab
3. Browse tables dan run queries langsung

### Logs & Monitoring

1. Go to **Observability** tab
2. View real-time logs
3. Monitor CPU, Memory, Network usage

### Backups

Railway Pro plan includes:
- Automatic daily backups
- Point-in-time recovery
- Manual backup snapshots

Untuk Hobby plan, setup manual backup:

```powershell
# Backup via mysqldump
mysqldump -h $MYSQLHOST -P $MYSQLPORT -u root -p railway > backup_$(Get-Date -Format "yyyyMMdd").sql
```

### Environment Variables

Railway otomatis inject variables ke aplikasi. Jika deploy backend ke Railway juga:

1. Add Workradar backend service
2. Railway akan auto-detect Go app
3. Variables seperti `MYSQL_URL` otomatis available

## 🚀 Deploy Backend ke Railway (Optional)

Jika ingin deploy backend Workradar ke Railway juga:

### 1. Connect GitHub Repo

1. New Project → **Deploy from GitHub repo**
2. Select workradar repository
3. Configure root directory: `server/`

### 2. Add Environment Variables

Di Railway dashboard → Variables:

```bash
PORT=8080
ENV=production
JWT_SECRET=your_jwt_secret_here
ALLOWED_ORIGINS=https://your-frontend-domain.com

# Database (auto-injected jika MySQL service di project yang sama)
# Atau manual copy dari MySQL service

# External APIs
GEMINI_API_KEY=your_key
WEATHER_API_KEY=your_key
MIDTRANS_SERVER_KEY=your_key
MIDTRANS_CLIENT_KEY=your_key
MIDTRANS_IS_PRODUCTION=true

# Mailgun SMTP
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=postmaster@mg.workradar.com
SMTP_PASSWORD=your_mailgun_password
SMTP_FROM_NAME=Workradar
SMTP_FROM_EMAIL=noreply@mg.workradar.com
```

### 3. Configure Build

Railway akan auto-detect `go.mod`. Atau add `railway.json`:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "./server",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 30
  }
}
```

### 4. Setup Domain

1. Go to **Settings** → **Networking**
2. Generate Railway domain atau add custom domain
3. Railway auto-provisions SSL certificate

## 🔒 Security Best Practices

### 1. Use Private Networking

Jika backend juga di Railway:
- Enable **Private Networking**
- Database hanya accessible dari internal network
- Lebih secure, lower latency

### 2. Restrict Public Access

Jika harus public access:
- Use strong password
- Consider IP whitelist
- Enable SSL (default on Railway)

### 3. Regular Backups

```powershell
# Schedule backup script
# Save as backup_railway.ps1

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = "workradar_backup_$timestamp.sql"

mysqldump -h $env:DB_HOST -P $env:DB_PORT -u $env:DB_USER -p$env:DB_PASSWORD $env:DB_NAME > $backupFile

Write-Host "Backup created: $backupFile"
```

## 📊 Monitoring & Metrics

Railway provides:
- **CPU Usage** - Monitor processing load
- **Memory Usage** - Track RAM consumption
- **Network I/O** - Monitor data transfer
- **Disk Usage** - Storage monitoring

Access via: Dashboard → Service → **Metrics** tab

## 🆚 Railway vs Alternatives

| Feature | Railway | PlanetScale | Aiven |
|---------|---------|-------------|-------|
| **Setup** | Very Easy | Easy | Medium |
| **Free Tier** | $5 credit | 5GB storage | No |
| **SSL** | ✅ Auto | ✅ Auto | ✅ Auto |
| **Backups** | Pro only | ✅ Built-in | ✅ Built-in |
| **Branching** | No | ✅ Yes | No |
| **Price** | $5/mo | Free-$29/mo | $19/mo |

## 📝 Production Checklist

- [ ] Railway account created
- [ ] MySQL service provisioned
- [ ] Connection tested from local
- [ ] Environment variables configured
- [ ] Migrations run successfully
- [ ] Holiday data seeded
- [ ] Backup strategy planned
- [ ] SSL connection verified
- [ ] Monitoring dashboard checked

## 🆘 Troubleshooting

### Connection Refused

1. Check port number (Railway uses non-standard ports!)
2. Verify password correct
3. Check if service is running (green status)

### Timeout Errors

1. Railway sleeping? (Hobby plan sleeps after inactivity)
2. Check network/firewall
3. Increase connection timeout in Go config

### Migration Errors

1. Check database user has CREATE privileges
2. Verify database name correct
3. Check for existing tables conflicts

## 🔗 Useful Links

- [Railway Documentation](https://docs.railway.app/)
- [Railway CLI](https://docs.railway.app/develop/cli)
- [MySQL on Railway](https://docs.railway.app/databases/mysql)
- [Railway Discord](https://discord.gg/railway) - Community support
- [Railway Status](https://status.railway.app/)

---

## Quick Reference Card

```bash
# Connection Details (contoh)
Host:     containers-us-west-xxx.railway.app
Port:     6547  # BUKAN 3306!
User:     root
Password: [dari Railway dashboard]
Database: railway

# Connection String
mysql://root:password@host:port/railway

# Test Connection
mysql -h HOST -P PORT -u root -p DATABASE
```
