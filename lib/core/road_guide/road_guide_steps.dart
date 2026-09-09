import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import '../../models/task.dart';
import '../../models/user_goal.dart';
import '../home_widget/home_widget_add_prompt.dart';
import 'main_shell_controller.dart';

/// Stable negative ids so tour demo rows never collide with real entities.
abstract final class RoadGuideDemoIds {
  static const goalId = -91001;
  static const habitId = -91002;
  static const taskId = 'road-guide-demo-task';
}

UserGoal roadGuideDemoGoal(AppLocalizations l10n) => UserGoal(
  id: RoadGuideDemoIds.goalId,
  name: l10n.roadGuideDemoGoalName,
  isCompleted: false,
);

Habit roadGuideDemoHabit(AppLocalizations l10n) => Habit(
  id: RoadGuideDemoIds.habitId,
  name: l10n.roadGuideDemoHabitName,
  targetGoal: l10n.roadGuideDemoGoalName,
  targetGoalId: RoadGuideDemoIds.goalId,
  difficulty: 4,
);

Task roadGuideDemoTask(AppLocalizations l10n) => Task(
  id: RoadGuideDemoIds.taskId,
  title: '${l10n.roadGuideDemoTaskName} (${l10n.roadGuideExampleBadge})',
  createdAt: DateTime.now(),
  dueDate: DateTime.now(),
);

enum RoadGuideStepId {
  goalsTab,
  goalsComposer,
  goalsDemo,
  habitsTab,
  habitsFab,
  recommendHabits,
  habitsDemo,
  habitDetail,
  tasksTab,
  tasksAdd,
  tasksDemo,
  tasksHabits,
  chatTab,
  chatInput,
  settingsTab,
  settingsProfile,
  settingsCalendarWidget,
  settingsReplay,
}

class RoadGuideStep {
  const RoadGuideStep({
    required this.id,
    required this.title,
    required this.body,
    this.targetKey,
    this.tabIndex,
    this.switchToTabOnNext,
    this.ensureTabOnShow,
    this.openEditHabitOnShow = false,
    this.openHabitDetailOnShow = false,
  });

  final RoadGuideStepId id;

  /// Widget key for in-page chrome (composer, FAB, demo tile, …).
  /// Null = full-screen dim with no spotlight hole.
  final GlobalKey? targetKey;

  /// When set, spotlight a tab-bar segment (Chat, Goals, Tasks, Habits, Settings)
  /// computed from screen metrics — never via a [GlobalKey] on [GlassTabBar].
  final int? tabIndex;

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) body;

  /// After Next on this step, switch to this tab before the next step.
  final int? switchToTabOnNext;

  /// Ensure this tab is visible when the step is shown.
  final int? ensureTabOnShow;

  /// Push the Add Habit screen so the recommended-habits button can be shown.
  final bool openEditHabitOnShow;

  /// Push habit details for the demo habit (progress, streaks, stability).
  final bool openHabitDetailOnShow;

  bool get opensPushedRoute => openEditHabitOnShow || openHabitDetailOnShow;
}

class RoadGuideKeys {
  RoadGuideKeys();

  final goalsComposer = GlobalKey(debugLabel: 'roadGuideGoalsComposer');
  final goalsDemo = GlobalKey(debugLabel: 'roadGuideGoalsDemo');
  final habitsFab = GlobalKey(debugLabel: 'roadGuideHabitsFab');
  final recommendedHabits = GlobalKey(debugLabel: 'roadGuideRecommendedHabits');
  final habitsDemo = GlobalKey(debugLabel: 'roadGuideHabitsDemo');
  final tasksAdd = GlobalKey(debugLabel: 'roadGuideTasksAdd');
  final tasksDemo = GlobalKey(debugLabel: 'roadGuideTasksDemo');
  final tasksHabits = GlobalKey(debugLabel: 'roadGuideTasksHabits');
  final chatInput = GlobalKey(debugLabel: 'roadGuideChatInput');
  final settingsProfile = GlobalKey(debugLabel: 'roadGuideSettingsProfile');
  final settingsCalendarWidget = GlobalKey(
    debugLabel: 'roadGuideSettingsCalendarWidget',
  );
  final settingsReplay = GlobalKey(debugLabel: 'roadGuideSettingsReplay');

  static const tabCount = 5;
  static const tabBarHeight = 58.0;
  static const tabBarVerticalPadding = 20.0;
  static const tabBarHorizontalPadding = 16.0;

  /// Spotlight rect for a tab, derived from screen size (no tab-bar GlobalKey).
  static Rect? tabHole(BuildContext context, int tabIndex) {
    if (tabIndex < 0 || tabIndex >= tabCount) return null;
    final media = MediaQuery.of(context);
    final bottomInset = Theme.of(context).platform == TargetPlatform.android
        ? media.padding.bottom
        : 0.0;
    final totalHeight = tabBarHeight + tabBarVerticalPadding * 2;
    final top = media.size.height - bottomInset - totalHeight;
    final innerWidth = media.size.width - tabBarHorizontalPadding * 2;
    final segmentWidth = innerWidth / tabCount;
    return Rect.fromLTWH(
      tabBarHorizontalPadding + segmentWidth * tabIndex,
      top,
      segmentWidth,
      totalHeight,
    );
  }

