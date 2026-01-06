import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class CompletedTasksChart extends StatelessWidget {
  final String period;
  final bool isVip;
  final List<int> taskData; // Count of completed tasks per period
  final bool hasData;

  const CompletedTasksChart({
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDarkMode ? AppTheme.darkDivider : Colors.grey.shade200,
              strokeWidth: 1,
              dashArray: [5, 5],
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
              reservedSize: 40,
              interval: _getHorizontalInterval(),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextLight
                        : AppTheme.textLight,
                    fontSize: 11,
                  ),
                );
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
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (taskData.length - 1).toDouble(),
        minY: 0,
        maxY: _getMaxY(),
        lineBarsData: [
          LineChartBarData(
            spots: _getSpots(),
            isCurved: true,
            color: AppTheme.secondaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.secondaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppTheme.secondaryColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final count = spot.y.toInt();
                return LineTooltipItem(
                  '$count tugas',
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
      ),
    );
  }

  List<FlSpot> _getSpots() {
    return taskData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();
  }

  Widget _buildEmptyState(bool isDarkMode) {
    String message;
    switch (period) {
      case 'Daily':
        message = 'Tidak ada tugas selesai di Minggu ini';
        break;
      case 'Weekly':
        message = 'Tidak ada tugas selesai di Bulan ini';
        break;
      case 'Monthly':
        message = 'Tidak ada tugas selesai di Tahun ini';
        break;
      default:
        message = 'Tidak ada tugas selesai';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
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
    final maxCount = taskData.reduce((a, b) => a > b ? a : b);
    // Round up to next multiple of 5 for clean chart
    return ((maxCount + 4) ~/ 5) * 5.0;
  }

  double _getHorizontalInterval() {
    final maxY = _getMaxY();
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    return 10;
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
