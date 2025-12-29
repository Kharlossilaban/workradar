# 📘 Workradar Backend - Panduan Setup Lengkap

Panduan ini akan membantu Anda setup backend Workradar **step by step**.

---

## 📋 Prasyarat

Pastikan sudah terinstall:
- ✅ MySQL Server
- ✅ Go (Golang) - minimal versi 1.21
- ✅ Terminal/CMD

---

## 🗄️ STEP 1: Setup Database MySQL

### 1.1 Buka MySQL

**PILIHAN A - Menggunakan MySQL Command Line Client:**
1. Cari aplikasi **MySQL Command Line Client** di Windows Start Menu
2. Klik kanan → **Run as Administrator**
3. Masukkan password root MySQL Anda

**PILIHAN B - Menggunakan CMD:**
1. Buka **Command Prompt** (CMD) sebagai Administrator
2. Ketik perintah ini:
   ```bash
   mysql -u root -p
   ```
3. Masukkan password root MySQL Anda

### 1.2 Buat Database Workradar

**Di MySQL prompt (setelah login), ketik satu per satu:**

```sql
CREATE DATABASE workradar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
➡️ Tekan **Enter**

```sql
USE workradar;
```
➡️ Tekan **Enter**

Anda akan melihat: `Database changed`

### 1.3 Import Schema Database

**PENTING:** Buka **Terminal BARU** (jangan pakai MySQL prompt yang tadi!)

**Di Terminal Antigravity atau PowerShell BARU:**

```bash
cd c:\myradar\server
```
➡️ Tekan **Enter**

```bash
Get-Content internal\database\migrations\001_initial_schema.sql | mysql -u root -p workradar
```
➡️ Tekan **Enter**, lalu masukkan password MySQL

**ALTERNATIF jika command atas error:**
```bash
mysql -u root -p workradar < internal\database\migrations\001_initial_schema.sql
```

**⚠️ JIKA ADA ERROR "Unknown column" atau schema sudah pernah dibuat sebelumnya:**

```bash
mysql -u root -p workradar < internal\database\migrations\002_recreate_tables.sql
```
➡️ Script ini akan **DROP semua tables lama** dan buat ulang dengan schema yang benar.

### 1.4 Verifikasi Database

Kembali ke **MySQL prompt** tadi, ketik:

```sql
SHOW TABLES;
```

**Anda harus melihat 5 tables:**
```
+--------------------+
| Tables_in_workradar|
+--------------------+
| categories         |
| password_resets    |
| subscriptions      |
| tasks              |
| users              |
+--------------------+
```

✅ Database siap! Ketik `exit;` untuk keluar dari MySQL.

---

## ⚙️ STEP 2: Setup Environment Variables

### 2.1 Copy File .env

**Di Terminal Antigravity (atau PowerShell):**

```bash
cd c:\myradar\server
```

```bash
Copy-Item .env.example .env
```

### 2.2 Edit File .env

1. **Buka file** `c:\myradar\server\.env` dengan **Notepad** atau **VS Code**
2. **Cari baris** `DB_PASSWORD=` (sekitar baris 12)
3. **Ganti** dengan password MySQL Anda:
   ```env
   DB_PASSWORD=password_mysql_anda_disini
   ```
4. **Simpan file** (Ctrl+S)

**Contoh lengkap .env:**
```env
PORT=8080
ENV=development

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=rahasia123
DB_NAME=workradar

JWT_SECRET=workradar-super-secret-key-change-in-production
JWT_EXPIRY=24h
```

---

## 🔧 STEP 3: Install Dependencies Go

**Di Terminal Antigravity:**

```bash
cd c:\myradar\server
```

```bash
go mod tidy
```

➡️ Tunggu sampai selesai download packages (~30 detik)

Anda akan melihat:
```
go: downloading github.com/gofiber/fiber/v2 ...
go: downloading gorm.io/gorm ...
```

---

## 🚀 STEP 4: Jalankan Server

**Di Terminal Antigravity:**

```bash
go run cmd\main.go
```

**Jika BERHASIL, Anda akan melihat:**

```
2025/12/28 18:07:58 ✅ Database connected successfully
2025/12/28 18:07:58 🚀 Server starting on port 8080

 ┌───────────────────────────────────────────────────┐
 │                Workradar API v1.0                 │
 │                   Fiber v2.52.0                   │
 │               http://127.0.0.1:8080               │
 │       (bound on host 0.0.0.0 and port 8080)       │
 │                                                   │
 │ Handlers ............ 14  Processes ........... 1 │
 │ Prefork ....... Disabled  PID ............. 19744 │
 └───────────────────────────────────────────────────┘
