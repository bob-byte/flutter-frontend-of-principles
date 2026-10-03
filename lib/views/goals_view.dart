import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/launch_data_loader.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit.dart';
import '../models/user_goal.dart';
import '../services/dialog_service.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import 'common/app_liquid_background.dart';
import 'common/app_loading_indicator.dart';
import 'common/completion_burst.dart';
import 'common/context_menu_overlay.dart';
import 'common/themed_lottie.dart';
import 'edit_goal_view.dart';
import 'habit_detail_view.dart';

Color _primarySoft(TasksUiPalette palette) =>
    palette.primary.withValues(alpha: palette.isDark ? 0.22 : 0.14);

class GoalsView extends StatefulWidget {
  const GoalsView({super.key, this.embedded = false});

  static const routeName = '/goals';

  final bool embedded;

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldSkipShellTabReload(context)) return;
      context.read<GoalsViewModel>().load(silent: widget.embedded);
      context.read<HabitProgressViewModel>().load(
        silent: true,
        syncRemote: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return Consumer<RoadGuideController>(
      builder: (context, guide, _) {
        final scaffold = Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: Padding(
            key: guide.keys.goalsComposer,
            // Android has no home-indicator lift; raise the FAB above the shell pill.
            padding: EdgeInsets.only(
              bottom: widget.embedded
                  ? (Theme.of(context).platform == TargetPlatform.android
                        ? 64
                        : 48)
                  : 0,
            ),
            child: FloatingActionButton(
              heroTag: 'goalsAddFab',
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: l10n.addGoalTitle,
              onPressed: () async {
                if (guide.isActive) return;
                final changed = await EditGoalView.open(context);
                if (!context.mounted || !changed) return;
                await context.read<GoalsViewModel>().load(silent: true);
                try {
                  await context.read<HabitProgressViewModel>().load(
                    silent: true,
                    syncRemote: false,
                  );
                } catch (e) {
                  debugPrint('Reload habits after goal create failed: $e');
                }
              },
              child: Icon(Icons.add, color: palette.onPrimary, size: 32),
            ),
          ),
          body: SafeArea(
            bottom: !widget.embedded,
            child: Consumer<GoalsViewModel>(
              builder: (context, goalsVm, _) {
                return Column(
                  children: [
                    _buildHeader(context, goalsVm, palette, l10n),
                    _GoalsFiltersPanelHost(palette: palette),
                    Expanded(child: _GoalsBody(embedded: widget.embedded)),
                  ],
                );
              },
            ),
          ),
        );

        if (widget.embedded) return scaffold;
        return Stack(
          fit: StackFit.expand,
          children: [const AppLiquidBackground(), scaffold],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    GoalsViewModel goalsVm,
    TasksUiPalette palette,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!widget.embedded) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: palette.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              l10n.goalsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              _GoalsFilterButton(
                key: const Key('goalFiltersButton'),
                palette: palette,
                tooltip: l10n.goalFiltersTooltip,
                emphasized: goalsVm.filtersVisible || goalsVm.hasActiveFilters,
                showBadge: goalsVm.hasActiveFilters,
                onPressed: goalsVm.toggleFiltersVisible,
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('goalArchiveButton'),
                tooltip: l10n.archiveTooltip,
                icon: Icon(
                  Icons.archive_outlined,
                  color: palette.primary,
                  size: 24,
                ),
                onPressed: () {
                  DialogService()
                      .showCustomSheet(variant: BottomSheetType.goalArchive)
                      .then((_) {
                        if (!context.mounted) return;
                        context.read<GoalsViewModel>().load(silent: true);
                      });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsBody extends StatelessWidget {
  const _GoalsBody({this.embedded = false});

  final bool embedded;

  Future<void> _openEditor(BuildContext context, UserGoal? goal) async {
    final changed = await EditGoalView.open(context, goal: goal);
    if (!context.mounted || !changed) return;
    await context.read<GoalsViewModel>().load(silent: true);
    try {
      await context.read<HabitProgressViewModel>().load(
        silent: true,
        syncRemote: false,
      );
    } catch (e) {
      debugPrint('Reload habits after goal edit failed: $e');
    }
  }

  void _showGoalMenu(
    BuildContext context,
    UserGoal goal,
    GoalsViewModel vm,
    TasksUiPalette palette, {
    Rect? anchor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    ContextMenuOverlay.show(
      context: context,
      builder: (dialogContext, animation) => ContextMenuOverlay(
        animation: animation,
        palette: palette,
        anchor: anchor,
        estimatedHeight: 320,
        child: Column(
          key: const Key('goalContextMenu'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuHeader(
              palette: palette,
              leading: ContextMenuLeadingIcon(
                icon: goal.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.flag_outlined,
                palette: palette,
              ),
              title: goal.name,
            ),
            const SizedBox(height: 12),
            ContextMenuActionList(
              palette: palette,
              actions: [
                ContextMenuAction(
                  label: l10n.habitMenuEdit,
                  icon: Icons.edit_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _openEditor(context, goal);
                  },
                ),
                ContextMenuAction(
                  label: goal.isCompleted
                      ? l10n.markGoalIncomplete
                      : l10n.markGoalCompleted,
                  icon: goal.isCompleted
                      ? Icons.restart_alt
                      : Icons.check_circle_outline,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    if (!goal.isCompleted) {
                      playCompletionCelebration(
                        context,
                        color: palette.primary,
                        origin: anchor?.center,
                      );
                    }
                    vm.setGoalCompleted(goal, isCompleted: !goal.isCompleted);
                  },
                ),
                ContextMenuAction(
                  label: l10n.archiveTooltip,
                  icon: Icons.archive_outlined,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final confirmed = await vm.confirmArchiveGoal(goal);
                    if (confirmed) {
                      await vm.archiveGoal(goal);
                    }
                  },
                ),
                ContextMenuAction(
                  label: l10n.deleteTooltip,
                  icon: Icons.delete_outline,
                  destructive: true,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final confirmed = await vm.confirmDeleteGoal(goal);
                    if (confirmed) {
                      await vm.deleteGoal(goal);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return Consumer3<
      GoalsViewModel,
      HabitProgressViewModel,
      RoadGuideController
    >(
      builder: (context, vm, habitVm, guide, child) {
        final demoGoal = guide.showDemoData ? roadGuideDemoGoal(l10n) : null;
        final sourceGoals = guide.isActive ? vm.goals : vm.filteredGoals;
        final displayGoals = [?demoGoal, ...sourceGoals];
        final displayHabits = [
          if (guide.showDemoData) roadGuideDemoHabit(l10n),
          ...habitVm.habits,
        ];
        final showUnassigned = guide.isActive || vm.showsUnassignedHabits;

        if (vm.isLoading && vm.goals.isEmpty && demoGoal == null) {
          return const AppLoadingIndicator();
        }
        if (vm.goals.isEmpty && demoGoal == null) {
          return _GoalsEmptyState(
            message: l10n.goalsEmptyList,
            embedded: embedded,
          );
        }
        if (displayGoals.isEmpty &&
            !(showUnassigned &&
                habitsUnassignedToGoals(displayHabits, vm.goals).isNotEmpty)) {
          return _GoalsEmptyState(
            message: l10n.goalFiltersEmpty,
            embedded: embedded,
          );
        }

        return _GoalsList(
          goals: displayGoals,
          habits: displayHabits,
          allGoals: [?demoGoal, ...vm.goals],
          showUnassignedHabits: showUnassigned,
          demoGoalId: demoGoal?.id,
          guideActive: guide.isActive,
          embedded: embedded,
          onShowMenu: (tileContext, goal, {Rect? anchor}) {
            if (guide.isActive) return;
            if (goal.id == RoadGuideDemoIds.goalId) return;
            _showGoalMenu(tileContext, goal, vm, palette, anchor: anchor);
          },
          onOpen: (goal) => _openEditor(context, goal),
        );
      },
    );
  }
}

class _GoalsList extends StatelessWidget {
  const _GoalsList({
    required this.goals,
    required this.habits,
    required this.allGoals,
    required this.showUnassignedHabits,
    required this.embedded,
    required this.onShowMenu,
    required this.onOpen,
    required this.guideActive,
    this.demoGoalId,
  });

  final List<UserGoal> goals;
  final List<Habit> habits;
  final List<UserGoal> allGoals;
  final bool showUnassignedHabits;
  final bool embedded;
  final bool guideActive;
  final int? demoGoalId;
  final void Function(BuildContext tileContext, UserGoal goal, {Rect? anchor})
  onShowMenu;
  final void Function(UserGoal goal) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final vm = context.watch<GoalsViewModel>();
    final active = goals.where(vm.appearsInActiveSection).toList();
    final completed = goals
        .where((goal) => goal.isCompleted && !vm.isHeldCompletedGoal(goal))
        .toList();
    final unassigned = showUnassignedHabits
        ? habitsUnassignedToGoals(habits, allGoals)
        : const <Habit>[];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, embedded ? 80 : 24),
      children: [
        for (var i = 0; i < active.length; i++)
          _GoalDismissibleTile(
            goal: active[i],
            habits: habitsForGoal(habits, active[i]),
            index: i,
            vm: vm,
            scheme: scheme,
            onShowMenu: onShowMenu,
            onOpen: onOpen,
            guideActive: guideActive,
            keepActiveAppearance: vm.isHeldCompletedGoal(active[i]),
            isDemo: active[i].id == demoGoalId,
          ),
        if (completed.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4, active.isEmpty ? 4 : 12, 4, 8),
            child: Text(
              l10n.completedGoalsHeader,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var i = 0; i < completed.length; i++)
            _GoalDismissibleTile(
              goal: completed[i],
              habits: habitsForGoal(habits, completed[i]),
              index: active.length + i,
              vm: vm,
              scheme: scheme,
              onShowMenu: onShowMenu,
              onOpen: onOpen,
              guideActive: guideActive,
              isDemo: completed[i].id == demoGoalId,
            ),
        ],
        if (unassigned.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              active.isEmpty && completed.isEmpty ? 4 : 12,
              4,
              8,
            ),
            child: Text(
              l10n.undefinedGoalLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          for (final habit in unassigned)
            _GoalHabitTile(
              habit: habit,
              guideActive: guideActive,
              isDemo: habit.id == RoadGuideDemoIds.habitId,
            ),
        ],
      ],
    );
  }
}

class _GoalDismissibleTile extends StatelessWidget {
  const _GoalDismissibleTile({
    required this.goal,
    required this.habits,
    required this.index,
    required this.vm,
    required this.scheme,
    required this.onShowMenu,
    required this.onOpen,
    required this.guideActive,
    this.keepActiveAppearance = false,
    this.isDemo = false,
  });

  final UserGoal goal;
  final List<Habit> habits;
  final int index;
  final GoalsViewModel vm;
  final ColorScheme scheme;
  final bool guideActive;
  final bool keepActiveAppearance;
  final bool isDemo;
  final void Function(BuildContext tileContext, UserGoal goal, {Rect? anchor})
  onShowMenu;
  final void Function(UserGoal goal) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showCompletedChrome = goal.isCompleted && !keepActiveAppearance;
    final tile = GlassListTile.standalone(
      key: Key(_goalKey(goal, index)),
      leading: CompletionCelebrate(
        isCompleted: goal.isCompleted,
        color: scheme.primary,
        burstRadius: 44,
        child: Icon(
          showCompletedChrome
              ? Icons.check_circle_outline
              : Icons.flag_outlined,
        ),
      ),
      title: Text(
        isDemo ? '${goal.name} (${l10n.roadGuideExampleBadge})' : goal.name,
        style: TextStyle(
          decoration: showCompletedChrome ? TextDecoration.lineThrough : null,
          color: showCompletedChrome
              ? scheme.onSurface.withValues(alpha: 0.55)
              : null,
        ),
      ),
      subtitle: habits.isEmpty
          ? null
          : Text(l10n.goalHabitsCount(habits.length)),
      trailing: GlassListTile.chevron,
      onTap: (guideActive || isDemo) ? null : () => onOpen(goal),
      onLongPress: (guideActive || isDemo)
          ? null
          : () {
              final box = context.findRenderObject() as RenderBox?;
              Rect? anchor;
              if (box != null && box.hasSize) {
                anchor = box.localToGlobal(Offset.zero) & box.size;
              }
              onShowMenu(context, goal, anchor: anchor);
            },
    );

    final goalRow = isDemo || guideActive
        ? tile
        : Dismissible(
            key: ValueKey(
              'goalDismiss-${goal.id ?? goal.localId ?? index}-${goal.name}',
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => vm.confirmDeleteGoal(goal),
            onDismissed: (_) => vm.deleteGoal(goal),
            background: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete_outline, color: scheme.onError),
                ),
              ),
            ),
            child: tile,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          goalRow,
          if (habits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 6),
              child: Column(
                children: [
                  for (final habit in habits)
                    _GoalHabitTile(
                      habit: habit,
                      guideActive: guideActive,
                      isDemo: isDemo || habit.id == RoadGuideDemoIds.habitId,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _goalKey(UserGoal goal, int index) {
    return 'goalTile-${goal.id ?? goal.localId ?? index}-${goal.name}';
  }
}

class _GoalHabitTile extends StatelessWidget {
  const _GoalHabitTile({
    required this.habit,
    required this.guideActive,
    required this.isDemo,
  });

  final Habit habit;
  final bool guideActive;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = isDemo && habit.id == RoadGuideDemoIds.habitId
        ? '${habit.name} (${l10n.roadGuideExampleBadge})'
        : habit.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassListTile.standalone(
        key: Key('goalHabitTile-${habit.id ?? habit.name}'),
        leading: const Icon(Icons.insights_outlined),
        title: Text(displayName),
        trailing: GlassListTile.chevron,
        onTap: (guideActive || isDemo)
            ? null
            : () async {
                await Navigator.pushNamed(
                  context,
                  HabitDetailView.routeName,
                  arguments: habit.id,
                );
                if (!context.mounted) return;
                await context.read<HabitProgressViewModel>().load(silent: true);
              },
      ),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState({required this.message, this.embedded = false});

  final String message;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Match list bottom clearance so content stays above the shell tab bar.
      padding: EdgeInsets.fromLTRB(24, 0, 24, embedded ? 80 : 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ThemedLottie(
              assetPath: 'assets/lottie/goals.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsFilterButton extends StatelessWidget {
  const _GoalsFilterButton({
    super.key,
    required this.palette,
    required this.onPressed,
    required this.tooltip,
    this.emphasized = false,
    this.showBadge = false,
  });

  final TasksUiPalette palette;
  final VoidCallback onPressed;
  final String tooltip;
  final bool emphasized;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(Icons.tune, color: palette.primary, size: 24);
    final button = emphasized
        ? GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primarySoft(palette),
                borderRadius: BorderRadius.circular(20),
              ),
              child: iconWidget,
            ),
          )
        : IconButton(onPressed: onPressed, icon: iconWidget);

    final badged = showBadge
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.cardBg, width: 1.5),
                  ),
                ),
              ),
            ],
          )
        : button;

    return Tooltip(message: tooltip, child: badged);
  }
}

