import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class WorkloadChart extends StatelessWidget {
  final String period;
  final bool isVip;
  final List<int> taskData; // This now contains duration in minutes
  final bool hasData;
  final int totalWorkMinutes; // Added to calculate capacity

  const WorkloadChart({
    super.key,
    required this.period,
    required this.isVip,
    required this.taskData,
    required this.totalWorkMinutes,
    this.hasData = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show empty state if no data
    if (!hasData || taskData.every((minutes) => minutes == 0)) {
      return _buildEmptyState(isDarkMode);
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.primaryColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final minutes = rod.toY.toInt();
              final hours = minutes ~/ 60;
              final remainingMins = minutes % 60;
              String timeStr = hours > 0
                  ? '${hours}j ${remainingMins}m'
                  : '${remainingMins}m';
              return BarTooltipItem(
                timeStr,
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _getBottomTitle(value.toInt()),
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      fontSize: period == 'Monthly' ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 60 == 0) {
                  return Text(
                    '${(value / 60).toInt()}j',
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkTextLight
                          : AppTheme.textLight,
                      fontSize: 11,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 60, // Every hour
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDarkMode ? AppTheme.darkDivider : Colors.grey.shade200,
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: _getBarGroups(isDarkMode),
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups(bool isDarkMode) {
    return taskData.asMap().entries.map((e) {
      final index = e.key;
      final minutes = e.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: minutes.toDouble(),
            color: _getBarColor(minutes),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: isDarkMode
                  ? AppTheme.darkDivider.withValues(alpha: 0.3)
                  : Colors.grey.shade100,
            ),
          ),
        ],
      );
    }).toList();
  }

  // Modern color palette for workload bars (avoiding blue/purple from theme)
  static const List<Color> _workloadColors = [
    Color(0xFF4ECDC4), // Teal - Low workload
    Color(0xFF95E1D3), // Mint - Fair workload
    Color(0xFFFFD93D), // Yellow - Medium workload
    Color(0xFFFF8C42), // Orange - High workload
    Color(0xFFFF6B6B), // Red - Very high workload
    Color(0xFFF38181), // Soft Red - Overload
  ];

  Color _getBarColor(int totalMinutes) {
    if (totalWorkMinutes <= 0) return _workloadColors[0];

    // Calculate workload percentage
    final workloadPercentage = (totalMinutes / totalWorkMinutes * 100).clamp(
      0.0,
      150.0,
    );

    // Progressive color selection based on workload
    if (workloadPercentage < 30) {
      return _workloadColors[0]; // Teal - Light
    } else if (workloadPercentage < 50) {
      return _workloadColors[1]; // Mint - Fair
    } else if (workloadPercentage < 70) {
      return _workloadColors[2]; // Yellow - Medium
    } else if (workloadPercentage < 90) {
      return _workloadColors[3]; // Orange - High
    } else if (workloadPercentage < 100) {
      return _workloadColors[4]; // Red - Very High
    } else {
      return _workloadColors[5]; // Soft Red - Overload
    }
  }

  Widget _buildEmptyState(bool isDarkMode) {
    String message;
    switch (period) {
      case 'Daily':
        message = 'Tidak ada kegiatan di Minggu ini';
        break;
      case 'Weekly':
        message = 'Tidak ada kegiatan di Bulan ini';
        break;
      case 'Monthly':
        message = 'Tidak ada kegiatan di Tahun ini';
        break;
      default:
        message = 'Tidak ada kegiatan';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: isDarkMode ? AppTheme.darkTextLight : AppTheme.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            message,
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

  double _getMaxY() {
    if (taskData.isEmpty) return 480; // Default 8 hours
    final maxMinutes = taskData.reduce((a, b) => a > b ? a : b);

    // Ensure maxY is at least 8 hours (480 mins) or the max duration found
    double baseline = totalWorkMinutes > 0 ? totalWorkMinutes.toDouble() : 480;

    return maxMinutes > baseline ? (maxMinutes + 60).toDouble() : baseline;
  }

  String _getBottomTitle(int index) {
    switch (period) {
      case 'Daily':
        const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        return index >= 0 && index < days.length ? days[index] : '';
      case 'Weekly':
        return index >= 0 && index < 4 ? 'W${index + 1}' : '';
      case 'Monthly':
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        return index >= 0 && index < months.length ? months[index] : '';
      default:
        return '';
    }
  }
}
