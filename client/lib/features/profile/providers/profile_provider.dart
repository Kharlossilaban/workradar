import 'package:flutter/material.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';

/// Model for daily work hours
class DailyWorkHours {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool isWorkDay;

  DailyWorkHours({this.start, this.end, this.isWorkDay = true});

  bool get hasHours => start != null && end != null;

  int get totalMinutes {
    if (!hasHours) return 0;
    final startMinutes = start!.hour * 60 + start!.minute;
    final endMinutes = end!.hour * 60 + end!.minute;

    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    } else {
      return (24 * 60 - startMinutes) + endMinutes;
    }
  }

  DailyWorkHours copyWith({TimeOfDay? start, TimeOfDay? end, bool? isWorkDay}) {
    return DailyWorkHours(
      start: start ?? this.start,
      end: end ?? this.end,
      isWorkDay: isWorkDay ?? this.isWorkDay,
    );
  }
}

class ProfileProvider with ChangeNotifier {
  final ProfileApiService _apiService = ProfileApiService();

  String _username = '';
  String _gmail = '';
  String? _userId;

  // Stats from server
  int _totalTasks = 0;
  int _completedTasks = 0;
  double _completionRate = 0.0;
  int _todayTasks = 0;
  int _pendingTasks = 0;

  bool _isLoading = false;
  String? _errorMessage;

  // Constructor: Load username from storage on init
  ProfileProvider() {
    _loadUsernameFromStorage();
  }

  /// Load username from secure storage (fallback for quick display)
  Future<void> _loadUsernameFromStorage() async {
    final storedUsername = await SecureStorage.getUsername();
    if (storedUsername != null && storedUsername.isNotEmpty) {
      _username = storedUsername;
      notifyListeners();
    }
  }

  // Legacy single work hours (for backward compatibility)
  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;

  // New: Work hours per day (Monday = 0, Sunday = 6)
  final Map<int, DailyWorkHours> _workDays = {
    0: DailyWorkHours(isWorkDay: true), // Monday
    1: DailyWorkHours(isWorkDay: true), // Tuesday
    2: DailyWorkHours(isWorkDay: true), // Wednesday
    3: DailyWorkHours(isWorkDay: true), // Thursday
    4: DailyWorkHours(isWorkDay: true), // Friday
    5: DailyWorkHours(isWorkDay: false), // Saturday
    6: DailyWorkHours(isWorkDay: false), // Sunday
  };

  // Getters
  String get username => _username;
  String get gmail => _gmail;
  String? get userId => _userId;
  TimeOfDay? get workStart => _workStart;
  TimeOfDay? get workEnd => _workEnd;

  int get totalTasks => _totalTasks;
  int get completedTasks => _completedTasks;
  double get completionRate => _completionRate;
  int get todayTasks => _todayTasks;
  int get pendingTasks => _pendingTasks;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get work hours for specific day (0 = Monday, 6 = Sunday)
  DailyWorkHours getWorkHoursForDay(int dayIndex) {
    return _workDays[dayIndex] ?? DailyWorkHours(isWorkDay: false);
  }

  // Get all work days
  Map<int, DailyWorkHours> get workDays => Map.unmodifiable(_workDays);

  // Check if user has configured any work hours
  bool get hasWorkHours => _workStart != null && _workEnd != null;

  // Get work days list (indices of days that are work days)
  List<int> get workDayIndices {
    return _workDays.entries
        .where((entry) => entry.value.isWorkDay)
        .map((entry) => entry.key)
        .toList();
  }

  // Get work days names
  List<String> get workDayNames {
    const dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return workDayIndices.map((index) => dayNames[index]).toList();
  }

  String get workHoursRange {
    if (!hasWorkHours) return '';
    final start = _formatTime(_workStart!);
    final end = _formatTime(_workEnd!);
    return '$start - $end WIB';
  }

  // Get work hours range for specific day
  String getWorkHoursRangeForDay(int dayIndex) {
    final dayHours = _workDays[dayIndex];
    if (dayHours == null || !dayHours.hasHours) return 'Libur';
    final start = _formatTime(dayHours.start!);
    final end = _formatTime(dayHours.end!);
    return '$start - $end';
  }

