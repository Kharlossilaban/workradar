import 'package:flutter/foundation.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];

  List<Task> get tasks => List.unmodifiable(_tasks);

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

  /// Get tasks for a specific date
  List<Task> getTasksForDate(DateTime date, {bool includeCompleted = false}) {
    return _tasks.where((task) {
      // Filter by completion status
      if (!includeCompleted && task.isCompleted) return false;

      if (task.deadline == null) return false;
      return task.deadline!.year == date.year &&
          task.deadline!.month == date.month &&
          task.deadline!.day == date.day;
    }).toList();
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
  Map<DateTime, List<Task>> getCompletedTasksByDate() {
    final Map<DateTime, List<Task>> grouped = {};

    for (final task in completedTasks) {
      if (task.completedAt == null) continue;

      // Get date without time
      final date = DateTime(
        task.completedAt!.year,
        task.completedAt!.month,
        task.completedAt!.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(task);
    }

    return grouped;
  }

  /// Add a new task
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

  /// Update an existing task
  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// Toggle task completion
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

  /// Delete a task
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
}