  List<RoadGuideStep> buildSteps() {
    return [
      RoadGuideStep(
        id: RoadGuideStepId.goalsTab,
        tabIndex: MainShellTab.goals,
        title: (l) => l.roadGuideGoalsTabTitle,
        body: (l) => l.roadGuideGoalsTabBody,
        switchToTabOnNext: MainShellTab.goals,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.goalsComposer,
        targetKey: goalsComposer,
        title: (l) => l.roadGuideGoalsComposerTitle,
        body: (l) => l.roadGuideGoalsComposerBody,
        ensureTabOnShow: MainShellTab.goals,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.goalsDemo,
        targetKey: goalsDemo,
        title: (l) => l.roadGuideGoalsDemoTitle,
        body: (l) => l.roadGuideGoalsDemoBody,
        ensureTabOnShow: MainShellTab.goals,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.habitsTab,
        tabIndex: MainShellTab.habits,
        title: (l) => l.roadGuideHabitsTabTitle,
        body: (l) => l.roadGuideHabitsTabBody,
        switchToTabOnNext: MainShellTab.habits,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.habitsFab,
        targetKey: habitsFab,
        title: (l) => l.roadGuideHabitsFabTitle,
        body: (l) => l.roadGuideHabitsFabBody,
        ensureTabOnShow: MainShellTab.habits,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.recommendHabits,
        targetKey: recommendedHabits,
        title: (l) => l.roadGuideRecommendTitle,
        body: (l) => l.roadGuideRecommendBody,
        ensureTabOnShow: MainShellTab.habits,
        openEditHabitOnShow: true,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.habitsDemo,
        targetKey: habitsDemo,
        title: (l) => l.roadGuideHabitsDemoTitle,
        body: (l) => l.roadGuideHabitsDemoBody,
        ensureTabOnShow: MainShellTab.habits,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.habitDetail,
        title: (l) => l.roadGuideHabitDetailTitle,
        body: (l) => l.roadGuideHabitDetailBody,
        ensureTabOnShow: MainShellTab.habits,
        openHabitDetailOnShow: true,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.tasksTab,
        tabIndex: MainShellTab.tasks,
        title: (l) => l.roadGuideTasksTabTitle,
        body: (l) => l.roadGuideTasksTabBody,
        switchToTabOnNext: MainShellTab.tasks,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.tasksAdd,
        targetKey: tasksAdd,
        title: (l) => l.roadGuideTasksAddTitle,
        body: (l) => l.roadGuideTasksAddBody,
        ensureTabOnShow: MainShellTab.tasks,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.tasksDemo,
        targetKey: tasksDemo,
        title: (l) => l.roadGuideTasksDemoTitle,
        body: (l) => l.roadGuideTasksDemoBody,
        ensureTabOnShow: MainShellTab.tasks,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.tasksHabits,
        targetKey: tasksHabits,
        title: (l) => l.roadGuideTasksHabitsTitle,
        body: (l) => l.roadGuideTasksHabitsBody,
        ensureTabOnShow: MainShellTab.tasks,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.chatTab,
        tabIndex: MainShellTab.chat,
        title: (l) => l.roadGuideChatTabTitle,
        body: (l) => l.roadGuideChatTabBody,
        switchToTabOnNext: MainShellTab.chat,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.chatInput,
        targetKey: chatInput,
        title: (l) => l.roadGuideChatInputTitle,
        body: (l) => l.roadGuideChatInputBody,
        ensureTabOnShow: MainShellTab.chat,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.settingsTab,
        tabIndex: MainShellTab.settings,
        title: (l) => l.roadGuideSettingsTabTitle,
        body: (l) => l.roadGuideSettingsTabBody,
        switchToTabOnNext: MainShellTab.settings,
      ),
      RoadGuideStep(
        id: RoadGuideStepId.settingsProfile,
        targetKey: settingsProfile,
        title: (l) => l.roadGuideSettingsProfileTitle,
        body: (l) => l.roadGuideSettingsProfileBody,
        ensureTabOnShow: MainShellTab.settings,
      ),
      if (showHomeCalendarWidgetSettingsEntry())
        RoadGuideStep(
          id: RoadGuideStepId.settingsCalendarWidget,
          targetKey: settingsCalendarWidget,
          title: (l) => l.roadGuideSettingsCalendarTitle,
          body: (l) => l.roadGuideSettingsCalendarBody,
          ensureTabOnShow: MainShellTab.settings,
        ),
      RoadGuideStep(
        id: RoadGuideStepId.settingsReplay,
        targetKey: settingsReplay,
        title: (l) => l.roadGuideSettingsReplayTitle,
        body: (l) => l.roadGuideSettingsReplayBody,
        ensureTabOnShow: MainShellTab.settings,
      ),
    ];
  }
}