```

✅ **Server berjalan di:** `http://localhost:8080`

**JANGAN TUTUP terminal ini!** Server akan terus berjalan di sini.

---

## ✅ STEP 5: Test API Endpoints

Buka **Terminal/CMD BARU** (jangan pakai yang server running!).

### 5.1 Test Health Check

**Di CMD laptop Anda yang BARU (bukan terminal server):**

```bash
curl http://localhost:8080/api/health
```

**Response yang benar:**
```json
{"status":"OK","message":"Workradar API is running"}
```

### 5.2 Test Register User

**Di CMD laptop yang SAMA (yang baru tadi):**

```bash
curl -X POST http://localhost:8080/api/auth/register -H "Content-Type: application/json" -d "{\"email\":\"test@example.com\",\"username\":\"Test User\",\"password\":\"password123\"}"
```

**Response yang benar (akan ada token):**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "...",
    "email": "test@example.com",
    "username": "Test User",
    ...
  },
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

✅ **BERHASIL!** Default categories (Kerja, Pribadi, Wishlist, Hari Ulang Tahun) otomatis dibuat!

### 5.3 Test Login

**Di CMD laptop yang SAMA:**

```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}"
```

**COPY token dari response** untuk digunakan di langkah berikutnya!

### 5.4 Test Get Profile (Protected Route)

**GANTI `YOUR_TOKEN_HERE` dengan token dari login:**

```bash
curl http://localhost:8080/api/profile -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
{"user_id":"..."}
```

---

## 🎯 Ringkasan Perintah

| Tujuan | Command | Dimana? |
|--------|---------|---------|
| Jalankan server | `go run cmd\main.go` | Terminal Antigravity |
| Stop server | `Ctrl+C` | Terminal yang running server |
| Test endpoint | `curl http://localhost:8080/api/health` | CMD laptop BARU |

---

## ❓ Troubleshooting

### Error: "Unknown column 'v_ip_expires_at'" atau Schema Mismatch
Database sudah pernah dibuat dengan schema lama. **Solusi:**

**Di Terminal Antigravity (PowerShell):**
```bash
Get-Content internal\database\migrations\002_recreate_tables.sql | mysql -u root -p workradar
```
➡️ Ini akan DROP dan RECREATE semua tables dengan schema yang benar

### Error: "Failed to connect to database"
- ✅ Pastikan MySQL sudah **running**
- ✅ Password di `.env` **BENAR**
- ✅ Database `workradar` sudah **dibuat**

### Error: "missing go.sum entry"
```bash
go mod tidy
```

### Error: "port 8080 already in use"
- Server sudah jalan! Cek di browser: `http://localhost:8080/api/health`
- Atau ganti port di `.env`: `PORT=8081`

### Tidak bisa curl
- Install curl: `winget install curl.curl`
- Atau gunakan **Postman** / browser

---

## 📝 Notes Penting

- **Server harus tetap running** saat testing!
- **Token expires** setelah 24 jam
- **Password reset code** expires setelah 15 menit
- Default **port: 8080** bisa diganti di `.env`

---

## 🚀 Next Steps

Backend **Step 1 (Auth)** sudah selesai!

Selanjutnya:
- **Step 2:** Tasks CRUD endpoints
- **Step 3:** Calendar & Profile
- **Step 4:** VIP features (weather, subscription)
- **Step 5:** Connect Flutter ke backend

---

Selamat! Backend Workradar sudah berjalan! 🎉
