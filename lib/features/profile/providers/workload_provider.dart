import 'package:flutter/foundation.dart';

/// Provider for managing workload chart data and date navigation
class WorkloadProvider with ChangeNotifier {
  // Map to store task completion counts by date (YYYY-MM-DD format)
  final Map<String, int> _taskCompletions = {};

  // Current date offset for navigation (0 = current period, -1 = previous, +1 = next)
  int _dateOffset = 0;

  int get dateOffset => _dateOffset;

  /// Record a task completion for a specific date
  void recordTaskCompletion(DateTime date) {
    final dateKey = _formatDateKey(date);
    _taskCompletions[dateKey] = (_taskCompletions[dateKey] ?? 0) + 1;
    notifyListeners();
  }

  /// Get task count for a specific date
  int getTaskCount(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _taskCompletions[dateKey] ?? 0;
  }

  /// Get daily task counts for a specific week (7 days)
  List<int> getDailyTaskCounts(DateTime startOfWeek) {
    final counts = <int>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      counts.add(getTaskCount(date));
    }
    return counts;
  }

  /// Get weekly task counts for a specific month (4 weeks)
  List<int> getWeeklyTaskCounts(DateTime monthDate) {
    final counts = <int>[];
    // Get first day of month
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);

    // Calculate 4 weeks from start of month
    for (int week = 0; week < 4; week++) {
      int weekTotal = 0;
      final weekStart = firstDayOfMonth.add(Duration(days: week * 7));

      // Sum up tasks for 7 days in this week
      for (int day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        // Only count if still in the same month
        if (date.month == monthDate.month) {
          weekTotal += getTaskCount(date);
        }
      }
      counts.add(weekTotal);
    }
    return counts;
  }

  /// Get monthly task counts for a specific year (12 months)
  List<int> getMonthlyTaskCounts(int year) {
    final counts = <int>[];
    for (int month = 1; month <= 12; month++) {
      int monthTotal = 0;
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        monthTotal += getTaskCount(date);
      }
      counts.add(monthTotal);
    }
    return counts;
  }

  /// Check if there's any task data for a given week
  bool hasDataForWeek(DateTime startOfWeek) {
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (getTaskCount(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any task data for a given month
  bool hasDataForMonth(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      if (getTaskCount(date) > 0) return true;
    }
    return false;
  }

  /// Check if there's any task data for a given year
  bool hasDataForYear(int year) {
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        if (getTaskCount(date) > 0) return true;
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
    _taskCompletions.clear();
    _dateOffset = 0;
    notifyListeners();
  }

  /// Add sample data for testing
  void addSampleData() {
    final now = DateTime.now();

    // Add some tasks for this week
    for (int i = 0; i < 7; i++) {
      final date = now
          .subtract(Duration(days: now.weekday - 1))
          .add(Duration(days: i));
      final count = (i % 3) + 1; // Varying counts
      for (int j = 0; j < count; j++) {
        recordTaskCompletion(date);
      }
    }

    // Add some tasks for previous weeks this month
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    for (int day = 1; day < now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final count = day % 4;
      for (int j = 0; j < count; j++) {
        recordTaskCompletion(date);
      }
    }
  }
}
