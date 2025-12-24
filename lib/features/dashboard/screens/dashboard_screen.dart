import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/category_provider.dart';
import '../../profile/providers/workload_provider.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/custom_button.dart';
import '../widgets/task_input_modal.dart';
import '../../tasks/screens/edit_task_screen.dart';
import '../../tasks/screens/completed_tasks_screen.dart';
import '../../category/screens/manage_category_screen.dart';
import '../../search/screens/search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCategory = 'Semua';

  // Collapsible section states
  bool _isTodayExpanded = true;
  bool _isUpcomingExpanded = true;
  bool _isCompletedTodayExpanded = false;

  void _showAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        onTaskCreated: (task) {
          context.read<TaskProvider>().addTask(task);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _onTaskComplete(Task task) {
    final workloadProvider = context.read<WorkloadProvider>();
    context.read<TaskProvider>().toggleTaskCompletion(
      task.id,
      onCompleted: (date) {
        // Record task completion in workload graph
        workloadProvider.recordTaskCompletion(date);
      },
    );
  }

  void _onTaskTap(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(
          task: task,
          onTaskUpdated: (updatedTask) {
            context.read<TaskProvider>().updateTask(updatedTask);
          },
          onTaskDeleted: () {
            context.read<TaskProvider>().deleteTask(task.id);
          },
        ),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'manage_category':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ManageCategoryScreen()),
        );
        break;
      case 'completed_tasks':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CompletedTasksScreen()),
        );
        break;
      case 'search':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
        break;
      case 'toggle_theme':
        context.read<ThemeProvider>().toggleTheme();
        final isDark = context.read<ThemeProvider>().isDarkMode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDark ? 'Mode Gelap aktif' : 'Mode Terang aktif'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  // Helper method to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Get today's incomplete tasks
  List<Task> _getTodayTasks(List<Task> tasks) {
    final today = DateTime.now();
    return tasks.where((task) {
      return task.deadline != null &&
          !task.isCompleted &&
          _isSameDay(task.deadline!, today);
    }).toList();
  }

  // Get upcoming incomplete tasks (deadline > today)
  List<Task> _getUpcomingTasks(List<Task> tasks) {
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return tasks.where((task) {
      return task.deadline != null &&
          !task.isCompleted &&
          task.deadline!.isAfter(endOfToday);
    }).toList();
  }

  // Get today's completed tasks
  List<Task> _getCompletedTodayTasks(List<Task> tasks) {
    final today = DateTime.now();
    return tasks.where((task) {
      return task.isCompleted &&
          task.completedAt != null &&
          _isSameDay(task.completedAt!, today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final filteredTasks = taskProvider.getTasksByCategory(
      _selectedCategory,
      includeCompleted: false, // Only show incomplete tasks
    );

    // Ensure selected category exists in the list
    final categories = categoryProvider.categoryNames;
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'Semua';
    }

    // Get task groups
    final todayTasks = _getTodayTasks(filteredTasks);
    final upcomingTasks = _getUpcomingTasks(filteredTasks);
    final completedTodayTasks = _getCompletedTodayTasks(
      taskProvider.getTasksByCategory(
        _selectedCategory,
        includeCompleted: true,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Chips + Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: CategoryChipList(
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Iconsax.more,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusMedium,
                      ),
                    ),
                    onSelected: _onMenuSelected,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'manage_category',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.category,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Kelola Kategori'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: 'search',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.search_normal,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Telusuri'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_theme',
                        child: Row(
                          children: [
                            Icon(
                              themeProvider.isDarkMode
                                  ? Iconsax.sun_1
                                  : Iconsax.moon,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              themeProvider.isDarkMode
                                  ? 'Mode Terang'
                                  : 'Mode Gelap',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Collapsible Task Sections
            Expanded(
              child:
                  todayTasks.isEmpty &&
                      upcomingTasks.isEmpty &&
                      completedTodayTasks.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Today Section - Only show if has tasks
                          if (todayTasks.isNotEmpty)
                            _buildCollapsibleSection(
                              title: 'Hari ini',
                              isExpanded: _isTodayExpanded,
                              onToggle: () => setState(
                                () => _isTodayExpanded = !_isTodayExpanded,
                              ),
                              tasks: todayTasks,
                              emptyMessage: 'Tidak ada tugas untuk hari ini',
                            ),

                          // Upcoming Section - Only show if has tasks
                          if (upcomingTasks.isNotEmpty)
                            _buildCollapsibleSection(
                              title: 'Masa Mendatang',
                              isExpanded: _isUpcomingExpanded,
                              onToggle: () => setState(
                                () =>
                                    _isUpcomingExpanded = !_isUpcomingExpanded,
                              ),
                              tasks: upcomingTasks,
                              emptyMessage: 'Tidak ada tugas mendatang',
                            ),

                          // Completed Today Section - Only show if has tasks
                          if (completedTodayTasks.isNotEmpty)
                            _buildCollapsibleSection(
                              title: 'Selesai Hari Ini',
                              isExpanded: _isCompletedTodayExpanded,
                              onToggle: () => setState(
                                () => _isCompletedTodayExpanded =
                                    !_isCompletedTodayExpanded,
                              ),
                              tasks: completedTodayTasks,
                              emptyMessage: 'Tidak ada tugas selesai hari ini',
                              isCompletedSection: true,
                            ),

                          // Text link at the bottom
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CompletedTasksScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Periksa semua tugas yang sudah selesai',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingAddButton(onPressed: _showAddTaskModal),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Task> tasks,
    required String emptyMessage,
    bool isCompletedSection = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                  size: 20,
                  color: isDarkMode
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Expandable Content
        if (isExpanded)
          tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: Text(
                      emptyMessage,
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => _onTaskTap(task),
                      onComplete: () => _onTaskComplete(task),
                    );
                  },
                ),

        const SizedBox(height: 8),
      ],
    );
  }

  String? _getCategoryImage(String category) {
    switch (category) {
      case 'Semua':
        return 'assets/images/semua.jpg';
      case 'Kerja':
        return 'assets/images/kerja.jpg';
      case 'Pribadi':
        return 'assets/images/pribadi.jpg';
      case 'Wishlist':
        return 'assets/images/wishlist.png';
      case 'Hari Ulang Tahun':
        return 'assets/images/ulang_tahun.jpg';
      default:
        return null;
    }
  }

  Widget _buildEmptyState({Key? key}) {
    final categoryImage = _getCategoryImage(_selectedCategory);

    return Center(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration or Icon
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: categoryImage != null
                  ? Image.asset(
                      categoryImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Iconsax.task_square,
                          size: 80,
                          color: AppTheme.primaryColor.withOpacity(0.5),
                        );
                      },
                    )
                  : Icon(
                      Iconsax.task_square,
                      size: 80,
                      color: AppTheme.primaryColor.withOpacity(0.5),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Belum ada tugas',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          Text(
            'Ketuk tombol + untuk menambahkan\ntugas pertama anda',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          // Tooltip pointing to FAB
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mulai buat tugas baru!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
