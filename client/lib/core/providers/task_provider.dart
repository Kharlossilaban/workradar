import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_api_service.dart';
import '../network/api_exception.dart';

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];
  final TaskApiService _apiService = TaskApiService();

  bool _isLoading = false;
  String? _errorMessage;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Get only incomplete tasks
  List<Task> get incompleteTasks =>
      _tasks.where((t) => !t.isCompleted).toList();

  /// Get only completed tasks, sorted by completion date (newest first)
  List<Task> get completedTasks {
    final completed = _tasks.where((t) => t.isCompleted).toList();
    completed.sort(
      (a, b) => (b.completedAt ?? DateTime.now()).compareTo(
        a.completedAt ?? DateTime.now(),
      ),
    );
    return completed;
  }

  /// Get total count of all completed tasks
  int get totalCompletedTasks => _tasks.where((t) => t.isCompleted).length;

  /// Get tasks for a specific date
  List<Task> getTasksForDate(DateTime date, {bool includeCompleted = false}) {
    return _tasks.where((task) {
      // Filter by completion status
      if (!includeCompleted && task.isCompleted) return false;

      // Use helper that considers repeat logic
      return isTaskActiveOnDate(task, date);
    }).toList();
  }

  /// Check if a task is active on a specific date (considering repeat)
  bool isTaskActiveOnDate(Task task, DateTime date) {
    if (task.deadline == null) return false;

    // Normalize dates to remove time component
    final startDate = DateTime(
      task.deadline!.year,
      task.deadline!.month,
      task.deadline!.day,
    );
    final checkDate = DateTime(date.year, date.month, date.day);

    // Check if date is before task start
    if (checkDate.isBefore(startDate)) {
      return false;
    }

    // If no repeat, just check deadline
    if (task.repeatType == RepeatType.none) {
      return startDate.year == checkDate.year &&
          startDate.month == checkDate.month &&
          startDate.day == checkDate.day;
    }

    // Check if date is after repeat end date
    if (task.repeatEndDate != null) {
      final endDate = DateTime(
        task.repeatEndDate!.year,
        task.repeatEndDate!.month,
        task.repeatEndDate!.day,
      );
      if (checkDate.isAfter(endDate)) {
        return false;
      }
    }

    // Calculate difference based on repeat type
    switch (task.repeatType) {
      case RepeatType.hourly:
        // For hourly, we check if it's the same day as start
        return startDate.year == checkDate.year &&
            startDate.month == checkDate.month &&
            startDate.day == checkDate.day;

      case RepeatType.daily:
        final daysDiff = checkDate.difference(startDate).inDays;
        return daysDiff >= 0 && daysDiff % task.repeatInterval == 0;

      case RepeatType.weekly:
        final daysDiff = checkDate.difference(startDate).inDays;
        return daysDiff >= 0 && daysDiff % (task.repeatInterval * 7) == 0;

      case RepeatType.monthly:
        // Check if same day of month
        if (startDate.day != checkDate.day) return false;
        final monthsDiff =
            (checkDate.year - startDate.year) * 12 +
            (checkDate.month - startDate.month);
        return monthsDiff >= 0 && monthsDiff % task.repeatInterval == 0;

      case RepeatType.none:
        return false;
    }
  }

  /// Get tasks for today
  List<Task> get todayTasks {
    final now = DateTime.now();
    return getTasksForDate(now, includeCompleted: false);
  }

  /// Check if a date has incomplete tasks
  bool hasTasksOnDate(DateTime date) {
    return getTasksForDate(date, includeCompleted: false).isNotEmpty;
  }

  /// Filter tasks by category
  List<Task> getTasksByCategory(
    String category, {
    bool includeCompleted = false,
  }) {
    final filtered = includeCompleted ? tasks : incompleteTasks;

    if (category == 'Semua') {
      return filtered;
    }
    return filtered.where((task) => task.categoryName == category).toList();
  }

  /// Get completed tasks grouped by date for timeline view
  /// Groups by deadline date, not completion date
  Map<DateTime, List<Task>> getCompletedTasksByDate() {
    final Map<DateTime, List<Task>> grouped = {};

    for (final task in completedTasks) {
      // Group by deadline date instead of completedAt
      if (task.deadline == null) continue;

      // Get date without time
      final date = DateTime(
        task.deadline!.year,
        task.deadline!.month,
        task.deadline!.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(task);
    }

    return grouped;
  }

  // ==================== API METHODS ====================

  /// Load tasks from server
  Future<void> loadTasksFromServer() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final taskModels = await _apiService.getTasks();
      _tasks.clear();
      _tasks.addAll(taskModels.map(_taskModelToTask).toList());
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat tugas: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Add task to server
  Future<void> addTaskToServer(Task task) async {
    try {
      final createdTaskModel = await _apiService.createTask(
        title: task.title,
        description:
            task.categoryName, // Store category name as description for now
        categoryId: task.categoryId,
        deadline: task.deadline,
        reminderMinutes: task.reminderMinutes,
        repeatType: task.repeatType.name,
        repeatInterval: task.repeatInterval,
        repeatEndDate: task.repeatEndDate,
        durationMinutes:
            task.durationMinutes, // ✅ FIX: Send duration to backend
        difficulty: task.difficulty.name, // ✅ FIX: Send difficulty to backend
      );

      final createdTask = _taskModelToTask(createdTaskModel);

      // Preserve duration and difficulty from local task (not in backend)
      final taskWithDuration = createdTask.copyWith(
        durationMinutes: task.durationMinutes,
        difficulty: task.difficulty,
        categoryName: task.categoryName,
      );

      _tasks.add(taskWithDuration);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal membuat tugas: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle task completion on server
  /// For repeating tasks: marks current as complete and fetches the newly created next occurrence
  Future<void> toggleTaskCompletionOnServer(
    String taskId, {
    Function(DateTime)? onCompleted,
  }) async {
    try {
      final oldTaskIndex = _tasks.indexWhere((t) => t.id == taskId);
      Task? oldTask;
      if (oldTaskIndex != -1) {
        oldTask = _tasks[oldTaskIndex];
      }

      final updatedTaskModel = await _apiService.toggleComplete(taskId);
      final updatedTask = _taskModelToTask(updatedTaskModel);

      if (oldTaskIndex != -1 && oldTask != null) {
        // Preserve duration and difficulty from old task
        _tasks[oldTaskIndex] = updatedTask.copyWith(
          durationMinutes: oldTask.durationMinutes,
          difficulty: oldTask.difficulty,
        );

        // If this is a repeating task that just got completed,
        // fetch all tasks again to get the newly created next occurrence
        if (updatedTask.isCompleted &&
            !oldTask.isCompleted &&
            oldTask.repeatType != RepeatType.none) {
          // Refresh tasks to get newly created repeat occurrence
          await loadTasksFromServer();
        }

        // If task just got completed, call callback
        if (updatedTask.isCompleted &&
            !oldTask.isCompleted &&
            onCompleted != null) {
          onCompleted(updatedTask.completedAt ?? DateTime.now());
        }

        notifyListeners();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal mengubah status tugas: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete task from server
  Future<void> deleteTaskFromServer(String taskId) async {
    try {
      await _apiService.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal menghapus tugas: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update task on server
  Future<void> updateTaskOnServer(Task task) async {
    try {
      final updatedTaskModel = await _apiService.updateTask(
        taskId: task.id,
        title: task.title,
        description: task.categoryName,
        categoryId: task.categoryId,
        deadline: task.deadline,
        reminderMinutes: task.reminderMinutes,
        repeatType: task.repeatType.name,
        repeatInterval: task.repeatInterval,
        repeatEndDate: task.repeatEndDate,
      );

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedTask = _taskModelToTask(updatedTaskModel);

        // Preserve duration, difficulty, and categoryName
        _tasks[index] = updatedTask.copyWith(
          durationMinutes: task.durationMinutes,
          difficulty: task.difficulty,
          categoryName: task.categoryName,
        );

        notifyListeners();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui tugas: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ==================== LOCAL METHODS (Keep for backward compatibility) ====================

  /// Add a new task (local only)
  void addTask(Task task) {
    if (task.repeatType == RepeatType.none || task.deadline == null) {
      _tasks.add(task);
    } else {
      _tasks.addAll(_generateRecurringTasks(task));
    }
    notifyListeners();
  }

  /// Helper to generate recurring tasks
  List<Task> _generateRecurringTasks(Task baseTask) {
    List<Task> generatedTasks = [baseTask];

    // Safety limit to prevent infinite loops or excessive memory usage
    const int maxInstances = 50;
    final DateTime? endDate = baseTask.repeatEndDate;

    // If no end date is provided, we might want a default or just limit by count
    DateTime currentDeadline = baseTask.deadline!;

    for (int i = 1; i < maxInstances; i++) {
      DateTime nextDeadline;

      switch (baseTask.repeatType) {
        case RepeatType.hourly:
          nextDeadline = currentDeadline.add(
            Duration(hours: baseTask.repeatInterval),
          );
          break;
        case RepeatType.daily:
          nextDeadline = currentDeadline.add(
            Duration(days: baseTask.repeatInterval),
          );
          break;
        case RepeatType.weekly:
          nextDeadline = currentDeadline.add(
            Duration(days: 7 * baseTask.repeatInterval),
          );
          break;
        case RepeatType.monthly:
          // Simple month addition (preserving same day if possible)
          nextDeadline = DateTime(
            currentDeadline.year,
            currentDeadline.month + baseTask.repeatInterval,
            currentDeadline.day,
            currentDeadline.hour,
            currentDeadline.minute,
          );
          break;
        case RepeatType.none:
          return generatedTasks;
      }

      // Check if we passed the end date
      if (endDate != null && nextDeadline.isAfter(endDate)) {
        break;
      }

      generatedTasks.add(
        baseTask.copyWith(
          id: '${baseTask.id}_$i', // Simple unique ID for recurring instances
          deadline: nextDeadline,
        ),
      );

      currentDeadline = nextDeadline;
    }

    return generatedTasks;
  }

  /// Update an existing task (local only)
  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// Toggle task completion (local only)
  void toggleTaskCompletion(String taskId, {Function(DateTime)? onCompleted}) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final wasCompleted = task.isCompleted;
      final nowCompleted = !wasCompleted;

      _tasks[index] = task.copyWith(
        isCompleted: nowCompleted,
        completedAt: nowCompleted ? DateTime.now() : null,
      );

      // If task just got completed (not uncompleted), record it
      if (nowCompleted && !wasCompleted && onCompleted != null) {
        onCompleted(DateTime.now());
      }

      notifyListeners();
    }
  }

  /// Delete a task (local only)
  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  /// Permanently delete a completed task
  void deleteCompletedTask(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.isCompleted) {
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    }
  }

  /// Delete all completed tasks
  void deleteAllCompletedTasks() {
    _tasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
  }

  // ==================== CONVERTER METHODS ====================

  /// Convert TaskModel from API to Task for UI
  Task _taskModelToTask(TaskModel model) {
    return Task(
      id: model.id,
      userId: model.userId,
      categoryId: model.categoryId,
      categoryName: model.category?.name ?? 'Kerja',
      title: model.title,
      deadline: model.deadline,
      reminderMinutes: model.reminderMinutes,
      repeatType: _parseRepeatType(model.repeatType),
      repeatInterval: model.repeatInterval,
      repeatEndDate: model.repeatEndDate,
      isCompleted: model.isCompleted,
      completedAt: model.completedAt,
      difficulty: _parseDifficulty(model.difficulty), // ✅ FIX: From backend
      durationMinutes: model.durationMinutes, // ✅ FIX: From backend
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  static TaskDifficulty _parseDifficulty(String? difficulty) {
    switch (difficulty) {
      case 'relaxed':
        return TaskDifficulty.relaxed;
      case 'focus':
        return TaskDifficulty.focus;
      default:
        return TaskDifficulty.normal;
    }
  }

  static RepeatType _parseRepeatType(String type) {
    switch (type) {
      case 'hourly':
        return RepeatType.hourly;
      case 'daily':
        return RepeatType.daily;
      case 'weekly':
        return RepeatType.weekly;
      case 'monthly':
        return RepeatType.monthly;
      default:
        return RepeatType.none;
    }
  }
}
