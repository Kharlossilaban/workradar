# 🚀 Step 2: Tasks Module - Testing Guide

## Sebelum Mulai

**PENTING:** Pastikan server sudah running!

**Di Terminal Antigravity:**
```bash
cd c:\myradar\server
go run cmd\main.go
```

Jangan tutup terminal ini!

---

## 📝 Dapatkan Token JWT Dulu

Kita perlu token untuk akses protected endpoints.

**Di CMD baru (bukan yang running server):**

### 1. Register (jika belum)
```bash
curl -X POST http://localhost:8080/api/auth/register -H "Content-Type: application/json" -d "{\"email\":\"user@test.com\",\"username\":\"Test User\",\"password\":\"password123\"}"
```

### 2. Login & Salin Token
```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"user@test.com\",\"password\":\"password123\"}"
```

**COPY token dari response!** Contoh:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**GANTI `YOUR_TOKEN` di command berikut dengan token Anda!**

---

## ✅ Test 1: Buat Task Baru

```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Belajar Golang\",\"description\":\"Belajar konsep struct dan pointer\"}"
```

**Response yang benar:**
```json
{
  "message": "Task created successfully",
  "task": {
    "id": "...",
    "title": "Belajar Golang",
    "is_completed": false,
    ...
  }
}
```

---

## 📋 Test 2: Lihat Semua Tasks

```bash
curl http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**
```json
{
  "tasks": [
    {
      "id": "...",
      "title": "Belajar Golang",
      ...
    }
  ],
  "count": 1
}
```

---

## 🔍 Test 3: Lihat Detail Task

**GANTI `TASK_ID` dengan ID task dari response sebelumnya!**

```bash
curl http://localhost:8080/api/tasks/TASK_ID -H "Authorization: Bearer YOUR_TOKEN"
```

---

## ✏️ Test 4: Update Task (Mark as Complete)

```bash
curl -X PUT http://localhost:8080/api/tasks/TASK_ID -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"is_completed\":true}"
```

**Response:**
```json
{
  "message": "Task updated successfully",
  "task": {
    "is_completed": true,
    "completed_at": "2025-12-28T..."
  }
}
```

---

## 🔄 Test 5: Toggle Task Complete

Lebih cepat untuk toggle tanpa kirim JSON:

```bash
curl -X PATCH http://localhost:8080/api/tasks/TASK_ID/toggle -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 🗑️ Test 6: Hapus Task

```bash
curl -X DELETE http://localhost:8080/api/tasks/TASK_ID -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**
```json
{
  "message": "Task deleted successfully"
}
```

---

## 🎯 Test dengan Category

### 1. Dapatkan Category ID

Default categories sudah dibuat saat register. Lihat dengan:

```bash
curl http://localhost:8080/api/profile -H "Authorization: Bearer YOUR_TOKEN"
```

Atau buat endpoint `/api/categories` (next step).

### 2. Buat Task dengan Category

```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Meeting\",\"category_id\":\"CATEGORY_ID_KERJA\"}"
```

### 3. Filter Tasks by Category

```bash
curl "http://localhost:8080/api/tasks?category_id=CATEGORY_ID_KERJA" -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 🧪 Test dengan Deadline & Reminder

```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Submit Project\",\"deadline\":\"2025-12-31T23:59:00Z\",\"reminder_minutes\":30}"
```

Format deadline: `YYYY-MM-DDTHH:MM:SSZ` (UTC time)

---

## 🔁 Test dengan Repeat

```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"Daily Standup\",\"repeat_type\":\"daily\",\"repeat_interval\":1}"
```

Repeat types: `none`, `hourly`, `daily`, `weekly`, `monthly`

---

## ❌ Test Error Handling

### Unauthorized (tanpa token):
```bash
curl http://localhost:8080/api/tasks
```
**Response:** `Missing authorization header`

### Task not found:
```bash
curl http://localhost:8080/api/tasks/invalid-id -H "Authorization: Bearer YOUR_TOKEN"
```
**Response:** `task not found`

### Empty title:
```bash
curl -X POST http://localhost:8080/api/tasks -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"\"}"
```
**Response:** `title is required`

---

## ✅ API Endpoints Summary

| Method | Endpoint | Description | Auth | Body |
|--------|----------|-------------|------|------|
| POST | `/api/tasks` | Buat task baru | ✅ | CreateTaskDTO |
| GET | `/api/tasks` | Lihat semua tasks | ✅ | - |
| GET | `/api/tasks?category_id=xxx` | Filter by category | ✅ | - |
| GET | `/api/tasks/:id` | Detail task | ✅ | - |
| PUT | `/api/tasks/:id` | Update task | ✅ | UpdateTaskDTO |
| DELETE | `/api/tasks/:id` | Hapus task | ✅ | - |
| PATCH | `/api/tasks/:id/toggle` | Toggle complete | ✅ | - |

---

## 📊 Next: Category Endpoints

Setelah tasks selesai, kita akan buat:
- GET `/api/categories` - List all categories
- POST `/api/categories` - Buat category baru
- PUT `/api/categories/:id` - Update category
- DELETE `/api/categories/:id` - Hapus category

---

**Selamat! Tasks Module sudah berjalan!** 🎉
