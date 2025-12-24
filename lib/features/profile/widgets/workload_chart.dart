import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class WorkloadChart extends StatelessWidget {
  final String period;
  final bool isVip;
  final List<int> taskData;
  final bool hasData;

  const WorkloadChart({
    super.key,
    required this.period,
    required this.isVip,
    required this.taskData,
    this.hasData = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show empty state if no data
    if (!hasData || taskData.every((count) => count == 0)) {
      return _buildEmptyState(isDarkMode);
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: _getMaxY(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppTheme.primaryColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.round()} tugas',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(),
          getDrawingHorizontalLine: (value) {
            final bool isBaseLine = value == 0;
            return FlLine(
              color: isBaseLine
                  ? (isDarkMode
                        ? AppTheme.darkTextSecondary.withOpacity(0.5)
                        : AppTheme.textPrimary.withOpacity(0.8))
                  : (isDarkMode ? AppTheme.darkDivider : Colors.grey.shade200),
              strokeWidth: isBaseLine ? 2 : 1,
              dashArray: isBaseLine ? null : [5, 5],
            );
          },
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
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                final interval = _getHorizontalInterval();
                if (value == 0 || value % interval == 0) {
                  return Text(
                    value.toInt().toString(),
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
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode
                  ? AppTheme.darkTextSecondary.withOpacity(0.3)
                  : AppTheme.textPrimary.withOpacity(0.2),
              width: 1,
            ),
            left: BorderSide(
              color: isDarkMode
                  ? AppTheme.darkTextSecondary.withOpacity(0.3)
                  : AppTheme.textPrimary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _getChartSpots(),
            isCurved: true,
            barWidth: 4,
            color: AppTheme.primaryColor,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 6,
                    color: isDarkMode ? AppTheme.darkCard : Colors.white,
                    strokeWidth: 3,
                    strokeColor: AppTheme.primaryColor,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    String message;
    switch (period) {
      case 'Daily':
        message = 'Tidak ada Tugas di Minggu ini';
        break;
      case 'Weekly':
        message = 'Tidak ada Tugas di Bulan ini';
        break;
      case 'Monthly':
        message = 'Tidak ada Tugas di Tahun ini';
        break;
      default:
        message = 'Tidak ada Tugas';
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
    if (taskData.isEmpty) return 10;
    final maxValue = taskData.reduce((a, b) => a > b ? a : b);
    // Add some padding above the max value
    return (maxValue * 1.2).ceilToDouble();
  }

  double _getHorizontalInterval() {
    final maxY = _getMaxY();
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return 20;
  }

  String _getBottomTitle(int index) {
    switch (period) {
      case 'Daily':
        const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        return index >= 0 && index < days.length ? days[index] : '';
      case 'Weekly':
        // Fixed: Show exactly 4 weeks (W1, W2, W3, W4)
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

  List<FlSpot> _getChartSpots() {
    return taskData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
  }
}
