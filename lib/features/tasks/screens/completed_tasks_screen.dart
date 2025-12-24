import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task.dart';
import '../../../core/providers/task_provider.dart';

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final groupedTasks = taskProvider.getCompletedTasksByDate();
    final dates = groupedTasks.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tugas Selesai',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: groupedTasks.isEmpty
          ? _buildEmptyState(isDarkMode)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final tasks = groupedTasks[date]!;
                return _buildDateSection(context, date, tasks, isDarkMode);
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.task_square,
            size: 80,
            color: isDarkMode ? AppTheme.darkTextLight : AppTheme.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada tugas yang diselesaikan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(
    BuildContext context,
    DateTime date,
    List<Task> tasks,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 12),
          child: Text(
            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.darkTextPrimary
                  : AppTheme.textPrimary,
            ),
          ),
        ),

        // Timeline tasks
        ...tasks.asMap().entries.map((entry) {
          final taskIndex = entry.key;
          final task = entry.value;
          final isLeft = taskIndex % 2 == 0;
          return _buildTimelineTask(
            context,
            task,
            isLeft,
            isDarkMode,
            isLast: taskIndex == tasks.length - 1,
          );
        }).toList(),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTimelineTask(
    BuildContext context,
    Task task,
    bool isLeft,
    bool isDarkMode, {
    bool isLast = false,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    // Get category color based on category name
    Color categoryColor;
    switch (task.categoryName) {
      case 'Kerja':
        categoryColor = AppTheme.primaryColor;
        break;
      case 'Pribadi':
        categoryColor = Colors.blue;
        break;
      case 'Wishlist':
        categoryColor = Colors.orange;
        break;
      case 'Hari Ulang Tahun':
        categoryColor = Colors.pink;
        break;
      default:
        categoryColor = AppTheme.primaryColor;
    }

    final timeText = task.completedAt != null
        ? DateFormat('HH:mm').format(task.completedAt!)
        : '';

    return SizedBox(
      height: 100,
      child: Row(
        children: [
          // Left card space
          if (isLeft)
            Expanded(
              child: _buildTaskCard(
                context,
                task,
                cardColor,
                textPrimaryColor,
                textSecondaryColor,
                timeText,
                categoryColor,
                isDarkMode,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Connecting line from previous
                if (!isLeft || isLeft)
                  Container(
                    width: 2,
                    height: 20,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),

                // Node/Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? AppTheme.darkBackground
                          : Colors.white,
                      width: 3,
                    ),
                  ),
                ),

                // Connecting line to next
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),

          // Right card space
          if (!isLeft)
            Expanded(
              child: _buildTaskCard(
                context,
                task,
                cardColor,
                textPrimaryColor,
                textSecondaryColor,
                timeText,
                categoryColor,
                isDarkMode,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    Color cardColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    String timeText,
    Color categoryColor,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Checkmark icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.tick_circle5,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(width: 12),

          // Task info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: TextStyle(fontSize: 12, color: textSecondaryColor),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Category flag
          Icon(Iconsax.flag, size: 16, color: categoryColor),

          const SizedBox(width: 4),

          // Delete button
          GestureDetector(
            onTap: () {
              _showDeleteConfirmation(context, task);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Iconsax.trash,
                size: 16,
                color: Colors.red.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: Text('Yakin ingin menghapus "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskProvider>().deleteCompletedTask(task.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
