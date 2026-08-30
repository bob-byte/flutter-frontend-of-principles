import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../widgets/app_liquid_background.dart';
import 'goals_view.dart';
import 'habit_detail_view.dart';
import 'helper_view.dart';
import 'progress_view.dart';
import 'settings_view.dart';
import 'tasks_view.dart';

/// Post-login shell with a Liquid Glass bottom tab bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const routeName = HelperView.routeName;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      extendBody: true,
      contentAwareBrightness: true,
      statusBarStyle: GlassStatusBarStyle.auto,
      resizeToAvoidBottomInset: true,
      background: const AppLiquidBackground(),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _index,
        onTabSelected: (index) => setState(() => _index = index),
        adaptiveBrightness: true,
        iconSize: 24,
        barHeight: 58,
        horizontalPadding: 16,
        spacing: 6,
        glowOpacity: 0.55,
        tabs: [
          GlassTab(
            icon: const Icon(Icons.auto_awesome),
            semanticLabel: l10n.tabChat,
            glowColor: scheme.primary,
          ),
          GlassTab(
            icon: const Icon(Icons.checklist_outlined),
            activeIcon: const Icon(Icons.checklist),
            semanticLabel: l10n.tabTasks,
            glowColor: scheme.primary,
          ),
          GlassTab(
            icon: const Icon(Icons.flag_outlined),
            activeIcon: const Icon(Icons.flag),
            semanticLabel: l10n.tabGoals,
            glowColor: scheme.primary,
          ),
          GlassTab(
            icon: const Icon(Icons.show_chart),
            semanticLabel: l10n.tabProgress,
            glowColor: scheme.primary,
          ),
          GlassTab(
            icon: const Icon(Icons.insights_outlined),
            activeIcon: const Icon(Icons.insights),
            semanticLabel: l10n.tabHabits,
            glowColor: scheme.primary,
          ),
          GlassTab(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            semanticLabel: l10n.tabSettings,
            glowColor: scheme.primary,
          ),
        ],
      ),
      body: Material(
        type: MaterialType.transparency,
        child: IndexedStack(
          index: _index,
          children: const [
            HelperView(embedded: true),
            TasksView(embedded: true),
            GoalsView(embedded: true),
            ProgressView(embedded: true),
            HabitDetailView(embedded: true),
            SettingsView(embedded: true),
          ],
        ),
      ),
    );
  }
}
