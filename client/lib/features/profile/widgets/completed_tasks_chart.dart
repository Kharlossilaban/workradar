import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/completed_tasks_provider.dart';

class CompletedTasksChart extends StatelessWidget {
  final String period;
  final bool isVip;
  final List<int> taskData; // Total count (backward compatible)
  final List<CategoryCount>? categoryData; // Category breakdown
  final bool hasData;

  const CompletedTasksChart({
    super.key,
    required this.period,
    required this.isVip,
    required this.taskData,
    this.categoryData,
    this.hasData = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show empty state if no data
    if (!hasData || taskData.every((count) => count == 0)) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      children: [
        // Chart
        Expanded(
          child: LineChart(
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
              lineBarsData: _getLineBarsData(),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => isDarkMode
                      ? AppTheme.darkCard
                      : Colors.white,
                  tooltipBorder: BorderSide(
                    color: isDarkMode ? AppTheme.darkDivider : Colors.grey.shade300,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final categoryInfo = CategoryColors.allCategories
                          .firstWhere((c) => c.color == spot.bar.color,
                              orElse: () => CategoryColors.allCategories.first);
                      final count = spot.y.toInt();
                      return LineTooltipItem(
                        '${categoryInfo.name}: $count',
                        TextStyle(
                          color: categoryInfo.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        
        // Legend
        const SizedBox(height: 16),
        _buildLegend(isDarkMode),
      ],
    );
  }

  List<LineChartBarData> _getLineBarsData() {
    if (categoryData == null) {
      // Fallback: single line for total
      return [
        LineChartBarData(
          spots: _getSpots(),
          isCurved: true,
          color: CategoryColors.kerjaColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: CategoryColors.kerjaColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ];
    }

    // Multi-line for each category
    final lines = <LineChartBarData>[];
    
    for (final cat in CategoryColors.allCategories) {
      final spots = <FlSpot>[];
      bool hasAnyData = false;
      
      for (int i = 0; i < categoryData!.length; i++) {
        final count = categoryData![i].getForCategory(cat.name);
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
        if (count > 0) hasAnyData = true;
      }
      
      // Only add line if there's data for this category
      if (hasAnyData) {
        lines.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cat.color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: cat.color,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }
    
    return lines;
  }

  List<FlSpot> _getSpots() {
    return taskData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();
  }

  Widget _buildLegend(bool isDarkMode) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: CategoryColors.allCategories.map((cat) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
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
    
    // If we have category data, find max across all categories
    int maxCount = taskData.reduce((a, b) => a > b ? a : b);
    
    if (categoryData != null) {
      for (final cat in CategoryColors.allCategories) {
        for (final data in categoryData!) {
          final count = data.getForCategory(cat.name);
          if (count > maxCount) maxCount = count;
        }
      }
    }
    
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
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
        ];
        return index >= 0 && index < months.length ? months[index] : '';
      default:
        return '';
    }
  }
}
