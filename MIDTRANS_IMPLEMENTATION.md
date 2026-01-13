# Midtrans Payment Integration - Implementation Guide

## 📋 Status Implementasi

✅ **Backend Setup** - Siap 100%
- Midtrans SDK terinstall (midtrans-go v1.3.8)
- Payment Service, Handler, dan Routes sudah konfigurasi
- Webhook untuk notification sudah siap
- Subscription auto-upgrade setelah payment success

✅ **Frontend Setup** - Siap 100%
- webview_flutter terinstall (v4.4.4)
- Payment WebView Screen dibuat
- Payment Flow terintegrasi dengan subscription
- Support untuk semua payment status (pending, success, failed, expired, cancelled)

---

## 🔧 Prerequisites

### 1. Pastikan Midtrans Credentials Sudah di Backend

Cek di `.env` atau Railway environment variables:

```bash
# .env (local development)
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxxxxxxxx
MIDTRANS_IS_PRODUCTION=false
```

### 2. Verify Backend Running

Pastikan Go server berjalan dengan payment routes:

```bash
POST   /api/payments/create          # Create payment & get snap token
GET    /api/payments/history         # Get payment history
GET    /api/payments/:order_id       # Check payment status
POST   /api/payments/:order_id/cancel # Cancel pending payment
POST   /api/webhooks/midtrans        # Webhook notification (public)
```

---

## 🧪 Testing Payment Flow

### Step 1: Start the App

```bash
cd client
flutter pub get
flutter run
```

### Step 2: Navigate to VIP Subscription

1. Open app
2. Go to Profile → Upgrade to VIP (atau navigasi ke PaymentScreen)
3. Select plan (Monthly/Yearly)
4. Click "Bayar Sekarang"

### Step 3: Test with Sandbox Card

**WebView akan membuka Midtrans Snap Payment**

Gunakan test cards ini:

#### ✅ Success Payment
```
Nomor Kartu: 4811 1111 1111 1114
CVV: 123
Exp: Any future date (contoh: 12/25)
OTP: 123456
```

**Expected Result:**
- WebView akan detect success
- Automatic call ke `/api/payments/:order_id` untuk verify
- Payment status akan berubah ke SUCCESS
- VIP subscription akan aktif
- Success dialog ditampilkan
- Bot message notification dikirim

#### ❌ Failed Payment
```
Nomor Kartu: 4011 1111 1111 1112
CVV: 123
Exp: Any future date
```

**Expected Result:**
- Payment ditolak
- Status berubah ke FAILED
- Error message ditampilkan

#### ⏳ Pending Payment
```
Nomor Kartu: 4611 1111 1111 1113
CVV: 123
Exp: Any future date
```

**Expected Result:**
- Payment pending (requires challenge)
- Status berubah ke PENDING
- WebView akan detect pending status

---

## 📱 Payment Flow Architecture

