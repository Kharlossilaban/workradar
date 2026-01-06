# 🧪 Step 4: Subscription & Workload - Testing Guide

## Persiapan

**1. RESTART Ser ver** (penting!)

Di terminal yang running server:
- Tekan **Ctrl+C**
- Jalankan: `go run cmd\main.go`

**2. Login & Simpan Token**

```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"user@test.com\",\"password\":\"password123\"}"
```

**Ganti `YOUR_TOKEN` di semua command dengan token Anda!**

---

## 💳 PART 1: Subscription Endpoints

### ✅ Test 1: Check VIP Status (Sebelum Upgrade)

```bash
curl http://localhost:8080/api/subscription/status -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected (Regular User):**
```json
{
  "is_vip": false,
  "days_remaining": 0,
  "active_subscription": null
}
```

### ✅ Test 2: Upgrade to VIP Monthly

```bash
curl -X POST http://localhost:8080/api/subscription/upgrade -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"plan_type\":\"monthly\",\"payment_method\":\"credit_card\",\"transaction_id\":\"TRX-12345\"}"
```

**Expected:**
```json
{
  "message": "Upgraded to VIP successfully",
  "subscription": {
    "id": "...",
    "plan_type": "monthly",
    "price": 49000,
    "start_date": "2025-12-29",
    "end_date": "2026-01-29",
    "is_active": true
  }
}
```

### ✅ Test 3: Check VIP Status (Setelah Upgrade)

```bash
curl http://localhost:8080/api/subscription/status -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "is_vip": true,
  "vip_expires_at": "2026-01-29T...",
  "days_remaining": 31,
  "active_subscription": {
    "id": "...",
    "plan_type": "monthly",
    "price": 49000
  }
}
```

### ✅ Test 4: Check Profile (User Sekarang VIP!)

```bash
curl http://localhost:8080/api/profile -H "Authorization: Bearer YOUR_TOKEN"
```

**Perhatikan:**
- `user_type`: sekarang `"vip"`
- `vip_expires_at`: ada tanggal expiry

### ✅ Test 5: Subscription History

```bash
curl http://localhost:8080/api/subscription/history -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "subscriptions": [
    {
      "id": "...",
      "plan_type": "monthly",
      "price": 49000,
      "start_date": "2025-12-29",
      "end_date": "2026-01-29",
      "is_active": true,
      "payment_method": "credit_card",
      "transaction_id": "TRX-12345"
    }
  ],
  "count": 1
}
```

### ✅ Test 6: Try Upgrade Again (Akan Error!)

```bash
curl -X POST http://localhost:8080/api/subscription/upgrade -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"plan_type\":\"yearly\",\"payment_method\":\"bank_transfer\",\"transaction_id\":\"TRX-67890\"}"
```

**Expected Error:**
```json
{
  "error": "user already has an active subscription"
}
```

---

## 📊 PART 2: Workload Endpoints

### Setup: Buat Tasks dengan Deadline Berbeda

Agar chart ada data, buat beberapa tasks:

```bash
# Task hari ini
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Task Today 1\",\"deadline\":\"2025-12-29T10:00:00Z\"}"

curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Task Today 2\",\"deadline\":\"2025-12-29T14:00:00Z\"}"

# Task kemarin
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Task Yesterday\",\"deadline\":\"2025-12-28T10:00:00Z\"}"

# Task minggu lalu
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Task Last Week\",\"deadline\":\"2025-12-22T10:00:00Z\"}"
```

**PENTING:** Sesuaikan tanggal dengan tanggal hari ini!

### ✅ Test 7: Daily Workload

```bash
curl "http://localhost:8080/api/workload?period=daily" -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "period": "daily",
  "data": [
    {"label": "Sun", "count": 1},
    {"label": "Mon", "count": 0},
    {"label": "Tue", "count": 0},
    {"label": "Wed", "count": 0},
    {"label": "Thu", "count": 0},
    {"label": "Fri", "count": 1},
    {"label": "Sat", "count": 2}
  ]
}
```

### ✅ Test 8: Weekly Workload

```bash
curl "http://localhost:8080/api/workload?period=weekly" -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "period": "weekly",
  "data": [
    {"label": "Week 1", "count": 5},
    {"label": "Week 2", "count": 3},
    {"label": "Week 3", "count": 2},
    {"label": "Week 4", "count": 4}
  ]
}
```

### ✅ Test 9: Monthly Workload

```bash
curl "http://localhost:8080/api/workload?period=monthly" -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "period": "monthly",
  "data": [
    {"label": "Jan", "count": 0},
    {"label": "Feb", "count": 0},
    ...
    {"label": "Nov", "count": 5},
    {"label": "Dec", "count": 15}
  ]
}
```

---

## 🎯 Advanced Testing: Yearly Subscription

### Test Upgrade Yearly (dengan User Baru)

**1. Register user baru:**
```bash
curl -X POST http://localhost:8080/api/auth/register -H "Content-Type: application/json" -d "{\"email\":\"vip@test.com\",\"username\":\"VIP User\",\"password\":\"password123\"}"
```

**2. Login & simpan token baru:**
```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"vip@test.com\",\"password\":\"password123\"}"
```

**3. Upgrade ke Yearly:**
```bash
curl -X POST http://localhost:8080/api/subscription/upgrade -H "Authorization: Bearer NEW_TOKEN" -H "Content-Type: application/json" -d "{\"plan_type\":\"yearly\",\"payment_method\":\"bank_transfer\",\"transaction_id\":\"TRX-YEARLY-001\"}"
```

**Expected:**
- `price`: 499000
- `end_date`: 1 tahun dari sekarang (2026-12-29)

---

## ✅ API Endpoints Summary Step 4

| Method | Endpoint | Description |
|--------|----------|-------------|
| **Subscription** |
| POST | `/api/subscription/upgrade` | Upgrade to VIP |
| GET | `/api/subscription/status` | Check VIP status |
| GET | `/api/subscription/history` | Subscription history |
| **Workload** |
| GET | `/api/workload?period=daily` | Last 7 days workload |
| GET | `/api/workload?period=weekly` | Last 4 weeks workload |
| GET | `/api/workload?period=monthly` | Last 12 months workload |

---

## 📊 Pricing Summary

| Plan | Price | Duration |
|------|-------|----------|
| Monthly | Rp 49,000 | 30 days |
| Yearly | Rp 499,000 | 365 days |

---

## 🎉 Selamat!

Step 4 selesai! Backend Workradar **DONE**! 🎊

### Total API Endpoints: **29 endpoints**

| Module | Count |
|--------|-------|
| Auth | 7 |
| Tasks | 6 |
| Categories | 4 |
| Profile | 2 |
| Calendar | 4 |
| **Subscription** | **3** |
| **Workload** | **1** (3 modes) |

---

**Next:** Integrasi Flutter dengan Backend! 🚀
