import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/home/top_items/top_items_section.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class TopItemsLists extends StatelessWidget {
  final List<HomeTopItems> order;

  const TopItemsLists({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    void filterDomainLogs({required String value}) {
      logsProvider.setSearchText(value);
      logsProvider.setSelectedClients(null);
      logsProvider.setSelectedResultStatus(value: 'all', refetch: true);
      appConfigProvider.setSelectedScreen(1);
    }

    void blockUnblock(
        {required String domain, required String newStatus}) async {
      final ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.savingUserFilters);

      final rules = await statusProvider.blockUnblockDomain(
          domain: domain, newStatus: newStatus);

      processModal.close();

      if (!context.mounted) return;
      if (rules == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.userFilteringRulesUpdated,
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.userFilteringRulesNotUpdated,
            color: Colors.red);
      }
    }

    void copyValueClipboard(dynamic value) {
      copyToClipboard(
          value: value,
          successMessage: AppLocalizations.of(context)!.copiedClipboard);
    }

    final visibleOrder = order
        .where((item) =>
            item == HomeTopItems.queriedDomains ||
            item == HomeTopItems.blockedDomains)
        .toList();

    return Column(
      children: visibleOrder.map((item) {
        switch (item) {
          case HomeTopItems.queriedDomains:
            return TopItemsSection(
              label: AppLocalizations.of(context)!.topQueriedDomains,
              type: HomeTopItems.queriedDomains,
              data: statusProvider.serverStatus?.stats.topQueriedDomains ?? [],
              withChart: true,
              withProgressBar: true,
              buildValue: (v) => v.toString(),
              menuOptions: (v) => [
                MenuOption(
                    title: AppLocalizations.of(context)!.blockDomain,
                    icon: Icons.block_rounded,
                    action: () =>
                        blockUnblock(domain: v.toString(), newStatus: 'block')),
                MenuOption(
                    title: AppLocalizations.of(context)!.copyClipboard,
                    icon: Icons.copy_rounded,
                    action: () => copyValueClipboard(v)),
              ],
              onTapEntry: (v) => filterDomainLogs(value: v.toString()),
            );

          case HomeTopItems.blockedDomains:
            return TopItemsSection(
              label: AppLocalizations.of(context)!.topBlockedDomains,
              type: HomeTopItems.blockedDomains,
              data: statusProvider.serverStatus?.stats.topBlockedDomains ?? [],
              withChart: true,
              withProgressBar: true,
              buildValue: (v) => v.toString(),
              menuOptions: (v) => [
                MenuOption(
                    title: AppLocalizations.of(context)!.unblockDomain,
                    icon: Icons.check_rounded,
                    action: () =>
                        blockUnblock(domain: v, newStatus: 'unblock')),
                MenuOption(
                    title: AppLocalizations.of(context)!.copyClipboard,
                    icon: Icons.copy_rounded,
                    action: () => copyValueClipboard(v))
              ],
              onTapEntry: (v) => filterDomainLogs(value: v),
            );

          case HomeTopItems.topUpstreams:
          case HomeTopItems.avgUpstreamResponseTime:
            return const SizedBox.shrink();
        }
      }).toList(),
    );
  }
}
