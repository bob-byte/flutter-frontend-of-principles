import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/ui_theme_switcher.dart';
import 'startup_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.embedded = false});

  static const routeName = '/settings';

  final bool embedded;

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
    const body = _SettingsBody();

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(
              title: Text(l10n.settingsTitle),
              actions: const [AppThemeSwitcher()],
            ),
            const Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.settingsTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: const [AppThemeSwitcher()],
      ),
      body: body,
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      type: MaterialType.transparency,
      child: Consumer<SettingsViewModel>(
        builder: (context, vm, child) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.themeLabel),
                  subtitle: Text(l10n.themeSubtitle),
                  trailing: const AppThemeSwitcher(compact: true),
                ),
                GlassListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.languageLabel),
                  subtitle: Text(l10n.languageSubtitle),
                  trailing: DropdownButton<Locale?>(
                    value: vm.localeOverride,
                    underline: const SizedBox.shrink(),
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
            const SizedBox(height: 16),
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutProgram),
                  trailing: GlassListTile.chevron,
                  onTap: () => vm.showAppBenefits(context),
                ),
                GlassListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.logoutLabel),
                  onTap: () async {
                    await context.read<AuthService>().logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      StartupView.routeName,
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
