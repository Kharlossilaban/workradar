import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/profile_api_service.dart';
import '../providers/profile_provider.dart';

class WorkDaysConfigSheet extends StatefulWidget {
  final ProfileProvider provider;
  final bool isFirstTimeSetup;
  final VoidCallback? onSaveComplete;

  const WorkDaysConfigSheet({
    super.key,
    required this.provider,
    this.isFirstTimeSetup = false,
    this.onSaveComplete,
  });

  @override
  State<WorkDaysConfigSheet> createState() => _WorkDaysConfigSheetState();
}

class _WorkDaysConfigSheetState extends State<WorkDaysConfigSheet> {
  // Day names in Indonesian
  static const List<String> dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  // Track which days are work days (local state)
  late Map<int, bool> workDayStatus;
  TimeOfDay? globalStartTime;
  TimeOfDay? globalEndTime;

  @override
  void initState() {
    super.initState();
    // Initialize with current settings
    workDayStatus = {};
    for (int i = 0; i < 7; i++) {
      workDayStatus[i] = widget.provider.getWorkHoursForDay(i).isWorkDay;
    }
    globalStartTime = widget.provider.workStart;
    globalEndTime = widget.provider.workEnd;
  }

  Future<void> _selectGlobalTimes() async {
    final start = await showTimePicker(
      context: context,
      initialTime: globalStartTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Pilih Jam Mulai Kerja',
    );

    if (start == null) return;

    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: globalEndTime ?? const TimeOfDay(hour: 17, minute: 0),
      helpText: 'Pilih Jam Selesai Kerja',
    );

    if (end == null) return;

    setState(() {
      globalStartTime = start;
      globalEndTime = end;
    });
  }

  void _save() {
    if (globalStartTime == null || globalEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap atur jam kerja terlebih dahulu')),
      );
      return;
    }

    // Get selected work day indices
    final selectedDays = workDayStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih minimal satu hari kerja')),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi'),
        content: Text(
          'Yakin ingin menyimpan jadwal kerja?\n\n'
          '${selectedDays.length} hari kerja dengan jam ${_formatTime(globalStartTime!)} - ${_formatTime(globalEndTime!)} WIB\n\n'
          'Perubahan ini akan mempengaruhi perhitungan beban kerja Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performSave(selectedDays); // Execute save
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSave(List<int> selectedDays) async {
    // Apply to provider (local state)
    widget.provider.setWorkHoursForAllDays(
      globalStartTime!,
      globalEndTime!,
      selectedDays,
    );

    // Save to backend
    try {
      // Format work days data for API
      final workDaysData = <String, dynamic>{};
      for (int i = 0; i < 7; i++) {
        workDaysData[i.toString()] = {
          'is_work_day': selectedDays.contains(i),
          'start': selectedDays.contains(i)
              ? '${globalStartTime!.hour.toString().padLeft(2, '0')}:${globalStartTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'end': selectedDays.contains(i)
              ? '${globalEndTime!.hour.toString().padLeft(2, '0')}:${globalEndTime!.minute.toString().padLeft(2, '0')}'
              : null,
        };
      }

      await ProfileApiService().updateWorkHours(workDaysData);
    } catch (e) {
      // Show error but don't block UI
      debugPrint('Failed to save work hours to backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Offline: Jadwal tersimpan lokal saja'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jadwal kerja berhasil disimpan! (${selectedDays.length} hari)',
          ),
        ),
      );
    }

    // Call callback if provided (for first time setup redirect)
    if (widget.onSaveComplete != null) {
      widget.onSaveComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Iconsax.calendar,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Jadwal Kerja',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sesuaikan hari & jam kerja Anda',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textSecondaryColor),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Work Hours Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.clock,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Jam Kerja',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (globalStartTime != null && globalEndTime != null) ...[
                      Text(
                        '${_formatTime(globalStartTime!)} - ${_formatTime(globalEndTime!)} WIB',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectGlobalTimes,
                        icon: const Icon(Iconsax.edit_2, size: 18),
                        label: Text(
                          globalStartTime == null
                              ? 'Atur Jam Kerja'
                              : 'Ubah Jam Kerja',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Work Days Section
              Text(
                'Hari Kerja',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih hari-hari kerja Anda',
                style: TextStyle(fontSize: 13, color: textSecondaryColor),
              ),
              const SizedBox(height: 16),

              // Day Checkboxes
              ...List.generate(7, (index) {
                final isWorkDay = workDayStatus[index] ?? false;
                final isWeekend = index >= 5; // Saturday & Sunday

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isWorkDay
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : (isDarkMode
                              ? AppTheme.darkDivider.withValues(alpha: 0.3)
                              : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWorkDay
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isWorkDay,
                    onChanged: (value) {
                      setState(() {
                        workDayStatus[index] = value ?? false;
                      });
                    },
                    title: Row(
                      children: [
                        Text(
                          dayNames[index],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isWorkDay
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isWorkDay
                                ? AppTheme.primaryColor
                                : textPrimaryColor,
                          ),
                        ),
                        if (isWeekend) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Weekend',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    activeColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Quick Select Buttons
              Wrap(
                spacing: 8,
                children: [
                  _QuickSelectChip(
                    label: 'Senin - Jumat',
                    icon: Iconsax.briefcase,
                    onTap: () {
                      setState(() {
                        for (int i = 0; i < 7; i++) {
                          workDayStatus[i] = i < 5; // Mon-Fri
                        }
                      });
                    },
                  ),
                  _QuickSelectChip(
                    label: 'Semua Hari',
                    icon: Iconsax.calendar_1,
                    onTap: () {
                      setState(() {
                        for (int i = 0; i < 7; i++) {
                          workDayStatus[i] = true;
                        }
                      });
                    },
                  ),
                  _QuickSelectChip(
                    label: 'Reset',
                    icon: Iconsax.refresh,
                    onTap: () {
                      setState(() {
                        for (int i = 0; i < 7; i++) {
                          workDayStatus[i] = false;
                        }
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Simpan Jadwal Kerja',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickSelectChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
