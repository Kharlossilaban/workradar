import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';

class RepeatModal extends StatefulWidget {
  final RepeatType initialRepeatType;
  final int initialRepeatInterval;
  final DateTime? initialEndDate;
  final bool isVip; // VIP status untuk restrict end date

  const RepeatModal({
    super.key,
    this.initialRepeatType = RepeatType.none,
    this.initialRepeatInterval = 1,
    this.initialEndDate,
    this.isVip = false, // Default non-VIP
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
                  const Expanded(
                    child: Text(
                      'Tetapkan sebagai Ulangi Tugas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.primaryColor,
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    value: _repeatInterval.clamp(1, _getMaxInterval()),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items:
                        List.generate(
                          _getMaxInterval(),
                          (index) => index + 1,
                        ).map((interval) {
                          return DropdownMenuItem(
                            value: interval,
                            child: Text(
                              '$interval ${_getIntervalUnit()}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

                // End date - VIP ONLY FEATURE
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Ulangi berakhir pada',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.vipGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.crown_15,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.isVip ? _selectEndDate : _showVipUpgradePrompt,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isVip
                            ? Colors.grey.shade300
                            : Colors.grey.shade200,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: widget.isVip ? null : Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.isVip
                                ? (_hasEndDate && _endDate != null
                                      ? DateFormat(
                                          'dd MMMM yyyy',
                                          'id_ID',
                                        ).format(_endDate!)
                                      : 'Tanpa henti')
                                : 'Upgrade ke VIP untuk fitur ini',
                            style: TextStyle(
                              color: widget.isVip
                                  ? (_hasEndDate
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary)
                                  : AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          widget.isVip ? Icons.calendar_today : Iconsax.lock,
                          size: 20,
                          color: widget.isVip ? null : AppTheme.textSecondary,
                        ),
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
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'repeatType': _isEnabled
                              ? _repeatType
                              : RepeatType.none,
                          'repeatInterval': _repeatInterval,
                          'endDate': _hasEndDate ? _endDate : null,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Selesai'),
                    ),
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
          setState(() {
            _repeatType = type;
            // Reset interval to 1 when changing type to avoid invalid values
            _repeatInterval = 1;
          });
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

  // Get max interval based on repeat type
  // Jam: 1-12, Harian: 1-30, Mingguan: 1-10, Bulanan: 1-12
  int _getMaxInterval() {
    switch (_repeatType) {
      case RepeatType.hourly:
        return 12; // Per 1-12 jam
      case RepeatType.daily:
        return 30; // Per 1-30 hari
      case RepeatType.weekly:
        return 10; // Per 1-10 minggu
      case RepeatType.monthly:
        return 12; // Per 1-12 bulan
      default:
        return 1;
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

  void _showVipUpgradePrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.vipGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Iconsax.crown_15,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Fitur VIP'),
          ],
        ),
        content: const Text(
          'Atur tanggal berakhir pengulangan tugas adalah fitur eksklusif untuk member VIP.\n\nUpgrade sekarang untuk akses fitur premium lainnya!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close repeat modal
              // Navigate to subscription screen
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.vipGold),
            child: const Text('Upgrade VIP'),
          ),
        ],
      ),
    );
  }
}
