import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/services/category_api_service.dart';
import '../../../core/services/task_api_service.dart';
import '../../profile/providers/profile_provider.dart';
import 'calendar_modal.dart';

class TaskInputModal extends StatefulWidget {
  final Function(Task) onTaskCreated;

  const TaskInputModal({super.key, required this.onTaskCreated});

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  final _titleController = TextEditingController();
  final _categoryApiService = CategoryApiService();

  String? _selectedCategory;
  String? _selectedCategoryId; // Store the category ID from server
  DateTime? _deadline;
  int? _reminderMinutes;
  RepeatType _repeatType = RepeatType.none;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;
  TaskDifficulty? _selectedDifficulty;
  int? _durationMinutes;

  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryApiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      // If failed to load categories, create default ones or show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kategori: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

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

    // Validate that category and difficulty are selected
    if (_selectedCategory == null || _selectedDifficulty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori dan beban kegiatan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final task = Task(
      id: const Uuid().v4(),
      userId: 'current_user', // Will be replaced with actual user ID
      categoryId: _selectedCategoryId, // Use categoryId from server
      categoryName: _selectedCategory!,
      title: _titleController.text.trim(),
      deadline: _deadline,
      reminderMinutes: _reminderMinutes,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatEndDate: _repeatEndDate,
      difficulty: _selectedDifficulty!,
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
      child: SafeArea(
        top: false,
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

              // Action row - fixed width to prevent shifting
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Category dropdown - FIXED WIDTH
                    SizedBox(
                      width: 150,
                      child: PopupMenuButton<String>(
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
                            color: _selectedCategory != null
                                ? _getCategoryColor().withValues(alpha: 0.1)
                                : hintColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  _isLoadingCategories
                                      ? 'Memuat...'
                                      : _selectedCategory ?? 'Pilih Kategori',
                                  style: TextStyle(
                                    color: _selectedCategory != null
                                        ? _getCategoryColor()
                                        : hintColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _selectedCategory != null
                                    ? _getCategoryColor()
                                    : hintColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          ..._categories.map(
                            (category) => PopupMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'new',
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.add,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text('Buat kategori baru'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'new') {
                            // Show create category dialog
                            _showCreateCategoryDialog();
                          } else {
                            // Find the selected category
                            final category = _categories.firstWhere(
                              (cat) => cat.id == value,
                            );
                            setState(() {
                              _selectedCategoryId = category.id;
                              _selectedCategory = category.name;
                            });

                            // Auto-suggest workload for "Kerja"
                            if (category.name == 'Kerja') {
                              final profileProvider = context
                                  .read<ProfileProvider>();
                              if (profileProvider.hasWorkHours) {
                                setState(() {
                                  _selectedDifficulty = TaskDifficulty.focus;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Saran: Beban kegiatan diatur ke "Berat" karena Anda memiliki jadwal kerja',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Difficulty dropdown - FIXED WIDTH
                    SizedBox(
                      width: 125,
                      child: PopupMenuButton<TaskDifficulty>(
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
                            color: _selectedDifficulty != null
                                ? Colors.amber.withValues(alpha: 0.1)
                                : hintColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDifficulty != null
                                      ? _getDifficultyLabel(
                                          _selectedDifficulty!,
                                        )
                                      : 'Pilih Beban',
                                  style: TextStyle(
                                    color: _selectedDifficulty != null
                                        ? Colors.amber
                                        : hintColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _selectedDifficulty != null
                                    ? Colors.amber
                                    : hintColor,
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
                            child: Text(
                              _getDifficultyLabel(TaskDifficulty.normal),
                            ),
                          ),
                          PopupMenuItem(
                            value: TaskDifficulty.focus,
                            child: Text(
                              _getDifficultyLabel(TaskDifficulty.focus),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() => _selectedDifficulty = value);
                        },
                      ),
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
      ),
    );
  }

  Color _getCategoryColor() {
    if (_selectedCategory == null) return AppTheme.primaryColor;

    switch (_selectedCategory!.toLowerCase()) {
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
        return 'Ringan';
      case TaskDifficulty.normal:
        return 'Sedang';
      case TaskDifficulty.focus:
        return 'Berat';
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
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);

                // Show loading
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Membuat kategori baru...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Create category via API
                  final newCategory = await _categoryApiService.createCategory(
                    name: controller.text.trim(),
                    color: _getRandomColor(), // Generate random color
                  );

                  // Add to local list
                  setState(() {
                    _categories.add(newCategory);
                    _selectedCategoryId = newCategory.id;
                    _selectedCategory = newCategory.name;
                  });

                  // Refresh CategoryProvider so dashboard filter updates
                  if (mounted) {
                    context.read<CategoryProvider>().refreshCategories();
                  }

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Kategori "${newCategory.name}" berhasil dibuat',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membuat kategori: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  String _getRandomColor() {
    // Generate random color for new category
    final colors = [
      '#6C5CE7', // Purple
      '#00B894', // Green
      '#0984E3', // Blue
      '#FD79A8', // Pink
      '#FDCB6E', // Yellow
      '#E17055', // Orange
      '#74B9FF', // Light Blue
      '#A29BFE', // Lavender
    ];
    colors.shuffle();
    return colors.first;
  }
}
