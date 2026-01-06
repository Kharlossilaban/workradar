import 'package:flutter/material.dart';
import '../models/task.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/profile/providers/holiday_provider.dart';

/// Extension for Work category smart features
class WorkTaskHelper {
  /// Check if a task was completed during overtime (outside work hours)
  /// Returns true if completed outside the user's defined work hours
  static bool isOvertimeWork(Task task, ProfileProvider profileProvider) {
    if (!task.isCompleted || task.completedAt == null) return false;
    if (task.categoryName.toLowerCase() != 'kerja') return false;

    final completedAt = task.completedAt!;
    final dayOfWeek = _getMondayBasedDayIndex(completedAt);
    final dayWorkHours = profileProvider.getWorkHoursForDay(dayOfWeek);

    // If not a work day, it's not overtime (it's weekend work)
    if (!dayWorkHours.isWorkDay || !dayWorkHours.hasHours) return false;

    final completedTime = TimeOfDay.fromDateTime(completedAt);
    final completedMinutes = completedTime.hour * 60 + completedTime.minute;

    final startMinutes =
        dayWorkHours.start!.hour * 60 + dayWorkHours.start!.minute;
    final endMinutes = dayWorkHours.end!.hour * 60 + dayWorkHours.end!.minute;

    // Check if completed outside work hours
    return completedMinutes < startMinutes || completedMinutes > endMinutes;
  }

  /// Check if a task was completed on a weekend/non-work day
  /// Returns true if completed on a day that's not configured as work day
  static bool isWeekendWork(
    Task task,
    ProfileProvider profileProvider,
    HolidayProvider holidayProvider,
  ) {
    if (!task.isCompleted || task.completedAt == null) return false;
    if (task.categoryName.toLowerCase() != 'kerja') return false;

    final completedAt = task.completedAt!;

    // Check if it's a holiday
    if (holidayProvider.isHoliday(completedAt)) return true;

    // Check if it's not a configured work day
    final dayOfWeek = _getMondayBasedDayIndex(completedAt);
    final dayWorkHours = profileProvider.getWorkHoursForDay(dayOfWeek);

    return !dayWorkHours.isWorkDay;
  }

  /// Get workload multiplier for a work task
  /// Returns:
  /// - 1.5 for overtime work (outside work hours)
  /// - 1.3 for weekend/holiday work
  /// - 1.0 for normal work
  static double getWorkloadMultiplier(
    Task task,
    ProfileProvider profileProvider,
    HolidayProvider holidayProvider,
  ) {
    if (task.categoryName.toLowerCase() != 'kerja') return 1.0;

    // Weekend work has priority over overtime
    if (isWeekendWork(task, profileProvider, holidayProvider)) {
      return 1.3;
    }

    if (isOvertimeWork(task, profileProvider)) {
      return 1.5;
    }

    return 1.0;
  }

  /// Get effective workload duration with multiplier applied
  static int getEffectiveWorkload(
    Task task,
    ProfileProvider profileProvider,
    HolidayProvider holidayProvider,
  ) {
    if (task.durationMinutes == null) return 0;

    final multiplier = getWorkloadMultiplier(
      task,
      profileProvider,
      holidayProvider,
    );

    return (task.durationMinutes! * multiplier).round();
  }

  /// Get workload badge text for UI display
  static String? getWorkloadBadge(
    Task task,
    ProfileProvider profileProvider,
    HolidayProvider holidayProvider,
  ) {
    if (task.categoryName.toLowerCase() != 'kerja') return null;
    if (!task.isCompleted) return null;

    if (isWeekendWork(task, profileProvider, holidayProvider)) {
      return '🌅 Weekend +30%';
    }

    if (isOvertimeWork(task, profileProvider)) {
      return '⏰ Lembur +50%';
    }

    return null;
  }

  /// Check if a date should be included in smart repeat for work tasks
  /// Returns false for weekends and holidays
  static bool shouldRepeatOnDate(
    DateTime date,
    ProfileProvider profileProvider,
    HolidayProvider holidayProvider,
  ) {
    // Check holidays
    if (holidayProvider.isHoliday(date)) return false;

    // Check if it's a work day
    final dayOfWeek = _getMondayBasedDayIndex(date);
    final dayWorkHours = profileProvider.getWorkHoursForDay(dayOfWeek);

    return dayWorkHours.isWorkDay;
  }

  /// Helper: Convert DateTime to Monday-based day index (0=Monday, 6=Sunday)
  static int _getMondayBasedDayIndex(DateTime date) {
    // DateTime.weekday: 1=Monday, 7=Sunday
    // We need: 0=Monday, 6=Sunday
    return date.weekday - 1;
  }
}
