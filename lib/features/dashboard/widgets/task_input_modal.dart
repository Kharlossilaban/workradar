import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import 'calendar_modal.dart';

class TaskInputModal extends StatefulWidget {
  final Function(Task) onTaskCreated;

  const TaskInputModal({super.key, required this.onTaskCreated});

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'Kerja';
  DateTime? _deadline;
  int? _reminderMinutes;
  RepeatType _repeatType = RepeatType.none;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;

  final List<String> _categories = [
    'Kerja',
    'Pribadi',
    'Wishlist',
    'Hari Ulang Tahun',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showCalendarModal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CalendarModal(
        initialDate: _deadline,
        initialReminderMinutes: _reminderMinutes,
        initialRepeatType: _repeatType,
        initialRepeatInterval: _repeatInterval,
        initialRepeatEndDate: _repeatEndDate,
      ),
    );

    if (result != null) {
      setState(() {
        _deadline = result['deadline'];
        _reminderMinutes = result['reminderMinutes'];
        _repeatType = result['repeatType'];
        _repeatInterval = result['repeatInterval'];
        _repeatEndDate = result['repeatEndDate'];
      });
    }
  }

  void _createTask() {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    final task = Task(
      id: const Uuid().v4(),
      userId: 'current_user', // Will be replaced with actual user ID
      categoryName: _selectedCategory,
      title: _titleController.text.trim(),
      deadline: _deadline,
      reminderMinutes: _reminderMinutes,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatEndDate: _repeatEndDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onTaskCreated(task);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Membuat tugas baru di sini',
                  hintStyle: TextStyle(color: AppTheme.textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            const Divider(height: 1),

            // Action row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Category dropdown
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategory,
                            style: TextStyle(
                              color: _getCategoryColor(),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            color: _getCategoryColor(),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      ..._categories.map(
                        (category) => PopupMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'new',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.add,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            const Text('Buat kategori baru'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'new') {
                        // Show create category dialog
                        _showCreateCategoryDialog();
                      } else {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),

                  const Spacer(),

                  // Calendar button
                  IconButton(
                    onPressed: _showCalendarModal,
                    icon: Icon(
                      _deadline != null
                          ? Iconsax.calendar_15
                          : Iconsax.calendar,
                      color: _deadline != null
                          ? AppTheme.primaryColor
                          : AppTheme.textLight,
                    ),
                  ),

                  // Send button
                  IconButton(
                    onPressed: _createTask,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.send_1,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (_selectedCategory.toLowerCase()) {
      case 'kerja':
        return AppTheme.categoryWork;
      case 'pribadi':
        return AppTheme.categoryPersonal;
      case 'wishlist':
        return AppTheme.categoryWishlist;
      case 'hari ulang tahun':
        return AppTheme.categoryBirthday;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _showCreateCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Baru'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama kategori'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _categories.add(controller.text.trim());
                  _selectedCategory = controller.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
