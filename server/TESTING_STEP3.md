# 🧪 Step 3: Category, Profile & Calendar - Testing Guide

## Persiapan

**1. RESTART Server** (penting agar kode baru ter-load!)

Di terminal yang running server:
- Tekan **Ctrl+C**
- Jalankan ulang: `go run cmd\main.go`

**2. Pastikan Anda punya Token JWT**

Login dan simpan token:
```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"user@test.com\",\"password\":\"password123\"}"
```

**Ganti `YOUR_TOKEN` di semua command dengan token Anda!**

---

## 📁 PART 1: Category Endpoints

### ✅ Test 1: List All Categories

```bash
curl http://localhost:8080/api/categories -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:**
```json
{
  "categories": [
    {"id": "...", "name": "Kerja", "color": "#6C5CE7", "is_default": true},
    {"id": "...", "name": "Pribadi", "color": "#00B894", "is_default": true},
    {"id": "...", "name": "Wishlist", "color": "#FDCB6E", "is_default": true},
    {"id": "...", "name": "Hari Ulang Tahun", "color": "#E17055", "is_default": true}
  ],
  "count": 4
}
```

### ✅ Test 2: Create Custom Category

```bash
curl -X POST http://localhost:8080/api/categories -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"Hobi\",\"color\":\"#FF6B6B\"}"
```

**Expected:**
```json
{
  "message": "Category created successfully",
  "category": {
    "id": "...",
    "name": "Hobi",
    "color": "#FF6B6B",
    "is_default": false
  }
}
```

### ✅ Test 3: Update Category

**GANTI `CATEGORY_ID` dengan ID category "Hobi" yang baru dibuat!**

```bash
curl -X PUT http://localhost:8080/api/categories/CATEGORY_ID -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"Hobby\",\"color\":\"#FF7777\"}"
```

### ✅ Test 4: Try Delete Default Category (Akan Error!)

**Get ID kategori "Kerja" dari list, lalu coba hapus:**

```bash
curl -X DELETE http://localhost:8080/api/categories/ID_KERJA -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Error:**
```json
{
  "error": "cannot delete default category"
}
```

### ✅ Test 5: Delete Custom Category (Berhasil!)

```bash
curl -X DELETE http://localhost:8080/api/categories/ID_HOBBY -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "message": "Category deleted successfully"
}
```

---

## 👤 PART 2: Profile Endpoints

### ✅ Test 6: Get Full Profile

```bash
curl http://localhost:8080/api/profile -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:**
```json
{
  "user": {
    "id": "...",
    "email": "user@test.com",
    "username": "Test User",
    "user_type": "regular",
    ...
  },
  "stats": {
    "total_tasks": 2,
    "completed_tasks": 1,
    "completion_rate": 50.0,
    "today_tasks": 0,
    "pending_tasks": 1
  },
  "categories": [...]
}
```

### ✅ Test 7: Get Stats Only

```bash
curl http://localhost:8080/api/profile/stats -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "stats": {
    "total_tasks": 2,
    "completed_tasks": 1,
    "completion_rate": 50.0,
    "today_tasks": 0,
    "pending_tasks": 1
  }
}
```

---

## 📅 PART 3: Calendar Endpoints

### Setup: Buat Task dengan Deadline Hari Ini

Agar ada task di calendar hari ini:

```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Task Hari Ini\",\"deadline\":\"2025-12-29T15:00:00Z\"}"
```

**Note:** Ganti tanggal `2025-12-29` dengan **tanggal hari ini** sesuai waktu Anda!

### ✅ Test 8: Today's Tasks

```bash
curl http://localhost:8080/api/calendar/today -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "date": "2025-12-29",
  "tasks": [
    {
      "id": "...",
      "title": "Task Hari Ini",
      "deadline": "2025-12-29T15:00:00+07:00",
      ...
    }
  ],
  "count": 1
}
```

### ✅ Test 9: This Week's Tasks

```bash
curl http://localhost:8080/api/calendar/week -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "date": "2025-12-23 to 2025-12-29",
  "tasks": [...],
  "count": 1
}
```

### ✅ Test 10: This Month's Tasks

```bash
curl http://localhost:8080/api/calendar/month -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "date": "2025-12 (month)",
  "tasks": [...],
  "count": 2
}
```

### ✅ Test 11: Custom Date Range

```bash
curl "http://localhost:8080/api/calendar/range?start=2025-12-01&end=2025-12-31" -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:**
```json
{
  "date": "2025-12-01 to 2025-12-31",
  "tasks": [...],
  "count": 2
}
```

---

## 🎯 Advanced Testing: Integration

### Scenario: Buat Task dengan Category → Lihat Stats

**1. Buat kategori "Workout":**
```bash
curl -X POST http://localhost:8080/api/categories -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"Workout\",\"color\":\"#E74C3C\"}"
```

**2. Simpan `category_id` dari response.**

**3. Buat 3 tasks dengan kategori Workout:**
```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Push Up 50x\",\"category_id\":\"WORKOUT_CATEGORY_ID\"}"

curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Jogging 5km\",\"category_id\":\"WORKOUT_CATEGORY_ID\"}"

curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Yoga 30min\",\"category_id\":\"WORKOUT_CATEGORY_ID\"}"
```

**4. Mark 2 sebagai complete:**
```bash
curl -X PATCH http://localhost:8080/api/tasks/TASK_ID_1/toggle -H "Authorization: Bearer YOUR_TOKEN"
curl -X PATCH http://localhost:8080/api/tasks/TASK_ID_2/toggle -H "Authorization: Bearer YOUR_TOKEN"
```

**5. Cek stats:**
```bash
curl http://localhost:8080/api/profile/stats -H "Authorization: Bearer YOUR_TOKEN"
```

**Harusnya `total_tasks` naik, `completed_tasks` naik, dan `completion_rate` berubah!**

---

## ✅ API Endpoints Summary Step 3

| Method | Endpoint | Description |
|--------|----------|-------------|
| **Categories** |
| GET | `/api/categories` | List semua kategori |
| POST | `/api/categories` | Buat kategori baru |
| PUT | `/api/categories/:id` | Update kategori |
| DELETE | `/api/categories/:id` | Hapus kategori |
| **Profile** |
| GET | `/api/profile` | Full profile + stats + categories |
| GET | `/api/profile/stats` | Stats only |
| **Calendar** |
| GET | `/api/calendar/today` | Tasks hari ini |
| GET | `/api/calendar/week` | Tasks minggu ini |
| GET | `/api/calendar/month` | Tasks bulan ini |
| GET | `/api/calendar/range?start=X&end=Y` | Custom date range |

---

## 🎉 Selamat!

Step 3 selesai! Anda sekarang punya:
- ✅ Category management (CRUD)
- ✅ Profile dengan statistics
- ✅ Calendar dengan date filtering

**Next:** VIP Features & Subscription! 🚀
