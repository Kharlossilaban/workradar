import 'package:flutter/foundation.dart';
import '../../../core/models/task.dart';

/// Data class for category duration
class CategoryDuration {
  final Map<String, int> categoryMinutes;

  CategoryDuration({Map<String, int>? categoryMinutes})
      : categoryMinutes = categoryMinutes ?? {};

  int get total => categoryMinutes.values.fold(0, (a, b) => a + b);

  void add(String category, int minutes) {
    final normalizedCategory = category.toLowerCase();
    categoryMinutes[normalizedCategory] =
        (categoryMinutes[normalizedCategory] ?? 0) + minutes;
  }

  void remove(String category, int minutes) {
    final normalizedCategory = category.toLowerCase();
    final current = categoryMinutes[normalizedCategory] ?? 0;
    categoryMinutes[normalizedCategory] = (current - minutes).clamp(0, double.infinity).toInt();
  }

  int getForCategory(String category) {
    return categoryMinutes[category.toLowerCase()] ?? 0;
  }

  CategoryDuration copy() {
    return CategoryDuration(categoryMinutes: Map.from(categoryMinutes));
  }
}

/// Provider for managing workload chart data with category breakdown
class WorkloadProvider with ChangeNotifier {
  // Map to store task duration with category breakdown by date (YYYY-MM-DD format)
  final Map<String, CategoryDuration> _taskDurations = {};

  // Current date offset for navigation (0 = current period, -1 = previous, +1 = next)
  int _dateOffset = 0;

  int get dateOffset => _dateOffset;

  /// Get total all-time workload in minutes
  int get totalAllTimeWorkload {
    int total = 0;
    for (final duration in _taskDurations.values) {
      total += duration.total;
    }
    return total;
  }

  /// Sync workload data from a list of tasks
  void syncFromTasks(List<Task> tasks) {
    _taskDurations.clear();
    for (final task in tasks) {
      if (task.isCompleted) {
        final date = task.deadline ?? task.completedAt ?? DateTime.now();
        final dateKey = _formatDateKey(date);
        final duration = task.durationMinutes ?? 0;
        final category = task.categoryName;

        if (!_taskDurations.containsKey(dateKey)) {
          _taskDurations[dateKey] = CategoryDuration();
        }
        _taskDurations[dateKey]!.add(category, duration);
      }
    }
    notifyListeners();
  }

  /// Record a task completion for a specific date
  void recordTaskCompletion(DateTime date, {int duration = 0, String category = 'Kerja'}) {
    final dateKey = _formatDateKey(date);
    if (!_taskDurations.containsKey(dateKey)) {
      _taskDurations[dateKey] = CategoryDuration();
    }
    _taskDurations[dateKey]!.add(category, duration);
    notifyListeners();
  }

  /// Record a scheduled task (for real-time workload tracking)
  void recordScheduledTask(DateTime date, {required int duration, String category = 'Kerja'}) {
    if (duration <= 0) return;
    final dateKey = _formatDateKey(date);
    if (!_taskDurations.containsKey(dateKey)) {
      _taskDurations[dateKey] = CategoryDuration();
    }
    _taskDurations[dateKey]!.add(category, duration);
    notifyListeners();
  }

  /// Remove a scheduled task from workload (when task is deleted before completion)
  void removeScheduledTask(DateTime date, {required int duration, String category = 'Kerja'}) {
    if (duration <= 0) return;
    final dateKey = _formatDateKey(date);
    if (_taskDurations.containsKey(dateKey)) {
      _taskDurations[dateKey]!.remove(category, duration);
    }
    notifyListeners();
  }

  /// Get total duration for a specific date
  int getTotalDuration(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _taskDurations[dateKey]?.total ?? 0;
  }

  /// Get category duration for a specific date
  CategoryDuration getCategoryDuration(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _taskDurations[dateKey]?.copy() ?? CategoryDuration();
  }

