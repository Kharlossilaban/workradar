import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';
import '../utils/accessibility_utils.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const TaskCard({super.key, required this.task, this.onTap, this.onComplete});

  Color get _categoryColor {
    switch (task.categoryName.toLowerCase()) {
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

  /// Check if task is overdue (deadline passed and not completed)
  bool get isOverdue {
    if (task.isCompleted) return false;
    if (!task.hasDeadline) return false;
    return task.deadline!.isBefore(DateTime.now());
  }

  /// Get the overdue indicator color
  Color get _overdueColor => const Color(0xFFE53935); // Modern red
  Color get _overdueGradientStart => const Color(0xFFFF6B6B); // Light coral
  Color get _overdueGradientEnd => const Color(0xFFE53935); // Deep red

  Color _getDifficultyColor() {
    switch (task.difficulty) {
      case TaskDifficulty.relaxed:
        return Colors.green;
      case TaskDifficulty.focus:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _buildSemanticLabel() {
    return AccessibilityUtils.taskSemanticLabel(
      title: task.title,
      isCompleted: task.isCompleted,
      category: task.categoryName,
      deadline: task.hasDeadline
          ? DateFormat('dd MMM yyyy HH:mm').format(task.deadline!)
          : null,
      duration: task.durationMinutes != null ? task.durationString : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textLightColor = isDarkMode
        ? AppTheme.darkTextLight
        : AppTheme.textLight;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    final dividerColor = isDarkMode
        ? AppTheme.darkDivider
        : Colors.grey.shade100;

    // Overdue styling
    final isTaskOverdue = isOverdue;
    final cardBackgroundColor = isTaskOverdue
        ? (isDarkMode
              ? const Color(0xFF2D1F1F) // Dark mode overdue bg
              : const Color(0xFFFFF5F5)) // Light mode overdue bg
        : cardColor;

    return Semantics(
      label: _buildSemanticLabel(),
      hint: 'Ketuk dua kali untuk melihat detail tugas',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: isDarkMode ? null : AppTheme.cardShadow,
            border: isTaskOverdue
                ? Border.all(
                    color: _overdueColor.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Left vertical color block indicator - shows overdue color if overdue
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: isTaskOverdue
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_overdueGradientStart, _overdueGradientEnd],
                        )
                      : null,
                  color: isTaskOverdue ? null : _categoryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                    bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
                  ),
                ),
              ),
              // Main card content
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox circle - accessible with minimum touch target
                          Semantics(
                            label: task.isCompleted
                                ? 'Tandai belum selesai'
                                : 'Tandai selesai',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                // Haptic feedback for better UX
                                HapticFeedback.lightImpact();
                                onComplete?.call();
                              },
                              child: SizedBox(
                                width: AccessibilityUtils.minTouchTarget,
                                height: AccessibilityUtils.minTouchTarget,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: task.isCompleted
                                            ? AppTheme.successColor
                                            : _categoryColor,
                                        width: 2,
                                      ),
                                      color: task.isCompleted
                                          ? AppTheme.successColor
                                          : Colors.transparent,
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Task content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: task.isCompleted
                                        ? textLightColor
                                        : textPrimaryColor,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _categoryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.categoryName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _categoryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor().withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.difficultyString,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _getDifficultyColor(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Divider(height: 1, color: dividerColor),
                    // Bottom info row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (task.hasDeadline) ...[
                            Icon(
                              isTaskOverdue ? Iconsax.warning_2 : Iconsax.clock,
                              size: 16,
                              color: isTaskOverdue
                                  ? _overdueColor
                                  : textLightColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isTaskOverdue
                                  ? 'Terlambat - ${DateFormat('HH:mm').format(task.deadline!)}'
                                  : DateFormat('HH:mm').format(task.deadline!),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isTaskOverdue
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isTaskOverdue
                                    ? _overdueColor
                                    : textSecondaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (task.durationMinutes != null) ...[
                            Icon(
                              Iconsax.timer_1,
                              size: 16,
                              color: textLightColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              task.durationString,
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (task.hasRepeat) ...[
                            Icon(
                              Iconsax.repeat,
                              size: 16,
                              color: textLightColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.hasDeadline
                                    ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(task.deadline!)
                                    : task.repeatTypeString,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondaryColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
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
}
