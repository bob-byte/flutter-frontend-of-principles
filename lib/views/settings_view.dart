import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/settings_viewmodel.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SettingsViewModel>();
      vm.loadTheme();
      vm.loadLocale();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, child) => ListView(
          children: [
            ListTile(
              title: Text(l10n.themeLabel),
              subtitle: Text(l10n.themeSubtitle),
              trailing: DropdownButton<ThemeMode>(
                value: vm.themeMode,
                items: [
                  DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
                  DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    vm.setTheme(value);
                  }
                },
              ),
            ),
            ListTile(
              title: Text(l10n.languageLabel),
              subtitle: Text(l10n.languageSubtitle),
              trailing: DropdownButton<Locale?>(
                value: vm.localeOverride,
                items: [
                  DropdownMenuItem<Locale?>(
                    value: null,
                    child: Text(l10n.languageSystem),
                  ),
                  DropdownMenuItem<Locale?>(
                    value: const Locale('en'),
                    child: Text(l10n.languageEnglish),
                  ),
                  DropdownMenuItem<Locale?>(
                    value: const Locale('uk'),
                    child: Text(l10n.languageUkrainian),
                  ),
                ],
                onChanged: (value) => vm.setLocaleOverride(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
