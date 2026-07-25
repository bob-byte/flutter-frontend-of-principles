import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../app/task_navigation.dart';
import '../core/utils/date_helpers.dart';
import '../models/task_priority.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../widgets/task_tile.dart';
import '../widgets/tasks_glass.dart';

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  static const routeName = '/tasks';

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TasksViewModel>().load();
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
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            appBar: TasksGlassAppBar(
              palette: palette,
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
                _TasksThemeSwitcher(
                  selected: vm.uiTheme,
                  strings: strings,
                  onSelected: vm.setUiTheme,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: TasksGlassBackground(
              palette: palette,
              child: vm.isLoading && vm.tasks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _TasksBody(strings: strings, palette: palette),
            ),
            bottomNavigationBar: SafeArea(
              child: TasksGlassBottomBar(
                palette: palette,
                child: Row(
                  children: [
                    TasksGlassCircleButton(
                      palette: palette,
                      icon: Icons.menu_rounded,
                      tooltip: strings.taskListMenuTitle,
                      onPressed: () => TasksNavigation.openListMenu(context),
                    ),
                    const Spacer(),
                    TasksGlassCircleButton(
                      palette: palette,
                      icon: Icons.add,
                      tooltip: strings.taskAdd,
                      isPrimary: true,
                      size: 56,
                      onPressed: () async {
                        final changed =
                            await TasksNavigation.openCreateTask(context);
                        if (!context.mounted) return;
                        if (changed == true) {
                          await context.read<TasksViewModel>().load();
                        }
                      },
                    ),
                  ],
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
  const _TasksBody({required this.strings, required this.palette});

  final TaskStrings strings;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksViewModel>(
      builder: (context, vm, _) {
        final filtered = vm.filteredTasks;
        final todayTotal = vm.todayTasks.length;
        final todayCompleted = vm.todayCompletedCount;
        final todayProgress = vm.todayProgressPercent;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            TasksGlassPanel(
              palette: palette,
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
                        Text(
                          '${todayProgress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  tasksGradientProgress(
                    palette: palette,
                    value: todayTotal == 0 ? 0 : todayCompleted / todayTotal,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.taskProgressCount(todayCompleted, todayTotal),
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TasksFiltersPanel(strings: strings, palette: palette),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    TasksGlassPanel(
                      palette: palette,
                      borderRadius: BorderRadius.circular(999),
                      padding: const EdgeInsets.all(20),
                      child: Icon(
                        _emptyIcon(vm.listMode),
                        size: 34,
                        color: palette.accentMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _emptyTitle(strings, vm),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _emptyHint(strings, vm),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskTile(
                    task: task,
                    palette: palette,
                    themeColor: task.theme != null
                        ? vm.colorForTheme(task.theme!)
                        : palette.textMuted,
                    onTap: () async {
                      final changed = await TasksNavigation.openEditTask(
                        context,
                        taskId: task.id,
                      );
                      if (!context.mounted) return;
                      if (changed == true) {
                        await context.read<TasksViewModel>().load();
                      }
                    },
                    onToggle: () => vm.toggleTask(task.id),
                    strings: strings,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

IconData _emptyIcon(TasksListMode mode) => switch (mode) {
      TasksListMode.inbox => Icons.inbox_outlined,
      TasksListMode.day => Icons.calendar_today_outlined,
      TasksListMode.today => Icons.checklist_outlined,
    };

String _emptyTitle(TaskStrings strings, TasksViewModel vm) => switch (vm.listMode) {
      TasksListMode.inbox => strings.taskNoTasksInbox,
      TasksListMode.day =>
        strings.taskNoTasksForDayLabel(formatTaskDate(vm.selectedDay)),
      TasksListMode.today => strings.taskNoTasks,
    };

String _emptyHint(TaskStrings strings, TasksViewModel vm) => switch (vm.listMode) {
      TasksListMode.inbox => strings.taskNoTasksInboxHint,
      TasksListMode.day => strings.taskNoTasksHint,
      TasksListMode.today => strings.taskNoTasksHint,
    };

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
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  if (vm.hasActiveFilters && vm.filtersVisible)
                    const SizedBox(width: 4),
                  Text(
                    vm.filtersVisible ? strings.taskHide : strings.taskShow,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textMuted,
                    ),
                  ),
                  Icon(
                    vm.filtersVisible
                        ? Icons.expand_less
                        : Icons.expand_more,
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
              _FilterSectionTitle(
                palette: palette,
                label: strings.taskThemes,
              ),
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
                        onTap: () =>
                            vm.setThemeFilter(taskNoCategoryFilterKey),
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

class _TasksThemeSwitcher extends StatelessWidget {
  const _TasksThemeSwitcher({
    required this.selected,
    required this.strings,
    required this.onSelected,
  });

  final TasksUiTheme selected;
  final TaskStrings strings;
  final ValueChanged<TasksUiTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TasksUiTheme>(
      tooltip: strings.taskUiThemeTooltip,
      initialValue: selected,
      onSelected: onSelected,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => TasksUiTheme.values
          .map(
            (theme) => PopupMenuItem(
              value: theme,
              child: Row(
                children: [
                  _ThemeSwatch(theme: theme, selected: theme == selected),
                  const SizedBox(width: 10),
                  Text(theme.label(strings)),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSwatch(theme: selected, selected: true, compact: true),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    this.compact = false,
  });

  final TasksUiTheme theme;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = TasksUiPalette.of(theme);
    final size = compact ? 22.0 : 18.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: palette.primaryGradient,
        border: Border.all(
          color: selected ? palette.textPrimary : Colors.transparent,
          width: selected ? 2 : 0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}
