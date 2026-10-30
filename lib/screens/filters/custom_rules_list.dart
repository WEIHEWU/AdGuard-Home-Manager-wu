// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/sort_rules.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';

class CustomRulesList extends StatefulWidget {
  final LoadStatus loadStatus;
  final ScrollController scrollController;
  final List<String> data;
  final void Function(String) onRemoveCustomRule;

  const CustomRulesList({
    super.key,
    required this.loadStatus,
    required this.scrollController,
    required this.data,
    required this.onRemoveCustomRule
  });

  @override
  State<CustomRulesList> createState() => _CustomRulesListState();
}

class _CustomRulesListState extends State<CustomRulesList> {
  late bool isVisible;

  CustomRulesSorting _sortingMethod = CustomRulesSorting.topBottom;
  String _ruleFilter = 'active'; // 'active' | 'allow' | 'block' | 'all'

  List<String>? _cachedSourceData;
  CustomRulesSorting? _cachedSortingMethod;
  String? _cachedRuleFilter;
  List<String> _renderData = const [];
  int _activeCount = 0;
  int _allowCount = 0;
  int _blockCount = 0;
  int _totalCount = 0;

  static bool _checkIfComment(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ||
        trimmed.startsWith('!') ||
        trimmed.startsWith('#');
  }

  static bool _checkIfAllow(String value) {
    return value.trim().startsWith('@@');
  }

  void _ensureFilteredRulesComputed() {
    if (identical(_cachedSourceData, widget.data) &&
        _cachedSortingMethod == _sortingMethod &&
        _cachedRuleFilter == _ruleFilter) {
      return;
    }

    final sortedData = _sortingMethod == CustomRulesSorting.bottomTop
        ? widget.data.reversed.toList(growable: false)
        : widget.data;

    final rendered = <String>[];
    var active = 0;
    var allow = 0;
    var block = 0;

    for (final rule in sortedData) {
      final isComment = _checkIfComment(rule);
      final isAllow = !isComment && _checkIfAllow(rule);
      if (!isComment) {
        active++;
        if (isAllow) {
          allow++;
        } else {
          block++;
        }
      }

      switch (_ruleFilter) {
        case 'active':
          if (!isComment) rendered.add(rule);
          break;
        case 'allow':
          if (isAllow) rendered.add(rule);
          break;
        case 'block':
          if (!isComment && !isAllow) rendered.add(rule);
          break;
        case 'all':
        default:
          rendered.add(rule);
          break;
      }
    }

    _cachedSourceData = widget.data;
    _cachedSortingMethod = _sortingMethod;
    _cachedRuleFilter = _ruleFilter;
    _renderData = rendered;
    _activeCount = active;
    _allowCount = allow;
    _blockCount = block;
    _totalCount = sortedData.length;
  }

  @override
  initState(){
    super.initState();
    
    isVisible = true;
    widget.scrollController.addListener(() {
      if (widget.scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (mounted && isVisible == true) {
          setState(() => isVisible = false);
        }
      } 
      else {
        if (widget.scrollController.position.userScrollDirection == ScrollDirection.forward) {
          if (mounted && isVisible == false) {
            setState(() => isVisible = true);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    _ensureFilteredRulesComputed();
    final renderData = _renderData;
    final activeCount = _activeCount;
    final allowCount = _allowCount;
    final blockCount = _blockCount;

    Widget? generateSubtitle(String rule) {
      final trimmed = rule.trim();
      if (_checkIfAllow(trimmed)) {
        return Text(
          AppLocalizations.of(context)!.allowed,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );
      }
      else if (_checkIfComment(trimmed)) {
        return Text(
          AppLocalizations.of(context)!.comment,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        );
      }
      else {
        return Text(
          AppLocalizations.of(context)!.blocked,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );
      }
    }

    void showSortingMethodModal() {
      showDialog(
        context: context, 
        builder: (ctx) => SortCustomRulesModal(
          sortingMethod: _sortingMethod, 
          onSelect: (value) => setState(() => _sortingMethod = value),
        ),
      );
    }

    Widget buildFilterBar() {
      final chips = [
        (key: 'active', label: '全部生效 ($activeCount)'),
        (key: 'allow', label: '仅看放行 ($allowCount)'),
        (key: 'block', label: '仅看拦截 ($blockCount)'),
        (key: 'all', label: '显示注释 ($_totalCount)'),
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: chips.map((c) {
            final selected = _ruleFilter == c.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                selected: selected,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _ruleFilter = c.key),
              ),
            );
          }).toList(),
        ),
      );
    }

    final totalListCount = widget.data.isEmpty
      ? 0
      : (renderData.isEmpty ? 2 : renderData.length + 1);

    return CustomTabContentList(
      loadingGenerator: () => SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height-171,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 30),
            Text(
              AppLocalizations.of(context)!.loadingFilters,
              style: TextStyle(
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          ],
        ),
      ), 
      itemsCount: totalListCount, 
      contentWidget: (index) {
        if (index == 0) {
          return buildFilterBar();
        }
        if (renderData.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Center(
              child: Text(
                '当前筛选下暂无规则',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final rule = renderData[index - 1];
        final isComment = _checkIfComment(rule);
        return ListTile(
          dense: true,
          title: Text(
            rule,
            style: TextStyle(
              color: isComment
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)
                : Theme.of(context).colorScheme.onSurface,
              fontWeight: isComment ? FontWeight.normal : FontWeight.w500,
              fontFamily: 'monospace',
              fontSize: 13.5,
            ),
          ),
          subtitle: generateSubtitle(rule),
          trailing: IconButton(
            onPressed: () => widget.onRemoveCustomRule(rule),
            icon: const Icon(Icons.delete_outline_rounded, size: 20)
          ),
        );
      }, 
      noData: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                AppLocalizations.of(context)!.noCustomFilters,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 30),
            TextButton.icon(
              onPressed: () async {
                final result = await filteringProvider.fetchFilters();
                if (result == false && context.mounted) {
                  showSnackbar(
                    appConfigProvider: appConfigProvider,
                    label: AppLocalizations.of(context)!.errorLoadFilters, 
                    color: Colors.red
                  );
                }
              }, 
              icon: const Icon(Icons.refresh_rounded), 
              label: Text(AppLocalizations.of(context)!.refresh),
            )
          ],
        ),
      ), 
      errorGenerator: () => SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height-171,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 30),
            Text(
              AppLocalizations.of(context)!.filtersNotLoaded,
              style: TextStyle(
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          ],
        ),
      ), 
      loadStatus: widget.loadStatus, 
      onRefresh: () async {
        final result = await filteringProvider.fetchFilters();
        if (result == false && context.mounted) {
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.errorLoadFilters, 
            color: Colors.red
          );
        }
      }, 
      fab: Column(
        children: [
          FloatingActionButton.small(
            onPressed: showSortingMethodModal,
            child: Icon(Icons.sort_rounded),
          ),
          const SizedBox(height: 16),
          AddFiltersButton(
            type: 'edit_custom_rule', 
            widget: (fn) => FloatingActionButton.small(
              onPressed: fn,
              child: const Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 16),
          AddFiltersButton(
            type: 'add_custom_rule',
            widget: (fn) => FloatingActionButton(
              onPressed: fn,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      heightFabHidden: -180,
      fabVisible: isVisible,
    );
  }
}