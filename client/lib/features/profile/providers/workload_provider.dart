import 'package:flutter/foundation.dart';
import '../../../core/models/task.dart';

/// Provider for managing workload chart data and date navigation
class WorkloadProvider with ChangeNotifier {
  // Map to store task duration sum by date (YYYY-MM-DD format)
  final Map<String, int> _taskDurations = {};

  // Current date offset for navigation (0 = current period, -1 = previous, +1 = next)
  int _dateOffset = 0;

  int get dateOffset => _dateOffset;

  /// Get total all-time workload in minutes
  int get totalAllTimeWorkload {
    int total = 0;
    for (final duration in _taskDurations.values) {
      total += duration;
    }
    return total;
  }

  /// Sync workload data from a list of tasks
  void syncFromTasks(List<Task> tasks) {
    _taskDurations.clear();
    for (final task in tasks) {
      if (task.isCompleted) {
        // Use deadline if available, otherwise fallback to completion time or now
        final date = task.deadline ?? task.completedAt ?? DateTime.now();
        final dateKey = _formatDateKey(date);
        // Add duration (default to 30 mins if not set, or according to user preference)
        // For now, if duration is null, we treat it as 0 or a minimal value
        final duration = task.durationMinutes ?? 0;
        _taskDurations[dateKey] = (_taskDurations[dateKey] ?? 0) + duration;
      }
    }
    notifyListeners();
  }

  /// Record a task completion for a specific date
  void recordTaskCompletion(DateTime date, {int duration = 0}) {
    final dateKey = _formatDateKey(date);
    _taskDurations[dateKey] = (_taskDurations[dateKey] ?? 0) + duration;
    notifyListeners();
  }

  /// Record a scheduled task (for real-time workload tracking)
  /// This updates workload immediately when a task is added, not just when completed
  void recordScheduledTask(DateTime date, {required int duration}) {
    if (duration <= 0) return; // Don't track tasks without duration
    final dateKey = _formatDateKey(date);
    _taskDurations[dateKey] = (_taskDurations[dateKey] ?? 0) + duration;
    notifyListeners();
  }

  /// Remove a scheduled task from workload (when task is deleted before completion)
  void removeScheduledTask(DateTime date, {required int duration}) {
    if (duration <= 0) return;
    final dateKey = _formatDateKey(date);
    final currentDuration = _taskDurations[dateKey] ?? 0;
    _taskDurations[dateKey] = (currentDuration - duration)
        .clamp(0, double.infinity)
        .toInt();
    notifyListeners();
  }

  /// Get total duration for a specific date
  int getTotalDuration(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _taskDurations[dateKey] ?? 0;
  }

  /// Get daily durations for a specific week (7 days)
  List<int> getDailyDurations(DateTime startOfWeek) {
    final durations = <int>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      durations.add(getTotalDuration(date));
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
