import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../l10n/task_strings.dart';
import '../app/task_navigation.dart';
import '../core/utils/date_helpers.dart';
import '../models/habit_record.dart';
import '../models/task_priority.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/habit_context_menu.dart';
import '../widgets/habit_task_tile.dart';
import '../widgets/task_context_menu.dart';
import '../widgets/task_tile.dart';
import '../widgets/tasks_glass.dart';

const _kSectionAnimDuration = Duration(milliseconds: 280);
const _kSectionAnimCurve = Curves.easeInOutCubic;

class TasksView extends StatefulWidget {
  const TasksView({super.key, this.embedded = false});

  static const routeName = '/tasks';

  final bool embedded;

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TasksViewModel>().load(silent: widget.embedded);
      context.read<HabitProgressViewModel>().load(silent: true);
    });
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
              ),
              body: vm.isLoading && vm.tasks.isEmpty
                  ? const AppLoadingIndicator()
                  : _TasksBody(
                      strings: strings,
                      palette: palette,
                      embedded: widget.embedded,
                    ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.embedded ? _kEmbeddedTabBarClearance : 0,
                  ),
                  child: TasksGlassBottomBar(
                    palette: palette,
                    child: Row(
                      children: [
                        TasksGlassCircleButton(
                          palette: palette,
                          icon: Icons.menu_rounded,
                          tooltip: strings.taskListMenuTitle,
                          onPressed: () =>
                              TasksNavigation.openListMenu(context),
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
  });

  final TaskStrings strings;
  final TasksUiPalette palette;
  final bool embedded;

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
                          : null,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskTile(
                        key: Key('taskTile-${task.id}'),
                        task: task,
                        palette: palette,
                        themeColor: task.theme != null
                            ? vm.colorForTheme(task.theme!)
                            : palette.textMuted,
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
              expanded: guide.isActive || vm.habitsSectionExpanded,
              onTap: vm.toggleHabitsSectionExpanded,
            ),
            _CollapsibleSection(
              expanded: guide.isActive || vm.habitsSectionExpanded,
              child: Column(
                key: guide.keys.tasksHabits,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final habit in visibleHabits)
                    Padding(
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
                        strings: strings,
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
                          final ok = await habitVm.toggleHabitCompleted(
                            habit.id!,
                            habitsDay,
                          );
                          if (ok || !context.mounted) return;
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
const _kEmbeddedTabBarClearance = 35.0;
const _kMainShellTabBarHeight = 98.0;
const _kTasksListClearanceGap = 24.0;

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
    required this.expanded,
    required this.onTap,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String label;
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
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: _kSectionAnimDuration,
                  curve: _kSectionAnimCurve,
                  child: Icon(Icons.expand_more, color: palette.textMuted),
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
                      onTap: () => vm.setStatusFilter(TaskStatusFilter.active),
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
