import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

class HomeSummaryCards extends StatelessWidget {
  const HomeSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();

    if (statusProvider.serverStatus == null) {
      return const SizedBox();
    }

    final stats = statusProvider.serverStatus!.stats;
    final totalQueries = stats.numDnsQueries;
    final blockedQueries = stats.numBlockedFiltering;
    final blockRate = totalQueries > 0
        ? (blockedQueries / totalQueries)
        : 0.0;
    final avgLatencyMs = stats.avgProcessingTime * 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'DNS 查询总数',
                  primaryValue: intFormat(totalQueries, locale),
                  secondaryValue: '平均耗时: ${doubleFormat(avgLatencyMs, locale)} ms',
                  icon: Icons.dns_rounded,
                  iconColor: Colors.blue,
                  percent: 1.0,
                  progressColor: Colors.blue,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    logsProvider.setSelectedResultStatus(value: 'all', refetch: true);
                    logsProvider.filterLogs();
                    appConfigProvider.setSelectedScreen(1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: '拦截与去广告',
                  primaryValue: intFormat(blockedQueries, locale),
                  secondaryValue: '拦截率: ${(blockRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.block_rounded,
                  iconColor: Colors.red,
                  percent: blockRate.clamp(0.0, 1.0),
                  progressColor: Colors.red,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    logsProvider.setSelectedResultStatus(value: 'blocked', refetch: true);
                    logsProvider.filterLogs();
                    appConfigProvider.setSelectedScreen(1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: '已加载规则总数',
                  primaryValue: intFormat(
                      statusProvider.serverStatus!.filteringStatus.filters
                          .fold<int>(0, (prev, f) => prev + f.rulesCount),
                      locale),
                  secondaryValue:
                      '启用订阅: ${statusProvider.serverStatus!.filteringStatus.filters.where((f) => f.enabled).length} 组',
                  icon: Icons.rule_rounded,
                  iconColor: Colors.teal,
                  percent: 1.0,
                  progressColor: Colors.teal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appConfigProvider.setSelectedScreen(2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: '自定义规则与白名单',
                  primaryValue: intFormat(
                      statusProvider.serverStatus!.filteringStatus.userRules.length,
                      locale),
                  secondaryValue: statusProvider.serverStatus!.generalEnabled
                      ? '保护运行中'
                      : '保护已暂停',
                  icon: Icons.playlist_add_check_rounded,
                  iconColor: Colors.purple,
                  percent: 1.0,
                  progressColor: Colors.purple,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appConfigProvider.setSelectedScreen(2);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String title;
  final String primaryValue;
  final String secondaryValue;
  final IconData icon;
  final Color iconColor;
  final double percent;
  final Color progressColor;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    required this.icon,
    required this.iconColor,
    required this.percent,
    required this.progressColor,
    required this.onTap,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 20,
                      ),
                    ),
                    CircularPercentIndicator(
                      radius: 16.0,
                      lineWidth: 3.5,
                      percent: widget.percent,
                      progressColor: widget.progressColor,
                      backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.primaryValue,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.secondaryValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
