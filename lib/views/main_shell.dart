import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/launch_data_loader.dart';
import '../core/road_guide/main_shell_controller.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_overlay.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/theme/theme_controller.dart';
import '../widgets/app_liquid_background.dart';
import 'edit_habit_view.dart';
import 'goals_view.dart';
import 'habit_detail_view.dart';
import 'helper_view.dart';
import 'habit_progress_view.dart';
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
  OverlayEntry? _guideEntry;
  RoadGuideController? _guide;
  bool _editHabitOpenedByGuide = false;
  bool _habitDetailOpenedByGuide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final guide = context.read<RoadGuideController>();
    if (!identical(_guide, guide)) {
      _guide?.removeListener(_syncGuideOverlay);
      _guide = guide;
      _guide!.addListener(_syncGuideOverlay);
    }
  }

  @override
  void dispose() {
    _guide?.removeListener(_syncGuideOverlay);
    _guideEntry?.remove();
    _guideEntry = null;
    super.dispose();
  }

  void _syncGuideOverlay() {
    if (!mounted) return;
    final guide = _guide;
    if (guide == null) return;

    if (guide.isActive) {
      if (_guideEntry == null) {
        _guideEntry = OverlayEntry(
          builder: (overlayContext) =>
              const Positioned.fill(child: RoadGuideOverlay()),
        );
        Overlay.of(context).insert(_guideEntry!);
      } else {
        _guideEntry!.markNeedsBuild();
      }
    } else if (_guideEntry != null) {
      _guideEntry!.remove();
      _guideEntry = null;
    }
    _syncPushedGuideRoute();
  }

  void _raiseGuideOverlay() {
    final entry = _guideEntry;
    if (entry == null || !mounted) return;
    entry.remove();
    Overlay.of(context).insert(entry);
  }

  void _syncPushedGuideRoute() {
    final guide = _guide;
    if (guide == null || !mounted) return;
    final step = guide.currentStep;
    final wantEdit = guide.isActive && step?.openEditHabitOnShow == true;
    final wantDetail = guide.isActive && step?.openHabitDetailOnShow == true;

    if (wantEdit && !_editHabitOpenedByGuide) {
      _editHabitOpenedByGuide = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final opened = EditHabitView.show(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _raiseGuideOverlay();
          _guideEntry?.markNeedsBuild();
        });
        await opened;
        _editHabitOpenedByGuide = false;
      });
      return;
    }

    if (wantDetail && !_habitDetailOpenedByGuide) {
      _habitDetailOpenedByGuide = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final opened = Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: HabitDetailView.routeName,
              arguments: RoadGuideDemoIds.habitId,
            ),
            builder: (_) => const HabitDetailView(),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _raiseGuideOverlay();
          _guideEntry?.markNeedsBuild();
        });
        await opened;
        _habitDetailOpenedByGuide = false;
      });
      return;
    }

    if (!wantEdit && _editHabitOpenedByGuide) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
    if (!wantDetail && _habitDetailOpenedByGuide) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Future<void> _bootstrap() async {
    try {
      await context.read<LaunchDataLoader>().ensureLoaded();
    } catch (_) {}
    if (!mounted) return;
    final guide = context.read<RoadGuideController>();
    await guide.loadDeviceFlag();
    if (!mounted) return;
    await guide.maybeAutoStart();
    _syncGuideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.watch<ThemeController>().palette;
    final shell = context.watch<MainShellController>();
    final guide = context.watch<RoadGuideController>();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final index = shell.index;

    final tabBar = GlassTabBar.bottom(
      selectedIndex: index,
      onTabSelected: (i) {
        if (guide.isActive) return;
        shell.setIndex(i);
      },
      adaptiveBrightness: true,
      iconSize: 24,
      barHeight: 58,
      horizontalPadding: 16,
      spacing: 6,
      glowOpacity: 0.55,
      unselectedIconColor: palette.tabBarUnselectedIconColor,
      tabs: [
        GlassTab(
          icon: const Icon(Icons.auto_awesome),
          semanticLabel: l10n.tabChat,
          glowColor: scheme.primary,
        ),
        GlassTab(
          icon: const Icon(Icons.flag_outlined),
          activeIcon: const Icon(Icons.flag),
          semanticLabel: l10n.tabGoals,
          glowColor: scheme.primary,
        ),
        GlassTab(
          icon: const Icon(Icons.checklist_outlined),
          activeIcon: const Icon(Icons.checklist),
          semanticLabel: l10n.tabTasks,
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
    );

    return GlassScaffold(
      extendBody: true,
      contentAwareBrightness: true,
      statusBarStyle: GlassStatusBarStyle.auto,
      resizeToAvoidBottomInset: true,
      background: const AppLiquidBackground(),
      bottomBar: _KeyboardAwareTabBar(hidden: keyboardOpen, child: tabBar),
      body: Material(
        type: MaterialType.transparency,
        child: IndexedStack(
          index: index,
          children: [
            HelperView(
              embedded: true,
              bottomBarClearance: keyboardOpen ? 0 : 80,
            ),
            const GoalsView(embedded: true),
            const TasksView(embedded: true),
            HabitProgressView(
              embedded: true,
              isActive: index == MainShellTab.habits,
            ),
            const SettingsView(embedded: true),
          ],
        ),
      ),
    );
  }
}

/// Hides the tab bar without removing [GlassScaffold.bottomBar].
///
/// Setting [GlassScaffold.bottomBar] to null unwraps the body from
/// [GlassScrollEdgeEffect], remounting the chat field and dismissing the
/// keyboard.
class _KeyboardAwareTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _KeyboardAwareTabBar({required this.hidden, required this.child});

  final bool hidden;
  final PreferredSizeWidget child;

  @override
  Size get preferredSize => hidden ? Size.zero : child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox.shrink();
    return child;
  }
}
