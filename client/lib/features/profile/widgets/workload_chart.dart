import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/workload_provider.dart';

class WorkloadChart extends StatelessWidget {
  final String period;
  final bool isVip;
  final List<int> taskData; // Total duration (backward compatible)
  final List<CategoryDuration>? categoryData; // Category breakdown
  final bool hasData;
  final int totalWorkMinutes;

  const WorkloadChart({
    super.key,
    required this.period,
    required this.isVip,
    required this.taskData,
    required this.totalWorkMinutes,
    this.categoryData,
    this.hasData = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show empty state if no data
    if (!hasData || taskData.every((minutes) => minutes == 0)) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      children: [
        // Chart
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => isDarkMode
                      ? AppTheme.darkCard
                      : Colors.white,
                  tooltipBorder: BorderSide(
                    color: isDarkMode ? AppTheme.darkDivider : Colors.grey.shade300,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (categoryData != null && groupIndex < categoryData!.length) {
                      final catData = categoryData![groupIndex];
                      final lines = <TextSpan>[];
                      
                      // Add total
                      final totalMins = catData.total;
                      final totalHours = totalMins ~/ 60;
                      final totalRemMins = totalMins % 60;
                      lines.add(TextSpan(
                        text: 'Total: ${totalHours}j ${totalRemMins}m\n',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ));
                      
                      // Add breakdown per category
                      for (final cat in CategoryColors.allCategories) {
                        final mins = catData.getForCategory(cat.name);
                        if (mins > 0) {
                          final h = mins ~/ 60;
                          final m = mins % 60;
                          lines.add(TextSpan(
                            text: '${cat.name}: ${h > 0 ? "${h}j " : ""}${m}m\n',
                            style: TextStyle(
                              color: cat.color,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ));
                        }
                      }
                      
                      return BarTooltipItem(
                        '',
                        const TextStyle(),
                        children: lines,
                      );
                    }
                    
                    // Fallback for non-category data
                    final minutes = rod.toY.toInt();
                    final hours = minutes ~/ 60;
                    final remainingMins = minutes % 60;
                    return BarTooltipItem(
                      '${hours}j ${remainingMins}m',
                      TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
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
                horizontalInterval: 60,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: isDarkMode ? AppTheme.darkDivider : Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: _getStackedBarGroups(isDarkMode),
            ),
          ),
        ),
        
        // Legend
        const SizedBox(height: 16),
        _buildLegend(isDarkMode),
      ],
    );
  }

  List<BarChartGroupData> _getStackedBarGroups(bool isDarkMode) {
    final barWidth = period == 'Monthly' ? 12.0 : 16.0;
    
    return taskData.asMap().entries.map((e) {
      final index = e.key;
      
      // If we have category data, create stacked bars
      if (categoryData != null && index < categoryData!.length) {
        final catDuration = categoryData![index];
        final rodStackItems = <BarChartRodStackItem>[];
        double currentY = 0;
        
        // Order: Kerja, Pribadi, Wishlist, Hari Ulang Tahun
        for (final cat in CategoryColors.allCategories) {
          final mins = catDuration.getForCategory(cat.name);
          if (mins > 0) {
            rodStackItems.add(BarChartRodStackItem(
              currentY,
              currentY + mins,
              cat.color,
            ));
            currentY += mins;
          }
        }
        
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: currentY,
              rodStackItems: rodStackItems,
              width: barWidth,
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
      }
      
      // Fallback: single color bar
      final minutes = e.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: minutes.toDouble(),
            color: CategoryColors.kerjaColor,
            width: barWidth,
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
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(3),
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
    if (taskData.isEmpty) return 480;
    final maxMinutes = taskData.reduce((a, b) => a > b ? a : b);
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
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
        ];
        return index >= 0 && index < months.length ? months[index] : '';
      default:
        return '';
    }
  }
}
