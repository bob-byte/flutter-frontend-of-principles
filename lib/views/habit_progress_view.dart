import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/habit_score.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit_record.dart';
import '../models/habit.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/habit_context_menu.dart';
import 'edit_habit_view.dart';
import 'habit_detail_view.dart';
import '../services/dialog_service.dart';
import 'widgets/global_reminder_sheet.dart';

const _kGoalGroupAnimDuration = Duration(milliseconds: 280);
const _kGoalGroupAnimCurve = Curves.easeInOutCubic;

Color _primarySoft(TasksUiPalette palette) =>
    palette.primary.withValues(alpha: palette.isDark ? 0.22 : 0.14);

Color _completedColor(TasksUiPalette palette) =>
    palette.isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);

class HabitProgressView extends StatefulWidget {
  const HabitProgressView({
    super.key,
    this.embedded = false,
    this.isActive = true,
  });

  static const routeName = '/progress';

  final bool embedded;
  final bool isActive;

  @override
  State<HabitProgressView> createState() => _HabitProgressViewState();
}

class _HabitProgressViewState extends State<HabitProgressView> {
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HabitProgressViewModel>().load(silent: widget.embedded);
      if (widget.isActive) {
        _scrollToCurrentDate();
      }
    });
  }

  @override
  void didUpdateWidget(HabitProgressView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _scrollToCurrentDate();
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentDate() {
    _tryScrollToCurrentDate(attemptsLeft: 8);
  }

  void _tryScrollToCurrentDate({required int attemptsLeft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_dateScrollController.hasClients ||
          !_dateScrollController.position.hasContentDimensions) {
        if (attemptsLeft > 0) {
          _tryScrollToCurrentDate(attemptsLeft: attemptsLeft - 1);
        }
        return;
      }
      _dateScrollController.animateTo(
        _dateScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    return Consumer2<HabitProgressViewModel, RoadGuideController>(
      builder: (context, vm, guide, child) {
        final scaffold = Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: !widget.embedded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, vm, palette),
                const SizedBox(height: 16),
                _buildDateCarousel(context, vm, palette),
                const SizedBox(height: 16),
                _buildSummaryBanner(context, vm, palette),
                const SizedBox(height: 16),
                Expanded(child: _buildHabitsList(context, vm, palette, guide)),
              ],
            ),
          ),
          floatingActionButton: Padding(
            key: guide.keys.habitsFab,
            padding: EdgeInsets.only(bottom: widget.embedded ? 48 : 0),
            child: FloatingActionButton(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () async {
                if (guide.isActive) return;
                await EditHabitView.show(context);
                if (context.mounted) {
                  context.read<HabitProgressViewModel>().load();
                }
              },
              child: Icon(Icons.add, color: palette.onPrimary, size: 32),
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
    HabitProgressViewModel vm,
    TasksUiPalette palette,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).languageCode;
    final today = DateTime.now();
    final isTodaySelected =
        vm.selectedDate.year == today.year &&
        vm.selectedDate.month == today.month &&
        vm.selectedDate.day == today.day;

    final weekday = DateFormat('E', dateLocale).format(vm.selectedDate);
    final dateTitle = isTodaySelected
        ? '${l10n.habitsTodayLabel}, $weekday'
        : DateFormat('d MMMM, E', dateLocale).format(vm.selectedDate);

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tabHabits,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Стрік
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.habitStreakExplanation,
                        style: TextStyle(color: palette.onPrimary),
                      ),
                      backgroundColor: palette.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      action: SnackBarAction(
                        label: l10n.okButton,
                        textColor: palette.onPrimary,
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _primarySoft(palette),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: palette.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${vm.currentStreak}',
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Дзвіночок
              GestureDetector(
                onTap: () {
                  GlobalReminderBottomSheet.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primarySoft(palette),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none,
                    color: palette.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Архів
              GestureDetector(
                onTap: () {
                  DialogService()
                      .showCustomSheet(variant: BottomSheetType.archive)
                      .then((_) {
                        context.read<HabitProgressViewModel>().load();
                      });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.softBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.archive_outlined,
                    color: palette.textMuted,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateCarousel(
    BuildContext context,
    HabitProgressViewModel vm,
    TasksUiPalette palette,
  ) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _dateScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: vm.dates.length,
        itemBuilder: (context, index) {
          final date = vm.dates[index];
          final isSelected =
              date.year == vm.selectedDate.year &&
              date.month == vm.selectedDate.month &&
              date.day == vm.selectedDate.day;

          final dateLocale = Localizations.localeOf(context).languageCode;
          final weekdayStr = DateFormat(
            'E',
            dateLocale,
          ).format(date).toUpperCase();
          final dayStr = '${date.day}';

          return GestureDetector(
            onTap: () => vm.selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? palette.primary : palette.cardBg,
                borderRadius: BorderRadius.circular(26),
                border: isSelected
                    ? null
                    : Border.all(color: palette.cardBorder),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: palette.glassShadow,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? palette.onPrimary.withValues(alpha: 0.72)
                          : palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayStr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? palette.onPrimary
                          : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDayProgressBar(
                    ratio: vm.completionRatioOn(date),
                    isSelected: isSelected,
                    palette: palette,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayProgressBar({
    required double ratio,
    required bool isSelected,
    required TasksUiPalette palette,
  }) {
    final fill = ratio.clamp(0.0, 1.0);
    return Container(
      width: 18,
      height: 3,
      decoration: BoxDecoration(
        color: isSelected
            ? palette.onPrimary.withValues(alpha: 0.28)
            : palette.cardBorder,
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fill,
          heightFactor: 1,
          child: ColoredBox(
            color: isSelected ? palette.onPrimary : palette.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context,
    HabitProgressViewModel vm,
    TasksUiPalette palette,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _primarySoft(palette),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.habitsCompletedToday,
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${vm.completedHabitsCount}/${vm.totalHabitsCount}',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsList(
    BuildContext context,
    HabitProgressViewModel vm,
    TasksUiPalette palette,
    RoadGuideController guide,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final habits = [
      if (guide.showDemoData) roadGuideDemoHabit(l10n),
      ...vm.habits,
    ];
    if (vm.isLoading && habits.isEmpty) {
      return const AppLoadingIndicator();
    }

    final groups = groupHabitsByGoal(habits);
    if (groups.isEmpty) {
      return Center(
        child: Text(
          l10n.habitsEmptyList,
          style: TextStyle(color: palette.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: widget.embedded ? 120 : 100,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final expanded = guide.isActive || vm.isGoalGroupExpanded(group.key);
        final title = group.isUndefined
            ? l10n.undefinedGoalLabel
            : group.goalName!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _GoalHabitsSection(
            key: ValueKey(group.key),
            title: title,
            isUndefined: group.isUndefined,
            expanded: expanded,
            palette: palette,
            onToggle: () {
              if (guide.isActive) return;
              vm.toggleGoalGroup(group.key);
            },
            habitCards: [
              for (final habit in group.habits)
                _buildHabitCard(
                  context,
                  habit,
                  vm,
                  palette,
                  guideActive: guide.isActive,
                  isDemo: habit.id == RoadGuideDemoIds.habitId,
                  spotlightKey: habit.id == RoadGuideDemoIds.habitId
                      ? guide.keys.habitsDemo
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitCard(
    BuildContext context,
    Habit habit,
    HabitProgressViewModel vm,
    TasksUiPalette palette, {
    bool guideActive = false,
    bool isDemo = false,
    GlobalKey? spotlightKey,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final status = vm.getStatusForHabitAndDate(habit.id ?? 0, vm.selectedDate);
    final isCompleted = status == HabitStatus.completed;
    final weeklyProgress = isDemo ? 0.35 : vm.getPercentageAchieved(habit);
    final doneColor = _completedColor(palette);
    final progressColor = isCompleted ? doneColor : palette.primary;
    final displayName = isDemo
        ? '${habit.name} (${l10n.roadGuideExampleBadge})'
        : habit.name;

    return Builder(
      key: ValueKey(habit.id),
      builder: (cardContext) {
        return GestureDetector(
          onLongPress: (guideActive || isDemo)
              ? null
              : () {
                  final box = cardContext.findRenderObject() as RenderBox?;
                  Rect? anchor;
                  if (box != null && box.hasSize) {
                    anchor = box.localToGlobal(Offset.zero) & box.size;
                  }
                  showHabitContextMenu(
                    context: cardContext,
                    habit: habit,
                    vm: vm,
                    palette: palette,
                    anchor: anchor,
                  );
                },
          onTap: (guideActive || isDemo)
              ? null
              : () => _openDetails(context, habit, vm),
          child: SizedBox(
            key: spotlightKey,
            width: double.infinity,
            child: AnimatedContainer(
              duration: kTasksProgressAnimDuration,
              curve: kTasksProgressAnimCurve,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isCompleted
                      ? doneColor.withValues(alpha: 0.55)
                      : palette.cardBorder,
                  width: isCompleted ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.glassShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _AnimatedHabitPercentRing(
                    percent: weeklyProgress,
                    progressColor: progressColor,
                    backgroundColor: _primarySoft(palette),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? palette.textMuted
                                : palette.textPrimary,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (habit.reminderTime != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: palette.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(habit.reminderTime!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () =>
                        vm.toggleHabitStatus(habit.id ?? 0, vm.selectedDate),
                    child: AnimatedContainer(
                      duration: kTasksProgressAnimDuration,
                      curve: kTasksProgressAnimCurve,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? doneColor : palette.softBg,
                      ),
                      child: AnimatedSwitcher(
                        duration: kTasksProgressAnimDuration,
                        switchInCurve: kTasksProgressAnimCurve,
                        switchOutCurve: kTasksProgressAnimCurve,
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                key: ValueKey('done'),
                                color: Colors.white,
                                size: 24,
                              )
                            : const SizedBox.shrink(key: ValueKey('empty')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDetails(
    BuildContext context,
    Habit habit,
    HabitProgressViewModel vm,
  ) {
    Navigator.of(
      context,
    ).pushNamed(HabitDetailView.routeName, arguments: habit.id).then((_) {
      if (context.mounted) vm.load(silent: true);
    });
  }
}

class _GoalHabitsSection extends StatelessWidget {
  const _GoalHabitsSection({
    super.key,
    required this.title,
    required this.isUndefined,
    required this.expanded,
    required this.palette,
    required this.onToggle,
    required this.habitCards,
  });

  final String title;
  final bool isUndefined;
  final bool expanded;
  final TasksUiPalette palette;
  final VoidCallback onToggle;
  final List<Widget> habitCards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: _primarySoft(palette),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: _kGoalGroupAnimDuration,
                    curve: _kGoalGroupAnimCurve,
                    child: Icon(
                      Icons.expand_more,
                      color: palette.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontStyle: isUndefined
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          duration: _kGoalGroupAnimDuration,
          curve: _kGoalGroupAnimCurve,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SizedBox(height: 8), ...habitCards],
          ),
        ),
      ],
    );
  }
}

class _AnimatedHabitPercentRing extends StatelessWidget {
  const _AnimatedHabitPercentRing({
    required this.percent,
    required this.progressColor,
    required this.backgroundColor,
  });

  final double percent;
  final Color progressColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return CircularPercentIndicator(
      radius: 24,
      lineWidth: 4,
      animation: true,
      animateFromLastPercent: true,
      animateToInitialPercent: false,
      animationDuration: kTasksProgressAnimDuration.inMilliseconds,
      curve: kTasksProgressAnimCurve,
      percent: clamped,
      center: TweenAnimationBuilder<double>(
        duration: kTasksProgressAnimDuration,
        curve: kTasksProgressAnimCurve,
        tween: Tween<double>(end: clamped),
        builder: (context, value, _) {
          return Text(
            '${roundScoreToPercent(value)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          );
        },
      ),
      progressColor: progressColor,
      backgroundColor: backgroundColor,
    );
  }
}
