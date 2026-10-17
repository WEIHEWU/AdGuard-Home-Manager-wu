import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

class HomeBarChart extends StatefulWidget {
  const HomeBarChart({super.key});

  @override
  State<HomeBarChart> createState() => _HomeBarChartState();
}

class _HomeBarChartState extends State<HomeBarChart> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();

    if (statusProvider.serverStatus == null) return const SizedBox();

    final stats = statusProvider.serverStatus!.stats;
    final queries = stats.dnsQueries;
    final blocked = stats.blockedFiltering;
    final count = min(queries.length, blocked.length);

    if (count == 0) return const SizedBox();

    // Determine max Y for scaling
    double maxY = 10;
    for (int i = 0; i < count; i++) {
      if (queries[i] > maxY) maxY = queries[i].toDouble();
      if (blocked[i] > maxY) maxY = blocked[i].toDouble();
    }
    maxY = maxY * 1.15; // extra headroom

    final totalQueries = stats.numDnsQueries;
    final totalBlocked = stats.numBlockedFiltering;
    final blockRate = totalQueries > 0 ? (totalBlocked / totalQueries * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      logsProvider.setSelectedResultStatus(value: 'all', refetch: true);
                      logsProvider.filterLogs();
                      appConfigProvider.setSelectedScreen(1);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '每时段统计对比 (柱状图)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '总查询: ${intFormat(totalQueries, locale)} · 拦截率: ${blockRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Legend
                  Row(
                    children: [
                      _LegendItem(color: Colors.blue, label: '查询'),
                      const SizedBox(width: 8),
                      _LegendItem(color: Colors.red, label: '拦截'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Bar Chart
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.inverseSurface,
                        fitInsideHorizontally: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final isQuery = rodIndex == 0;
                          final value = rod.toY.toInt();
                          return BarTooltipItem(
                            '${isQuery ? "查询" : "拦截"}: $value',
                            TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      touchCallback: (event, response) {
                        if (response?.spot != null && event is FlTapUpEvent) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _touchedGroupIndex = response!.spot!.touchedBarGroupIndex;
                          });
                        }
                      },
                    ),
                    titlesData: const FlTitlesData(
                      show: false,
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 5 ? maxY / 4 : 2,
                      getDrawingHorizontalLine: (val) => FlLine(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(count, (index) {
                      final qVal = queries[index].toDouble();
                      final bVal = blocked[index].toDouble();
                      final isSelected = _touchedGroupIndex == index;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: qVal,
                            color: isSelected ? Colors.blue.shade300 : Colors.blue,
                            width: count > 16 ? 4.5 : 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                          BarChartRodData(
                            toY: bVal,
                            color: isSelected ? Colors.red.shade300 : Colors.red,
                            width: count > 16 ? 4.5 : 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
