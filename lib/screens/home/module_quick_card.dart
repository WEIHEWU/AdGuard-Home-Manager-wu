// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/module/app_allowlist_modal.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

/// 极简内嵌式模块快捷操作区（内嵌于首页顶部保护主卡片中）：
/// - 常态下仅展示一行 3 个高频操作按钮（误杀排错、应用白名单、网络刷新），零视觉噪音；
/// - 仅当检测到核心未运行或 DNS/SNI 转发异常时，才在按钮上方显示一行异常修复提示。
class ModuleQuickActions extends StatefulWidget {
  const ModuleQuickActions({super.key});

  @override
  State<ModuleQuickActions> createState() => _ModuleQuickActionsState();
}

class _ModuleQuickActionsState extends State<ModuleQuickActions> {
  bool _loadingDiag = true;
  bool _flushing = false;
  Map<String, dynamic> _diag = {
    'running': true,
    'natOk': true,
    'sniOk': true,
  };

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final diag = await ModuleConfigService().getModuleDiagnostics();
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _loadingDiag = false;
    });
  }

  Future<void> _handleQuickFlush() async {
    if (_flushing) return;
    HapticFeedback.mediumImpact();
    setState(() => _flushing = true);

    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final service = ModuleConfigService();

    await Future.wait([
      if (serversProvider.apiClient2 != null)
        serversProvider.apiClient2!.resetDnsCache(),
      service.flushSystemDnsCache(),
      service.reloadFirewallRules(),
    ]);

    await Future.delayed(const Duration(milliseconds: 500));
    await Future.wait([
      _loadDiagnostics(),
      statusProvider.getServerStatus(withLoadingIndicator: false),
    ]);

    if (!mounted) return;
    setState(() => _flushing = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '已刷新 DNS 缓存并重载规则',
      color: Colors.green,
    );
  }

  Future<void> _openAppAllowlist() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const AppAllowlistModal(),
    );
    if (mounted) {
      _loadDiagnostics();
    }
  }

  Future<void> _openFalsePositiveAssistant() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const _FalsePositiveAssistantModal(),
    );
  }

  String? _getAnomalyMessage(bool generalEnabled) {
    if (_loadingDiag || !generalEnabled) return null;
    final running = _diag['running'] == true;
    final natOk = _diag['natOk'] == true;
    final sniOk = _diag['sniOk'] == true;
    if (!running) return '模块核心未运行';
    if (!natOk && !sniOk) return 'DNS 与 SNI 转发未生效';
    if (!natOk) return 'DNS 转发规则未生效';
    if (!sniOk) return 'SNI 过滤规则未生效';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final generalEnabled = statusProvider.serverStatus?.generalEnabled ?? true;
    final anomalyMsg = _getAnomalyMessage(generalEnabled);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anomalyMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    anomalyMsg,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _flushing ? null : _handleQuickFlush,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '一键修复',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.troubleshoot_rounded,
                label: '误杀排错',
                onTap: _openFalsePositiveAssistant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.apps_rounded,
                label: '应用白名单',
                onTap: _openAppAllowlist,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: _flushing
                    ? Icons.hourglass_top_rounded
                    : Icons.bolt_rounded,
                label: _flushing ? '刷新中…' : '网络刷新',
                onTap: _flushing ? () {} : _handleQuickFlush,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final fgColor = colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: fgColor,
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

class _BlockedDomainSummary {
  final String domain;
  int count;
  DateTime latestTime;
  final String ruleText;
  final bool isSni;

  _BlockedDomainSummary({
    required this.domain,
    required this.count,
    required this.latestTime,
    required this.ruleText,
    required this.isSni,
  });
}

class _FalsePositiveAssistantModal extends StatefulWidget {
  const _FalsePositiveAssistantModal();

  @override
  State<_FalsePositiveAssistantModal> createState() =>
      _FalsePositiveAssistantModalState();
}

class _FalsePositiveAssistantModalState
    extends State<_FalsePositiveAssistantModal> {
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<_BlockedDomainSummary> _blockedDomains = [];
  final Set<String> _unblockedDomains = {};
  final Set<String> _unblockingInProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchRecentBlocked();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentBlocked() async {
    setState(() => _loading = true);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.apiClient2 == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final result = await serversProvider.apiClient2!.getLogs(
      count: 150,
      responseStatus: 'blocked',
    );

    if (!mounted) return;
    if (result.successful == true && result.content is LogsData) {
      final logs = (result.content as LogsData).data;
      final Map<String, _BlockedDomainSummary> map = {};
      for (final log in logs) {
        final domain = log.question.name?.trim() ?? '';
        if (domain.isEmpty) continue;
        final isSni =
            (log.clientProto?.toLowerCase().contains('sni') ?? false) ||
                log.question.type.toUpperCase() == 'SNI';
        final ruleText = log.rules.isNotEmpty
            ? log.rules.first.text
            : (log.rule?.isNotEmpty == true ? log.rule! : log.reason);

        if (map.containsKey(domain)) {
          map[domain]!.count += 1;
          if (log.time.isAfter(map[domain]!.latestTime)) {
            map[domain]!.latestTime = log.time;
          }
        } else {
          map[domain] = _BlockedDomainSummary(
            domain: domain,
            count: 1,
            latestTime: log.time,
            ruleText: ruleText,
            isSni: isSni,
          );
        }
      }
      final list = map.values.toList()
        ..sort((a, b) => b.latestTime.compareTo(a.latestTime));
      setState(() {
        _blockedDomains = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds.clamp(1, 59)}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _unblockDomain(String domain) async {
    if (_unblockingInProgress.contains(domain) ||
        _unblockedDomains.contains(domain)) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _unblockingInProgress.add(domain));

    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    final ok = await statusProvider.blockUnblockDomain(
      domain: domain,
      newStatus: 'unblock',
    );

    if (!mounted) return;
    setState(() {
      _unblockingInProgress.remove(domain);
      if (ok) {
        _unblockedDomains.add(domain);
      }
    });

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? '已放行 $domain' : '放行失败，请重试',
      color: ok ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final filtered = _blockedDomains.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.domain.toLowerCase().contains(_searchQuery) ||
          item.ruleText.toLowerCase().contains(_searchQuery);
    }).toList();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '误杀排错（最近拦截）',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _fetchRecentBlocked,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: '搜索域名…',
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? '无匹配域名'
                                : '最近暂无拦截记录',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isUnblocked =
                                _unblockedDomains.contains(item.domain);
                            final isBusy =
                                _unblockingInProgress.contains(item.domain);

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (item.isSni
                                              ? Colors.purple
                                              : Colors.red)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      item.isSni ? 'SNI' : 'DNS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.isSni
                                            ? Colors.purple
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.domain,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${_formatRelativeTime(item.latestTime)} · ${item.count}次 · ${item.ruleText}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: isUnblocked || isBusy
                                    ? null
                                    : () => _unblockDomain(item.domain),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        isUnblocked ? '已放行' : '放行',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
