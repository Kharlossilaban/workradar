import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/workload_chart.dart';
import '../providers/workload_provider.dart';
import 'profile_detail_screen.dart';
import '../../subscription/screens/subscription_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedPeriod = 'Daily';
  final String _username = 'John Doe';
  final String _gmail = 'john.doe@gmail.com';
  final bool _isVip = true; // Set to true for VIP access during UI/UX testing

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
              const SizedBox(height: 20),
              if (!_isVip) _buildVipBanner(),
              const SizedBox(height: 20),
              _buildWorkloadCard(isDarkMode),
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
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Iconsax.user, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $_username! 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Iconsax.sms, size: 18, color: textSecondaryColor),
                    const SizedBox(width: 6),
                    Text(
                      _gmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.vipGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.crown_15, color: Colors.white, size: 16),
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
              color: AppTheme.vipGold.withOpacity(0.4),
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
                color: Colors.white.withOpacity(0.2),
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
                      color: AppTheme.primaryColor.withOpacity(0.1),
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

    switch (_selectedPeriod) {
      case 'Daily':
        final weekStart = provider.getWeekStartDate();
        taskData = provider.getDailyTaskCounts(weekStart);
        hasData = provider.hasDataForWeek(weekStart);
        break;

      case 'Weekly':
        if (!_isVip) {
          taskData = [0, 0, 0, 0];
          hasData = false;
        } else {
          final monthDate = provider.getMonthDate();
          taskData = provider.getWeeklyTaskCounts(monthDate);
          hasData = provider.hasDataForMonth(monthDate);
        }
        break;

      case 'Monthly':
        if (!_isVip) {
          taskData = List.generate(12, (_) => 0);
          hasData = false;
        } else {
          final year = provider.getYear();
          taskData = provider.getMonthlyTaskCounts(year);
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
}
