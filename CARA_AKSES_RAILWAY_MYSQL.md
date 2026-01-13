# Cara Mengakses Railway MySQL Database

## 🎯 Kesimpulan

**Task SUDAH TERSIMPAN di database!** ✅

Aplikasi Anda menggunakan **Railway MySQL (production database di cloud)**, bukan local phpMyAdmin. Itulah mengapa:
- ✅ Task tersimpan dan muncul kembali setelah logout/login
- ❌ Task TIDAK terlihat di local phpMyAdmin (karena database berbeda)

---

## 🔍 Cara Melihat Data di Railway MySQL

### **Metode 1: Via Railway Dashboard (Paling Mudah)**

1. **Login ke Railway:**
   - Buka: https://railway.app
   - Login dengan akun yang digunakan untuk deploy

2. **Buka Project:**
   - Pilih project: `workradar-production` (atau nama project Anda)

3. **Akses MySQL Service:**
   - Klik pada service: `MySQL`
   - Pilih tab: **"Data"** atau **"Query"**

4. **Run SQL Query:**
   ```sql
   -- Lihat semua tasks
   SELECT * FROM tasks ORDER BY created_at DESC LIMIT 20;
   
   -- Lihat tasks dengan category
   SELECT 
     t.id,
     t.user_id,
     t.title,
     t.category_id,
     c.name as category_name,
     t.is_completed,
     t.deadline,
     t.created_at
   FROM tasks t
   LEFT JOIN categories c ON t.category_id = c.id
   ORDER BY t.created_at DESC;
   
   -- Count total tasks
   SELECT COUNT(*) as total_tasks FROM tasks;
   
   -- Lihat semua users
   SELECT id, email, full_name, created_at FROM users;
   
   -- Lihat semua categories
   SELECT * FROM categories;
   ```

---

### **Metode 2: Via MySQL Client (MySQL Workbench/TablePlus/DBeaver)**

1. **Get Database Credentials dari Railway:**
   - Login ke Railway Dashboard
   - Pilih project → MySQL service
   - Klik tab: **"Variables"** atau **"Connect"**
   - Copy credentials:
     - `MYSQLHOST` (contoh: monorail.proxy.rlwy.net)
     - `MYSQLPORT` (contoh: 12345)
     - `MYSQLUSER` (contoh: root)
     - `MYSQLPASSWORD` (password)
     - `MYSQLDATABASE` (contoh: railway)

2. **Connect menggunakan MySQL Workbench:**
   - Download: https://dev.mysql.com/downloads/workbench/
   - New Connection
   - Hostname: `MYSQLHOST`
   - Port: `MYSQLPORT`
   - Username: `MYSQLUSER`
   - Password: `MYSQLPASSWORD`
   - Default Schema: `MYSQLDATABASE`
   - Test Connection → OK → Connect

3. **Connect menggunakan TablePlus:**
   - Download: https://tableplus.com/
   - Create new connection (MySQL)
   - Fill in the credentials
   - Test → Connect

4. **Connect menggunakan CLI:**
   ```bash
   mysql -h <MYSQLHOST> -P <MYSQLPORT> -u <MYSQLUSER> -p<MYSQLPASSWORD> <MYSQLDATABASE>
   ```

---

### **Metode 3: Via Railway CLI (Advanced)**

1. **Install Railway CLI:**
   ```bash
   # Windows (via npm)
   npm install -g @railway/cli
   
   # Or download from: https://railway.app/cli
   ```

2. **Login dan Connect:**
   ```bash
   railway login
   railway link  # Link to your project
   railway run mysql -h <host> -P <port> -u <user> -p
   ```

---

## 📊 Query yang Berguna

