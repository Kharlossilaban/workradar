# Setup Guide - API Keys & Credentials

Panduan lengkap untuk mendapatkan API keys dan credentials yang dibutuhkan untuk Workradar backend.

---

## 1. 🔑 Google OAuth Client ID & Secret

### Langkah-langkah:

#### Step 1: Buat Project di Google Cloud Console
1. Buka [Google Cloud Console](https://console.cloud.google.com/)
2. Login dengan akun Google Anda
3. Klik **"Select a project"** → **"New Project"**
4. Nama project: `Workradar` (atau nama bebas)
5. Klik **"Create"**

#### Step 2: Enable Google+ API
1. Di sidebar kiri, klik **"APIs & Services"** → **"Library"**
2. Search: `Google+ API`
3. Klik **"Google+ API"**
4. Klik **"Enable"**

#### Step 3: Configure OAuth Consent Screen
1. Di sidebar, klik **"OAuth consent screen"**
2. Pilih **"External"** → **"Create"**
3. Isi form:
   - **App name:** Workradar
   - **User support email:** email Anda
   - **Developer contact:** email Anda
4. Klik **"Save and Continue"**
5. **Scopes:** Skip (klik "Save and Continue")
6. **Test users:** Tambahkan email Anda untuk testing
7. Klik **"Save and Continue"**

#### Step 4: Create OAuth Credentials
1. Di sidebar, klik **"Credentials"**
2. Klik **"+ Create Credentials"** → **"OAuth client ID"**
3. Application type: **"Web application"**
4. Name: `Workradar Web Client`
5. **Authorized JavaScript origins:**
   ```
   http://localhost:8080
   ```
6. **Authorized redirect URIs:**
   ```
   http://localhost:8080/api/auth/google/callback
   ```
7. Klik **"Create"**

#### Step 5: Copy Credentials
- Copy **Client ID** → masukkan ke `.env` sebagai `GOOGLE_CLIENT_ID`
- Copy **Client Secret** → masukkan ke `.env` sebagai `GOOGLE_CLIENT_SECRET`

**Contoh .env:**
```env
GOOGLE_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abcdefghijklmnop
GOOGLE_REDIRECT_URL=http://localhost:8080/api/auth/google/callback
```

**Referensi:**
- [Google OAuth 2.0 Setup](https://developers.google.com/identity/protocols/oauth2)
- [Google Cloud Console](https://console.cloud.google.com/)

---

## 2. 🌤️ OpenWeatherMap API Key

### Langkah-langkah:

#### Step 1: Create Account
1. Buka [OpenWeatherMap](https://openweathermap.org/)
2. Klik **"Sign Up"** di pojok kanan atas
3. Isi form registrasi:
   - Username
   - Email
   - Password
4. Verify email Anda

#### Step 2: Get API Key
1. Login ke [OpenWeatherMap](https://openweathermap.org/)
2. Klik nama Anda → **"My API Keys"**
3. Default API key sudah ada dengan nama "Default"
4. Copy API key tersebut

**Atau buat API key baru:**
1. Di halaman "API Keys"
2. **Key name:** `Workradar`
3. Klik **"Generate"**
4. Copy API key yang baru dibuat

#### Step 3: Add to .env
```env
WEATHER_API_KEY=your-32-character-api-key
```

**Contoh:**
```env
WEATHER_API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

#### Step 4: Test API
Test dengan curl:
```bash
curl "https://api.openweathermap.org/data/2.5/weather?q=Jakarta&appid=YOUR_API_KEY&units=metric"
```

**API Limits (Free Tier):**
- 60 calls/minute
- 1,000,000 calls/month
- Current weather + 5-day forecast

**Referensi:**
- [OpenWeatherMap API Docs](https://openweathermap.org/api)
- [How to Get API Key](https://openweathermap.org/appid)

---

## 3. 🔔 Firebase Cloud Messaging (FCM) - Service Account

> ⚠️ **PENTING:** Legacy Cloud Messaging API sudah **deprecated** dan dinonaktifkan sejak Juni 2024. Sekarang wajib menggunakan **HTTP v1 API** dengan Service Account.

### Langkah-langkah:

#### Step 1: Create Firebase Project
1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Klik **"Add project"**
3. Project name: `Workradar`
4. Klik **"Continue"**
5. **Google Analytics:** Disable (optional)
6. Klik **"Create project"**
7. Tunggu project selesai dibuat

#### Step 2: Enable Cloud Messaging API
1. Di Firebase Console project Anda
2. Klik **"Build"** → **"Cloud Messaging"** di sidebar
3. Jika muncul prompt **"Enable"**, klik untuk mengaktifkan

#### Step 3: Generate Service Account Key (REQUIRED)
1. Di Firebase Console, klik ⚙️ (Settings) → **"Project settings"**
2. Tab **"Service accounts"**
3. Klik tombol biru **"Generate new private key"**
4. Pop-up konfirmasi muncul → Klik **"Generate key"**
5. File JSON akan terdownload (contoh: `workradar-firebase-adminsdk-xxxxx.json`)

#### Step 4: Save JSON File
1. Rename file JSON menjadi: `workradar-firebase.json`
2. Pindahkan ke folder server: `c:\myradar\server\workradar-firebase.json`
3. **JANGAN commit file ini ke Git!** (Sudah ada di .gitignore)

#### Step 5: Get Project ID
1. Masih di **"Project settings"** → Tab **"General"**
2. Copy **"Project ID"** (contoh: `workradar-a1b2c`)

#### Step 6: Add to .env
```env
# Firebase FCM (HTTP v1 API)
FIREBASE_PROJECT_ID=workradar-a1b2c
FIREBASE_CREDENTIALS_FILE=workradar-firebase.json
```

**Contoh lengkap .env:**
```env
FIREBASE_PROJECT_ID=workradar-12345
FIREBASE_CREDENTIALS_FILE=workradar-firebase.json
```

**Referensi:**
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [FCM Server Setup](https://firebase.google.com/docs/cloud-messaging/server)

---

## 4. ✅ Gemini AI API Key (Already Have!)

Anda sudah punya:
```env
GEMINI_API_KEY=AIzaSyDF4la0w5V8xbfdpUlGr-pjNsqAXfxu4cQ
```

**Verify (Optional):**
1. Buka [Google AI Studio](https://aistudio.google.com/)
2. Login dengan akun Google
3. Klik **"Get API key"**
4. Verify key Anda masih valid

---

## 📝 Final .env Configuration

Setelah semua setup, file `.env` Anda harus seperti ini:

```env
# ========================================
# SERVER CONFIGURATION
# ========================================
PORT=8080
ENV=development

# ========================================
# DATABASE CONFIGURATION
# ========================================
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your-mysql-password
DB_NAME=workradar

# ========================================
# JWT CONFIGURATION
# ========================================
JWT_SECRET=workradar-super-secret-key-change-in-production
JWT_EXPIRY=24h

# ========================================
# CORS CONFIGURATION
# ========================================
ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*

# ========================================
# GOOGLE OAUTH
# ========================================
GOOGLE_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abcdefghijklmnop
GOOGLE_REDIRECT_URL=http://localhost:8080/api/auth/google/callback

# ========================================
# OPENWEATHERMAP API (VIP Feature)
# ========================================
WEATHER_API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# ========================================
# FIREBASE FCM (Push Notifications)
# ========================================
FCM_SERVER_KEY=AAAAxxxxxxx:APA91bFxxxxxxxxxxxxxxxxx

# ========================================
# MIDTRANS PAYMENT GATEWAY
# ========================================
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxxxxxxxx
MIDTRANS_IS_PRODUCTION=false

# ========================================
# GEMINI AI CHATBOT
# ========================================
GEMINI_API_KEY=AIzaSyDF4la0w5V8xbfdpUlGr-pjNsqAXfxu4cQ
```

---

## ⏱️ Estimated Setup Time

| Service | Time Required |
|---------|---------------|
| Google OAuth | 10-15 minutes |
| OpenWeatherMap | 5 minutes |
| Firebase FCM | 10 minutes |
| **Total** | **25-30 minutes** |

---

## 🐛 Common Issues

### Google OAuth
**Issue:** "Redirect URI mismatch"  
**Solution:** Pastikan redirect URI di Google Console sama persis dengan di kode

### OpenWeatherMap
**Issue:** "Invalid API key"  
**Solution:** Tunggu 10-15 menit setelah generate key (aktivasi delay)

### Firebase FCM
**Issue:** "Permission denied"  
**Solution:** Enable Cloud Messaging API di Firebase Console

---

## 🎯 Next Steps

Setelah semua API keys didapat:
1. ✅ Update `.env` file
2. ✅ Verifikasi semua keys valid
3. ✅ Ready untuk implementasi backend!

Siap mulai implementasi setelah dapat semua keys! 🚀
