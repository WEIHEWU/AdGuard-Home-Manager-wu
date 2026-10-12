import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/languages.dart';
import 'package:adguard_home_manager/widgets/custom_radio_list_tile.dart';

class LanguageSettings extends StatelessWidget {
  const LanguageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final selected = appConfigProvider.selectedLanguage ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.language),
        centerTitle: false,
        surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            CustomRadioListTile(
              groupValue: selected,
              value: '',
              radioBackgroundColor: Theme.of(context).colorScheme.surface,
              title: AppLocalizations.of(context)!.systemDefined,
              onChanged: (_) => appConfigProvider.setSelectedLanguage(null),
            ),
            const Divider(),
            ...sortedAppLanguages.map((language) => CustomRadioListTile(
              groupValue: selected,
              value: language.tag,
              radioBackgroundColor: Theme.of(context).colorScheme.surface,
              title: language.name,
              onChanged: (value) => appConfigProvider.setSelectedLanguage(value),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
