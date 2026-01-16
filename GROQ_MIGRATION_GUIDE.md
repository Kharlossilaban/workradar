# 🚀 Migrasi AI Service dari Google Gemini ke Groq

## 📋 Ringkasan Perubahan

Workradar AI Chatbot telah diupgrade dari **Google Gemini** ke **Groq** untuk performa yang lebih cepat!

### Keuntungan Groq:
- ⚡ **10-100x lebih cepat** dari Gemini dalam inference
- 💪 **Model LLaMA 3.3 70B** - lebih powerful
- 🎯 **API OpenAI-compatible** - standard industry
- 🆓 **Free tier generous** - 14,400 requests/day (6,000 RPM)

---

## 🔧 Cara Update di Railway

### **Step 1: Login ke Railway Dashboard**
1. Buka: https://railway.app/
2. Login dengan akun kamu
3. Pilih project **workradar**

### **Step 2: Update Environment Variable**

1. **Klik tab "Variables"** di Railway dashboard
2. **Hapus variable lama:**
   - ❌ Hapus: `GEMINI_API_KEY`

3. **Tambah variable baru:**
   - ✅ Klik **"New Variable"**
   - Name: `GROQ_API_KEY`
   - Value: `[GUNAKAN API KEY GROQ YANG SUDAH KAMU SHARE DI CHAT]`
   - Klik **"Add"**

### **Step 3: Deploy Ulang**

Railway akan **otomatis deploy** setelah kamu push ke GitHub (sudah done! ✅).

Tunggu 2-3 menit sampai deployment selesai. Cek di tab **"Deployments"**.

---

## 🧪 Cara Test Lokal (Opsional)

Jika ingin test di local sebelum test di Railway:

```powershell
# 1. Pastikan sudah di folder server
cd c:\Users\ASUS\workradar\server

# 2. File .env sudah diupdate otomatis dengan:
# GROQ_API_KEY=gsk_qV27mtP... (API key kamu)

# 3. Run server
go run cmd/main.go

# 4. Test AI Chatbot dari Flutter app atau via curl:
```

### Test dengan curl:
```powershell
# Ganti YOUR_JWT_TOKEN dengan token login kamu
curl -X POST http://localhost:8080/api/chat `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_JWT_TOKEN" `
  -d '{\"message\": \"Halo, apa kabar?\"}'
```

---

## 📊 Perbandingan API

| Feature | Google Gemini | Groq |
|---------|---------------|------|
| **Model** | gemini-2.0-flash-lite | llama-3.3-70b-versatile |
| **Speed** | ~2-5 detik | ~0.3-1 detik ⚡ |
| **Free Tier** | 15 RPM, 1M tokens/day | 30 RPM, 7000 tokens/min |
| **Rate Limit** | Sering quota error | Lebih stabil |
| **API Style** | Gemini-specific | OpenAI-compatible ✅ |

---

## 🔍 Troubleshooting

### ❌ Error: "AI assistant belum dikonfigurasi"
**Solusi:**
- Pastikan `GROQ_API_KEY` sudah diset di Railway Variables
- Check Railway logs untuk konfirmasi API key loaded

### ❌ Error: "401 Unauthorized" dari Groq
**Solusi:**
- API key salah atau expired
- Generate API key baru di: https://console.groq.com/keys
- Update `GROQ_API_KEY` di Railway

### ❌ Error: "Rate limit exceeded"
**Solusi:**
- Groq free tier: 30 requests/minute, 14,400/day
- Tunggu 1 menit lalu coba lagi
- Fallback response akan otomatis muncul

---

## 📝 Technical Details

### Changes Made:

**1. Backend Service (Go)**
- File: `server/internal/services/ai_service.go`
  - Struktur API berubah dari Gemini format ke OpenAI-compatible
  - Endpoint: `https://api.groq.com/openai/v1/chat/completions`
  - Model: `llama-3.3-70b-versatile`
  - Authorization: `Bearer` token (bukan query param)

**2. Configuration**
- File: `server/internal/config/config.go`
  - `GeminiAPIKey` → `GroqAPIKey`
  - Environment variable: `GEMINI_API_KEY` → `GROQ_API_KEY`

**3. Main Initialization**
- File: `server/cmd/main.go`
  - Updated service initialization dengan `GroqAPIKey`

### API Request Format:

**Before (Gemini):**
```json
{
  "contents": [
    {"role": "user", "parts": [{"text": "Hello"}]}
  ],
  "generationConfig": {"temperature": 0.7}
}
```

**After (Groq - OpenAI-compatible):**
```json
{
  "model": "llama-3.3-70b-versatile",
  "messages": [
    {"role": "system", "content": "You are..."},
    {"role": "user", "content": "Hello"}
  ],
  "temperature": 0.7,
  "max_tokens": 1024
}
```

---

## ✅ Checklist Migrasi

- [x] Update backend code (ai_service.go)
- [x] Update config (config.go)
- [x] Update main initialization (main.go)
- [x] Update .env.example
- [x] Commit & push ke GitHub
- [ ] **Update Railway Environment Variable** ⚠️ **KAMU HARUS LAKUKAN INI!**
- [ ] Test AI Chatbot di app

---

## 🎯 Next Steps

1. **Update Railway Variables** (langkah di atas)
2. **Test AI Chatbot** di Flutter app
3. **Enjoy faster responses!** 🚀

---

## 📞 Support

Jika ada masalah:
- Check Railway logs: https://railway.app/project/[your-project]/deployments
- Check Groq dashboard: https://console.groq.com/
- Verify API key valid

---

**Created:** January 16, 2026  
**Migration:** Google Gemini → Groq  
**Model:** llama-3.3-70b-versatile  
**Status:** ✅ Code Ready, ⚠️ Waiting Railway Variable Update
