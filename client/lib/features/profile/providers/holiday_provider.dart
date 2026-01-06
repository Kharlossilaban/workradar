import 'package:flutter/foundation.dart';
import '../../../core/models/holiday.dart';
import '../../../core/data/indonesian_holidays.dart';

class HolidayProvider with ChangeNotifier {
  // Personal holidays (user-created)
  final List<Holiday> _personalHolidays = [];

  /// Get all personal holidays
  List<Holiday> get personalHolidays => List.unmodifiable(_personalHolidays);

  /// Get national holidays for a specific year
  List<Holiday> getNationalHolidays(int year) {
    return IndonesianHolidays.getHolidaysForYear(year);
  }

  /// Get all holidays (national + personal) for a specific date
  List<Holiday> getHolidaysForDate(DateTime date) {
    final holidays = <Holiday>[];

    // Check national holidays
    final nationalHoliday = IndonesianHolidays.getHolidayForDate(date);
    if (nationalHoliday != null) {
      holidays.add(nationalHoliday);
    }

    // Check personal holidays
    for (final holiday in _personalHolidays) {
      if (holiday.date.year == date.year &&
          holiday.date.month == date.month &&
          holiday.date.day == date.day) {
        holidays.add(holiday);
      }
    }

    return holidays;
  }

  /// Check if a date is a holiday (national or personal)
  bool isHoliday(DateTime date) {
    return getHolidaysForDate(date).isNotEmpty;
  }

  /// Check if a date is a national holiday
  bool isNationalHoliday(DateTime date) {
    return IndonesianHolidays.isNationalHoliday(date);
  }

  /// Check if a date is a personal holiday
  bool isPersonalHoliday(DateTime date) {
    return _personalHolidays.any(
      (holiday) =>
          holiday.date.year == date.year &&
          holiday.date.month == date.month &&
          holiday.date.day == date.day,
    );
  }

  /// Add a personal holiday
  void addPersonalHoliday(Holiday holiday) {
    // Ensure it's marked as non-national
    final personalHoliday = holiday.copyWith(isNational: false);
    _personalHolidays.add(personalHoliday);
    notifyListeners();
  }

  /// Remove a personal holiday
  void removePersonalHoliday(String holidayId) {
    _personalHolidays.removeWhere((h) => h.id == holidayId);
    notifyListeners();
  }

  /// Update a personal holiday
  void updatePersonalHoliday(Holiday holiday) {
    final index = _personalHolidays.indexWhere((h) => h.id == holiday.id);
    if (index != -1) {
      _personalHolidays[index] = holiday.copyWith(isNational: false);
      notifyListeners();
    }
  }

  /// Get all holidays (national + personal) for a specific month
  List<Holiday> getHolidaysForMonth(int year, int month) {
    final holidays = <Holiday>[];

    // Get national holidays for the year
    final nationalHolidays = getNationalHolidays(year);
    holidays.addAll(nationalHolidays.where((h) => h.date.month == month));

    // Get personal holidays for the month
    holidays.addAll(
      _personalHolidays.where(
        (h) => h.date.year == year && h.date.month == month,
      ),
    );

    // Sort by date
    holidays.sort((a, b) => a.date.compareTo(b.date));

    return holidays;
  }

  /// Get all holidays (national + personal) for a specific year
  List<Holiday> getAllHolidaysForYear(int year) {
    final holidays = <Holiday>[];

    // Get national holidays
    holidays.addAll(getNationalHolidays(year));

    // Get personal holidays for the year
    holidays.addAll(_personalHolidays.where((h) => h.date.year == year));

    // Sort by date
    holidays.sort((a, b) => a.date.compareTo(b.date));

    return holidays;
  }

  /// Get holidays in a date range
  List<Holiday> getHolidaysInRange(DateTime start, DateTime end) {
    final holidays = <Holiday>[];

    // Get national holidays in range
    holidays.addAll(IndonesianHolidays.getHolidaysInRange(start, end));

    // Get personal holidays in range
    holidays.addAll(
      _personalHolidays.where(
        (h) => !h.date.isBefore(start) && !h.date.isAfter(end),
      ),
    );

    // Sort by date
    holidays.sort((a, b) => a.date.compareTo(b.date));

    return holidays;
  }

  /// Clear all personal holidays (for testing/reset)
  void clearPersonalHolidays() {
    _personalHolidays.clear();
    notifyListeners();
  }
}
