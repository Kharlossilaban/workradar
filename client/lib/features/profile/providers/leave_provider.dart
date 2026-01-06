import 'package:flutter/foundation.dart';
import '../../../core/models/leave.dart';

class LeaveProvider with ChangeNotifier {
  // Local leave storage
  final List<Leave> _leaves = [];

  /// Get all leaves
  List<Leave> get leaves => List.unmodifiable(_leaves);

  /// Get leaves for a specific month
  List<Leave> getLeavesForMonth(int year, int month) {
    return _leaves.where((leave) {
      return leave.date.year == year && leave.date.month == month;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get leaves for a specific date
  List<Leave> getLeavesForDate(DateTime date) {
    return _leaves.where((leave) {
      return leave.date.year == date.year &&
          leave.date.month == date.month &&
          leave.date.day == date.day;
    }).toList();
  }

  /// Check if a date is a leave day
  bool isLeaveDay(DateTime date) {
    return _leaves.any(
      (leave) =>
          leave.date.year == date.year &&
          leave.date.month == date.month &&
          leave.date.day == date.day,
    );
  }

  /// Add a new leave
  void addLeave(Leave leave) {
    _leaves.add(leave);
    _leaves.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  /// Add multiple leaves (for range selection)
  void addLeaves(List<Leave> newLeaves) {
    _leaves.addAll(newLeaves);
    _leaves.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  /// Update a leave
  void updateLeave(Leave leave) {
    final index = _leaves.indexWhere((l) => l.id == leave.id);
    if (index != -1) {
      _leaves[index] = leave;
      notifyListeners();
    }
  }

  /// Delete a leave
  void deleteLeave(String leaveId) {
    _leaves.removeWhere((l) => l.id == leaveId);
    notifyListeners();
  }

  /// Delete leaves for a specific date
  void deleteLeavesForDate(DateTime date) {
    _leaves.removeWhere(
      (leave) =>
          leave.date.year == date.year &&
          leave.date.month == date.month &&
          leave.date.day == date.day,
    );
    notifyListeners();
  }

  /// Get upcoming leaves (from today onwards)
  List<Leave> getUpcomingLeaves() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _leaves.where((leave) {
      return !leave.date.isBefore(today);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get past leaves
  List<Leave> getPastLeaves() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _leaves.where((leave) {
      return leave.date.isBefore(today);
    }).toList()..sort((a, b) => b.date.compareTo(a.date)); // Descending
  }

  /// Get count of leaves in a specific month
  int getLeaveCountForMonth(int year, int month) {
    return _leaves.where((leave) {
      return leave.date.year == year && leave.date.month == month;
    }).length;
  }

  /// Get count of upcoming leaves
  int get upcomingLeaveCount => getUpcomingLeaves().length;

  /// Suggest recurring work task dates to skip based on leaves
  /// This will be used when creating recurring work tasks
  List<DateTime> getDatesSuggestedToSkip(DateTime startDate, DateTime endDate) {
    return _leaves
        .where(
          (leave) =>
              !leave.date.isBefore(startDate) && !leave.date.isAfter(endDate),
        )
        .map((leave) => leave.date)
        .toList();
  }

  /// Clear all leaves (for testing/reset)
  void clearAll() {
    _leaves.clear();
    notifyListeners();
  }

  /// Load sample leaves for demo
  void loadSampleLeaves(String userId) {
    final now = DateTime.now();

    // Add some sample upcoming leaves
    _leaves.add(
      Leave(
        id: 'leave_1',
        userId: userId,
        date: DateTime(now.year, now.month, now.day + 3),
        reason: 'Liburan keluarga',
        createdAt: DateTime.now(),
      ),
    );

    _leaves.add(
      Leave(
        id: 'leave_2',
        userId: userId,
        date: DateTime(now.year, now.month, now.day + 10),
        reason: 'Keperluan pribadi',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }
}
