// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/logs/live/live_logs_screen.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/widgets/floating_search_bar.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

final GlobalKey _searchButtonKey = GlobalKey();

class LogsListAppBar extends StatelessWidget {
  final bool innerBoxIsScrolled;
  final bool showDivider;

  const LogsListAppBar({
    super.key,
    required this.innerBoxIsScrolled,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);

    final width = MediaQuery.of(context).size.width;

    void openFilersModal() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
            context: context,
            builder: (context) => const LogsFiltersModal(
                  dialog: true,
                ),
            barrierDismissible: false);
      } else {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            builder: (context) => const LogsFiltersModal(
                  dialog: false,
                ),
            backgroundColor: Colors.transparent,
            isScrollControlled: true);
      }
    }

    void showSearchDialog() {
      showDialog(
        context: context,
        builder: (context) => FloatingSearchBar(
          existingSearchValue: logsProvider.appliedFilters.searchText ?? "",
          searchButtonRenderBox:
              _searchButtonKey.currentContext?.findRenderObject() as RenderBox?,
          onSearchCompleted: (v) {
            logsProvider.setAppliedFilters(AppliedFiters(
                selectedResultStatus:
                    logsProvider.appliedFilters.selectedResultStatus,
                searchText: v != "" ? v : null,
                clients: logsProvider.appliedFilters.clients));
            logsProvider.filterLogs();
          },
          onSearchFieldUpdated: (v) {
            if (v == "") {
              logsProvider.setSearchText(null);
              return;
            }
            logsProvider.setSearchText(v);
          },
          onSearchFieldCleared: () {
            logsProvider.setSearchText(null);
          },
        ),
      );
    }

    void openLiveLogsScreen() {
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MultiProvider(providers: [
                ChangeNotifierProxyProvider<ServersProvider, LiveLogsProvider>(
                  create: (context) => LiveLogsProvider(),
                  update: (context, servers, logs) => logs!..update(servers),
                ),
              ], child: const LiveLogsScreen())));
    }

    final Map<String, String> translatedString = {
      "all": AppLocalizations.of(context)!.all,
      "filtered": AppLocalizations.of(context)!.filtered,
      "processed": AppLocalizations.of(context)!.processedRow,
      "whitelisted": AppLocalizations.of(context)!.processedWhitelistRow,
      "blocked": AppLocalizations.of(context)!.blocked,
    };

    return SliverAppBar.large(
      pinned: true,
      floating: true,
      centerTitle: false,
      forceElevated: innerBoxIsScrolled,
      surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
      title: Text(AppLocalizations.of(context)!.logs),
      actions: [
        if (!(Platform.isAndroid || Platform.isIOS))
          IconButton(
            onPressed: () => logsProvider.fetchLogs(inOffset: 0),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        if (logsProvider.loadStatus == LoadStatus.loaded)
          IconButton(
            key: _searchButtonKey,
            onPressed: showSearchDialog,
            icon: const Icon(Icons.search_rounded),
            tooltip: AppLocalizations.of(context)!.search,
          ),
        if (logsProvider.loadStatus == LoadStatus.loaded)
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                  onTap: openFilersModal,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded),
                      const SizedBox(width: 10),
                      Text(AppLocalizations.of(context)!.filters)
                    ],
                  )),
              PopupMenuItem(
                  onTap: openLiveLogsScreen,
                  child: Row(
                    children: [
                      const Icon(Icons.stream_rounded),
                      const SizedBox(width: 10),
                      Text(AppLocalizations.of(context)!.liveLogs)
                    ],
                  )),
            ],
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size(double.maxFinite, 52),
        child: Container(
          height: 48,
          width: double.maxFinite,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: showDivider == true
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
                    : Colors.transparent,
              ),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final entry in const [
                MapEntry('all', '全部'),
                MapEntry('blocked', '已拦截'),
                MapEntry('processed', '已放行'),
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    selected: logsProvider.appliedFilters.selectedResultStatus ==
                        entry.key,
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (!selected &&
                          logsProvider.appliedFilters.selectedResultStatus ==
                              entry.key) {
                        return;
                      }
                      logsProvider.setSelectedResultStatus(
                        value: entry.key,
                        refetch: true,
                      );
                    },
                  ),
                ),
              ],
              if (logsProvider.appliedFilters.selectedResultStatus != 'all' &&
                  logsProvider.appliedFilters.selectedResultStatus !=
                      'blocked' &&
                  logsProvider.appliedFilters.selectedResultStatus !=
                      'processed') ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.shield_rounded, size: 16),
                    label: Text(
                      translatedString[
                              logsProvider.appliedFilters.selectedResultStatus] ??
                          logsProvider.appliedFilters.selectedResultStatus,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    deleteIcon: const Icon(Icons.clear, size: 16),
                    onDeleted: () {
                      logsProvider.setSelectedResultStatus(
                        value: 'all',
                        refetch: true,
                      );
                    },
                  ),
                ),
              ],
              if (logsProvider.appliedFilters.searchText != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                      logsProvider.appliedFilters.searchText!,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    deleteIcon: const Icon(Icons.clear, size: 16),
                    onDeleted: () {
                      logsProvider.setAppliedFilters(AppliedFiters(
                          selectedResultStatus:
                              logsProvider.appliedFilters.selectedResultStatus,
                          searchText: null,
                          clients: logsProvider.appliedFilters.clients));
                      logsProvider.setSearchText(null);
                      logsProvider.fetchLogs(inOffset: 0, searchText: '');
                    },
                  ),
                ),
              ],
              if (logsProvider.appliedFilters.clients.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.smartphone_rounded, size: 16),
                    label: Text(
                      logsProvider.appliedFilters.clients.length == 1
                          ? logsProvider.appliedFilters.clients[0]
                          : "${logsProvider.appliedFilters.clients.length} ${AppLocalizations.of(context)!.clients}",
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    deleteIcon: const Icon(Icons.clear, size: 16),
                    onDeleted: () {
                      logsProvider.setAppliedFilters(AppliedFiters(
                          selectedResultStatus:
                              logsProvider.appliedFilters.selectedResultStatus,
                          searchText: logsProvider.appliedFilters.searchText,
                          clients: []));
                      logsProvider.setSelectedClients(null);
                      logsProvider.fetchLogs(
                          inOffset: 0,
                          responseStatus:
                              logsProvider.appliedFilters.selectedResultStatus);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