### **Verify Task Tersimpan:**
```sql
-- Cek total tasks per user
SELECT 
  u.email,
  u.full_name,
  COUNT(t.id) as total_tasks
FROM users u
LEFT JOIN tasks t ON u.id = t.user_id
GROUP BY u.id;

-- Cek tasks dengan semua detail
SELECT 
  t.id,
  t.title,
  t.description,
  t.is_completed,
  t.deadline,
  t.reminder_minutes,
  t.repeat_type,
  c.name as category,
  c.color as category_color,
  u.email as user_email,
  t.created_at,
  t.updated_at
FROM tasks t
LEFT JOIN categories c ON t.category_id = c.id
LEFT JOIN users u ON t.user_id = u.id
ORDER BY t.created_at DESC;

-- Cek integrity: Tasks tanpa category (seharusnya 0)
SELECT COUNT(*) as tasks_without_category 
FROM tasks 
WHERE category_id IS NULL;

-- Cek integrity: Tasks dengan invalid category_id (seharusnya 0)
SELECT COUNT(*) as tasks_with_invalid_category
FROM tasks t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.category_id IS NOT NULL AND c.id IS NULL;
```

### **Cek User dan Login:**
```sql
-- Lihat user terakhir yang register
SELECT id, email, full_name, created_at 
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

-- Cek user dengan email tertentu
SELECT * FROM users WHERE email = 'your-email@example.com';
```

### **Cek Categories:**
```sql
-- Lihat semua categories
SELECT 
  c.id,
  c.user_id,
  c.name,
  c.color,
  c.is_default,
  COUNT(t.id) as total_tasks
FROM categories c
LEFT JOIN tasks t ON c.id = t.category_id
GROUP BY c.id
ORDER BY c.created_at DESC;
```

---

## 🎓 Penjelasan Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│              Your Computer (Local)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Flutter App (Emulator)                                     │
│  └─ Environment: production                                 │
│                                                             │
│  Local MySQL (phpMyAdmin) ❌                                │
│  └─ Data TIDAK ada di sini                                  │
│     (Karena app tidak connect ke sini)                      │
│                                                             │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ HTTPS Request
                        │ https://workradar-production.up.railway.app/api
                        │
                        ↓
┌─────────────────────────────────────────────────────────────┐
│              Railway Cloud (Production)                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Go Backend API Server ✅                                   │
│  └─ Running 24/7                                            │
│                                                             │
│  MySQL Database ✅                                          │
│  └─ Data TERSIMPAN DI SINI!                                 │
│     ├─ users table                                          │
│     ├─ tasks table ← Task Anda ada di sini!                 │
│     ├─ categories table                                     │
│     └─ ... (other tables)                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Kesimpulan

**Tidak Ada Masalah!** Aplikasi Anda bekerja dengan benar:

1. ✅ Task **TERSIMPAN** di Railway MySQL (cloud database)
2. ✅ Task **PERSISTENT** setelah logout/login
3. ✅ Database connection **BERFUNGSI**
4. ✅ Foreign key relationship **VALID** (categoryId tersimpan)

Yang perlu Anda lakukan hanya:
- **Akses Railway Dashboard** untuk melihat data
- **BUKAN local phpMyAdmin** (karena itu database berbeda)

---

## 🔧 Troubleshooting

### "Saya tidak punya akses Railway Dashboard"
- Minta akses dari yang setup project Railway
- Atau minta screenshot/export data dari database

### "Saya ingin test dengan local database"
- Perlu setup local environment:
  - Local MySQL running
  - Local .env file dengan credentials
  - Local Go server running
  - Change environment ke `development`

### "Saya ingin lihat real-time data"
- Gunakan Railway Dashboard → Data tab
- Atau install MySQL Workbench dan connect dengan credentials Railway

---

## 📝 Next Steps

1. **Login ke Railway Dashboard**: https://railway.app
2. **Buka MySQL service** di project Anda
3. **Run query** untuk verify data
4. **Confirm** bahwa task tersimpan dengan categoryId yang valid

Jika Anda butuh bantuan lebih lanjut untuk akses Railway, beritahu saya! 🚀