class _GoalsFiltersPanelHost extends StatelessWidget {
  const _GoalsFiltersPanelHost({required this.palette});

  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalsViewModel>();
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: vm.filtersVisible
          ? _GoalsFiltersPanel(vm: vm, palette: palette)
          : const SizedBox(width: double.infinity),
    );
  }
}

class _GoalsFiltersPanel extends StatelessWidget {
  const _GoalsFiltersPanel({required this.vm, required this.palette});

  final GoalsViewModel vm;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.goalFilters,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              if (vm.hasActiveFilters)
                TextButton(
                  onPressed: vm.clearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.goalClearFilters,
                    style: TextStyle(fontSize: 12, color: palette.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.goalFilterStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _GoalFilterChip(
                  palette: palette,
                  label: l10n.goalFilterAll,
                  selected: vm.statusFilter == GoalStatusFilter.all,
                  onTap: () => vm.setStatusFilter(GoalStatusFilter.all),
                ),
                _GoalFilterChip(
                  palette: palette,
                  label: l10n.goalFilterActive,
                  selected: vm.statusFilter == GoalStatusFilter.active,
                  onTap: () => vm.setStatusFilter(GoalStatusFilter.active),
                ),
                _GoalFilterChip(
                  palette: palette,
                  label: l10n.goalFilterCompleted,
                  selected: vm.statusFilter == GoalStatusFilter.completed,
                  onTap: () => vm.setStatusFilter(GoalStatusFilter.completed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalFilterChip extends StatelessWidget {
  const _GoalFilterChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TasksUiPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _primarySoft(palette) : palette.softBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? palette.primary : palette.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? palette.primary : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
