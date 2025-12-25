import 'package:flutter/material.dart';

class ProfileProvider with ChangeNotifier {
  String _username = 'John Doe';
  String _gmail = 'john.doe@gmail.com';
  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;

  String get username => _username;
  String get gmail => _gmail;
  TimeOfDay? get workStart => _workStart;
  TimeOfDay? get workEnd => _workEnd;

  bool get hasWorkHours => _workStart != null && _workEnd != null;

  String get workHoursRange {
    if (!hasWorkHours) return '';
    final start = _formatTime(_workStart!);
    final end = _formatTime(_workEnd!);
    return '$start - $end WIB';
  }

  int get totalWorkMinutes {
    if (!hasWorkHours) return 0;
    final startMinutes = _workStart!.hour * 60 + _workStart!.minute;
    final endMinutes = _workEnd!.hour * 60 + _workEnd!.minute;

    // Handle overnight shifts if necessary, though unlikely for this app
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    } else {
      // 24 hours wrap around
      return (24 * 60 - startMinutes) + endMinutes;
    }
  }

  void updateProfile({String? username, String? gmail}) {
    if (username != null) _username = username;
    if (gmail != null) _gmail = gmail;
    notifyListeners();
  }

  void setWorkHours(TimeOfDay start, TimeOfDay end) {
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
