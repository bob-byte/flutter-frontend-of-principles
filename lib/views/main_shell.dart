import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/task_navigation.dart';
import '../core/deep_link/deep_link_action.dart';
import '../core/deep_link/deep_link_controller.dart';
import '../core/launch_data_loader.dart';
import '../core/road_guide/main_shell_controller.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_overlay.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/sync/session_sync_binder.dart';
import '../core/sync/sync_gate_policy.dart';
import '../core/theme/theme_controller.dart';
import '../services/habit_service.dart';
import '../services/reminder_service.dart';
import '../services/settings_service.dart';
import '../services/task_service.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import 'edit_habit_view.dart';
import 'goals_view.dart';
import 'habit_detail_view.dart';
import 'helper_view.dart';
import 'habit_progress_view.dart';
import 'settings_view.dart';
import 'sync_gate_view.dart';
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
  DeepLinkController? _deepLink;
  bool _editHabitOpenedByGuide = false;
  bool _habitDetailOpenedByGuide = false;
  bool _bootstrapped = false;

  /// False until post-auth hydrate (and reminder restore) finishes.
  bool _sessionReady = false;

  /// SyncGate shows MAUI restore copy + OK instead of a ticker-stopping dialog.
  bool _askingRestore = false;
  Completer<void>? _restoreAck;

  /// Null until prefs say whether SyncGate should cover this cold start.
  bool? _showSyncGate;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      // Skip SyncGate only when first sync + reminder restore already finished.
      final loader = context.read<LaunchDataLoader>();
      _sessionReady = loader.isSyncGateComplete;
      if (_sessionReady) {
        _showSyncGate = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
    final guide = context.read<RoadGuideController>();
    if (!identical(_guide, guide)) {
      _guide?.removeListener(_syncGuideOverlay);
      _guide = guide;
      _guide!.addListener(_syncGuideOverlay);
    }
    final deepLink = context.read<DeepLinkController>();
    if (!identical(_deepLink, deepLink)) {
      _deepLink?.removeListener(_consumeDeepLink);
      _deepLink = deepLink;
      _deepLink!.addListener(_consumeDeepLink);
      if (_deepLink!.pending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _consumeDeepLink();
        });
      }
    }
  }

  @override
  void dispose() {
    _guide?.removeListener(_syncGuideOverlay);
    _deepLink?.removeListener(_consumeDeepLink);
    _guideEntry?.remove();
    _guideEntry = null;
    super.dispose();
  }

  void _consumeDeepLink() {
    if (!mounted || !_sessionReady) return;
    // Do not yank navigation out from under the post-sign-in road guide.
    if (_guide?.isActive == true) return;
    final action = _deepLink?.takePending();
    if (action == null) return;
    unawaited(_handleDeepLink(action));
  }

  Future<void> _handleDeepLink(DeepLinkAction action) async {
    if (!mounted) return;
    if (_guide?.isActive == true) return;
    _popTransientRoutes();
    if (!mounted) return;

    switch (action.kind) {
      case DeepLinkKind.homeWidget:
        await _openHomeWidget(action);
      case DeepLinkKind.openTask:
        await _openTask(action.taskId!);
      case DeepLinkKind.openHabitDetail:
        await _openHabitDetail(action.habitId!);
      case DeepLinkKind.openHabitsTab:
        context.read<MainShellController>().setIndex(MainShellTab.habits);
      case DeepLinkKind.openTasksTab:
        final shell = context.read<MainShellController>();
        final tasks = context.read<TasksViewModel>();
        shell.setIndex(MainShellTab.tasks);
        if (action.openToday) {
          tasks.setListModeToday();
        }
    }
  }

  Future<void> _openHomeWidget(DeepLinkAction action) async {
    final shell = context.read<MainShellController>();
    final tasks = context.read<TasksViewModel>();
    shell.setIndex(MainShellTab.tasks);
    if (action.day != null) {
      tasks.setListModeDay(action.day!);
    } else if (action.openToday) {
      tasks.setListModeToday();
    }
    if (!action.openCreate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(TasksNavigation.openCreateTask(context));
    });
  }

  Future<void> _openTask(String taskId) async {
    final task =
        context.read<TasksViewModel>().taskById(taskId) ??
        await context.read<TaskService>().getTask(taskId);
    if (!mounted) return;
    if (task == null) {
      _showMissingTargetSnack();
      return;
    }
    context.read<MainShellController>().setIndex(MainShellTab.tasks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(TasksNavigation.openEditTask(context, taskId: task.id));
    });
  }

  Future<void> _openHabitDetail(int habitId) async {
    final habitService = context.read<HabitService>();
    final habit =
        await habitService.getHabitById(habitId) ??
        await habitService.getHabitByServerId(habitId);
    if (!mounted) return;
    final localId = habit?.id;
    if (localId == null) {
      _showMissingTargetSnack();
      return;
    }
    context.read<MainShellController>().setIndex(MainShellTab.habits);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: HabitDetailView.routeName,
              arguments: localId,
            ),
            builder: (_) => const HabitDetailView(),
          ),
        ),
      );
    });
  }

  void _popTransientRoutes() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) {
      if (route.isFirst) return true;
      final name = route.settings.name;
      if (name == HabitDetailView.routeName ||
          name == EditHabitView.routeName) {
        return false;
      }
      if (route is PopupRoute) return false;
      return true;
    });
  }

  void _showMissingTargetSnack() {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.notificationTargetNotFound),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final loader = context.read<LaunchDataLoader>();
    final settings = context.read<SettingsService>();

    // Full bootstrap (no since) or since ≥ 20 days → cover shell with SyncGate.
    // Recent incremental catch-up paints the shell and syncs underneath.
    final showGate =
        !loader.isSyncGateComplete &&
        requiresSyncGate(await settings.getLastSuccessfulSyncAt());
    if (!mounted) return;
    if (_showSyncGate != showGate) {
      setState(() => _showSyncGate = showGate);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      await loader.ensureLocalSession();
    } catch (_) {}
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // Recent since: reveal shell before merge so SyncGate does not block UX.
    if (!showGate && !_sessionReady) {
      setState(() => _sessionReady = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    // Merge + hydrate (gate covers this when showGate; otherwise background).
    try {
      await loader.ensureLoaded();
    } catch (_) {}
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // Reminder restore: on SyncGate when shown; otherwise dialog explain if needed.
    if (!loader.hasCompletedReminderRestore) {
      final job = showGate
          ? await _prepareRemindersOnGate()
          : await _prepareRemindersWithoutGate();
      if (!mounted) return;
      // Back to "Loading content..." for the schedule pass.
      if (_askingRestore && mounted) {
        setState(() => _askingRestore = false);
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      if (job != null) {
        final reminders = context.read<ReminderService>();
        await reminders.applyReminderRestoreJob(job);
        if (!mounted) return;
      }
      context.read<ReminderService>().clearBootstrapReminders();
      loader.markReminderRestoreDone();
    }

    if (!_sessionReady) {
      setState(() {
        _sessionReady = true;
        _askingRestore = false;
      });
    }

    // Let GlassScaffold / IndexedStack / tab bar finish their first layout
    // before the road-guide overlay and demo tiles compete for the same frame.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    final guide = context.read<RoadGuideController>();
    await guide.loadDeviceFlag();
    if (!mounted) return;
    await guide.maybeAutoStart();
    if (!mounted) return;
    _syncGuideOverlay();

    if (guide.isActive) {
      // Retry/Cancel and deep links wait until the tour finishes so they do
      // not freeze or navigate over the spotlight.
      unawaited(_afterRoadGuide(guide));
    } else {
      _consumeDeepLink();
      unawaited(_finishPostAuthWork());
    }
  }

  /// Same restore job as the gate, but MAUI explain uses the service dialog.
  Future<Map<String, Object?>?> _prepareRemindersWithoutGate() async {
    final reminders = context.read<ReminderService>();
    final tasks = context.read<TasksViewModel>().tasks;
    final habits = context.read<HabitProgressViewModel>().habits;
    try {
      return await reminders.prepareReminderRestore(
        knownTasks: tasks,
        knownHabits: habits,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _afterRoadGuide(RoadGuideController guide) async {
    await _waitUntilGuideInactive(guide);
    if (!mounted) return;
    _consumeDeepLink();
    await _finishPostAuthWork();
  }

  Future<void> _waitUntilGuideInactive(RoadGuideController guide) {
    if (!guide.isActive) return Future<void>.value();
    final done = Completer<void>();
    void listener() {
      if (!guide.isActive && !done.isCompleted) {
        guide.removeListener(listener);
        done.complete();
      }
    }

    guide.addListener(listener);
    if (!guide.isActive && !done.isCompleted) {
      guide.removeListener(listener);
      done.complete();
    }
    return done.future;
  }

  Future<void> _finishPostAuthWork() async {
    if (!mounted) return;
    // After the gate (and road guide) so a 404/503 Retry/Cancel modal does
    // not freeze the tour / loading UI.
    await context.read<LaunchDataLoader>().retryStartupSyncIfServerDown();
  }

  /// MAUI-style explain + permission on SyncGate; returns schedule job (or null).
  Future<Map<String, Object?>?> _prepareRemindersOnGate() async {
    final reminders = context.read<ReminderService>();
    final tasks = context.read<TasksViewModel>().tasks;
    final habits = context.read<HabitProgressViewModel>().habits;
    try {
      return await reminders.prepareReminderRestore(
        knownTasks: tasks,
        knownHabits: habits,
        onExplainRestore: _explainRestoreOnGate,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _explainRestoreOnGate() async {
    final ack = Completer<void>();
    _restoreAck = ack;
    if (!mounted) return;
    setState(() => _askingRestore = true);
    // Paint MAUI RestoreReminders copy before waiting on OK.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      if (!ack.isCompleted) ack.complete();
      return;
    }
    await ack.future;
  }

  void _ackRestore() {
    final ack = _restoreAck;
    if (ack != null && !ack.isCompleted) ack.complete();
    if (mounted) setState(() => _askingRestore = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      // Avoid a one-frame SyncGate flash while reading lastSuccessfulSyncAt.
      if (_showSyncGate != true) {
        final palette = context.watch<ThemeController>().palette;
        return Scaffold(backgroundColor: palette.pageBg);
      }
      return SyncGateView(
        restore: _askingRestore,
        onRestoreAck: _askingRestore ? _ackRestore : null,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.watch<ThemeController>().palette;
    final shell = context.watch<MainShellController>();
    final guide = context.watch<RoadGuideController>();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final sidebarOpen = context.watch<HelperViewModel>().sidebarOpen;
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

    return SessionSyncBinder(
      child: GlassScaffold(
        extendBody: true,
        contentAwareBrightness: true,
        statusBarStyle: GlassStatusBarStyle.auto,
        resizeToAvoidBottomInset: true,
        background: const AppLiquidBackground(),
        bottomBar: _KeyboardAwareTabBar(
          hidden: keyboardOpen || sidebarOpen,
          child: tabBar,
        ),
        body: Material(
          type: MaterialType.transparency,
          child: IndexedStack(
            index: index,
            children: [
              HelperView(
                embedded: true,
                bottomBarClearance: keyboardOpen || sidebarOpen ? 0 : 80,
              ),
              const GoalsView(embedded: true),
              TasksView(embedded: true, isActive: index == MainShellTab.tasks),
              HabitProgressView(
                embedded: true,
                isActive: index == MainShellTab.habits,
              ),
              const SettingsView(embedded: true),
            ],
          ),
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
