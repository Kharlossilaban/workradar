import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/models/task.dart';
import '../../../core/services/auth_api_service.dart';
import '../widgets/workload_chart.dart';
import '../widgets/completed_tasks_chart.dart';
import '../widgets/work_days_config_sheet.dart';
import '../providers/workload_provider.dart';
import '../providers/completed_tasks_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/leave_provider.dart';
import '../../messaging/providers/messaging_provider.dart';
import 'profile_detail_screen.dart';
import 'leave_management_screen.dart';
import '../../messaging/screens/messages_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedPeriod = 'Daily';
  String _selectedCompletedPeriod = 'Daily';
  bool _isVip = false; // Will be loaded from storage

  @override
  void initState() {
    super.initState();
    _loadVipStatus();
    // Load profile and stats from server
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      final profileProvider = context.read<ProfileProvider>();
      final taskProvider = context.read<TaskProvider>();
      final workloadProvider = context.read<WorkloadProvider>();
      final completedTasksProvider = context.read<CompletedTasksProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        await profileProvider.loadProfileFromServer();
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Gagal memuat profil: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Sync workload and completed tasks data
      workloadProvider.syncFromTasks(taskProvider.tasks);
      completedTasksProvider.syncFromTasks(taskProvider.tasks);
    });
  }

  void _loadVipStatus() async {
    final userType = await SecureStorage.getUserType();
    setState(() {
      _isVip = userType == 'vip';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildProfileHeader(isDarkMode),
              if (!_isVip) const SizedBox(height: 20),
              if (!_isVip) _buildVipBanner(),
              const SizedBox(height: 20),
              _buildStatisticsCards(isDarkMode),
              const SizedBox(height: 20),
              _buildWorkHoursCard(isDarkMode),
              const SizedBox(height: 20),
              _buildQuickActionsSection(isDarkMode),
              const SizedBox(height: 20),
              _buildWorkloadCard(isDarkMode),
              const SizedBox(height: 20),
              _buildCompletedTasksCard(isDarkMode),
              const SizedBox(height: 20),
              _buildLogoutButton(isDarkMode),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDarkMode) {
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Profile picture
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileDetailScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.user,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${profileProvider.username}! 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Iconsax.sms, size: 18, color: textSecondaryColor),
                        const SizedBox(width: 6),
                        Text(
                          profileProvider.gmail,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: textSecondaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isVip)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.vipGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.crown_15,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVipBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.vipGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.vipGold.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.crown_15,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jadi Member VIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Buka semua fitur khusus dengan upgrade ke VIP',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkloadCard(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final periodBgColor = isDarkMode
        ? AppTheme.darkDivider
        : Colors.grey.shade100;

    return Consumer<WorkloadProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDarkMode ? null : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.chart_1,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Beban Kerja',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Date range navigation
              _buildDateRangeNavigation(provider, isDarkMode),

              const SizedBox(height: 16),

              // Period selector (below date range)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: periodBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPeriodButton('Daily', isDarkMode),
                      _buildPeriodButton('Weekly', isDarkMode, isVipOnly: true),
                      _buildPeriodButton(
                        'Monthly',
                        isDarkMode,
                        isVipOnly: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Chart
              SizedBox(height: 200, child: _buildChart(provider, isDarkMode)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRangeNavigation(WorkloadProvider provider, bool isDarkMode) {
    final textColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    String dateRangeText = _getDateRangeText(provider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        IconButton(
          icon: Icon(Icons.chevron_left, color: textColor, size: 28),
          onPressed: () {
            provider.navigatePrevious();
          },
        ),
        const SizedBox(width: 8),
        // Date range text
        Expanded(
          child: Text(
            dateRangeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Next button
        IconButton(
          icon: Icon(Icons.chevron_right, color: textColor, size: 28),
          onPressed: () {
            provider.navigateNext();
          },
        ),
      ],
    );
  }

  String _getDateRangeText(WorkloadProvider provider) {
    switch (_selectedPeriod) {
      case 'Daily':
        // Show week range (e.g., "20 Des - 26 Des 2025")
        final weekStart = provider.getWeekStartDate();
        final weekEnd = weekStart.add(const Duration(days: 6));

        final startDay = weekStart.day;
        final endDay = weekEnd.day;
        final startMonth = DateFormat('MMM', 'id_ID').format(weekStart);
        final endMonth = DateFormat('MMM', 'id_ID').format(weekEnd);
        final year = weekEnd.year;

        if (weekStart.month == weekEnd.month) {
          return '$startDay - $endDay $endMonth $year';
        } else {
          return '$startDay $startMonth - $endDay $endMonth $year';
        }

      case 'Weekly':
        // Show month (e.g., "Desember 2025")
        final monthDate = provider.getMonthDate();
        final monthName = DateFormat('MMMM yyyy', 'id_ID').format(monthDate);
        return monthName;

      case 'Monthly':
        // Show year (e.g., "2025")
        final year = provider.getYear();
        return year.toString();

      default:
        return '';
    }
  }

  Widget _buildChart(WorkloadProvider provider, bool isDarkMode) {
    List<int> taskData;
    bool hasData;
    final profileProvider = context.read<ProfileProvider>();
    final totalWorkMinutes = profileProvider.totalWorkMinutes;

    switch (_selectedPeriod) {
      case 'Daily':
        final weekStart = provider.getWeekStartDate();
        taskData = provider.getDailyDurations(weekStart);
        hasData = provider.hasDataForWeek(weekStart);
        break;

      case 'Weekly':
        if (!_isVip) {
          taskData = [0, 0, 0, 0];
          hasData = false;
        } else {
          final monthDate = provider.getMonthDate();
          taskData = provider.getWeeklyDurations(monthDate);
          hasData = provider.hasDataForMonth(monthDate);
        }
        break;

      case 'Monthly':
        if (!_isVip) {
          taskData = List.generate(12, (_) => 0);
          hasData = false;
        } else {
          final year = provider.getYear();
          taskData = provider.getMonthlyDurations(year);
          hasData = provider.hasDataForYear(year);
        }
        break;

      default:
        taskData = [];
        hasData = false;
    }

    return WorkloadChart(
      period: _selectedPeriod,
      isVip: _isVip,
      taskData: taskData,
      hasData: hasData,
      totalWorkMinutes: totalWorkMinutes,
    );
  }

  Widget _buildPeriodButton(
    String period,
    bool isDarkMode, {
    bool isVipOnly = false,
  }) {
    final isSelected = _selectedPeriod == period;
    final isLocked = isVipOnly && !_isVip;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    final textLightColor = isDarkMode
        ? AppTheme.darkTextLight
        : AppTheme.textLight;

    return GestureDetector(
      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur ini hanya untuk member VIP'),
                ),
              );
            }
          : () {
              setState(() => _selectedPeriod = period);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              period,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isLocked
                    ? textLightColor
                    : textSecondaryColor,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 4),
              Icon(Iconsax.lock, size: 12, color: textLightColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkHoursCard(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDarkMode ? null : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.clock,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Jadwal Kerja',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (provider.hasWorkHours) ...[
                // Work Hours
                Text(
                  'Jam Kerja:',
                  style: TextStyle(color: textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.workHoursRange,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Work Days
                Text(
                  'Hari Kerja:',
                  style: TextStyle(color: textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.workDayNames.map((dayName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Text(
                  'Anda belum mengatur jadwal kerja.',
                  style: TextStyle(color: textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _selectWorkHours(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    provider.hasWorkHours ? 'Ubah Jadwal' : 'Atur Jadwal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectWorkHours(
    BuildContext context,
    ProfileProvider provider,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkDaysConfigSheet(provider: provider),
    );
  }

  Widget _buildStatisticsCards(bool isDarkMode) {
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    return Consumer2<ProfileProvider, TaskProvider>(
      builder: (context, profileProvider, taskProvider, child) {
        if (profileProvider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Filter tasks based on selected period
        List<Task> filteredTasks = [];
        final now = DateTime.now();

        switch (_selectedPeriod) {
          case 'Daily':
            filteredTasks = taskProvider.tasks.where((t) {
              if (t.deadline == null) return false;
              return t.deadline!.year == now.year &&
                  t.deadline!.month == now.month &&
                  t.deadline!.day == now.day;
            }).toList();
            break;
          case 'Weekly':
            // Simple weekly filter (current week)
            // Assuming week starts on Monday
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 6));
            final start = DateTime(
              startOfWeek.year,
              startOfWeek.month,
              startOfWeek.day,
            );
            final end = DateTime(
              endOfWeek.year,
              endOfWeek.month,
              endOfWeek.day,
              23,
              59,
              59,
            );

            filteredTasks = taskProvider.tasks.where((t) {
              if (t.deadline == null) return false;
              return t.deadline!.isAfter(start) && t.deadline!.isBefore(end);
            }).toList();
            break;
          case 'Monthly':
            filteredTasks = taskProvider.tasks.where((t) {
              if (t.deadline == null) return false;
              return t.deadline!.year == now.year &&
                  t.deadline!.month == now.month;
            }).toList();
            break;
        }

        final int totalTasks = filteredTasks.length;
        final int completedTasks = filteredTasks
            .where((t) => t.isCompleted)
            .length;

        // Calculate total workload in minutes from filtered tasks
        int totalWorkloadMinutes = 0;
        for (var task in filteredTasks) {
          if (!task.isCompleted && task.durationMinutes != null) {
            totalWorkloadMinutes += task.durationMinutes!;
          }
        }

        // Format workload as hours and minutes
        final hours = totalWorkloadMinutes ~/ 60;
        final minutes = totalWorkloadMinutes % 60;
        String workloadValue;
        if (hours > 0 && minutes > 0) {
          workloadValue = '${hours}j ${minutes}m';
        } else if (hours > 0) {
          workloadValue = '${hours}j';
        } else {
          workloadValue = '${minutes}m';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Iconsax.task_square,
                      iconColor: AppTheme.primaryColor,
                      title: 'Total Tugas',
                      value: '$totalTasks tugas',
                      isDarkMode: isDarkMode,
                      textPrimaryColor: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Iconsax.tick_circle,
                      iconColor: AppTheme.secondaryColor,
                      title: 'Tugas Selesai',
                      value: '$completedTasks tugas',
                      isDarkMode: isDarkMode,
                      textPrimaryColor: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                icon: Iconsax.weight,
                iconColor: Colors.orange,
                title: 'Total Beban Kerja',
                value: workloadValue,
                isDarkMode: isDarkMode,
                textPrimaryColor: textPrimaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDarkMode,
    required Color textPrimaryColor,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTasksCard(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final periodBgColor = isDarkMode
        ? AppTheme.darkDivider
        : Colors.grey.shade100;

    return Consumer<CompletedTasksProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDarkMode ? null : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.task_square,
                      color: AppTheme.secondaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tugas Selesai',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Date range navigation
              _buildCompletedDateRangeNavigation(provider, isDarkMode),

              const SizedBox(height: 16),

              // Period selector (below date range)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: periodBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCompletedPeriodButton('Daily', isDarkMode),
                      _buildCompletedPeriodButton(
                        'Weekly',
                        isDarkMode,
                        isVipOnly: true,
                      ),
                      _buildCompletedPeriodButton(
                        'Monthly',
                        isDarkMode,
                        isVipOnly: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Chart
              SizedBox(
                height: 200,
                child: _buildCompletedChart(provider, isDarkMode),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedDateRangeNavigation(
    CompletedTasksProvider provider,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    String dateRangeText = _getCompletedDateRangeText(provider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        IconButton(
          icon: Icon(Icons.chevron_left, color: textColor, size: 28),
          onPressed: () {
            provider.navigatePrevious();
          },
        ),
        const SizedBox(width: 8),
        // Date range text
        Expanded(
          child: Text(
            dateRangeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Next button
        IconButton(
          icon: Icon(Icons.chevron_right, color: textColor, size: 28),
          onPressed: () {
            provider.navigateNext();
          },
        ),
      ],
    );
  }

  String _getCompletedDateRangeText(CompletedTasksProvider provider) {
    switch (_selectedCompletedPeriod) {
      case 'Daily':
        final weekStart = provider.getWeekStartDate();
        final weekEnd = weekStart.add(const Duration(days: 6));

        final startDay = weekStart.day;
        final endDay = weekEnd.day;
        final startMonth = DateFormat('MMM', 'id_ID').format(weekStart);
        final endMonth = DateFormat('MMM', 'id_ID').format(weekEnd);
        final year = weekEnd.year;

        if (weekStart.month == weekEnd.month) {
          return '$startDay - $endDay $endMonth $year';
        } else {
          return '$startDay $startMonth - $endDay $endMonth $year';
        }

      case 'Weekly':
        final monthDate = provider.getMonthDate();
        final monthName = DateFormat('MMMM yyyy', 'id_ID').format(monthDate);
        return monthName;

      case 'Monthly':
        final year = provider.getYear();
        return year.toString();

      default:
        return '';
    }
  }

  Widget _buildCompletedChart(
    CompletedTasksProvider provider,
    bool isDarkMode,
  ) {
    List<int> taskData;
    bool hasData;

    switch (_selectedCompletedPeriod) {
      case 'Daily':
        final weekStart = provider.getWeekStartDate();
        taskData = provider.getDailyCounts(weekStart);
        hasData = provider.hasDataForWeek(weekStart);
        break;

      case 'Weekly':
        if (!_isVip) {
          taskData = [0, 0, 0, 0];
          hasData = false;
        } else {
          final monthDate = provider.getMonthDate();
          taskData = provider.getWeeklyCounts(monthDate);
          hasData = provider.hasDataForMonth(monthDate);
        }
        break;

      case 'Monthly':
        if (!_isVip) {
          taskData = List.generate(12, (_) => 0);
          hasData = false;
        } else {
          final year = provider.getYear();
          taskData = provider.getMonthlyCounts(year);
          hasData = provider.hasDataForYear(year);
        }
        break;

      default:
        taskData = [];
        hasData = false;
    }

    return CompletedTasksChart(
      period: _selectedCompletedPeriod,
      isVip: _isVip,
      taskData: taskData,
      hasData: hasData,
    );
  }

  Widget _buildCompletedPeriodButton(
    String period,
    bool isDarkMode, {
    bool isVipOnly = false,
  }) {
    final isSelected = _selectedCompletedPeriod == period;
    final isLocked = isVipOnly && !_isVip;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    final textLightColor = isDarkMode
        ? AppTheme.darkTextLight
        : AppTheme.textLight;

    return GestureDetector(
      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur ini hanya untuk member VIP'),
                ),
              );
            }
          : () {
              setState(() => _selectedCompletedPeriod = period);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              period,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isLocked
                    ? textLightColor
                    : textSecondaryColor,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 4),
              Icon(Iconsax.lock, size: 12, color: textLightColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            // Show confirmation dialog
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Apakah Anda yakin ingin keluar?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            );

            if (shouldLogout == true && mounted) {
              // Call logout API
              await AuthApiService().logout();

              if (mounted) {
                // Navigate to login screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
          icon: const Icon(Iconsax.logout, color: Colors.red),
          label: const Text(
            'Logout',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.red, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: cardColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isDarkMode) {
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Leave Management Card
              Expanded(
                child: Consumer<LeaveProvider>(
                  builder: (context, leaveProvider, child) {
                    final upcomingCount = leaveProvider.upcomingLeaveCount;
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    return _buildActionCard(
                      isDarkMode: isDarkMode,
                      icon: Iconsax.calendar_tick,
                      title: 'Manajemen Cuti',
                      subtitle: upcomingCount > 0
                          ? '$upcomingCount cuti mendatang'
                          : 'Atur hari libur Anda',
                      color: AppTheme.primaryColor,
                      onTap: () async {
                        final userId = await SecureStorage.getUserId();
                        if (userId == null || userId.isEmpty) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sesi login tidak valid. Silakan login ulang.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }
                        if (!mounted) return;
                        navigator.push(
                          MaterialPageRoute(
                            builder: (navContext) =>
                                LeaveManagementScreen(userId: userId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Messages/Inbox Card
              Expanded(
                child: Consumer<MessagingProvider>(
                  builder: (context, messaging, child) {
                    final unreadCount = messaging.unreadCount;

                    return _buildActionCard(
                      isDarkMode: isDarkMode,
                      icon: Iconsax.message,
                      title: 'Pesan Bot',
                      subtitle: unreadCount > 0
                          ? '$unreadCount pesan baru'
                          : 'Lihat semua pesan',
                      color: Colors.orange,
                      badge: unreadCount > 0 ? unreadCount : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MessagesScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    int? badge,
    required VoidCallback onTap,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: isDarkMode ? null : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: textSecondaryColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
