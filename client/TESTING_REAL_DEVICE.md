# 🧪 Real Device Testing Guide - Flutter + Backend Integration

## 📱 Persiapan Real Device Testing

### Step 1: Cari IP Komputer Anda

Di **Command Prompt** (bukan PowerShell), ketik:
```bash
ipconfig
```

Cari **IPv4 Address** di bagian WiFi atau Ethernet Anda.
Contoh: `192.168.1.100`

**PENTING:** HP dan komputer harus terhubung ke **WiFi yang sama**!

---

### Step 2: Update Environment Config

Buka file `lib/core/config/environment.dart` dan ganti IP address:

```dart
case Environment.development:
  // Ganti dengan IP komputer Anda!
  return 'http://192.168.1.100:8080/api';
```

**Ganti `192.168.1.100` dengan IP dari Step 1!**

---

### Step 3: Jalankan Backend Server

**Terminal 1 (Backend):**
```bash
cd c:\myradar\server
go run cmd\main.go
```

Pastikan output menunjukkan:
```
🚀 Server starting on port 8080
```

---

### Step 4: Install Dependencies Flutter

**Terminal 2 (Flutter):**
```bash
cd c:\myradar\client
flutter pub get
```

---

### Step 5: Hubungkan HP ke Komputer

1. **Enable Developer Options** di HP:
   - Settings → About Phone → Tap "Build Number" 7x

2. **Enable USB Debugging**:
   - Settings → Developer Options → USB Debugging → ON

3. **Hubungkan dengan kabel USB**

4. **Cek device terhubung:**
   ```bash
   flutter devices
   ```
   Harus ada device HP Anda dalam list.

---

### Step 6: Run Flutter App

```bash
flutter run
```

Atau jika ada multiple devices:
```bash
flutter run -d <device_id>
```

---

## 🧪 Testing Scenarios

### Scenario 1: Register & Login

1. Buka app → Tap "Register"
2. Isi form:
   - Email: `test@gmail.com`
   - Username: `Test User`
   - Password: `password123`
3. Tap Register
4. **Expected:** Berhasil register dan masuk ke dashboard

**Jika error "Connection refused":**
- Cek IP address sudah benar
- Cek backend sudah running
- Cek HP dan komputer di WiFi yang sama

---

### Scenario 2: Create Task

1. Di Dashboard, tap tombol "+" untuk create task
2. Isi title: "Test Task"
3. Pilih category jika ada
4. Tap Create
5. **Expected:** Task muncul di list

---

### Scenario 3: Toggle Task Complete

1. Tap checkbox pada task
2. **Expected:** Task ditandai selesai

---

### Scenario 4: View Profile & Stats

1. Buka Profile screen
2. **Expected:** Lihat stats (total tasks, completed, rate)

---

### Scenario 5: Biometric Auth (Opsional)

1. Di Profile → Settings → Enable Biometric
2. Keluar dari app
3. Buka app lagi
4. **Expected:** Diminta fingerprint/face ID

---

## 🔧 Troubleshooting

### Error: "Connection refused"
```
Penyebab: HP tidak bisa connect ke backend
Solusi:
1. Pastikan IP address benar (ipconfig)
2. Pastikan backend running (go run cmd\main.go)
3. Pastikan WiFi sama antara HP dan komputer
4. Disable Windows Firewall sementara untuk testing
```

### Error: "Connection timeout"
```
Penyebab: Network lambat atau IP salah
Solusi:
1. Restart backend server
2. Restart app di HP
3. Cek koneksi WiFi
```

### Error: "Invalid token" atau "Unauthorized"
```
Penyebab: Token expired atau blacklisted
Solusi:
1. Logout dari app
2. Login ulang
```

### Error: "Too many requests"
```
Penyebab: Rate limiter aktif
Solusi:
1. Tunggu 1 menit
2. Rate limit: 60 req/min (regular), 120 req/min (VIP)
```

---

## 🎯 Checklist Testing

- [ ] Backend running di komputer
- [ ] IP address sudah benar di `environment.dart`
- [ ] HP dan komputer di WiFi yang sama
- [ ] `flutter pub get` sukses
- [ ] App bisa dijalankan di HP (`flutter run`)
- [ ] Register berhasil
- [ ] Login berhasil
- [ ] Create task berhasil
- [ ] Toggle complete berhasil
- [ ] Profile & Stats tampil
- [ ] Logout berhasil

---

## 📊 API Services Summary

| Service | File | Methods |
|---------|------|---------|
| **Auth** | `auth_api_service.dart` | register, login, logout, refresh, forgotPassword, resetPassword |
| **Task** | `task_api_service.dart` | getTasks, getTaskById, createTask, updateTask, deleteTask, toggleComplete |
| **Category** | `category_api_service.dart` | getCategories, createCategory, updateCategory, deleteCategory |
| **Profile** | `profile_api_service.dart` | getProfile, getStats, updateProfile, changePassword |
| **Calendar** | `calendar_api_service.dart` | getTodayTasks, getWeekTasks, getMonthTasks, getTasksByDateRange |
| **Subscription** | `subscription_api_service.dart` | upgradeToVip, getVipStatus, getHistory |
| **Workload** | `workload_api_service.dart` | getWorkload (daily/weekly/monthly) |

---

## 🎉 Selamat!

Flutter dan Backend sudah terintegrasi dengan:
- ✅ Secure token storage (encrypted)
- ✅ Auto token refresh
- ✅ Rate limiting protection
- ✅ User-friendly error messages
- ✅ Biometric authentication ready

**Next:** Update UI screens untuk menggunakan API services! 🚀
