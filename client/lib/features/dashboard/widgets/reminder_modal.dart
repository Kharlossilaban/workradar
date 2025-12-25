import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ReminderModal extends StatefulWidget {
  final int? initialMinutes;

  const ReminderModal({super.key, this.initialMinutes});

  @override
  State<ReminderModal> createState() => _ReminderModalState();
}

class _ReminderModalState extends State<ReminderModal> {
  bool _isEnabled = false;
  int _selectedMinutes = 10;

  final List<int> _options = [5, 10, 15, 30];

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
                const Text(
                  'Pengingat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 16),

              const Text(
                'Ingatkan saya',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 12),

              // Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: Text('$minutes menit sebelumnya'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMinutes = value);
                    }
                  },
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
