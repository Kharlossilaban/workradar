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
        actions: [
          if (groupedTasks.isNotEmpty)
            IconButton(
              icon: Icon(
                Iconsax.trash,
                color: Colors.red.withValues(alpha: 0.8),
              ),
              onPressed: () => _showDeleteAllConfirmation(context),
            ),
        ],
      ),
      body: groupedTasks.isEmpty
          ? _buildEmptyState(isDarkMode)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final tasks = groupedTasks[date]!;
                return _buildDateSection(
                  context,
                  date,
                  tasks,
                  isDarkMode,
                  isFirst: index == 0,
                  isLastDate: index == dates.length - 1,
                );
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
    bool isDarkMode, {
    bool isFirst = false,
    bool isLastDate = false,
  }) {
    final lineColor = AppTheme.primaryColor.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header with timeline node
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            // Timeline column with date node
            SizedBox(
              width: 50,
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Top line (except for very first item)
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isFirst ? Colors.transparent : lineColor,
                      ),
                    ),
                    // Date node
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? AppTheme.darkBackground
                              : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // Bottom line
                    Expanded(child: Container(width: 3, color: lineColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Date text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Timeline tasks - all on right side
        ...tasks.asMap().entries.map((entry) {
          final taskIndex = entry.key;
          final task = entry.value;
          final isLastTaskOfDate = taskIndex == tasks.length - 1;

          return _buildTimelineTask(
            context,
            task,
            isDarkMode,
            // Only hide the bottom part of the line if it's the last task of the last date
            showBottomLine: !(isLastDate && isLastTaskOfDate),
          );
        }),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTimelineTask(
    BuildContext context,
    Task task,
    bool isDarkMode, {
    bool showBottomLine = true,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    final timeText = task.completedAt != null
        ? DateFormat('HH:mm').format(task.completedAt!)
        : '';

    return IntrinsicHeight(
      child: Row(
        children: [
          const SizedBox(width: 16),
          // Timeline column (left side)
          SizedBox(
            width: 50,
            child: Center(
              child: Container(
                width: 3,
                color: showBottomLine
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Task card (right side only)
          Expanded(
            child: _buildTaskCard(
              context,
              task,
              cardColor,
              textPrimaryColor,
              textSecondaryColor,
              timeText,
              isDarkMode,
            ),
          ),
          const SizedBox(width: 16),
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
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Checkmark status indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.tick_circle5,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(width: 12),

          // Task info with timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title with strikethrough
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: textSecondaryColor,
                    decorationThickness: 2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: () {
              _showDeleteConfirmation(context, task);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Iconsax.trash,
                size: 18,
                color: Colors.red.withValues(alpha: 0.7),
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

  void _showDeleteAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Tugas'),
        content: const Text(
          'Yakin ingin menghapus SEMUA tugas yang telah selesai? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskProvider>().deleteAllCompletedTasks();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }
}
