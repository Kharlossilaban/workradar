# Midtrans Quick Start - Testing Panduan

## ⚡ 5 Menit Setup & Test

### Prerequisites
- ✅ Midtrans sandbox credentials sudah di `.env`
- ✅ Go backend running (`go run cmd/main.go`)
- ✅ Flutter app siap (`flutter pub get`)

---

## 🚀 Step 1: Start Backend

```bash
cd server
# Pastikan .env sudah ada dengan Midtrans credentials
go run cmd/main.go
```

Check di terminal:
```
Payment routes registered ✓
Server running on :8080 ✓
```

---

## 🎮 Step 2: Run Flutter App

```bash
cd client
flutter run
```

---

## 💳 Step 3: Test Payment

### Navigate ke Payment Screen:
1. Login dengan akun user
2. Go to Profile/Dashboard
3. Click "Upgrade to VIP" atau "Bayar Sekarang"
4. Select "Monthly" (Rp 15.000)
5. Click "Bayar Sekarang"

### Expected: 
- ✅ WebView membuka dengan Midtrans Snap Payment
- ✅ Beautiful UI dengan loading indicator

---

## 💰 Step 4: Complete Payment (Success)

**Di Snap Payment WebView, gunakan test card:**

```
Nomor:    4811 1111 1111 1114
CVV:      123
Exp:      12/25 (atau date lainnya)
OTP:      123456
```

### Then:
1. Click "Bayar" / "Pay"
2. Tunggu proses (2-3 detik)
3. ✅ Success message muncul!

### What happens behind the scenes:
1. WebView detect payment success
2. Automatic verify ke backend (`GET /api/payments/:order_id`)
3. Backend receive Midtrans webhook
4. Create subscription record
5. Upgrade user ke VIP
6. Send bot notification: "Selamat! Status VIP Anda aktif"
7. Show success dialog

---

## 🔍 Step 5: Verify Success

### Check di App:
- [ ] Success dialog ditampilkan
- [ ] VIP status terbaca "ACTIVE"
- [ ] Profile menampilkan VIP badge
- [ ] Bot message notification received

### Check di Backend Logs:
```
Payment success for order: ORDER-xxxxx
User upgraded to VIP
Subscription created with expiry: 2026-02-12
```

### Check di Midtrans Dashboard:
1. Login ke https://app.sandbox.midtrans.com/
2. Transactions
3. Cari Order ID dari payment
4. Status: **SETTLEMENT** ✓
5. Amount: **Rp 15.000** ✓

---

## 🧪 Test Lainnya (Optional)

### Test: Failed Payment
Card: `4011 1111 1111 1112` → Will be denied → Status: FAILED

### Test: Pending Payment
Card: `4611 1111 1111 1113` → Requires challenge → Status: PENDING

### Test: Cancel Payment
- Saat di WebView, click back/close → Cancel confirmation dialog
- Status: CANCELLED

---

## ⚙️ Configuration

### Change VIP Pricing:
File: `client/lib/core/services/midtrans_service.dart`
```dart
static const int vipMonthlyPrice = 15000;  // Edit sini
static const int vipYearlyPrice = 150000;  // Edit sini
```

### Change Payment Gateway (if needed):
File: `server/internal/services/payment_service.go`
- Line 33: `midtrans.Sandbox` → production config
- Pastikan MIDTRANS_IS_PRODUCTION=true di .env

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| WebView blank/tidak load | Restart backend, check internet connection |
| "Payment gateway error" | Verify Midtrans keys di .env valid |
| Payment success tapi no notification | Check email configuration, restart app |
| VIP badge tidak muncul | Logout/login, refresh data |

---

## 📱 Demo Flow Video (Mental Model)

```
App Start → Profile → "Upgrade VIP" button
   ↓
PaymentScreen: Select Plan (Monthly: Rp 15.000)
   ↓
"Bayar Sekarang" → Create payment transaction
   ↓
WebView Opens → Midtrans Snap Payment UI
   ↓
User fills: Card 4811 1111 1111 1114, CVV 123
   ↓
Click Bayar → Processing...
   ↓
Success ✓ → Backend verify + Subscribe
   ↓
Return to App → "Pembayaran Berhasil!" dialog
   ↓
VIP Status: ACTIVE ✓
Bot: "Selamat! Anda sekarang VIP" ✓
```

---

## ✅ Checklist Sebelum Testing

- [ ] Go server running (check logs untuk "listening on :8080")
- [ ] Flutter app compiled tanpa errors
- [ ] Internet connection aktif
- [ ] User sudah logged in
- [ ] Midtrans credentials valid di .env
- [ ] Database (MySQL/SQLite) running

---

## 🎯 Next Steps After Success

1. **Test all payment scenarios:**
   - ✅ Success (test card 4811...)
   - ✅ Failed (test card 4011...)
   - ✅ Pending (test card 4611...)
   - ✅ Cancel (close WebView)

2. **Verify database:**
   ```sql
   -- Check transaction created
   SELECT * FROM transactions WHERE user_id = 'YOUR_USER_ID';
   
   -- Check subscription created
   SELECT * FROM subscriptions WHERE user_id = 'YOUR_USER_ID';
   ```

3. **Test webhook (optional):**
   - Middleware sudah ada di backend
   - Webhook automatically called by Midtrans
   - Check logs untuk webhook received

4. **Production deployment:**
   - Get production keys dari Midtrans
   - Update .env.production
   - Update webhook URL
   - Deploy!

---

**Happy Testing! 🎉**

> Jika ada masalah, check logs di:
> - Backend: Terminal/logs
> - Frontend: Flutter console/debugger
> - Midtrans: Dashboard → Transactions
