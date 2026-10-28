// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/home/top_items/row_item.dart';
import 'package:adguard_home_manager/screens/home/top_items/top_items_screen.dart';
import 'package:adguard_home_manager/widgets/custom_pie_chart.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class TopItemsSection extends StatelessWidget {
  final HomeTopItems type;
  final String label;
  final List<Map<String, dynamic>> data;
  final bool withChart;
  final bool withProgressBar;
  final String Function(dynamic) buildValue;
  final List<MenuOption> Function(dynamic) menuOptions;
  final void Function(dynamic)? onTapEntry;

  const TopItemsSection({
    super.key,
    required this.type,
    required this.label,
    required this.data,
    required this.withChart,
    required this.withProgressBar,
    required this.buildValue,
    required this.menuOptions,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.teal,
      Colors.grey
    ];

    final width = MediaQuery.of(context).size.width;

    final withChart = type != HomeTopItems.avgUpstreamResponseTime;

    Map<String, double> ringData() {
      Map<String, double> values = {};
      data.sublist(0, data.length > 5 ? 5 : data.length).forEach((element) {
        values = {
          ...values,
          element.keys.first: element.values.first.toDouble()
        };
      });
      if (data.length > 5) {
        final int rest = List<int>.from(
                data.sublist(5, data.length).map((e) => e.values.first.toInt()))
            .reduce((a, b) => a + b);
        values = {
          ...values,
          AppLocalizations.of(context)!.others: rest.toDouble()
        };
      }
      return values;
    }

    List<Map<String, dynamic>> lineData() {
      List<Map<String, dynamic>> values = [];
      data.sublist(0, data.length > 5 ? 5 : data.length).forEach((element) {
        values.add({
          "label": element.keys.first,
          "value": element.values.first.toDouble()
        });
      });
      return values;
    }

    final List<Map<String, dynamic>> lineChartData = lineData();
    final mapData = lineChartData.map((e) => e["value"]);
    final double total =
        mapData.isNotEmpty ? mapData.reduce((a, b) => a + b) : 0;

    void openMoreScreen() {
      if (width > 700) {
        showDialog(
          context: context,
          builder: (context) => TopItemsScreen(
            type: type,
            title: label,
            data: data,
            withProgressBar: withProgressBar,
            buildValue: buildValue,
            options: menuOptions,
            onTapEntry: onTapEntry,
            isFullscreen: !(width > 700 || !(Platform.isAndroid | Platform.isIOS)),
          ),
        );
      } else {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopItemsScreen(
                type: type,
                title: label,
                data: data,
                withProgressBar: withProgressBar,
                buildValue: buildValue,
                options: menuOptions,
                onTapEntry: onTapEntry,
                isFullscreen:
                    !(width > 700 || !(Platform.isAndroid | Platform.isIOS)),
              ),
            ));
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (data.length > 5)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: openMoreScreen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.viewMore,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.noDataThisSection,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (data.isNotEmpty && width > 700)
            Padding(
              padding: EdgeInsets.only(bottom: withChart == false ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (withChart == true)
                    Expanded(
                        flex: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: CustomPieChart(
                                  data: ringData(), colors: colors)),
                        )),
                  Expanded(
                    flex: 2,
                    child: _ItemsList(
                      colors: colors,
                      data: data,
                      type: type,
                      showChart: withChart,
                      buildValue: buildValue,
                      menuOptions: menuOptions,
                      onTapEntry: onTapEntry,
                    ),
                  )
                ],
              ),
            ),
          if (data.isNotEmpty && width <= 700) ...[
            if (withChart == true && total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                      height: 8,
                      child: LayoutBuilder(
                          builder: (context, constraints) => Row(
                              children: lineChartData
                                  .asMap()
                                  .entries
                                  .map((e) => Tooltip(
                                        message:
                                            '${e.value["label"]} (${doubleFormat((e.value["value"] / total) * 100, Platform.localeName)}%)',
                                        child: Container(
                                          width: constraints.maxWidth *
                                              (e.value["value"] / total),
                                          decoration: BoxDecoration(
                                              color: colors[e.key]),
                                        ),
                                      ))
                                  .toList()))),
                ),
              ),
            const SizedBox(height: 4),
            _ItemsList(
              colors: colors,
              data: data,
              type: type,
              showChart: withChart,
              buildValue: buildValue,
              menuOptions: menuOptions,
              onTapEntry: onTapEntry,
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final List<Color> colors;
  final List<Map<String, dynamic>> data;
  final HomeTopItems type;
  final bool showChart;
  final String Function(dynamic) buildValue;
  final List<MenuOption> Function(dynamic) menuOptions;
  final void Function(dynamic)? onTapEntry;

  const _ItemsList({
    required this.colors,
    required this.data,
    required this.type,
    required this.showChart,
    required this.buildValue,
    required this.menuOptions,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        children: data
            .sublist(0, data.length > 5 ? 5 : data.length)
            .asMap()
            .entries
            .map((e) => RowItem(
                  domain: e.value.keys.toList()[0],
                  number: buildValue(e.value.values.toList()[0]),
                  type: type,
                  chartColor: colors[e.key],
                  showColor: showChart,
                  options: menuOptions,
                  onTapEntry: onTapEntry,
                ))
            .toList());
  }
}
