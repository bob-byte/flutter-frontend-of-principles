import 'dart:async';

import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/launch_data_loader.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/sync/sync_trigger.dart';
import '../l10n/task_strings.dart';
import '../app/task_navigation.dart';
import '../core/utils/date_helpers.dart';
import '../models/habit_record.dart';
import '../models/task_priority.dart';
import '../services/reminder_service.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/habit_context_menu.dart';
import '../widgets/habit_task_tile.dart';
import '../widgets/task_context_menu.dart';
import '../widgets/task_tile.dart';
import '../widgets/tasks_glass.dart';
import '../widgets/tasks_list_menu_sheet.dart';
import 'widgets/global_reminder_sheet.dart';

const _kSectionAnimDuration = Duration(milliseconds: 280);
const _kSectionAnimCurve = Curves.easeInOutCubic;

class TasksView extends StatefulWidget {
  const TasksView({super.key, this.embedded = false, this.isActive = true});

  static const routeName = '/tasks';

  final bool embedded;

  /// When embedded in [MainShell], true while the Tasks tab is selected.
  final bool isActive;

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  bool _dailyReminderEnabled = false;
  TimeOfDay? _dailyReminderTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldSkipShellTabReload(context)) return;
      context.read<TasksViewModel>().load(silent: widget.embedded);
      context.read<HabitProgressViewModel>().load(
        silent: true,
        syncRemote: false,
      );
      unawaited(_refreshDailyReminderIcon());
    });
  }

  @override
  void didUpdateWidget(TasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _syncOnTabFocus();
      unawaited(_refreshDailyReminderIcon());
    }
  }

  Future<void> _refreshDailyReminderIcon() async {
    try {
      final cached = await context
          .read<ReminderService>()
          .cachedHabitsReportReminder();
      if (!mounted) return;
      setState(() {
        _dailyReminderEnabled = cached?.isEnabled == true;
        _dailyReminderTime = cached?.isEnabled == true ? cached!.time : null;
      });
    } on ProviderNotFoundException {
      // Widget tests may omit ReminderService.
    }
  }

  Future<void> _openDailyReminder() async {
    final guide = context.read<RoadGuideController>();
    if (guide.isActive) return;
    await GlobalReminderBottomSheet.show(context);
    if (!mounted) return;
    await _refreshDailyReminderIcon();
  }

  Future<void> _openListMenu() async {
    final result = await TasksNavigation.openListMenu(context);
    if (!mounted) return;
    if (result == TasksListMenuResult.openDailyReminder) {
      await _openDailyReminder();
      return;
    }
    await _refreshDailyReminderIcon();
  }

  void _syncOnTabFocus() {
    try {
      unawaited(
        context.read<LaunchDataLoader>().syncAndHydrate(
          SyncTrigger.resume,
          skipIfRecent: true,
        ),
      );
    } on ProviderNotFoundException {
      // Widget tests may mount TasksView without LaunchDataLoader.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksViewModel>(
      builder: (context, vm, _) {
        final strings = TaskStrings.of(context);
        final palette = vm.palette;

        return Theme(
          data: vm.themeData,
          child: TasksGlassBackground(
            palette: palette,
            child: Scaffold(
              extendBody: true,
              backgroundColor: Colors.transparent,
              appBar: TasksGlassAppBar(
                palette: palette,
                showLeading: !widget.embedded,
                title: Text(
                  vm.listModeTitle(strings),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: palette.textPrimary,
                  ),
                ),
                actions: [
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      final time = _dailyReminderTime;
                      final tooltip = _dailyReminderEnabled && time != null
                          ? l10n.habitsReportReminderOnTooltip(
                              time.format(context),
                            )
                          : l10n.habitsReportReminderOffTooltip;
                      return IconButton(
                        tooltip: tooltip,
                        icon: Icon(
                          _dailyReminderEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: palette.primary,
                          size: 24,
                        ),
                        onPressed: _openDailyReminder,
                      );
                    },
                  ),
                ],
              ),
              body: vm.isLoading && vm.tasks.isEmpty
                  ? const AppLoadingIndicator()
                  : _TasksBody(
                      strings: strings,
                      palette: palette,
                      embedded: widget.embedded,
                      onOpenDailyReminder: _openDailyReminder,
                    ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.embedded
                        ? _embeddedTasksBarClearance(context)
                        : 0,
                  ),
                  child: TasksGlassBottomBar(
                    palette: palette,
                    child: Row(
                      children: [
                        TasksGlassCircleButton(
                          palette: palette,
                          icon: Icons.menu_rounded,
                          tooltip: strings.taskListMenuTitle,
                          onPressed: _openListMenu,
                        ),
                        const Spacer(),
                        TasksGlassCircleButton(
                          key: context
                              .read<RoadGuideController>()
                              .keys
                              .tasksAdd,
                          palette: palette,
                          icon: Icons.add,
                          tooltip: strings.taskAdd,
                          isPrimary: true,
                          size: 56,
                          onPressed: () async {
                            final guide = context.read<RoadGuideController>();
                            if (guide.isActive) return;
                            final saved = await TasksNavigation.openCreateTask(
                              context,
                            );
                            if (!context.mounted || saved == null) return;
                            await context.read<TasksViewModel>().upsertTask(
                              saved,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TasksBody extends StatelessWidget {
  const _TasksBody({
    required this.strings,
    required this.palette,
    required this.embedded,
    required this.onOpenDailyReminder,
  });

  final TaskStrings strings;
  final TasksUiPalette palette;
  final bool embedded;
  final Future<void> Function() onOpenDailyReminder;

  @override
  Widget build(BuildContext context) {
    return Consumer3<
      TasksViewModel,
      HabitProgressViewModel,
      RoadGuideController
    >(
      builder: (context, vm, habitVm, guide, _) {
        final l10n = AppLocalizations.of(context)!;
        final filtered = [
          if (guide.showDemoData) roadGuideDemoTask(l10n),
          ...vm.filteredTasks,
        ];
        final habitsDay = habitsDayForTasksTab(vm);
        final today = dateOnly(DateTime.now());
        final habits = [
          if (guide.showDemoData) roadGuideDemoHabit(l10n),
          ...habitVm.habits,
        ];
        final visibleHabits = habitsVisibleOnTasksTab(
          listMode: vm.listMode,
          habits: habits,
          statusFilter: vm.statusFilter,
          priorityFilter: vm.selectedPriorityFilter,
          themeFilter: vm.selectedThemeFilter,
          isCompleted: (habit) =>
              habitVm.getStatusForHabitAndDate(habit.id ?? 0, habitsDay) ==
              HabitStatus.completed,
          keepVisibleWhileCompleted: (habit) =>
              habit.id != null && vm.isHeldCompletedHabit(habit.id!),
        );
        final todayHabitsTotal = habits.length;
        final todayHabitsCompleted = habitVm.completedHabitsOn(today);
        final todayTotal = vm.todayTasks.length + todayHabitsTotal;
        final todayCompleted = vm.todayCompletedCount + todayHabitsCompleted;
        final todayProgress = todayTotal == 0
            ? 0.0
            : (todayCompleted / todayTotal) * 100;
        final listBottomPadding = _tasksListBottomPadding(
          context,
          embedded: embedded,
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
          children: [
            TasksGlassPanel(
              palette: palette,
              blur: 0,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: palette.primaryGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.taskProgressToday,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (todayTotal > 0)
                        TweenAnimationBuilder<double>(
                          duration: kTasksProgressAnimDuration,
                          curve: kTasksProgressAnimCurve,
                          tween: Tween<double>(end: todayProgress),
                          builder: (context, animated, _) {
                            return Text(
                              '${animated.round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  tasksGradientProgress(
                    palette: palette,
                    value: todayTotal == 0 ? 0 : todayCompleted / todayTotal,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: kTasksProgressAnimDuration,
                    switchInCurve: kTasksProgressAnimCurve,
                    switchOutCurve: kTasksProgressAnimCurve,
                    child: Text(
                      strings.taskProgressCount(todayCompleted, todayTotal),
                      key: ValueKey('$todayCompleted-$todayTotal'),
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TasksFiltersPanel(strings: strings, palette: palette),
            const SizedBox(height: 16),
            if (vm.loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.of(context)!.genericErrorOccurred,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            _TasksSectionHeader(
              palette: palette,
              icon: Icons.checklist_outlined,
              label: strings.tasksTitle,
              showLabel: strings.taskShow,
              hideLabel: strings.taskHide,
              expanded: guide.isActive || vm.tasksSectionExpanded,
              onTap: vm.toggleTasksSectionExpanded,
            ),
            _CollapsibleSection(
              expanded: guide.isActive || vm.tasksSectionExpanded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final task in filtered)
                    Padding(
                      key: task.id == RoadGuideDemoIds.taskId
                          ? guide.keys.tasksDemo
                          : ValueKey('task-${task.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskTile(
                        key: Key('taskTile-${task.id}'),
                        task: task,
                        palette: palette,
                        themeColor: task.theme != null
                            ? vm.colorForTheme(task.theme!)
                            : palette.textMuted,
                        keepActiveAppearance: vm.isHeldCompletedTask(task.id),
                        onTap: () async {
                          if (guide.isActive ||
                              task.id == RoadGuideDemoIds.taskId) {
                            return;
                          }
                          final saved = await TasksNavigation.openEditTask(
                            context,
                            taskId: task.id,
                          );
                          if (!context.mounted || saved == null) return;
                          await context.read<TasksViewModel>().upsertTask(
                            saved,
                          );
                        },
                        onToggle: () {
                          if (guide.isActive ||
                              task.id == RoadGuideDemoIds.taskId) {
                            return;
                          }
                          vm.toggleTask(task.id);
                        },
                        onMoveToToday: () {
                          if (guide.isActive ||
                              task.id == RoadGuideDemoIds.taskId) {
                            return;
                          }
                          vm.moveTaskToToday(task.id);
                        },
                        onLongPress: (anchor) {
                          if (guide.isActive ||
                              task.id == RoadGuideDemoIds.taskId) {
                            return;
                          }
                          showTaskContextMenu(
                            context: context,
                            task: task,
                            vm: vm,
                            palette: palette,
                            anchor: anchor,
                          );
                        },
                        onToggleSubtask: (subtaskId) {
                          if (guide.isActive ||
                              task.id == RoadGuideDemoIds.taskId) {
                            return;
                          }
                          vm.toggleSubtask(task.id, subtaskId);
                        },
                        strings: strings,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _TasksSectionHeader(
              palette: palette,
              icon: Icons.insights_outlined,
              label: strings.taskHabitsSection,
              showLabel: strings.taskShow,
              hideLabel: strings.taskHide,
              expanded: guide.isActive || vm.habitsSectionExpanded,
              onTap: vm.toggleHabitsSectionExpanded,
            ),
            if (guide.isActive || vm.habitsSectionExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: guide.isActive
                        ? null
                        : () => onOpenDailyReminder(),
                    icon: Icon(
                      Icons.notifications_none,
                      size: 16,
                      color: palette.accentMuted,
                    ),
                    label: Text(
                      l10n.habitsReportReminderMenuHint,
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: palette.textMuted,
                    ),
                  ),
                ),
              ),
            _CollapsibleSection(
              expanded: guide.isActive || vm.habitsSectionExpanded,
              child: Column(
                key: guide.keys.tasksHabits,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final habit in visibleHabits)
                    Padding(
                      key: ValueKey('habit-${habit.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HabitTaskTile(
                        key: Key('habitTaskTile-${habit.id}'),
                        habit: habit,
                        palette: palette,
                        isCompleted: habit.id == RoadGuideDemoIds.habitId
                            ? false
                            : habitVm.getStatusForHabitAndDate(
                                    habit.id ?? 0,
                                    habitsDay,
                                  ) ==
                                  HabitStatus.completed,
                        keepActiveAppearance:
                            habit.id != null &&
                            vm.isHeldCompletedHabit(habit.id!),
                        onTap: () async {
                          if (guide.isActive ||
                              habit.id == RoadGuideDemoIds.habitId) {
                            return;
                          }
                          await Navigator.pushNamed(
                            context,
                            '/habit-detail',
                            arguments: habit.id,
                          );
                          if (!context.mounted) return;
                          await context.read<HabitProgressViewModel>().load(
                            silent: true,
                          );
                        },
                        onLongPress: (anchor) {
                          if (guide.isActive ||
                              habit.id == RoadGuideDemoIds.habitId) {
                            return;
                          }
                          showHabitContextMenu(
                            context: context,
                            habit: habit,
                            vm: habitVm,
                            palette: palette,
                            anchor: anchor,
                          );
                        },
                        onToggle: () async {
                          final habitId = habit.id!;
                          final wasCompleted =
                              habitVm.getStatusForHabitAndDate(
                                habitId,
                                habitsDay,
                              ) ==
                              HabitStatus.completed;
                          if (!wasCompleted) {
                            vm.holdCompletedHabit(habitId);
                          }
                          final ok = await habitVm.toggleHabitCompleted(
                            habitId,
                            habitsDay,
                          );
                          if (!ok) {
                            vm.releaseHeldCompletedHabit(habitId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.cannotCompleteHabitInTheFuture,
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          if (wasCompleted) {
                            vm.releaseHeldCompletedHabit(habitId);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

const _kTasksGlassBarHeight = 88.0;

/// iOS-only: [GlassScaffold] does not SafeArea the shell tab bar, so this
/// bar's own [SafeArea] (home indicator) already lifts it enough.
const _kEmbeddedTabBarClearanceIos = 35.0;

/// Matches [MainShell] [GlassTabBar.bottom] `barHeight` (the visible pill).
const _kShellTabPillHeight = 58.0;

/// Gap between the Tasks action panel and the shell tab pill on Android.
/// [TasksGlassBottomBar] already adds 16px bottom padding inside the bar.
const _kEmbeddedTabBarGapAndroid = 8.0;

/// [GlassTabBar] preferred height: barHeight 58 + verticalPadding 20×2.
const _kMainShellTabBarHeight = 98.0;
const _kTasksListClearanceGap = 24.0;

/// Space under the Tasks action bar so it clears the shell tab pill.
///
/// [GlassScaffold] applies bottom [SafeArea] to the tab bar on Android only.
/// Clear to just above the visible pill (not the full preferred height — that
/// includes the tab bar's top padding and left a large empty gap).
double _embeddedTasksBarClearance(BuildContext context) {
  if (Theme.of(context).platform == TargetPlatform.android) {
    // From the shared SafeArea baseline: empty tab-bar bottom pad, then pill.
    // [TasksGlassBottomBar] already pads 16px below the panel — subtract that
    // so the visual gap above the pill is only [_kEmbeddedTabBarGapAndroid].
    const tabBarBottomPad = 20.0;
    const tasksBarBottomPad = 16.0;
    return tabBarBottomPad +
        _kShellTabPillHeight +
        _kEmbeddedTabBarGapAndroid -
        tasksBarBottomPad;
  }
  return _kEmbeddedTabBarClearanceIos;
}

double _tasksListBottomPadding(BuildContext context, {required bool embedded}) {
  final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
  final overlay =
      _kTasksGlassBarHeight +
      _kTasksListClearanceGap +
      (embedded ? _kMainShellTabBarHeight : 0) +
      systemBottom;
  final scaffoldInset = MediaQuery.paddingOf(context).bottom;
  return overlay > scaffoldInset
      ? overlay
      : scaffoldInset + _kTasksListClearanceGap;
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: _kSectionAnimDuration,
      curve: _kSectionAnimCurve,
      tween: Tween<double>(end: expanded ? 1 : 0),
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: t,
              child: IgnorePointer(ignoring: t == 0, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _TasksSectionHeader extends StatelessWidget {
  const _TasksSectionHeader({
    required this.palette,
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.hideLabel,
    required this.expanded,
    required this.onTap,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String label;
  final String showLabel;
  final String hideLabel;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: palette.accentMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                Text(
                  expanded ? hideLabel : showLabel,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TasksFiltersPanel extends StatelessWidget {
  const _TasksFiltersPanel({required this.strings, required this.palette});

  final TaskStrings strings;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<TasksViewModel>(
      builder: (context, vm, _) {
        final themes = vm.allThemes.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TasksGlassPanel(
              palette: palette,
              borderRadius: BorderRadius.circular(18),
              onTap: vm.toggleFiltersVisible,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 18, color: palette.accentMuted),
                  const SizedBox(width: 8),
                  Text(
                    strings.taskFilters,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (vm.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '•',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.onPrimary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (vm.hasActiveFilters && vm.filtersVisible)
                    TextButton(
                      onPressed: vm.clearFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        strings.taskClearFilters,
                        style: TextStyle(fontSize: 12, color: palette.primary),
                      ),
                    ),
                  if (vm.hasActiveFilters && vm.filtersVisible)
                    const SizedBox(width: 4),
                  Text(
                    vm.filtersVisible ? strings.taskHide : strings.taskShow,
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                  Icon(
                    vm.filtersVisible ? Icons.expand_less : Icons.expand_more,
                    color: palette.textMuted,
                  ),
                ],
              ),
            ),
            if (vm.filtersVisible) ...[
              const SizedBox(height: 12),
              _FilterSectionTitle(
                palette: palette,
                label: strings.taskFilterPriority,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TasksGlassChip(
                      label: strings.taskAll,
                      palette: palette,
                      selected: vm.selectedPriorityFilter == null,
                      onTap: () => vm.setPriorityFilter(null),
                    ),
                    ...TaskPriority.values.map(
                      (priority) => TasksGlassChip(
                        palette: palette,
                        label: priority.label(strings),
                        selected: vm.selectedPriorityFilter == priority,
                        color: priorityColor(priority, scheme),
                        onTap: () => vm.setPriorityFilter(priority),
                      ),
                    ),
                  ],
                ),
              ),
              if (vm.showsStatusFilter) ...[
                const SizedBox(height: 12),
                _FilterSectionTitle(
                  palette: palette,
                  label: strings.taskFilterStatus,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TasksGlassChip(
                        label: strings.taskAll,
                        palette: palette,
                        selected: vm.statusFilter == TaskStatusFilter.all,
                        onTap: () => vm.setStatusFilter(TaskStatusFilter.all),
                      ),
                      TasksGlassChip(
                        label: strings.taskStatusActive,
                        palette: palette,
                        selected: vm.statusFilter == TaskStatusFilter.active,
                        onTap: () =>
                            vm.setStatusFilter(TaskStatusFilter.active),
                      ),
                      TasksGlassChip(
                        label: strings.taskStatusDone,
                        palette: palette,
                        selected: vm.statusFilter == TaskStatusFilter.done,
                        onTap: () => vm.setStatusFilter(TaskStatusFilter.done),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _FilterSectionTitle(palette: palette, label: strings.taskThemes),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TasksGlassChip(
                      label: strings.taskAll,
                      palette: palette,
                      selected: vm.selectedThemeFilter == null,
                      onTap: () => vm.setThemeFilter(null),
                    ),
                    if (vm.hasTasksWithoutCategory)
                      TasksGlassChip(
                        label: strings.taskNoTheme,
                        palette: palette,
                        selected:
                            vm.selectedThemeFilter == taskNoCategoryFilterKey,
                        onTap: () => vm.setThemeFilter(taskNoCategoryFilterKey),
                      ),
                    ...themes.map(
                      (theme) => TasksGlassChip(
                        label: theme,
                        palette: palette,
                        selected: vm.selectedThemeFilter == theme,
                        color: vm.colorForTheme(theme),
                        onTap: () => vm.setThemeFilter(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.palette, required this.label});

  final TasksUiPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.textMuted,
      ),
    );
  }
}
