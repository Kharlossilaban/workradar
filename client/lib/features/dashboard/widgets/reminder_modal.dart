import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';

class ReminderModal extends StatefulWidget {
  final int? initialMinutes;
  final bool isVip; // VIP status untuk restrict reminder options

  const ReminderModal({
    super.key,
    this.initialMinutes,
    this.isVip = false, // Default non-VIP
  });

  @override
  State<ReminderModal> createState() => _ReminderModalState();
}

class _ReminderModalState extends State<ReminderModal> {
  bool _isEnabled = false;
  int _selectedMinutes = 10;

  // Regular users: only 10 minutes
  // VIP users: 5, 10, 15, 30 minutes
  List<int> get _options => widget.isVip ? [5, 10, 15, 30] : [10];

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialMinutes != null;
    _selectedMinutes = widget.initialMinutes ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    'Pengingat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    maxLines: 1,
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
              const SizedBox(height: 16),

              const Text(
                'Ingatkan saya',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Dropdown - VIP gets more options
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
                  value: _selectedMinutes,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _options.map((minutes) {
                    return DropdownMenuItem(
                      value: minutes,
                      child: Text(
                        '$minutes menit sebelumnya',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMinutes = value);
                    }
                  },
                ),
              ),

              // Show VIP upgrade hint for regular users
              if (!widget.isVip) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.vipGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.vipGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.crown_15, color: AppTheme.vipGold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upgrade ke VIP untuk pilihan 5, 15, 30 menit',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.vipGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    Navigator.pop(context, _isEnabled ? _selectedMinutes : 0);
                  },
                  child: const Text('Selesai'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
