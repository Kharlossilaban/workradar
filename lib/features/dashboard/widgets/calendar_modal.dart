import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import 'reminder_modal.dart';
import 'repeat_modal.dart';

class CalendarModal extends StatefulWidget {
  final DateTime? initialDate;
  final int? initialReminderMinutes;
  final RepeatType initialRepeatType;
  final int initialRepeatInterval;
  final DateTime? initialRepeatEndDate;

  const CalendarModal({
    super.key,
    this.initialDate,
    this.initialReminderMinutes,
    this.initialRepeatType = RepeatType.none,
    this.initialRepeatInterval = 1,
    this.initialRepeatEndDate,
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
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: AppTheme.textSecondary)),
          const Icon(Icons.chevron_right),
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
      builder: (context) => ReminderModal(initialMinutes: _reminderMinutes),
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

    Navigator.pop(context, {
      'deadline': deadline,
      'reminderMinutes': _reminderMinutes,
      'repeatType': _repeatType,
      'repeatInterval': _repeatInterval,
      'repeatEndDate': _repeatEndDate,
    });
  }
}
