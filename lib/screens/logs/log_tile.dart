import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/functions/format_time.dart';

class LogTile extends StatelessWidget {
  final Log log;
  final int length;
  final int index;
  final bool? isLogSelected;
  final void Function(Log) onLogTap;
  final bool? useAlwaysNormalTile;
  final bool twoColumns;

  const LogTile({
    super.key,
    required this.log,
    required this.length,
    required this.index,
    this.isLogSelected,
    required this.onLogTap,
    this.useAlwaysNormalTile,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final filteringProvider = Provider.of<FilteringProvider>(context);

    Widget logStatusWidget(
        {required IconData icon, required Color color, required String text}) {
      return SizedBox(
        width: 80,
        child: Column(children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 12),
          )
        ]),
      );
    }

    Widget generateLogStatus() {
      final filter =
          getFilteredStatus(context, appConfigProvider, log.reason, false);
      return logStatusWidget(
        icon: filter['icon'],
        color: filter['color'],
        text: filter['label'],
      );
    }

    String logClient() {
      if (appConfigProvider.showIpLogs == true) {
        return log.client;
      } else if (log.clientInfo != null && log.clientInfo!.name != "") {
        return log.clientInfo!.name;
      } else {
        return log.client;
      }
    }

    void blockUnblock(
        {required String domain, required String newStatus}) async {
      if (!context.mounted) return;

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

    void blockUnblockRuleClient() async {
      if (!context.mounted) return;

      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.addingRule);

      final rule = isDomainBlocked(log.reason) == true
          ? "@@||${log.question.name}^\$client='${log.client}',important"
          : "||${log.question.name}^\$client='${log.client}',important";

      final result = await filteringProvider.addCustomRule(rule);

      processModal.close();

      if (!context.mounted) return;
      if (result == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: isDomainBlocked(log.reason) == true
                ? AppLocalizations.of(context)!
                    .domainUnblockedThisClient(log.question.name!)
                : AppLocalizations.of(context)!
                    .domainBlockedThisClient(log.question.name!),
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.ruleNotAdded,
            color: Colors.red);
      }
    }

    final domainBlocked = isDomainBlocked(log.reason);
    final isSniLog = log.reason == 'FilteredSNI' ||
        log.reason == 'NotFilteredSNI' ||
        log.question.type.toUpperCase() == 'SNI' ||
        (log.clientProto?.toLowerCase().contains('sni') ?? false);

    final clientText = logClient();
    final isLoopbackClient = clientText == '127.0.0.1' ||
        clientText == '::1' ||
        clientText.toLowerCase() == 'localhost';

    Widget buildSubtitleRow(BuildContext context) {
      final subColor = Theme.of(context).colorScheme.onSurfaceVariant;
      final badgeColor = isSniLog ? Colors.purple : Colors.blue;
      final badgeLabel = isSniLog
          ? 'SNI'
          : (log.question.type.isNotEmpty ? log.question.type : 'DNS');
      final ruleHint = log.rules.isNotEmpty ? log.rules.first.text : '';
      String? elapsedText;
      if (log.elapsedMs.isNotEmpty) {
        final parsed = double.tryParse(log.elapsedMs);
        if (parsed != null) {
          elapsedText =
              '${parsed < 10 ? parsed.toStringAsFixed(1) : parsed.toStringAsFixed(0)} ms';
        }
      }

      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              convertTimestampLocalTimezone(log.time, 'HH:mm:ss'),
              style: TextStyle(color: subColor, fontSize: 12.5),
            ),
            if (elapsedText != null) ...[
              const SizedBox(width: 8),
              Text(
                '· $elapsedText',
                style: TextStyle(color: subColor, fontSize: 12.5),
              ),
            ],
            if (!isLoopbackClient) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· $clientText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor, fontSize: 12.5),
                ),
              ),
            ] else if (ruleHint.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '· $ruleHint',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (twoColumns && !(useAlwaysNormalTile == true)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          child: OptionsMenu(
            onTap: (_) => onLogTap(log),
            borderRadius: BorderRadius.circular(28),
            options: (_) => [
              if (log.question.name != null)
                MenuOption(
                    title: domainBlocked == true
                        ? AppLocalizations.of(context)!.unblockDomain
                        : AppLocalizations.of(context)!.blockDomain,
                    icon: domainBlocked == true
                        ? Icons.check_rounded
                        : Icons.block_rounded,
                    action: () => blockUnblock(
                        domain: log.question.name!,
                        newStatus:
                            domainBlocked == true ? 'unblock' : 'block')),
              if (filteringProvider.filtering != null && !isSniLog)
                MenuOption(
                    title: domainBlocked == true
                        ? AppLocalizations.of(context)!.unblockThisClientOnly
                        : AppLocalizations.of(context)!.blockThisClientOnly,
                    icon: domainBlocked == true
                        ? Icons.check_rounded
                        : Icons.block_rounded,
                    action: blockUnblockRuleClient),
              if (log.question.name != null)
                MenuOption(
                    title: AppLocalizations.of(context)!.copyClipboard,
                    icon: Icons.copy_rounded,
                    action: () => copyToClipboard(
                        value: log.question.name!,
                        successMessage:
                            AppLocalizations.of(context)!.copiedClipboard))
            ],
            child: Container(
                width: double.maxFinite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: isLogSelected == true
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.question.name ?? "N/A",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          buildSubtitleRow(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    generateLogStatus()
                  ],
                )),
          ),
        ),
      );
    } else {
      return Material(
        color: Colors.transparent,
        child: OptionsMenu(
          onTap: (_) => onLogTap(log),
          options: (_) => [
            if (log.question.name != null)
              MenuOption(
                  title: domainBlocked == true
                      ? AppLocalizations.of(context)!.unblockDomain
                      : AppLocalizations.of(context)!.blockDomain,
                  icon: domainBlocked == true
                      ? Icons.check_rounded
                      : Icons.block_rounded,
                  action: () => blockUnblock(
                      domain: log.question.name!,
                      newStatus: domainBlocked == true ? 'unblock' : 'block')),
            if (filteringProvider.filtering != null && !isSniLog)
              MenuOption(
                  title: domainBlocked == true
                      ? AppLocalizations.of(context)!.unblockThisClientOnly
                      : AppLocalizations.of(context)!.blockThisClientOnly,
                  icon: domainBlocked == true
                      ? Icons.check_rounded
                      : Icons.block_rounded,
                  action: blockUnblockRuleClient),
            if (log.question.name != null)
              MenuOption(
                  title: AppLocalizations.of(context)!.copyClipboard,
                  icon: Icons.copy_rounded,
                  action: () => copyToClipboard(
                      value: log.question.name!,
                      successMessage:
                          AppLocalizations.of(context)?.copiedClipboard ??
                              "Success"))
          ],
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.question.name ?? "N/A",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      buildSubtitleRow(context),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                generateLogStatus()
              ],
            ),
          ),
        ),
      );
    }
  }
}
