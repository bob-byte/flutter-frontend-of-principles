import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit.dart';
import '../models/user_goal.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/context_menu_overlay.dart';
import '../widgets/themed_lottie.dart';
import 'habit_detail_view.dart';

class GoalsView extends StatefulWidget {
  const GoalsView({super.key, this.embedded = false});

  static const routeName = '/goals';

  final bool embedded;

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.embedded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsViewModel>().load();
      context.read<HabitProgressViewModel>().load(silent: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _GoalsBody(controller: _controller, embedded: widget.embedded);

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(title: Text(l10n.goalsTitle)),
            Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.goalsTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: body,
    );
  }
}

class _GoalsBody extends StatelessWidget {
  const _GoalsBody({required this.controller, this.embedded = false});

  final TextEditingController controller;
  final bool embedded;

  Future<void> _submit(GoalsViewModel vm) async {
    await vm.addGoal(controller.text);
    controller.clear();
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
        estimatedHeight: 272,
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
                    vm.editGoal(goal);
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
                    vm.setGoalCompleted(goal, isCompleted: !goal.isCompleted);
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
        final displayGoals = [?demoGoal, ...vm.goals];
        final displayHabits = [
          if (guide.showDemoData) roadGuideDemoHabit(l10n),
          ...habitVm.habits,
        ];

        return Column(
          children: [
            Padding(
              key: guide.keys.goalsComposer,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      useOwnLayer: true,
                      controller: controller,
                      placeholder: l10n.newGoalLabel,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (guide.isActive) return;
                        _submit(vm);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (guide.isActive) return;
                      _submit(vm);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: vm.isLoading && displayGoals.isEmpty
                  ? const AppLoadingIndicator()
                  : displayGoals.isEmpty
                  ? _GoalsEmptyState(message: l10n.goalsEmptyList)
                  : _GoalsList(
                      goals: displayGoals,
                      habits: displayHabits,
                      demoGoalId: demoGoal?.id,
                      demoKey: guide.keys.goalsDemo,
                      guideActive: guide.isActive,
                      embedded: embedded,
                      onShowMenu: (tileContext, goal, {Rect? anchor}) {
                        if (guide.isActive) return;
                        if (goal.id == RoadGuideDemoIds.goalId) return;
                        _showGoalMenu(
                          tileContext,
                          goal,
                          vm,
                          palette,
                          anchor: anchor,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GoalsList extends StatelessWidget {
  const _GoalsList({
    required this.goals,
    required this.habits,
    required this.embedded,
    required this.onShowMenu,
    required this.guideActive,
    this.demoGoalId,
    this.demoKey,
  });

  final List<UserGoal> goals;
  final List<Habit> habits;
  final bool embedded;
  final bool guideActive;
  final int? demoGoalId;
  final GlobalKey? demoKey;
  final void Function(BuildContext tileContext, UserGoal goal, {Rect? anchor})
  onShowMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final vm = context.read<GoalsViewModel>();
    final active = goals.where((goal) => !goal.isCompleted).toList();
    final completed = goals.where((goal) => goal.isCompleted).toList();
    final unassigned = habitsUnassignedToGoals(habits, goals);

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
            guideActive: guideActive,
            tileKey: active[i].id == demoGoalId ? demoKey : null,
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
    required this.guideActive,
    this.tileKey,
    this.isDemo = false,
  });

  final UserGoal goal;
  final List<Habit> habits;
  final int index;
  final GoalsViewModel vm;
  final ColorScheme scheme;
  final bool guideActive;
  final GlobalKey? tileKey;
  final bool isDemo;
  final void Function(BuildContext tileContext, UserGoal goal, {Rect? anchor})
  onShowMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tile = GlassListTile.standalone(
      key: Key(_goalKey(goal, index)),
      leading: Icon(
        goal.isCompleted ? Icons.check_circle_outline : Icons.flag_outlined,
      ),
      title: Text(
        isDemo ? '${goal.name} (${l10n.roadGuideExampleBadge})' : goal.name,
        style: TextStyle(
          decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
          color: goal.isCompleted
              ? scheme.onSurface.withValues(alpha: 0.55)
              : null,
        ),
      ),
      subtitle: habits.isEmpty
          ? null
          : Text(l10n.goalHabitsCount(habits.length)),
      trailing: GlassListTile.chevron,
      onTap: (guideActive || isDemo) ? null : () => vm.editGoal(goal),
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
      key: tileKey,
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
  const _GoalsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Center(
            child: ThemedLottie(
              assetPath: 'assets/lottie/goals.json',
              width: 200,
              height: 200,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
