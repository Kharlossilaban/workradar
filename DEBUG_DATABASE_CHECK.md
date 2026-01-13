# Debug: Task Not Showing in phpMyAdmin

## 🔍 Diagnosis

### Situasi Saat Ini:
- ✅ Task tersimpan dan muncul kembali setelah logout/login
- ❌ Task TIDAK terlihat di phpMyAdmin
- ⚙️ Environment: `production` (Railway server)

## 🤔 Kemungkinan Penyebab

### **Kemungkinan #1: Different Database** (PALING MUNGKIN)
Aplikasi Flutter tersambung ke **Railway MySQL** (production), tapi Anda cek di **local phpMyAdmin**

```
Flutter App (Emulator)
    ↓ (API Call)
Railway Server (Production)
    ↓ (MySQL)
Railway MySQL Database ✅ (Data ada di sini!)
    
Local phpMyAdmin
    ↓ (MySQL)
Local MySQL Database ❌ (Data TIDAK ada di sini)
```

### **Kemungkinan #2: User ID Berbeda**
Task tersimpan dengan user_id tertentu, tapi Anda filter/cek dengan user_id yang berbeda

### **Kemungkinan #3: Server Sedang Down**
Railway server mati, aplikasi fallback ke local storage atau cache

## ✅ Cara Memverifikasi

### **Step 1: Cek Environment yang Digunakan**

Tambahkan debug log di aplikasi Flutter untuk melihat API URL:

```dart
// Di client/lib/main.dart atau dashboard_screen.dart
print('🔍 API URL: ${AppConfig.apiUrl}');
print('🔍 Environment: ${AppConfig.environmentName}');
```

**Expected Output:**
```
🔍 API URL: https://workradar-production.up.railway.app/api
🔍 Environment: production
```

### **Step 2: Test API Connection**

Buka browser atau Postman, test endpoint health:
```
https://workradar-production.up.railway.app/api/health
```

**Expected Response:**
```json
{
  "status": "OK",
  "message": "Workradar API is running"
}
```

### **Step 3: Cek Database Railway (Bukan Local)**

#### **Option A: Via Railway Dashboard**
1. Login ke https://railway.app
2. Pilih project `workradar-production`
3. Klik service MySQL
4. Cek tab "Data" atau "Query"
5. Run query:
   ```sql
   SELECT * FROM tasks ORDER BY created_at DESC LIMIT 10;
   ```

#### **Option B: Via MySQL Client**
1. Get Railway MySQL credentials:
   - MYSQLHOST
   - MYSQLPORT
   - MYSQLUSER
   - MYSQLPASSWORD
   - MYSQLDATABASE

2. Connect menggunakan MySQL Workbench atau CLI:
   ```bash
   mysql -h <MYSQLHOST> -P <MYSQLPORT> -u <MYSQLUSER> -p<MYSQLPASSWORD> <MYSQLDATABASE>
   ```

3. Query tasks:
   ```sql
   USE railway; -- atau database name yang sesuai
   
   SELECT 
     t.id,
     t.user_id,
     t.title,
     t.category_id,
     c.name as category_name,
     t.created_at
   FROM tasks t
   LEFT JOIN categories c ON t.category_id = c.id
   ORDER BY t.created_at DESC
   LIMIT 10;
   ```

### **Step 4: Get User ID dari Aplikasi**

Tambahkan log untuk melihat user ID yang sedang login:

```dart
// Di task_provider.dart atau dashboard_screen.dart
final authProvider = context.read<AuthProvider>();
print('🔍 Current User ID: ${authProvider.user?.id}');
print('🔍 Current User Email: ${authProvider.user?.email}');
```

Kemudian cek di database dengan user ID tersebut:
```sql
-- Ganti dengan user_id yang actual
SELECT * FROM tasks WHERE user_id = 'user-id-from-app';
```

## 🛠️ Quick Fix: Switch to Development

Jika Anda ingin test dengan local database (phpMyAdmin lokal), ubah environment:

```dart
// client/lib/core/config/environment.dart
static const Environment _env = Environment.development; // Change to development
```

Dan pastikan:
1. ✅ Local Go server running: `cd server && go run cmd/main.go`
2. ✅ Local MySQL running
3. ✅ IP address di `_developmentIP` benar

## 📊 Expected Results

### **Scenario 1: Production (Railway)**
- ✅ Data ada di Railway MySQL
- ❌ Data TIDAK ada di local phpMyAdmin
- ✅ Task tetap ada setelah logout/login

### **Scenario 2: Development (Local)**
- ✅ Data ada di local MySQL (phpMyAdmin)
- ❌ Data TIDAK ada di Railway MySQL
- ✅ Task tetap ada setelah logout/login

## 🔧 Debugging Commands

### Check Railway Server Status
```powershell
Invoke-WebRequest -Uri "https://workradar-production.up.railway.app/api/health" -Method GET
```

### Check if Local Server Running
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/health" -Method GET
```

### Get Railway Database Credentials
```bash
# Via Railway CLI (if installed)
railway variables

# Or check Railway dashboard web
```

## 📝 Recommended Actions

### **Untuk Production Testing:**
1. **Akses Railway MySQL**, bukan local phpMyAdmin
2. Get credentials dari Railway dashboard
3. Use MySQL Workbench atau TablePlus untuk connect
4. Query dengan user_id yang benar

### **Untuk Local Testing:**
1. **Switch ke development** environment
2. Run local Go server
3. Pastikan local MySQL running
4. Cek di local phpMyAdmin

## 🎯 Decision Tree

```
Apakah Anda ingin test dengan database mana?

1. Railway MySQL (Production)
   ├─ Kelebihan: Real production environment
   ├─ Kekurangan: Perlu credentials Railway
   └─ Action: Connect ke Railway MySQL, bukan local

2. Local MySQL (Development)  
   ├─ Kelebihan: Easy access via phpMyAdmin
   ├─ Kekurangan: Need to run local server
   └─ Action: Change env to development + run local server
```

## ⚠️ IMPORTANT NOTE

**Environment `production` = Railway Database (Cloud)**
**Environment `development` = Local Database (Your Computer)**

Jika environment = production, maka:
- ✅ Task tersimpan di Railway MySQL
- ❌ Task TIDAK akan muncul di local phpMyAdmin
- ✅ Untuk melihat data, harus connect ke Railway MySQL

---

**Next Step:** 
Pilih salah satu:
1. **Connect ke Railway MySQL** untuk lihat data production
2. **Switch ke development** untuk test dengan local database

Mana yang Anda inginkan?
