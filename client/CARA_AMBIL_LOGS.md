# 📱 Cara Ambil Logs untuk Debug Force Close Issue

## ✅ Prerequisites
- [x] ADB sudah terinstall dan ada di PATH
- [x] HP Android tersambung dengan kabel USB
- [x] USB Debugging sudah diaktifkan
- [ ] Device sudah di-authorize (Allow USB debugging)

---

## 🔧 Langkah 1: Authorize Device

1. **Jalankan command ini untuk cek status device:**
   ```powershell
   adb devices
   ```

2. **Jika muncul "unauthorized":**
   - Cek HP Android Anda
   - Akan muncul popup "Allow USB debugging?"
   - ✅ Centang **"Always allow from this computer"**
   - ✅ Tap **"OK"**

3. **Jika popup tidak muncul:**
   - Settings → Developer Options → Revoke USB debugging authorizations
   - Disconnect dan reconnect kabel USB
   - Popup akan muncul lagi

4. **Verifikasi - harusnya muncul seperti ini:**
   ```
   List of devices attached
   RRCW906FG6E     device
   ```
   (bukan "unauthorized" lagi)

---

## 📦 Langkah 2: Install APK ke HP

1. **Tunggu build APK selesai** (sedang berjalan di background)

2. **Setelah build selesai, install ke HP:**
   ```powershell
   cd c:\Users\ASUS\workradar\client
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

3. **Verifikasi instalasi:**
   - Buka app drawer di HP
   - Cari app "Workradar"
   - Icon dan nama app harus muncul

---

## 🎯 Langkah 3: Test Force Close Scenario

### **Test Case 1: Login + Force Close**

1. **Buka app Workradar di HP**
2. **Login dengan Google:**
   - Tap tombol "Login with Google"
   - Pilih akun Google
   - Tunggu sampai masuk ke Dashboard
3. **Force Close app:**
   - Tekan tombol Recent Apps (kotak/garis 3)
   - Swipe app Workradar ke atas (force close)
4. **Reopen app:**
   - Buka app Workradar lagi dari app drawer
5. **Cek hasilnya:**
   - ✅ PASS: Langsung ke Dashboard (tanpa login lagi)
   - ❌ FAIL: Kembali ke halaman Login

---

## 📝 Langkah 4: Capture Logs

### **Opsi A: Real-time Logs (Recommended)**

1. **Jalankan script capture:**
   ```powershell
   cd c:\Users\ASUS\workradar\client
   .\capture_logs.ps1
   ```

2. **Ikuti instruksi di screen:**
   - Press any key untuk mulai
   - Logs akan muncul real-time
   - Lakukan test di HP (login → force close → reopen)
   - Press Ctrl+C untuk stop

3. **Cari logs penting:**
   - `🔍 AUTH CHECK` - Saat app cek login status
   - `✅ Token saved` - Saat token disimpan
   - `❌ Error saving` - Jika ada error save token
   - `isLoggedIn: true/false` - Result dari cek login

### **Opsi B: Save Logs ke File**

1. **Jalankan script save:**
   ```powershell
   cd c:\Users\ASUS\workradar\client
   .\save_logs.ps1
   ```

2. **Ikuti instruksi:**
   - Press any key untuk mulai
   - Lakukan test di HP (60 detik)
   - Script akan auto-save logs ke folder `logs/`
   - Notepad akan otomatis membuka file logs

3. **Share logs:**
   - File ada di `client/logs/workradar_YYYYMMDD_HHMMSS.log`
   - Bisa dibuka dengan text editor
   - Copy paste yang relevant untuk analisis

---

## 🔍 Langkah 5: Analisis Logs

### **Skenario 1: Token Berhasil Disimpan**
```
✅ Access token saved successfully
✅ Refresh token saved successfully
```
→ **Artinya:** Token tersimpan dengan baik
→ **Cek selanjutnya:** Apakah token hilang setelah force close?

### **Skenario 2: Token Save Verification Failed**
```
⚠️ Warning: Token save verification failed!
```
→ **Artinya:** Write berhasil tapi read gagal
→ **Problem:** Storage encryption issue

### **Skenario 3: Error Saving Token**
```
❌ Error saving access token: <error message>
```
→ **Artinya:** Write gagal total
→ **Problem:** Storage permission atau encryption error

### **Skenario 4: Token Hilang Setelah Force Close**
```
🔍 AUTH CHECK:
  - isLoggedIn: false
  - accessToken exists: false
  - refreshToken exists: false
```
→ **Artinya:** Token tidak ada setelah reopen
→ **Problem:** Storage di-clear atau tidak flush ke disk

---

## 🚀 Quick Commands Cheatsheet

```powershell
# Cek device
adb devices

# Restart ADB
adb kill-server
adb start-server

# Install APK
adb install -r build\app\outputs\flutter-apk\app-debug.apk

# Uninstall app
adb uninstall com.workradar.workradar

# Clear app data
adb shell pm clear com.workradar.workradar

# Real-time logs (manual)
adb logcat | Select-String "AUTH CHECK|Token saved|Error"

# Clear logs
adb logcat -c
```

---

## 📞 Next Steps

Setelah dapat logs:

1. **Jika token hilang setelah force close:**
   - Implementasi Option A (Hybrid Storage)
   - atau Option B (Synchronous Flush)
   - atau Option C (Backup Storage)

2. **Jika token tidak bisa disimpan:**
   - Cek Android version
   - Cek storage permissions
   - Coba disable encryption temporarily

3. **Jika test PASS (no issue):**
   - Berarti fix yang sebelumnya sudah work!
   - Tinggal build release APK

---

## 💡 Tips

- **Pastikan HP tidak dalam Battery Saver mode** (bisa affect storage)
- **Jangan test sambil charging** (bisa affect force close behavior)
- **Clear app data sebelum test** untuk hasil yang konsisten:
  ```powershell
  adb shell pm clear com.workradar.workradar
  ```
- **Restart HP** jika behavior aneh (kadang storage service stuck)

---

## ❓ Troubleshooting

**Q: ADB tidak detect device**
- Coba kabel USB lain
- Restart ADB: `adb kill-server && adb start-server`
- Restart HP

**Q: Logs terlalu banyak, susah dibaca**
- Gunakan `save_logs.ps1` untuk filter otomatis
- Atau filter manual: `adb logcat | Select-String "workradar"`

**Q: App crash saat dibuka**
- Check logs untuk error message
- Coba clear app data: `adb shell pm clear com.workradar.workradar`

---

**Status Build APK:** Sedang berjalan di background
**Setelah build selesai:** Langsung ke Langkah 2 (Install APK)
