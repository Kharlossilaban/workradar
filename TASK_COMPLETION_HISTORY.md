# Task Completion History - Database Storage

## 📋 Jawaban Singkat

**Riwayat tugas yang sudah selesai tersimpan di tabel: `tasks`**

Bukan di tabel terpisah, melainkan **di tabel `tasks` yang sama** dengan menggunakan 2 kolom khusus:

| Kolom | Tipe | Fungsi |
|-------|------|--------|
| `is_completed` | BOOLEAN | Menandai apakah task sudah selesai (TRUE/FALSE) |
| `completed_at` | TIMESTAMP | Menyimpan kapan task ditandai selesai |

---

## 🏗️ Database Schema

### Tabel: `tasks`

```sql
CREATE TABLE tasks (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  category_id VARCHAR(36),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  deadline DATETIME,
  reminder_minutes INT,
  duration_minutes INT,
  repeat_type ENUM('none','hourly','daily','weekly','monthly') DEFAULT 'none',
  repeat_interval INT DEFAULT 1,
  repeat_end_date DATE,
  is_completed BOOLEAN DEFAULT FALSE,        -- ✅ Menandai selesai/belum
  completed_at TIMESTAMP NULL,               -- ✅ Waktu selesai
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (category_id) REFERENCES categories(id),
  INDEX idx_user_id (user_id),
  INDEX idx_category_id (category_id),
  INDEX idx_is_completed (is_completed)      -- ✅ Index untuk query cepat
);
```

---

## 📊 Contoh Data

### Contoh 1: Task Belum Selesai
```
id:             "task-001"
title:          "Membaca buku Flutter"
is_completed:   FALSE
completed_at:   NULL
created_at:     2026-01-12 10:00:00
```

### Contoh 2: Task Sudah Selesai
```
id:             "task-002"
title:          "Rapat dengan manager"
is_completed:   TRUE
completed_at:   2026-01-12 15:30:45    -- ✅ Diisi saat task ditandai selesai
created_at:     2026-01-12 10:00:00
```

---

## 🔍 Query untuk Lihat Task yang Sudah Selesai

### Query 1: Semua Task Selesai User Tertentu
```sql
SELECT 
  id,
  title,
  category_id,
  is_completed,
  completed_at,
  created_at
FROM tasks
WHERE user_id = 'user-id-xxx' 
  AND is_completed = TRUE
ORDER BY completed_at DESC;
```

### Query 2: Task Selesai dengan Kategori
```sql
SELECT 
  t.id,
  t.title,
  c.name as category_name,
  t.is_completed,
  t.completed_at,
  t.deadline,
  DATEDIFF(t.completed_at, t.deadline) as days_diff
FROM tasks t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = 'user-id-xxx' 
  AND t.is_completed = TRUE
ORDER BY t.completed_at DESC;
```

### Query 3: Statistik Completion
```sql
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN is_completed = TRUE THEN 1 ELSE 0 END) as completed_tasks,
  SUM(CASE WHEN is_completed = FALSE THEN 1 ELSE 0 END) as pending_tasks,
  ROUND(
    SUM(CASE WHEN is_completed = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
    2
  ) as completion_percentage
FROM tasks
WHERE user_id = 'user-id-xxx';
```

**Expected Output:**
```
total_tasks: 10
completed_tasks: 7
pending_tasks: 3
completion_percentage: 70.00
```

---

## 🖥️ Backend - Cara Menyimpan Completion Status

### Go Code (server/internal/models/task.go)

```go
type Task struct {
  ID          string     `json:"id"`
  Title       string     `json:"title"`
  // ...
  IsCompleted bool       `gorm:"default:false;index:idx_is_completed" json:"is_completed"`
  CompletedAt *time.Time `json:"completed_at,omitempty"`
  // ...
}
```

### Toggle Task Completion (server/internal/services/task_service.go)

```go
func (s *TaskService) ToggleTaskComplete(userID, taskID string) (*models.Task, error) {
  task, err := s.taskRepo.FindByID(taskID)
  if err != nil {
    return nil, err
  }

  // Verify ownership
  if task.UserID != userID {
    return nil, errors.New("unauthorized")
  }

  // Toggle status
  task.IsCompleted = !task.IsCompleted
  
  // Set completed_at timestamp
  if task.IsCompleted {
    now := time.Now()
    task.CompletedAt = &now  // ✅ Record completion time
  } else {
    task.CompletedAt = nil   // Clear jika di-uncomplete
  }

  // Simpan ke database
  if err := s.taskRepo.Update(task); err != nil {
    return nil, err
  }

  return task, nil
}
```

---

## 📱 Flutter Client - Bagaimana Menampilkan Completed Tasks

