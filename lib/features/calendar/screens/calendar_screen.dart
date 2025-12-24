import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/task_provider.dart';
import '../../profile/providers/workload_provider.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/custom_button.dart';

import '../../dashboard/widgets/task_input_modal.dart';
import '../../tasks/screens/edit_task_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isWeekView = false;

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

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with month navigation
            _buildHeader(isDarkMode),

            // Calendar view
            _isWeekView
                ? _buildWeekView(taskProvider, isDarkMode)
                : _buildMonthView(taskProvider, isDarkMode),

            const SizedBox(height: 16),

            // Tasks for selected date
            Expanded(child: _buildTasksList(taskProvider, isDarkMode)),
          ],
        ),
      ),
      floatingActionButton: FloatingAddButton(onPressed: _showAddTaskModal),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy', 'id_ID').format(_focusedMonth),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                    );
                  });
                },
                icon: Icon(
                  Iconsax.arrow_left_2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    );
                  });
                },
                icon: Icon(
                  Iconsax.arrow_right_3,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _isWeekView = !_isWeekView);
                },
                icon: Icon(
                  _isWeekView ? Iconsax.arrow_down_2 : Iconsax.arrow_up_2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthView(TaskProvider taskProvider, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Day headers
          _buildDayHeaders(isDarkMode),
          const SizedBox(height: 8),
          // Calendar grid
          _buildCalendarGrid(taskProvider, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildWeekView(TaskProvider taskProvider, bool isDarkMode) {
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    // Get the week containing the selected date
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildDayHeaders(isDarkMode),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isSelected =
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              final isToday =
                  date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final hasTasks = taskProvider.hasTasksOnDate(date);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : null,
                    border: isToday && !isSelected
                        ? Border.all(color: AppTheme.primaryColor, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: isSelected || isToday
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? AppTheme.primaryColor
                              : textPrimaryColor,
                        ),
                      ),
                      if (hasTasks && !isSelected)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(bool isDarkMode) {
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => SizedBox(
              width: 40,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondaryColor,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(TaskProvider taskProvider, bool isDarkMode) {
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = ((firstWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayOffset = index - (firstWeekday - 1);

        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox();
        }

        final date = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayOffset + 1,
        );
        final isSelected =
            date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        final isToday =
            date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        // Check if there are tasks on this date using provider
        final hasTasks = taskProvider.hasTasksOnDate(date);

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : null,
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${dayOffset + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? AppTheme.primaryColor
                        : textPrimaryColor,
                  ),
                ),
                if (hasTasks && !isSelected)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTasksList(TaskProvider taskProvider, bool isDarkMode) {
    final textLightColor = isDarkMode
        ? AppTheme.darkTextLight
        : AppTheme.textLight;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    final isToday =
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    final tasksForSelectedDate = taskProvider.getTasksForDate(
      _selectedDate,
      includeCompleted: false, // Only show incomplete tasks
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday
                ? 'Hari ini'
                : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan tugas dan pantau progres anda',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksForSelectedDate.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.calendar_tick,
                          size: 60,
                          color: textLightColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada tugas',
                          style: TextStyle(color: textSecondaryColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tasksForSelectedDate.length,
                    itemBuilder: (context, index) {
                      final task = tasksForSelectedDate[index];
                      return TaskCard(
                        task: task,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditTaskScreen(
                                task: task,
                                onTaskUpdated: (updatedTask) {
                                  context.read<TaskProvider>().updateTask(
                                    updatedTask,
                                  );
                                },
                                onTaskDeleted: () {
                                  context.read<TaskProvider>().deleteTask(
                                    task.id,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        onComplete: () {
                          final workloadProvider = context
                              .read<WorkloadProvider>();
                          context.read<TaskProvider>().toggleTaskCompletion(
                            task.id,
                            onCompleted: (date) {
                              // Record task completion in workload graph
                              workloadProvider.recordTaskCompletion(date);
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
