# Workradar Backend

Backend API untuk aplikasi Workradar menggunakan **Golang + Fiber + MySQL**.

## 🚀 Tech Stack

- **Framework**: [Fiber v2](https://gofiber.io/) - Express-inspired web framework
- **Database**: MySQL with [GORM](https://gorm.io/)
- **Auth**: JWT (JSON Web Tokens)
- **Password**: bcrypt hashing

## 📁 Struktur Project

```
server/
├── cmd/
│   └── main.go                 # Entry point
├── internal/
│   ├── config/                 # Configuration loader
│   ├── database/               # DB connection & migrations
│   ├── models/                 # Data models (User, Task, Category, dll)
│   ├── repository/             # Database queries
│   ├── services/               # Business logic
│   ├── handlers/               # HTTP handlers
│   └── middleware/             # Auth & VIP middleware
├── pkg/
│   └── utils/                  # JWT, password, helpers
├── go.mod
└── .env.example
```

## 🛠️ Setup

### 1. Install MySQL

Pastikan MySQL sudah terinstall dan running.

### 2. Buat Database

```sql
CREATE DATABASE workradar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3. Import Schema

```bash
mysql -u root -p workradar < internal/database/migrations/001_initial_schema.sql
```

### 4. Environment Variables

Copy `.env.example` ke `.env` dan isi dengan kredensial Anda:

```bash
cp .env.example .env
```

Edit `.env`:
```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=workradar
JWT_SECRET=your-secret-key
```

### 5. Install Dependencies

```bash
cd server
go mod download
```

### 6. Run Server

```bash
go run cmd/main.go
```

Server akan berjalan di `http://localhost:8080`

## 📡 API Endpoints

### Auth (Public)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register user baru |
| POST | `/api/auth/login` | Login user |
| POST | `/api/auth/forgot-password` | Request reset password |
| POST | `/api/auth/reset-password` | Reset password dengan code |

### Profile (Protected)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/profile` | Get user profile |
| PUT | `/api/profile` | Update profile |
| POST | `/api/profile/change-password` | Change password |

## 📝 Request/Response Examples

### Register
```json
POST /api/auth/register
{
  "email": "user@example.com",
  "username": "John Doe",
  "password": "password123"
}
```

### Login
```json
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "password123"
}

Response:
{
  "message": "Login successful",
  "user": {...},
  "token": "eyJhbGciOiJ..."
}
```

### Protected Routes
Gunakan token di header:
```
Authorization: Bearer <your-token>
```

## ✅ Status

**Step 1: Foundation** - ✅ Complete
- [x] Project structure  
- [x] Database schema
- [x] Config & DB connection
- [x] Models (User, Task, Category, Subscription, PasswordReset)
- [x] Repositories
- [x] Auth service & handlers
- [x] JWT & password utilities
- [x] Middleware (Auth, VIP)

**Next:** Tasks CRUD endpoints

## 🔧 Development

### Run with hot reload (optional)
```bash
go install github.com/cosmtrek/air@latest
air
```

### Test Database Connection
```bash
go run cmd/main.go
```

Cek health endpoint:
```bash
curl http://localhost:8080/api/health
```
