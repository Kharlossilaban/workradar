import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';

class RepeatModal extends StatefulWidget {
  final RepeatType initialRepeatType;
  final int initialRepeatInterval;
  final DateTime? initialEndDate;

  const RepeatModal({
    super.key,
    this.initialRepeatType = RepeatType.none,
    this.initialRepeatInterval = 1,
    this.initialEndDate,
  });

  @override
  State<RepeatModal> createState() => _RepeatModalState();
}

class _RepeatModalState extends State<RepeatModal> {
  bool _isEnabled = false;
  RepeatType _repeatType = RepeatType.daily;
  int _repeatInterval = 1;
  bool _hasEndDate = false;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialRepeatType != RepeatType.none;
    _repeatType = widget.initialRepeatType == RepeatType.none
        ? RepeatType.daily
        : widget.initialRepeatType;
    _repeatInterval = widget.initialRepeatInterval;
    _hasEndDate = widget.initialEndDate != null;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tetapkan sebagai Ulangi Tugas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),

              if (_isEnabled) ...[
                const SizedBox(height: 20),

                // Repeat type buttons
                Row(
                  children: [
                    _buildTypeButton('Jam', RepeatType.hourly),
                    const SizedBox(width: 8),
                    _buildTypeButton('Harian', RepeatType.daily),
                    const SizedBox(width: 8),
                    _buildTypeButton('Mingguan', RepeatType.weekly),
                    const SizedBox(width: 8),
                    _buildTypeButton('Bulanan', RepeatType.monthly),
                  ],
                ),

                const SizedBox(height: 20),

                // Repeat interval
                const Text(
                  'Ulangi Setiap',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    value: _repeatInterval,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: List.generate(30, (index) => index + 1).map((num) {
                      return DropdownMenuItem(
                        value: num,
                        child: Text('$num ${_getIntervalUnit()}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _repeatInterval = value);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // End date
                const Text(
                  'Ulangi berakhir pada',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _hasEndDate && _endDate != null
                              ? DateFormat(
                                  'dd MMMM yyyy',
                                  'id_ID',
                                ).format(_endDate!)
                              : 'Tanpa henti',
                          style: TextStyle(
                            color: _hasEndDate
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'repeatType': _isEnabled
                            ? _repeatType
                            : RepeatType.none,
                        'repeatInterval': _repeatInterval,
                        'endDate': _hasEndDate ? _endDate : null,
                      });
                    },
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

  Widget _buildTypeButton(String label, RepeatType type) {
    final isSelected = _repeatType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _repeatType = type);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  String _getIntervalUnit() {
    switch (_repeatType) {
      case RepeatType.hourly:
        return 'jam';
      case RepeatType.daily:
        return 'hari';
      case RepeatType.weekly:
        return 'minggu';
      case RepeatType.monthly:
        return 'bulan';
      default:
        return '';
    }
  }

  void _selectEndDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (result != null) {
      setState(() {
        _hasEndDate = true;
        _endDate = result;
      });
    } else {
      // User can choose "Tanpa henti" by dismissing the picker
      setState(() {
        _hasEndDate = false;
        _endDate = null;
      });
    }
  }
}
