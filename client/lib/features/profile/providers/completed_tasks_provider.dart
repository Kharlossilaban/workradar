import 'package:flutter/foundation.dart';
import '../../../core/models/task.dart';

/// Data class for category count
class CategoryCount {
  final Map<String, int> categoryCounts;

  CategoryCount({Map<String, int>? categoryCounts})
      : categoryCounts = categoryCounts ?? {};

  int get total => categoryCounts.values.fold(0, (a, b) => a + b);

  void add(String category, [int count = 1]) {
    final normalizedCategory = category.toLowerCase();
    categoryCounts[normalizedCategory] =
        (categoryCounts[normalizedCategory] ?? 0) + count;
  }

  int getForCategory(String category) {
    return categoryCounts[category.toLowerCase()] ?? 0;
  }

  CategoryCount copy() {
    return CategoryCount(categoryCounts: Map.from(categoryCounts));
  }
}

/// Provider for managing completed tasks chart data with category breakdown
class CompletedTasksProvider with ChangeNotifier {
  // Map to store completed task counts by date (YYYY-MM-DD format) with category breakdown
  final Map<String, CategoryCount> _completedCounts = {};

  // Current date offset for navigation (0 = current period, -1 = previous, +1 = next)
  int _dateOffset = 0;

  int get dateOffset => _dateOffset;

  /// Sync completed tasks data from a list of tasks
  void syncFromTasks(List<Task> tasks) {
    _completedCounts.clear();
    for (final task in tasks) {
      if (task.isCompleted) {
        final date = task.deadline ?? task.completedAt ?? DateTime.now();
        final dateKey = _formatDateKey(date);
        final category = task.categoryName;

        if (!_completedCounts.containsKey(dateKey)) {
          _completedCounts[dateKey] = CategoryCount();
        }
        _completedCounts[dateKey]!.add(category);
      }
    }
    notifyListeners();
  }

  /// Record a task completion for a specific date
  void recordTaskCompletion(DateTime date, {String category = 'Kerja'}) {
    final dateKey = _formatDateKey(date);
    if (!_completedCounts.containsKey(dateKey)) {
      _completedCounts[dateKey] = CategoryCount();
    }
    _completedCounts[dateKey]!.add(category);
    notifyListeners();
  }

  /// Get completed count for a specific date (total)
  int getCompletedCount(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _completedCounts[dateKey]?.total ?? 0;
  }

  /// Get category count for a specific date
  CategoryCount getCategoryCount(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _completedCounts[dateKey]?.copy() ?? CategoryCount();
  }

  /// Get daily completed counts for a specific week (7 days)
  List<int> getDailyCounts(DateTime startOfWeek) {
    final counts = <int>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      counts.add(getCompletedCount(date));
    }
    return counts;
  }

  /// Get daily completed counts with category breakdown for a specific week
  List<CategoryCount> getDailyCategoryCounts(DateTime startOfWeek) {
    final counts = <CategoryCount>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      counts.add(getCategoryCount(date));
    }
    return counts;
  }

  /// Get weekly completed counts for a specific month (4 weeks)
  List<int> getWeeklyCounts(DateTime monthDate) {
    final counts = <int>[];
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);

    for (int week = 0; week < 4; week++) {
      int weekTotal = 0;
      final weekStart = firstDayOfMonth.add(Duration(days: week * 7));

      for (int day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        if (date.month == monthDate.month) {
          weekTotal += getCompletedCount(date);
        }
      }
      counts.add(weekTotal);
    }
    return counts;
  }

  /// Get weekly completed counts with category breakdown for a specific month
  List<CategoryCount> getWeeklyCategoryCounts(DateTime monthDate) {
    final counts = <CategoryCount>[];
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);

    for (int week = 0; week < 4; week++) {
      final weekCount = CategoryCount();
      final weekStart = firstDayOfMonth.add(Duration(days: week * 7));

      for (int day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        if (date.month == monthDate.month) {
          final dayCount = getCategoryCount(date);
          for (final entry in dayCount.categoryCounts.entries) {
            weekCount.add(entry.key, entry.value);
          }
        }
      }
      counts.add(weekCount);
    }
    return counts;
  }

  /// Get monthly completed counts for a specific year (12 months)
  List<int> getMonthlyCounts(int year) {
    final counts = <int>[];
    for (int month = 1; month <= 12; month++) {
      int monthTotal = 0;
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        monthTotal += getCompletedCount(date);
      }
      counts.add(monthTotal);
    }
    return counts;
  }

  /// Get monthly completed counts with category breakdown for a specific year
  List<CategoryCount> getMonthlyCategoryCounts(int year) {
    final counts = <CategoryCount>[];
    for (int month = 1; month <= 12; month++) {
      final monthCount = CategoryCount();
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final dayCount = getCategoryCount(date);
        for (final entry in dayCount.categoryCounts.entries) {
          monthCount.add(entry.key, entry.value);
        }
      }
      counts.add(monthCount);
    }
    return counts;
  }

  /// Check if there's any completed task data for a given week
  bool hasDataForWeek(DateTime startOfWeek) {
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (getCompletedCount(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any completed task data for a given month
  bool hasDataForMonth(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      if (getCompletedCount(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any completed task data for a given year
  bool hasDataForYear(int year) {
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        if (getCompletedCount(date) > 0) return true;
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
    _completedCounts.clear();
    _dateOffset = 0;
    notifyListeners();
  }
}
