import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/screens/settings/statistics_settings/statistics_settings.dart';
import 'package:adguard_home_manager/screens/settings/customization/customization.dart';
import 'package:adguard_home_manager/screens/settings/language/language_settings.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';

import 'package:adguard_home_manager/widgets/custom_settings_tile.dart';
import 'package:adguard_home_manager/widgets/section_label.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

final settingsNavigatorKey = GlobalKey<NavigatorState>();

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: [
              const Expanded(
                  flex: 1,
                  child: _SettingsWidget(
                    twoColumns: true,
                  )),
              Expanded(
                flex: 2,
                child: Navigator(
                  key: settingsNavigatorKey,
                  onGenerateRoute: (settings) =>
                      MaterialPageRoute(builder: (ctx) => const SizedBox()),
                ),
              )
            ],
          );
        } else {
          return const _SettingsWidget(
            twoColumns: false,
          );
        }
      },
    );
  }
}

class _SettingsWidget extends StatefulWidget {
  final bool twoColumns;

  const _SettingsWidget({
    required this.twoColumns,
  });

  @override
  State<_SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<_SettingsWidget> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _proxyUrlController = TextEditingController();

  bool _proxyUrlLoading = true;
  bool _proxyUrlSaving = false;
  bool _diagLoading = true;
  bool _cleaningAdCache = false;
  bool _restoringRules = false;
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
    Provider.of<AppConfigProvider>(context, listen: false)
        .setSelectedSettingsScreen(screen: null);
    super.initState();
    _loadProxyUrl();
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _proxyUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadProxyUrl() async {
    final moduleConfigService = ModuleConfigService();
    final url = await moduleConfigService.readProxyUrl();
    if (!mounted) return;
    setState(() {
      _proxyUrlController.text = url;
      _proxyUrlLoading = false;
    });
  }

