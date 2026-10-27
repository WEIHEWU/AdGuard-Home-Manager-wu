// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_miuix/miuix.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/module/app_allowlist_modal.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

class ModuleQuickCard extends StatefulWidget {
  const ModuleQuickCard({super.key});

  @override
  State<ModuleQuickCard> createState() => _ModuleQuickCardState();
}

class _ModuleQuickCardState extends State<ModuleQuickCard> {
  bool _loadingDiag = true;
  bool _flushing = false;
  Map<String, dynamic> _diag = {
    'running': false,
    'pid': '',
    'dnsPort': '',
    'natOk': false,
    'sniOk': false,
    'vpnMode': 'off',
    'rssMb': '',
    'allowlistCount': 0,
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

    await Future.delayed(const Duration(milliseconds: 600));
    await Future.wait([
      _loadDiagnostics(),
      statusProvider.getServerStatus(withLoadingIndicator: false),
    ]);

    if (!mounted) return;
    setState(() => _flushing = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '已刷新系统与核心 DNS 缓存，并重载防火墙规则',
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
      builder: (ctx) => _FalsePositiveAssistantModal(
        onOpenAppAllowlist: () {
          Navigator.of(ctx).pop();
          _openAppAllowlist();
        },
      ),
    );
    if (mounted) {
      _loadDiagnostics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final running = _diag['running'] == true;
    final natOk = _diag['natOk'] == true;
    final sniOk = _diag['sniOk'] == true;
    final vpnMode = (_diag['vpnMode'] ?? 'off').toString();
    final rssMb = (_diag['rssMb'] ?? '').toString();
    final allowlistCount = (_diag['allowlistCount'] as int?) ?? 0;

    String vpnLabel = '直连模式';
    Color vpnColor = colorScheme.onSurfaceVariant;
    if (vpnMode == 'takeover') {
      vpnLabel = 'VPN 接管去广告';
      vpnColor = Colors.blue;
    } else if (vpnMode == 'bypass') {
      vpnLabel = 'VPN 翻墙防污染';
      vpnColor = Colors.teal;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MiuixCard(
        cornerRadius: 20,
        insideMargin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _loadingDiag
                        ? Colors.grey
                        : (running && natOk ? Colors.green : Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '模块引擎与排错快捷台',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (rssMb.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '内存 $rssMb',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _loadDiagnostics,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusBadge(
                    icon: natOk
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    label: natOk ? 'DNS 接管正常' : 'DNS 未接管',
                    color: natOk ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _StatusBadge(
                    icon: sniOk
                        ? Icons.security_rounded
                        : Icons.shield_outlined,
                    label: sniOk ? 'SNI 嗅探生效' : 'SNI 未生效',
                    color: sniOk ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _StatusBadge(
                    icon: Icons.vpn_lock_rounded,
                    label: vpnLabel,
                    color: vpnColor,
                  ),
                  if (allowlistCount > 0) ...[
                    const SizedBox(width: 6),
                    _StatusBadge(
                      icon: Icons.verified_user_outlined,
                      label: '已放行 $allowlistCount 款应用',
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.troubleshoot_rounded,
                    label: '误杀排错',
                    highlight: true,
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
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = highlight
        ? colorScheme.primaryContainer.withValues(alpha: 0.75)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final fgColor = highlight
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
  final VoidCallback onOpenAppAllowlist;

  const _FalsePositiveAssistantModal({
    required this.onOpenAppAllowlist,
  });

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
        final isSni = (log.clientProto?.toLowerCase().contains('sni') ?? false) ||
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
      label: ok
          ? '已放行 $domain 并清空系统 DNS 缓存，请切回应用重试'
          : '放行失败，请重试',
      color: ok ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _blockedDomains.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.domain.toLowerCase().contains(_searchQuery) ||
          item.ruleText.toLowerCase().contains(_searchQuery);
    }).toList();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '误杀排错助手',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '展示最近被拦截的域名，点击「放行」立即解除拦截并刷新缓存',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: '重新拉取最近拦截记录',
                    onPressed: _fetchRecentBlocked,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 引导去应用白名单的提示卡片
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '如果是某款 App 整体无法联网或闪退，建议直接将其加入应用白名单。',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: widget.onOpenAppAllowlist,
                    child: const Text('去加白名单'),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: '搜索被拦截的域名或命中规则…',
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
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? '未找到匹配的被拦截域名'
                                : '最近暂无被拦截的请求记录',
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (item.isSni
                                              ? Colors.purple
                                              : Colors.red)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
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
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${_formatRelativeTime(item.latestTime)} · 拦截 ${item.count} 次 · 规则: ${item.ruleText}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
                                        isUnblocked ? '已放行' : '一键放行',
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
