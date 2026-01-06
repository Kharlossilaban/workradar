import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/models/task.dart';
import '../../profile/providers/completed_tasks_provider.dart';
import '../../../core/widgets/task_card.dart';
import '../../tasks/screens/edit_task_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto focus on search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Task> _filterTasks(List<Task> tasks) {
    if (_searchQuery.isEmpty) return [];

    final query = _searchQuery.toLowerCase();
    return tasks.where((task) {
      return task.title.toLowerCase().contains(query) ||
          task.categoryName.toLowerCase().contains(query);
    }).toList();
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

  void _onTaskComplete(Task task) {
    final completedTasksProvider = context.read<CompletedTasksProvider>();

    context.read<TaskProvider>().toggleTaskCompletion(
      task.id,
      onCompleted: (_) {
        // Record completed task in completed tasks provider
        final date = task.deadline ?? DateTime.now();
        completedTasksProvider.recordTaskCompletion(date);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final filteredTasks = _filterTasks(taskProvider.tasks);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telusuri'),
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(
                  AppTheme.borderRadiusMedium,
                ),
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari tugas...',
                  prefixIcon: Icon(
                    Iconsax.search_normal,
                    color: AppTheme.primaryColor,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Iconsax.close_circle,
                            color: isDarkMode
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildInitialState(context, isDarkMode)
                : filteredTasks.isEmpty
                ? _buildEmptyResult(context, isDarkMode)
                : _buildSearchResults(filteredTasks),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.search_normal,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text('Cari Tugas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ketik untuk mencari tugas berdasarkan\njudul atau kategori',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult(BuildContext context, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.search_status,
              size: 48,
              color: AppTheme.warningColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak ditemukan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada tugas yang cocok dengan\n"$_searchQuery"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Task> tasks) {
    return ListView.builder(
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
    );
  }
}