  Future<void> _loadDiagnostics({bool forceRefresh = false}) async {
    final diag = await ModuleConfigService()
        .getModuleDiagnostics(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _diagLoading = false;
    });
  }

  String _buildDiagSummary(String moduleAddr) {
    if (_diagLoading) return '正在检测…';
    final running = _diag['running'] == true;
    final natOk = _diag['natOk'] == true;
    final sniOk = _diag['sniOk'] == true;
    final vpnMode = (_diag['vpnMode'] ?? 'off').toString();
    final rssMb = (_diag['rssMb'] ?? '').toString();
    final addrSuffix = moduleAddr.isNotEmpty ? ' · $moduleAddr' : '';
    if (!running) {
      return '未运行（点击查看日志或修复）$addrSuffix';
    }
    var vpnText = '';
    if (vpnMode == 'takeover') {
      vpnText = ' · VPN 接管去广告';
    } else if (vpnMode == 'bypass') {
      vpnText = ' · VPN 兼容防环路';
    }
    final memText = rssMb.isNotEmpty ? ' · $rssMb' : '';
    if (natOk && sniOk) {
      return '运行中 · 转发正常$memText$vpnText$addrSuffix';
    }
    final issues = <String>[
      if (!natOk) 'DNS 未接管',
      if (!sniOk) 'SNI 未生效',
    ].join(' / ');
    return '运行中 · $issues$memText$addrSuffix';
  }

  Future<void> _showLogsAndDiagModal() async {
    final service = ModuleConfigService();
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    String logs = await service.readModuleLogs(maxLines: 150);
    await _loadDiagnostics(forceRefresh: true);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('模块自检与运行日志'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildDiagSummary(appConfigProvider.moduleHttpAddress),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: (_diag['running'] == true &&
                                _diag['natOk'] == true)
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 280,
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: SelectableText(
                          logs.isEmpty
                              ? '暂无日志记录（/data/adb/agh/agh.log 为空）'
                              : logs,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final ok = await service.reloadFirewallRules();
                    await Future.delayed(const Duration(seconds: 2));
                    await _loadDiagnostics(forceRefresh: true);
                    logs = await service.readModuleLogs(maxLines: 150);
                    setModalState(() {});
                    if (mounted) {
                      showSnackbar(
                        appConfigProvider: appConfigProvider,
                        label: ok ? '已触发防火墙与守护规则重载' : '重载失败，请检查 Root 权限',
                        color: ok ? Colors.green : Colors.red,
                      );
                    }
                  },
                  child: const Text('重载防火墙规则'),
                ),
                TextButton(
                  onPressed: () async {
                    await service.clearModuleLogs();
                    logs = '';
                    setModalState(() {});
                  },
                  child: const Text('清空日志'),
                ),
                TextButton(
                  onPressed: () async {
                    await _loadDiagnostics(forceRefresh: true);
                    logs = await service.readModuleLogs(maxLines: 150);
                    setModalState(() {});
                  },
                  child: const Text('刷新'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showProxyUrlModal() async {
    final editController = TextEditingController(text: _proxyUrlController.text);
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        title: const Text('代理订阅链接 (PROXY_URL)'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: editController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '填写代理订阅链接，留空则关闭模块内置代理',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    tooltip: '清空',
                    onPressed: () => editController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '• 平时使用独立 VPN 客户端（Clash / FlClash / v2rayNG 等）时无需填写，模块会自动识别并兼容。\n'
                '• 填写或清空保存后立即生效，无需重启手机。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(editController.text.trim()),
            child: const Text('保存并应用'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    _proxyUrlController.text = result;
    await _saveProxyUrl();
  }

  Future<void> _handleCleanAdCaches() async {
    if (_cleaningAdCache) return;
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    setState(() => _cleaningAdCache = true);
    final ok = await ModuleConfigService().cleanAppAdCaches();
    if (!mounted) return;
    setState(() => _cleaningAdCache = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? '已清理国内外应用开屏及广告 SDK 缓存' : '清理失败，请检查 Root 权限',
      color: ok ? Colors.green : Colors.red,
    );
  }

  Future<void> _handleRestoreFactoryRules() async {
    if (_restoringRules) return;
    final mode = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认自定义规则'),
        content: const Text(
          '请选择恢复方式：\n\n'
          '• 智能补全（推荐）：保留你自己手动添加的规则，仅补全被误删的模块默认防广告规则。\n'
          '• 完全重置：清除所有手动改动的规则，完全恢复为模块出厂默认规则。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('reset'),
            child: const Text('完全重置'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('merge'),
            child: const Text('智能补全（推荐）'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;

    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final filteringProvider =
        Provider.of<FilteringProvider>(context, listen: false);

    if (serversProvider.apiClient2 == null) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: '未连接到本地 AdGuard Home 服务',
        color: Colors.red,
      );
      return;
    }

    setState(() => _restoringRules = true);
    final factoryRules = await ModuleConfigService().readFactoryUserRules();
    if (factoryRules.isEmpty) {
      if (!mounted) return;
      setState(() => _restoringRules = false);
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: '未能读取到模块默认规则备份',
        color: Colors.red,
      );
      return;
    }

    List<String> targetRules = List<String>.from(factoryRules);
    if (mode == 'merge') {
      final currentRes = await serversProvider.apiClient2!.getFilteringRules();
      if (currentRes.successful == true) {
        final existing = (currentRes.content as FilteringStatus).userRules;
        final factorySet = factoryRules.map((e) => e.trim()).toSet();
        for (final r in existing) {
          final trimmed = r.trim();
          if (trimmed.isNotEmpty && !factorySet.contains(trimmed)) {
            targetRules.add(r);
          }
        }
      }
    }

    final postRes = await serversProvider.apiClient2!
        .postFilteringRules(data: {'rules': targetRules});
    if (postRes.successful == true) {
      await filteringProvider.fetchFilters();
    }
    if (!mounted) return;
    setState(() => _restoringRules = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: postRes.successful == true
          ? (mode == 'merge' ? '已智能补全模块默认自定义规则' : '已完全重置为模块出厂默认规则')
          : '恢复规则失败，请稍后重试',
      color: postRes.successful == true ? Colors.green : Colors.red,
    );
  }

  Future<void> _saveProxyUrl() async {
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final value = _proxyUrlController.text.trim();
    setState(() => _proxyUrlSaving = true);
    final ok = await ModuleConfigService().saveProxyUrl(value);
    if (!mounted) return;
    setState(() => _proxyUrlSaving = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? '订阅链接已保存并立即生效' : '保存失败，请检查 Root 权限',
      color: ok ? Colors.green : Colors.red,
    );
  }

  void _showTileHelp() {
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '请下拉通知栏 → 点击编辑（铅笔图标）→ 将“AdGuard 开关”拖入快捷设置',
      color: Colors.blueGrey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;

    if (!widget.twoColumns &&
        appConfigProvider.selectedSettingsScreen != null) {
      appConfigProvider.setSelectedSettingsScreen(screen: null);
    }

    return ScaffoldMessenger(
      key: widget.twoColumns ? _scaffoldMessengerKey : null,
      child: Scaffold(
          body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar.large(
                pinned: true,
                floating: true,
                centerTitle: false,
                forceElevated: innerBoxIsScrolled,
                surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
                title: Text(AppLocalizations.of(context)!.settings),
              ))
        ],
        body: SafeArea(
          top: false,
          bottom: false,
          child: Builder(
              builder: (context) => CustomScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverOverlapInjector(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                            context),
                      ),
                      SliverList.list(
                        children: [
                          SectionLabel(label: '模块设置'),
                          CustomListTile(
                            icon: Icons.health_and_safety_rounded,
                            title: '模块运行状态与自检',
                            subtitle: _buildDiagSummary(
                                appConfigProvider.moduleHttpAddress),
                            onTap: _showLogsAndDiagModal,
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                          CustomListTile(
                            icon: Icons.vpn_key_rounded,
                            title: '代理订阅链接 (PROXY_URL)',
                            subtitle: _proxyUrlLoading
                                ? '正在读取配置…'
                                : (_proxyUrlController.text.trim().isEmpty
                                    ? '未启用（独立 VPN 自动兼容）'
                                    : '已配置: ${_proxyUrlController.text.trim()}'),
                            onTap: _proxyUrlSaving ? null : _showProxyUrlModal,
                            trailing: _proxyUrlSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                          ),
                          CustomListTile(
                            icon: Icons.cleaning_services_rounded,
                            title: '清理广告与 SDK 缓存',
                            subtitle: _cleaningAdCache
                                ? '正在清理…'
                                : '清理国内外应用开屏与广告 SDK 离线缓存',
                            onTap: _cleaningAdCache ? null : _handleCleanAdCaches,
                            trailing: _cleaningAdCache
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                          ),
                          CustomListTile(
                            icon: Icons.restore_rounded,
                            title: '恢复默认规则',
                            subtitle: _restoringRules
                                ? '正在恢复…'
                                : '补全或重置模块预置规则',
                            onTap: _restoringRules
                                ? null
                                : _handleRestoreFactoryRules,
                            trailing: _restoringRules
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                          ),
                          CustomListTile(
                            icon: Icons.toggle_on_rounded,
                            title: '通知栏快捷开关',
                            subtitle: '查看快捷磁贴添加方式',
                            onTap: _showTileHelp,
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                          if (serversProvider.selectedServer != null &&
                              statusProvider.serverStatus != null &&
                              serversProvider.apiClient2 != null) ...[
                            SectionLabel(
                                label: AppLocalizations.of(context)!
                                    .serverSettings),
                            _SettingsTile(
                              icon: Icons.list_alt_rounded,
                              title: AppLocalizations.of(context)!.logsSettings,
                              subtitle: AppLocalizations.of(context)!
                                  .logsSettingsDescription,
                              thisItem: 0,
                              screenToNavigate: const LogsSettings(),
                              twoColumns: widget.twoColumns,
                            ),
                            _SettingsTile(
                              icon: Icons.analytics_rounded,
                              title: AppLocalizations.of(context)!
                                  .statisticsSettings,
                              subtitle: AppLocalizations.of(context)!
                                  .statisticsSettingsDescription,
                              thisItem: 1,
                              screenToNavigate: const StatisticsSettings(),
                              twoColumns: widget.twoColumns,
                            ),
                            _SettingsTile(
                              icon: Icons.dns_rounded,
                              title: AppLocalizations.of(context)!.dnsSettings,
                              subtitle: AppLocalizations.of(context)!
                                  .dnsSettingsDescription,
                              thisItem: 2,
                              screenToNavigate: DnsSettings(
                                splitView: widget.twoColumns,
                              ),
                              twoColumns: widget.twoColumns,
                            ),
                            _SettingsTile(
                              icon: Icons.route_rounded,
                              title: AppLocalizations.of(context)!.dnsRewrites,
                              subtitle: AppLocalizations.of(context)!
                                  .dnsRewritesDescription,
                              thisItem: 3,
                              screenToNavigate: const DnsRewritesScreen(),
                              twoColumns: widget.twoColumns,
                            ),
                          ],
                          SectionLabel(
                              label: AppLocalizations.of(context)!.appSettings),
                          _SettingsTile(
                            icon: Icons.palette_rounded,
                            title: AppLocalizations.of(context)!.customization,
                            subtitle: AppLocalizations.of(context)!
                                .customizationDescription,
                            thisItem: 4,
                            screenToNavigate: const Customization(),
                            twoColumns: widget.twoColumns,
                          ),
                          _SettingsTile(
                            icon: Icons.translate_rounded,
                            title: AppLocalizations.of(context)!.language,
                            subtitle: AppLocalizations.of(context)!
                                .languageDescription,
                            thisItem: 5,
                            screenToNavigate: const LanguageSettings(),
                            twoColumns: widget.twoColumns,
                          ),
                          SectionLabel(
                              label: AppLocalizations.of(context)!.aboutApp),
                          CustomListTile(
                            title: AppLocalizations.of(context)!.appVersion,
                            subtitle: appConfigProvider.getAppInfo!.version,
                          ),
                          const SizedBox(height: 16)
                        ],
                      )
                    ],
                  )),
        ),
      )),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screenToNavigate;
  final int thisItem;
  final bool twoColumns;

  const _SettingsTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.screenToNavigate,
      required this.thisItem,
      required this.twoColumns});

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    if (twoColumns) {
      return CustomSettingsTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        thisItem: thisItem,
        selectedItem: appConfigProvider.selectedSettingsScreen,
        onTap: () {
          appConfigProvider.setSelectedSettingsScreen(
              screen: thisItem, notify: true);
          Navigator.of(settingsNavigatorKey.currentContext!).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) =>
                  screenToNavigate,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
      );
    } else {
      return CustomListTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => screenToNavigate));
        },
      );
    }
  }
}