### Filter Tasks (client/lib/core/providers/task_provider.dart)

```dart
// Ambil hanya tasks yang sudah selesai
List<Task> get completedTasks {
  return _tasks.where((task) => task.isCompleted).toList();
}

// Ambil hanya tasks yang belum selesai
List<Task> get pendingTasks {
  return _tasks.where((task) => !task.isCompleted).toList();
}

// Ambil dengan kategori
List<Task> getCompletedTasksByCategory(String categoryId) {
  return _tasks.where(
    (task) => task.isCompleted && task.categoryId == categoryId
  ).toList();
}
```

### API Call untuk Toggle Completion

```dart
Future<void> toggleTaskCompletion(String taskId) async {
  try {
    final updatedTask = await _apiService.toggleComplete(taskId);
    
    // Update local state
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  } catch (e) {
    _errorMessage = 'Gagal mengubah status task: $e';
    notifyListeners();
    rethrow;
  }
}
```

---

## 🎯 UI - Menampilkan Riwayat Task Selesai

Contoh implementasi di Flutter:

```dart
// Filter completed tasks
final completedTasks = taskProvider.tasks
  .where((task) => task.isCompleted)
  .toList();

// Sort by completion date (newest first)
completedTasks.sort(
  (a, b) => (b.completedAt ?? DateTime(0))
    .compareTo(a.completedAt ?? DateTime(0))
);

// Display
ListView.builder(
  itemCount: completedTasks.length,
  itemBuilder: (context, index) {
    final task = completedTasks[index];
    return CompletedTaskCard(
      title: task.title,
      completedAt: task.completedAt,
      categoryName: task.categoryName,
      duration: task.durationMinutes,
    );
  },
)
```

---

## 📈 Statistik & Analytics

Untuk menampilkan statistik completion, gunakan query:

```sql
-- Daily completion count
SELECT 
  DATE(completed_at) as date,
  COUNT(*) as tasks_completed
FROM tasks
WHERE user_id = 'user-id-xxx'
  AND is_completed = TRUE
  AND completed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(completed_at)
ORDER BY date DESC;
```

**Expected Output:**
```
date       | tasks_completed
2026-01-12 | 5
2026-01-11 | 3
2026-01-10 | 2
...
```

---

## 🔐 Verifikasi Data di Railway MySQL

Untuk melihat task yang sudah selesai di database production:

### Via Railway Dashboard
1. Login: https://railway.app
2. Project: `workradar-production`
3. Service: `MySQL`
4. Tab: `Data` atau `Query`
5. Run:
```sql
SELECT 
  t.id,
  t.title,
  t.is_completed,
  t.completed_at,
  c.name as category_name,
  COUNT(*) OVER () as total_count
FROM tasks t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.is_completed = TRUE
ORDER BY t.completed_at DESC
LIMIT 20;
```

---

## 📊 Database Schema - Lengkap

```
┌─────────────────────────────────────────┐
│              TASKS TABLE                │
├─────────────────────────────────────────┤
│ PK   id: UUID                           │
│ FK   user_id: UUID                      │
│ FK   category_id: UUID (nullable)       │
│      title: VARCHAR(255)                │
│      description: TEXT                  │
│      deadline: DATETIME (nullable)      │
│      is_completed: BOOLEAN (default 0)  │ ← Status
│      completed_at: TIMESTAMP (nullable) │ ← Waktu
│      created_at: TIMESTAMP              │
│      updated_at: TIMESTAMP              │
│      ...                                │
└─────────────────────────────────────────┘
          ↓
    INDEX idx_is_completed  ← Cepat query
    untuk filter completed tasks
```

---

## ✅ Ringkasan

| Aspek | Detail |
|-------|--------|
| **Tabel** | `tasks` (bukan tabel terpisah) |
| **Kolom Status** | `is_completed` (BOOLEAN) |
| **Kolom Waktu** | `completed_at` (TIMESTAMP) |
| **Cara Kerja** | Task ditandai selesai = set `is_completed=TRUE` + isi `completed_at` |
| **Query Filter** | `WHERE is_completed = TRUE` |
| **Index** | `idx_is_completed` untuk performa |
| **Persistensi** | Tersimpan di MySQL database |
| **Setelah Logout** | Data tetap ada di database |

**Jadi, riwayat task yang sudah selesai aman tersimpan di database dan tidak hilang!** ✅

---

**Next Step:** 
Apakah Anda ingin saya:
1. Buatkan dokumentasi API untuk endpoint toggle completion?
2. Buatkan query untuk analytics/statistics completion?
3. Cek UI di aplikasi untuk memastikan completion feature bekerja dengan baik?
