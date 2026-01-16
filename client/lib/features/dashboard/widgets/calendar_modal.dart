import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import '../../../core/storage/secure_storage.dart';
import 'reminder_modal.dart';
import 'repeat_modal.dart';

class CalendarModal extends StatefulWidget {
  final DateTime? initialDate;
  final int? initialReminderMinutes;
  final RepeatType initialRepeatType;
  final int initialRepeatInterval;
  final DateTime? initialRepeatEndDate;
  final int? initialDurationMinutes;

  const CalendarModal({
    super.key,
    this.initialDate,
    this.initialReminderMinutes,
    this.initialRepeatType = RepeatType.none,
    this.initialRepeatInterval = 1,
    this.initialRepeatEndDate,
    this.initialDurationMinutes,
  });

  @override
  State<CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<CalendarModal> {
  late DateTime _focusedMonth;
  late DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _reminderMinutes;
  RepeatType _repeatType = RepeatType.none;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;
  int? _durationMinutes;
  bool _isVip = false; // VIP status untuk restrict fitur

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialDate ?? DateTime.now();
    _selectedDate = widget.initialDate;
    if (widget.initialDate != null) {
      _selectedTime = TimeOfDay.fromDateTime(widget.initialDate!);
    }
    _reminderMinutes = widget.initialReminderMinutes;
    _repeatType = widget.initialRepeatType;
    _repeatInterval = widget.initialRepeatInterval;
    _repeatEndDate = widget.initialRepeatEndDate;
    _durationMinutes = widget.initialDurationMinutes;
    _loadVipStatus();
  }

  Future<void> _loadVipStatus() async {
    final userType = await SecureStorage.getUserType();
    if (mounted) {
      setState(() {
        _isVip = userType == 'vip';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Month navigation
              _buildMonthNavigation(),

              const SizedBox(height: 16),

              // Day headers
              _buildDayHeaders(),

              const SizedBox(height: 8),

              // Calendar grid
              _buildCalendarGrid(),

              const SizedBox(height: 16),

              const Divider(),

              // Time setting
              _buildSettingTile(
                icon: Iconsax.clock,
                title: 'Waktu',
                value: _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Tidak diatur',
                onTap: _selectTime,
              ),

              // Reminder setting
              _buildSettingTile(
                icon: Iconsax.notification,
                title: 'Pengingat',
                value: _reminderMinutes != null
                    ? '$_reminderMinutes menit sebelumnya'
                    : 'Tidak ada',
                onTap: _showReminderModal,
              ),

              // Repeat setting
              _buildSettingTile(
                icon: Iconsax.repeat,
                title: 'Ulangi',
                value: _repeatType != RepeatType.none
                    ? _getRepeatString()
                    : 'Tidak',
                onTap: _showRepeatModal,
              ),

              // Duration setting
              _buildSettingTile(
                icon: Iconsax.timer_1,
                title: 'Durasi',
                value: _getDurationString(),
                onTap: _selectDuration,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Selesai'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              );
            });
          },
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        Text(
          DateFormat('MMMM yyyy', 'id_ID').format(_focusedMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month + 1,
              );
            });
          },
          icon: const Icon(Iconsax.arrow_right_3),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => SizedBox(
              width: 36,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = ((firstWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayOffset = index - (firstWeekday - 1);

        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox();
        }

        final date = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayOffset + 1,
        );
        final isSelected =
            _selectedDate != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;
        final isToday =
            date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : null,
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${dayOffset + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  void _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _showReminderModal() async {
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => ReminderModal(
        initialMinutes: _reminderMinutes,
        isVip: _isVip, // Pass VIP status untuk restrict options
      ),
    );

    if (result != null) {
      setState(() => _reminderMinutes = result == 0 ? null : result);
    }
  }

  void _showRepeatModal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RepeatModal(
        initialRepeatType: _repeatType,
        initialRepeatInterval: _repeatInterval,
        initialEndDate: _repeatEndDate,
        isVip: _isVip, // Pass VIP status untuk restrict end date
      ),
    );

    if (result != null) {
      setState(() {
        _repeatType = result['repeatType'];
        _repeatInterval = result['repeatInterval'];
        _repeatEndDate = result['endDate'];
      });
    }
  }

  String _getRepeatString() {
    String typeStr;
    switch (_repeatType) {
      case RepeatType.hourly:
        typeStr = 'Setiap $_repeatInterval jam';
        break;
      case RepeatType.daily:
        typeStr = 'Setiap $_repeatInterval hari';
        break;
      case RepeatType.weekly:
        typeStr = 'Setiap $_repeatInterval minggu';
        break;
      case RepeatType.monthly:
        typeStr = 'Setiap $_repeatInterval bulan';
        break;
      default:
        typeStr = 'Tidak';
    }
    return typeStr;
  }

  String _getDurationString() {
    if (_durationMinutes == null) return 'Tidak diatur';
    final hours = _durationMinutes! ~/ 60;
    final minutes = _durationMinutes! % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}j ${minutes}m';
    } else if (hours > 0) {
      return '${hours}j';
    } else {
      return '${minutes}m';
    }
  }

  void _selectDuration() async {
    int hours = (_durationMinutes ?? 0) ~/ 60;
    int minutes = (_durationMinutes ?? 0) % 60;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        int tempHours = hours;
        int tempMinutes = minutes;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Atur Durasi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('Jam'),
                          DropdownButton<int>(
                            value: tempHours,
                            items: List.generate(24, (i) => i)
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('$i'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => tempHours = val);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      Column(
                        children: [
                          const Text('Menit'),
                          DropdownButton<int>(
                            value: tempMinutes,
                            items: List.generate(60, (i) => i)
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('$i'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => tempMinutes = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, tempHours * 60 + tempMinutes);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _durationMinutes = result == 0 ? null : result);
    }
  }

  void _saveSettings() {
    DateTime? deadline;
    if (_selectedDate != null) {
      if (_selectedTime != null) {
        deadline = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      } else {
        deadline = _selectedDate;
      }
    }

    // Check if selected date is in the past
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      _showPastDateWarning(deadline);
    } else {
      _returnSettings(deadline);
    }
  }

  void _showPastDateWarning(DateTime deadline) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tanggal Sudah Lewat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Tanggal yang Anda pilih (${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(deadline)}) sudah berlalu.\n\nApakah Anda yakin ingin melanjutkan?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close warning
                      // User can select new date
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Ubah Tanggal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close warning
                      _returnSettings(deadline); // Proceed with past date
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Lanjutkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _returnSettings(DateTime? deadline) {
    Navigator.pop(context, {
      'deadline': deadline,
      'reminderMinutes': _reminderMinutes,
      'repeatType': _repeatType,
      'repeatInterval': _repeatInterval,
      'repeatEndDate': _repeatEndDate,
      'durationMinutes': _durationMinutes,
    });
  }
}
