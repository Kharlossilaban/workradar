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
  TaskDifficulty _selectedDifficulty = TaskDifficulty.normal;
  int? _durationMinutes;

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
        initialDurationMinutes: _durationMinutes,
      ),
    );

    if (result != null) {
      setState(() {
        _deadline = result['deadline'];
        _reminderMinutes = result['reminderMinutes'];
        _repeatType = result['repeatType'];
        _repeatInterval = result['repeatInterval'];
        _repeatEndDate = result['repeatEndDate'];
        _durationMinutes = result['durationMinutes'];
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
      difficulty: _selectedDifficulty,
      durationMinutes: _durationMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onTaskCreated(task);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkSurface : Colors.white;
    final handleBarColor = isDarkMode
        ? AppTheme.darkTextLight
        : Colors.grey.shade300;
    final textColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final hintColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textLight;
    final dividerColor = isDarkMode
        ? AppTheme.darkDivider
        : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: handleBarColor,
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
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(fontSize: 16, color: textColor),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            Divider(height: 1, color: dividerColor),

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
                        color: _getCategoryColor().withValues(alpha: 0.1),
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

                  const SizedBox(width: 8),

                  // Difficulty dropdown
                  PopupMenuButton<TaskDifficulty>(
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
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getDifficultyLabel(_selectedDifficulty),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: TaskDifficulty.relaxed,
                        child: Text(
                          _getDifficultyLabel(TaskDifficulty.relaxed),
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskDifficulty.normal,
                        child: Text(_getDifficultyLabel(TaskDifficulty.normal)),
                      ),
                      PopupMenuItem(
                        value: TaskDifficulty.focus,
                        child: Text(_getDifficultyLabel(TaskDifficulty.focus)),
                      ),
                    ],
                    onSelected: (value) {
                      setState(() => _selectedDifficulty = value);
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

  String _getDifficultyLabel(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.relaxed:
        return 'Santai';
      case TaskDifficulty.normal:
        return 'Biasa';
      case TaskDifficulty.focus:
        return 'Fokus';
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