  int get totalWorkMinutes {
    if (!hasWorkHours) return 0;
    final startMinutes = _workStart!.hour * 60 + _workStart!.minute;
    final endMinutes = _workEnd!.hour * 60 + _workEnd!.minute;

    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    } else {
      return (24 * 60 - startMinutes) + endMinutes;
    }
  }

  // Get total work minutes for a specific day
  int getTotalWorkMinutesForDay(int dayIndex) {
    final dayHours = _workDays[dayIndex];
    if (dayHours == null || !dayHours.isWorkDay) return 0;
    return dayHours.totalMinutes;
  }

  // ==================== API METHODS ====================

  /// Load profile and stats from server
  Future<void> loadProfileFromServer() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profileResponse = await _apiService.getProfile();

      // Update user data
      _username = profileResponse.user.username;
      _gmail = profileResponse.user.email;
      _userId = profileResponse.user.id;

      // Update stats
      _totalTasks = profileResponse.stats.totalTasks;
      _completedTasks = profileResponse.stats.completedTasks;
      _completionRate = profileResponse.stats.completionRate;
      _todayTasks = profileResponse.stats.todayTasks;
      _pendingTasks = profileResponse.stats.pendingTasks;

      // Load work hours from backend
      try {
        await _loadWorkHours();
      } catch (e) {
        // Don't fail entire profile load if work hours fail
        debugPrint('Failed to load work hours: $e');
      }

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat profil: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update profile on server
  Future<void> updateProfileOnServer({String? username}) async {
    try {
      final updatedUser = await _apiService.updateProfile(username: username);

      _username = updatedUser.username;
      _gmail = updatedUser.email;

      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui profil: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Change password on server
  Future<void> changePasswordOnServer({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal mengubah password: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Load work hours from backend
  Future<void> _loadWorkHours() async {
    try {
      final workHoursData = await _apiService.getWorkHours();

      if (workHoursData.isEmpty) return;

      // Parse work hours data from backend
      for (int i = 0; i < 7; i++) {
        final dayData = workHoursData[i.toString()];
        if (dayData != null && dayData is Map<String, dynamic>) {
          final isWorkDay = dayData['is_work_day'] as bool? ?? false;

          TimeOfDay? start;
          TimeOfDay? end;

          if (isWorkDay) {
            final startStr = dayData['start'] as String?;
            final endStr = dayData['end'] as String?;

            if (startStr != null && endStr != null) {
              start = _parseTimeOfDay(startStr);
              end = _parseTimeOfDay(endStr);
            }
          }

          _workDays[i] = DailyWorkHours(
            start: start,
            end: end,
            isWorkDay: isWorkDay,
          );

          // Update legacy values
          if (isWorkDay && start != null && end != null) {
            _workStart ??= start;
            _workEnd ??= end;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading work hours: $e');
      rethrow;
    }
  }

  /// Parse time string (HH:mm) to TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 0, minute: 0);
  }

  // ==================== LOCAL METHODS ====================

  void updateProfile({String? username, String? gmail}) {
    if (username != null) _username = username;
    if (gmail != null) _gmail = gmail;
    notifyListeners();
  }

  // Legacy method for backward compatibility
  void setWorkHours(TimeOfDay start, TimeOfDay end) {
    _workStart = start;
    _workEnd = end;

    // Apply to all work days Mon-Fri by default
    for (int i = 0; i <= 4; i++) {
      _workDays[i] = DailyWorkHours(start: start, end: end, isWorkDay: true);
    }

    notifyListeners();
  }

  // Set work hours for a specific day
  void setWorkHoursForDay(
    int dayIndex, {
    TimeOfDay? start,
    TimeOfDay? end,
    bool? isWorkDay,
  }) {
    if (!_workDays.containsKey(dayIndex)) return;

    final currentDayHours = _workDays[dayIndex]!;
    _workDays[dayIndex] = currentDayHours.copyWith(
      start: start,
      end: end,
      isWorkDay: isWorkDay,
    );

    // Update legacy values to first work day's hours
    if (_workDays[dayIndex]!.hasHours) {
      _workStart = start ?? _workDays[dayIndex]!.start;
      _workEnd = end ?? _workDays[dayIndex]!.end;
    }

    notifyListeners();
  }

  // Toggle work day status
  void toggleWorkDay(int dayIndex) {
    if (!_workDays.containsKey(dayIndex)) return;

    final currentDayHours = _workDays[dayIndex]!;
    _workDays[dayIndex] = currentDayHours.copyWith(
      isWorkDay: !currentDayHours.isWorkDay,
    );

    notifyListeners();
  }

  // Set same hours for all work days
  void setWorkHoursForAllDays(
    TimeOfDay start,
    TimeOfDay end,
    List<int> workDayIndices,
  ) {
    for (int i = 0; i < 7; i++) {
      _workDays[i] = DailyWorkHours(
        start: workDayIndices.contains(i) ? start : null,
        end: workDayIndices.contains(i) ? end : null,
        isWorkDay: workDayIndices.contains(i),
      );
    }

    _workStart = start;
    _workEnd = end;
    notifyListeners();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
