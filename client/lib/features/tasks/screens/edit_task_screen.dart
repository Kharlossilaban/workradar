import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import '../../../core/services/category_api_service.dart';
import '../../../core/services/task_api_service.dart';
import '../../dashboard/widgets/calendar_modal.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;
  final VoidCallback onTaskDeleted;

  const EditTaskScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late String _selectedCategory;
  late String? _selectedCategoryId;
  late String _title;
  late DateTime? _deadline;
  late int? _reminderMinutes;
  late RepeatType _repeatType;
  late int _repeatInterval;
  late DateTime? _repeatEndDate;
  late TaskDifficulty _selectedDifficulty;
  late int? _durationMinutes;

  final _categoryApiService = CategoryApiService();
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.task.categoryName;
    _selectedCategoryId = widget.task.categoryId;
    _title = widget.task.title;
    _deadline = widget.task.deadline;
    _reminderMinutes = widget.task.reminderMinutes;
    _repeatType = widget.task.repeatType;
    _repeatInterval = widget.task.repeatInterval;
    _repeatEndDate = widget.task.repeatEndDate;
    _selectedDifficulty = widget.task.difficulty;
    _durationMinutes = widget.task.durationMinutes;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryApiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });

      // Ensure the task's current category is in the list
      final hasCategory = _categories.any(
        (cat) => cat.name == _selectedCategory,
      );
      if (!hasCategory && _selectedCategory.isNotEmpty) {
        // If the category doesn't exist in the list, add it
        setState(() {
          _categories.add(
            CategoryModel(
              id: _selectedCategoryId ?? '',
              userId: '',
              name: _selectedCategory,
              color: '#6C5CE7',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
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

  Color get _categoryColor {
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

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.copy, color: AppTheme.textPrimary),
              title: const Text('Duplikat Tugas'),
              onTap: () {
                Navigator.pop(context);
                // Handle duplicate
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tugas berhasil diduplikat!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.trash, color: AppTheme.errorColor),
              title: const Text(
                'Hapus Tugas',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: const Text('Apakah anda yakin ingin menghapus tugas ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onTaskDeleted();
              Navigator.pop(this.context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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

  void _saveChanges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menyimpan perubahan tugas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performSave(); // Execute save
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

  void _performSave() {
    final updatedTask = widget.task.copyWith(
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategory,
      title: _title,
      deadline: _deadline,
      reminderMinutes: _reminderMinutes,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatEndDate: _repeatEndDate,
      difficulty: _selectedDifficulty,
      durationMinutes: _durationMinutes,
      updatedAt: DateTime.now(),
    );

    widget.onTaskUpdated(updatedTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ubah Tugas'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.more, color: AppTheme.textPrimary),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: _isLoadingCategories
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category.name,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category.name),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final category = _categories.firstWhere(
                            (cat) => cat.name == value,
                          );
                          setState(() {
                            _selectedCategory = value;
                            _selectedCategoryId = category.id;
                          });
                        }
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Difficulty selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: DropdownButton<TaskDifficulty>(
                value: _selectedDifficulty,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down),
                items: TaskDifficulty.values.map((difficulty) {
                  return DropdownMenuItem(
                    value: difficulty,
                    child: Text(
                      'Beban Kegiatan: ${_getDifficultyLabel(difficulty)}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDifficulty = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextFormField(
                initialValue: _title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Judul tugas',
                ),
                onChanged: (value) => _title = value,
              ),
            ),

            const SizedBox(height: 16),

            // Settings card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  // Deadline
                  ListTile(
                    leading: Icon(
                      Iconsax.calendar,
                      color: _deadline != null
                          ? _categoryColor
                          : AppTheme.textLight,
                    ),
                    title: const Text('Batas Waktu'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _deadline != null
                              ? DateFormat('dd MMM, HH:mm').format(_deadline!)
                              : 'Tidak diatur',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _showCalendarModal,
                  ),

                  const Divider(height: 1, indent: 56),

                  // Reminder
                  ListTile(
                    leading: Icon(
                      Iconsax.notification,
                      color: _reminderMinutes != null
                          ? _categoryColor
                          : AppTheme.textLight,
                    ),
                    title: const Text('Pengingat pada'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _reminderMinutes != null
                              ? '$_reminderMinutes menit sebelumnya'
                              : 'Tidak ada',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _showCalendarModal,
                  ),

                  const Divider(height: 1, indent: 56),

                  // Repeat
                  ListTile(
                    leading: Icon(
                      Iconsax.repeat,
                      color: _repeatType != RepeatType.none
                          ? _categoryColor
                          : AppTheme.textLight,
                    ),
                    title: const Text('Ulangi tugas'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _repeatType != RepeatType.none
                              ? _getRepeatString()
                              : 'Tidak',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _showCalendarModal,
                  ),

                  const Divider(height: 1, indent: 56),

                  // Duration
                  ListTile(
                    leading: Icon(
                      Iconsax.timer_1,
                      color: _durationMinutes != null
                          ? _categoryColor
                          : AppTheme.textLight,
                    ),
                    title: const Text('Durasi'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDurationString(),
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _showCalendarModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
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
}
