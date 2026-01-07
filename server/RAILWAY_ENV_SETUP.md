# Railway Environment Variables Setup

## ⚠️ CRITICAL: Environment Variables yang Harus Diset di Railway

Railway otomatis menyediakan variabel MySQL, tapi aplikasi kita perlu variabel tambahan.

### 1. Database Variables (Auto-provided by Railway)
Railway sudah menyediakan:
- `MYSQLHOST=mysql.railway.internal`
- `MYSQLPORT=3306`
- `MYSQLUSER=root`
- `MYSQLPASSWORD=wGZAxycNOJUFEPBZfTWqEmkAdfdxgElt`
- `MYSQLDATABASE=railway`

✅ **Aplikasi sudah di-update untuk support variabel Railway!**

### 2. Required Environment Variables (HARUS DITAMBAHKAN)

Tambahkan variabel berikut di Railway Dashboard → Service → Variables:

#### Security & JWT (WAJIB)
```bash
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
ENV=production
PORT=8080
ALLOWED_ORIGINS=https://yourdomain.com
```

#### Firebase (untuk notifications)
```bash
FIREBASE_PROJECT_ID=workradar-firebase
FIREBASE_CREDENTIALS_FILE=workradar-firebase.json
```

#### Midtrans (untuk payment)
```bash
MIDTRANS_SERVER_KEY=your-server-key
MIDTRANS_CLIENT_KEY=your-client-key
MIDTRANS_IS_PRODUCTION=false
```

#### Google OAuth (opsional)
```bash
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URL=https://yourdomain.com/auth/google/callback
```

#### Gemini AI (opsional)
```bash
GEMINI_API_KEY=your-gemini-key
```

#### SMTP Email (opsional)
```bash
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
SMTP_FROM_NAME=Workradar
SMTP_FROM_EMAIL=noreply@workradar.app
```

#### Weather API (opsional)
```bash
WEATHER_API_KEY=your-weather-api-key
```

### 3. SSL/TLS Configuration (Opsional - untuk keamanan ekstra)
```bash
DB_SSL_ENABLED=false
```

Set ke `true` jika Railway MySQL support SSL dan tambahkan:
```bash
DB_SSL_CA=/path/to/ca.pem
DB_SSL_CERT=/path/to/client-cert.pem
DB_SSL_KEY=/path/to/client-key.pem
```

---

## 📋 Cara Setting di Railway

1. **Buka Railway Dashboard**: https://railway.app
2. **Pilih Project**: `feisty-heart`
3. **Pilih Service**: `workradar`
4. **Tab Variables**: Klik tab "Variables"
5. **Add Variables**: Klik "New Variable" dan tambahkan satu per satu

### Shortcut: Bulk Add Variables

Atau copy-paste ini di "Raw Editor":

```env
JWT_SECRET=your-super-secret-jwt-key-CHANGE-THIS
ENV=production
PORT=8080
ALLOWED_ORIGINS=*
FIREBASE_PROJECT_ID=workradar-firebase
FIREBASE_CREDENTIALS_FILE=workradar-firebase.json
MIDTRANS_SERVER_KEY=your-midtrans-server-key
MIDTRANS_CLIENT_KEY=your-midtrans-client-key
MIDTRANS_IS_PRODUCTION=false
```

---

## 🔍 Troubleshooting

### Error: "no such host mysql.railway.internal"
**Solusi**: Pastikan MySQL service sudah running di Railway dan service sudah terhubung via Private Network.

### Error: "DB_PASSWORD is empty"
**Solusi**: Railway otomatis set `MYSQLPASSWORD`, aplikasi sekarang sudah support variabel ini.

### Error: "failed to connect to database"
**Solusi**: 
1. Check MySQL service status
2. Verify `MYSQLHOST=mysql.railway.internal`
3. Restart service setelah MySQL ready

---

## ✅ Verification Steps

Setelah deploy, check logs untuk memastikan:

```
✅ Using environment variables (from .env or system)
✅ DB_PASSWORD loaded (length: 32 characters)
✅ Database connected successfully
```

Jika masih error, check:
1. MySQL service sudah running
2. Private network sudah configured
3. Environment variables sudah diset
4. Service sudah di-redeploy setelah update variables

---

## 🚀 Deploy ke Railway

```bash
# Push ke GitHub
git add .
git commit -m "Fix Railway MySQL connection and env variables"
git push

# Railway akan auto-deploy dari GitHub
```

Atau manual deploy:
```bash
railway up
```

---

## 📝 Notes

- Railway MySQL menggunakan internal DNS: `mysql.railway.internal:3306`
- Public URL: `turntable.proxy.rlwy.net:19284` (untuk testing dari luar)
- Volume: `mysql-volume` (untuk persistent data)
- **JANGAN** hardcode credentials di code
- **SELALU** gunakan environment variables

---

**Status**: ✅ Code sudah di-update untuk support Railway environment variables!