```
┌─────────────────────────────────────────────────┐
│ 1. PaymentScreen                                │
│    - Select plan (monthly/yearly)              │
│    - User click "Bayar Sekarang"              │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 2. Call /api/payments/create (via MidtransService)
│    - Request: { plan_type: "monthly" }         │
│    - Response: { token, redirect_url }        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 3. Open PaymentWebViewScreen                    │
│    - Load redirect_url dalam WebView           │
│    - Display Midtrans Snap Payment             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 4. User Complete Payment                        │
│    - Enter card details                        │
│    - Confirm OTP                              │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 5. WebView Detect Status Change                 │
│    - Detect URL pattern (success/fail/etc)    │
│    - Call /api/payments/:order_id untuk verify │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 6. Backend Process Webhook                      │
│    - Midtrans sends notification               │
│    - Verify transaction status                 │
│    - If success: Upgrade user to VIP          │
│    - Create subscription record               │
│    - Send bot message notification            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ 7. Return to App                                │
│    - Show success/failed dialog               │
│    - Update UI dengan new status              │
│    - User terupgrade ke VIP                   │
└─────────────────────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Issue: WebView tidak load payment page

**Solution:**
- Ensure Internet connection is active
- Check MIDTRANS_CLIENT_KEY di backend (must be valid)
- Verify backend `/api/payments/create` response includes `redirect_url`

```bash
# Test backend payment creation
curl -X POST http://localhost:8080/api/payments/create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"plan_type":"monthly"}'
```

### Issue: Payment success tapi tidak ada notification

**Solution:**
- Ensure `MAILGUN_SMTP_HOST`, `MAILGUN_SMTP_USER` diatur untuk email
- Check bot message service configuration
- Verify user email di database

### Issue: Webhook not received

**Solution:**
- For local testing, gunakan ngrok untuk expose local server:
  ```bash
  ngrok http 8080
  # Update webhook URL di Midtrans Dashboard dengan ngrok URL
  ```
- Untuk production, update webhook URL ke production domain

---

## 📊 Database Tables

### transactions
```sql
-- Created by backend
id, order_id, user_id, plan_type, amount, status, 
snap_token, payment_method, created_at, updated_at
```

### subscriptions
```sql
-- Auto-created saat payment success
id, user_id, plan_type, price, start_date, end_date,
is_active, payment_method, transaction_id, created_at, updated_at
```

---

## 🚀 Production Deployment

Sebelum launch ke production:

### 1. Get Production Keys dari Midtrans

1. Login ke Midtrans Dashboard (production mode)
2. Settings → Access Keys
3. Copy Production Server Key & Client Key (tanpa "SB-")

### 2. Update Environment Variables

```bash
# .env.production
MIDTRANS_SERVER_KEY=Mid-server-xxxxxxxxxxxxx
MIDTRANS_CLIENT_KEY=Mid-client-xxxxxxxxxxxxx
MIDTRANS_IS_PRODUCTION=true
```

### 3. Update Webhook URL

Di Midtrans Dashboard:
- Settings → Configuration
- Update webhook URL ke production domain:
  ```
  https://api.workradar.com/api/webhooks/midtrans
  ```

### 4. Test with Real Cards (Limited)

- Gunakan real card untuk test minimal 1-2 transaction
- Monitor dashboard untuk settlement status
- Verify email notifications terkirim

### 5. Monitor Dashboard

- Real-time transaction monitoring
- Settlement status tracking
- Revenue reporting
- Customer payment history

---

## 💰 Pricing Reference

```
Monthly VIP: Rp 15.000 (dapat update di MidtransService.vipMonthlyPrice)
Yearly VIP:  Rp 150.000 (dapat update di MidtransService.vipYearlyPrice)

Midtrans Fee: ~2.7% (akan dikurangi dari revenue)
```

---

## 📚 Files Modified/Created

### Created:
- `client/lib/features/subscription/screens/payment_webview_screen.dart` - WebView untuk Midtrans Snap Payment

### Modified:
- `client/pubspec.yaml` - Added webview_flutter
- `client/lib/features/subscription/screens/payment_screen.dart` - Integrated WebView payment flow
- `client/lib/core/models/payment.dart` - Payment model (existing)
- `client/lib/core/services/midtrans_service.dart` - Midtrans service (existing)

### Existing (No Changes):
- `server/internal/handlers/payment_handler.go` - Payment handler (complete)
- `server/internal/services/payment_service.go` - Payment service (complete)
- `server/cmd/main.go` - Routes registration (complete)

---

## ✅ Verification Checklist

- [ ] Backend Midtrans credentials sudah set di `.env`
- [ ] Backend running dengan payment routes accessible
- [ ] Flutter app compiled tanpa error
- [ ] WebView functionality tested dengan test card
- [ ] Success payment verified di dashboard
- [ ] Bot message notification terkirim
- [ ] VIP status terupdate di database
- [ ] Sandbox testing selesai dengan semua flow
- [ ] Production keys siap untuk deployment
- [ ] Webhook URL dikonfigurasi

---

## 🔗 Useful Links

- **Midtrans Dashboard**: https://dashboard.midtrans.com/
- **Midtrans Documentation**: https://docs.midtrans.com/
- **Test Cards**: https://docs.midtrans.com/en/technical-reference/sandbox-test-cards
- **Snap Integration Guide**: https://docs.midtrans.com/en/snap/overview

---

**Status**: ✅ Implementasi selesai, siap untuk testing
**Last Updated**: January 12, 2026