  /// Get daily durations for a specific week (7 days) - returns total only (backward compatible)
  List<int> getDailyDurations(DateTime startOfWeek) {
    final durations = <int>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      durations.add(getTotalDuration(date));
    }
    return durations;
  }

  /// Get daily durations with category breakdown for a specific week
  List<CategoryDuration> getDailyCategoryDurations(DateTime startOfWeek) {
    final durations = <CategoryDuration>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      durations.add(getCategoryDuration(date));
    }
    return durations;
  }

  /// Get weekly durations for a specific month (4 weeks)
  List<int> getWeeklyDurations(DateTime monthDate) {
    final durations = <int>[];
    // Get first day of month
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);

    // Calculate 4 weeks from start of month
    for (int week = 0; week < 4; week++) {
      int weekTotal = 0;
      final weekStart = firstDayOfMonth.add(Duration(days: week * 7));

      // Sum up durations for 7 days in this week
      for (int day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        // Only count if still in the same month
        if (date.month == monthDate.month) {
          weekTotal += getTotalDuration(date);
        }
      }
      durations.add(weekTotal);
    }
    return durations;
  }

  /// Get weekly durations with category breakdown for a specific month
  List<CategoryDuration> getWeeklyCategoryDurations(DateTime monthDate) {
    final durations = <CategoryDuration>[];
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);

    for (int week = 0; week < 4; week++) {
      final weekDuration = CategoryDuration();
      final weekStart = firstDayOfMonth.add(Duration(days: week * 7));

      for (int day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        if (date.month == monthDate.month) {
          final dayDuration = getCategoryDuration(date);
          for (final entry in dayDuration.categoryMinutes.entries) {
            weekDuration.add(entry.key, entry.value);
          }
        }
      }
      durations.add(weekDuration);
    }
    return durations;
  }

  /// Get monthly durations for a specific year (12 months)
  List<int> getMonthlyDurations(int year) {
    final durations = <int>[];
    for (int month = 1; month <= 12; month++) {
      int monthTotal = 0;
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        monthTotal += getTotalDuration(date);
      }
      durations.add(monthTotal);
    }
    return durations;
  }

  /// Get monthly durations with category breakdown for a specific year
  List<CategoryDuration> getMonthlyCategoryDurations(int year) {
    final durations = <CategoryDuration>[];
    for (int month = 1; month <= 12; month++) {
      final monthDuration = CategoryDuration();
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final dayDuration = getCategoryDuration(date);
        for (final entry in dayDuration.categoryMinutes.entries) {
          monthDuration.add(entry.key, entry.value);
        }
      }
      durations.add(monthDuration);
    }
    return durations;
  }

  /// Check if there's any task data for a given week
  bool hasDataForWeek(DateTime startOfWeek) {
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (getTotalDuration(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any task data for a given month
  bool hasDataForMonth(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      if (getTotalDuration(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any task data for a given year
  bool hasDataForYear(int year) {
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        if (getTotalDuration(date) > 0) return true;
      }
    }
    return false;
  }

  /// Navigate to next period
  void navigateNext() {
    _dateOffset++;
    notifyListeners();
  }

  /// Navigate to previous period
  void navigatePrevious() {
    _dateOffset--;
    notifyListeners();
  }

  /// Reset to current period
  void resetToCurrentPeriod() {
    _dateOffset = 0;
    notifyListeners();
  }

  /// Get the start date of current week with offset
  DateTime getWeekStartDate() {
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    return currentWeekStart.add(Duration(days: _dateOffset * 7));
  }

  /// Get the month date with offset
  DateTime getMonthDate() {
    final now = DateTime.now();
    final targetMonth = now.month + _dateOffset;
    final targetYear = now.year + (targetMonth - 1) ~/ 12;
    final adjustedMonth = ((targetMonth - 1) % 12) + 1;
    return DateTime(targetYear, adjustedMonth, 1);
  }

  /// Get the year with offset
  int getYear() {
    final now = DateTime.now();
    return now.year + _dateOffset;
  }

  /// Format date as string key (YYYY-MM-DD)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Clear all data (for testing purposes)
  void clearAllData() {
    _taskDurations.clear();
    _dateOffset = 0;
    notifyListeners();
  }
}
