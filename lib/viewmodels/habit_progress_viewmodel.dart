import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/day_change_notifier.dart';
import '../core/habit_score.dart';
import '../core/habit_streak.dart';
import '../core/home_widget/home_calendar_constants.dart';
import '../core/utils/date_helpers.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/progress_value.dart';
import '../models/user_goal.dart';
import '../services/app_open_tracker_service.dart';
import '../services/completion_feedback.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';

/// Goal key + label for the Habits tab filter chips (not list sections).
class HabitGoalFilterOption {
  const HabitGoalFilterOption({required this.key, this.goalName});

  final String key;
  final String? goalName;

  bool get isUndefined => goalName == null || goalName!.trim().isEmpty;
}

const kHabitProgressDateCount = 14;

/// Goal-filter key for habits with no [Habit.targetGoalId] and empty name.
const kUndefinedHabitGoalKey = 'undefined';

enum HabitDayStatusFilter { all, notDone, done }

/// Whether a habit applies on the date-strip selection (`habitAppliesOnDate`).
enum HabitDueFilter { all, due, notDue }

/// How far back streak may scan when there is no last-missed day (not kept in RAM).
const kHabitStreakLookbackDays = 730;

/// Session [HabitProgressViewModel.records] cover the home-widget calendar span.
({DateTime start, DateTime end}) habitSessionRecordRange(DateTime today) {
  final day = dateOnly(today);
  return (
    start: DateTime(
      day.year,
      day.month - HomeCalendarWidgetConfig.monthsBack,
      1,
    ),
    end: DateTime(
      day.year,
      day.month + HomeCalendarWidgetConfig.monthsForward + 1,
      0,
    ),
  );
}

/// Last [count] calendar days ending at [now]'s local today.
List<DateTime> habitProgressDates({
  DateTime? now,
  int count = kHabitProgressDateCount,
}) {
  final today = dateOnly(now ?? DateTime.now());
  return List.generate(
    count,
    (index) => today.subtract(Duration(days: count - 1 - index)),
  );
}

class HabitProgressViewModel extends ChangeNotifier {
  HabitProgressViewModel(
    this._habitService, {
    AppOpenTrackerService? appOpenTracker,
    DatabaseService? dbService,
    DayChangeNotifier? dayChange,
  }) : _appOpenTracker = appOpenTracker ?? AppOpenTrackerService(),
       _dbService = dbService ?? DatabaseService(),
       _dayChange = dayChange {
    final today = dateOnly(DateTime.now());
    selectedDate = today;
    dates = habitProgressDates(now: today);
    _dayChange?.addListener(_onCalendarDayChanged);
  }

  final HabitService _habitService;
  final AppOpenTrackerService _appOpenTracker;
  final DatabaseService _dbService;
  final DayChangeNotifier? _dayChange;
  DateTime? _lastMissedAppOpen;

  bool isLoading = false;

  List<Habit> habits = [];
  List<HabitRecord> records = [];
  final Map<int, double> _percentages = {};

  /// Last [kHabitProgressDateCount] days ending at the observed today.
  List<DateTime> dates = const [];

  late DateTime selectedDate;

  bool filtersVisible = false;
  HabitDayStatusFilter dayStatusFilter = HabitDayStatusFilter.notDone;
  HabitDueFilter dueFilter = HabitDueFilter.due;
  String? selectedGoalFilter;

  final Set<int> _heldCompletedHabitIds = {};
  final Map<int, Timer> _holdCompletedHabitTimers = {};

  void selectDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void _onCalendarDayChanged() {
    refreshForNewDay(now: _dayChange?.today);
  }

  /// MAUI [TryAddNewDayColumn]: roll the date strip to include today.
  ///
  /// If the user was on the previous tip day ("today"), follow the new today.
  /// Explicit older selections stay put.
  void refreshForNewDay({DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final previousTip = dates.isEmpty ? selectedDate : dates.last;
    final wasOnTip = isSameDay(selectedDate, previousTip);

    dates = habitProgressDates(now: today);
    if (wasOnTip || isSameDay(selectedDate, today)) {
      selectedDate = today;
    }

    _recomputePercentages();
    notifyListeners();
    // Widen/shift the SQLite window when the month rolls; ignore closed-DB tests.
    unawaited(_softReloadSessionRecords(today));
  }

  Future<void> _softReloadSessionRecords(DateTime today) async {
    try {
      records = await _loadSessionRecords(now: today);
      _recomputePercentages();
      await _refreshStreak();
      notifyListeners();
    } catch (_) {
      // Keep the in-memory strip if SQLite is unavailable.
    }
  }

  Future<List<HabitRecord>> _loadSessionRecords({DateTime? now}) {
    final range = habitSessionRecordRange(now ?? DateTime.now());
    return _dbService.getRecordsForDateRange(range.start, range.end);
  }

  Future<void> _refreshStreak({bool preferSessionRecords = false}) async {
    if (preferSessionRecords) {
      currentStreak = calculateUserHabitsStreak(
        habitIds: [
          for (final habit in habits)
            if (habit.id != null) habit.id!,
        ],
        records: records,
        lastMissedAppOpen: _lastMissedAppOpen,
      );
      return;
    }
    try {
      final today = dateOnly(DateTime.now());
      final afterMissed = _lastMissedAppOpen == null
          ? null
          : dateOnly(_lastMissedAppOpen!).add(const Duration(days: 1));
      final streakStart =
          afterMissed ??
          today.subtract(const Duration(days: kHabitStreakLookbackDays));
      // Temporary list for streak only — not assigned to [records].
      final streakRecords = await _dbService.getRecordsForDateRange(
        streakStart.isAfter(today) ? today : streakStart,
        today,
      );
      currentStreak = calculateUserHabitsStreak(
        habitIds: [
          for (final habit in habits)
            if (habit.id != null) habit.id!,
        ],
        records: streakRecords,
        lastMissedAppOpen: _lastMissedAppOpen,
        now: today,
      );
    } catch (_) {
      // Fall back to the session window already in RAM.
      currentStreak = calculateUserHabitsStreak(
        habitIds: [
          for (final habit in habits)
            if (habit.id != null) habit.id!,
        ],
        records: records,
        lastMissedAppOpen: _lastMissedAppOpen,
      );
    }
  }

  @override
  void dispose() {
    _dayChange?.removeListener(_onCalendarDayChanged);
    _cancelCompletionHolds();
    super.dispose();
  }

  void toggleFiltersVisible() {
    filtersVisible = !filtersVisible;
    notifyListeners();
  }

  void setDayStatusFilter(HabitDayStatusFilter status) {
    dayStatusFilter = status;
    notifyListeners();
  }

  void setDueFilter(HabitDueFilter due) {
    dueFilter = due;
    notifyListeners();
  }

  void setGoalFilter(String? key) {
    selectedGoalFilter = key;
    notifyListeners();
  }

  void clearFilters() {
    dayStatusFilter = HabitDayStatusFilter.notDone;
    dueFilter = HabitDueFilter.due;
    selectedGoalFilter = null;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      dayStatusFilter != HabitDayStatusFilter.notDone ||
      dueFilter != HabitDueFilter.due ||
      selectedGoalFilter != null;

  bool isHeldCompletedHabit(int habitId) =>
      _heldCompletedHabitIds.contains(habitId);

  void _holdCompletedHabit(int habitId) {
    _holdCompletedHabitTimers[habitId]?.cancel();
    _heldCompletedHabitIds.add(habitId);
    _holdCompletedHabitTimers[habitId] = Timer(
      kCompletionCelebrationDuration,
      () {
        _heldCompletedHabitIds.remove(habitId);
        _holdCompletedHabitTimers.remove(habitId);
        notifyListeners();
      },
    );
  }

  void _releaseCompletedHabit(int habitId) {
    _holdCompletedHabitTimers.remove(habitId)?.cancel();
    _heldCompletedHabitIds.remove(habitId);
  }

  void _cancelCompletionHolds() {
    for (final timer in _holdCompletedHabitTimers.values) {
      timer.cancel();
    }
    _holdCompletedHabitTimers.clear();
    _heldCompletedHabitIds.clear();
  }

  int currentStreak = 0;

  Future<void>? _loadInFlight;

  Future<void> load({bool silent = false, bool syncRemote = false}) async {
    final existing = _loadInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final run = _loadBody(silent: silent, syncRemote: syncRemote);
    _loadInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_loadInFlight, run)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _loadBody({
    required bool silent,
    required bool syncRemote,
  }) async {
    if (!silent && habits.isEmpty) {
      isLoading = true;
      notifyListeners();
    }

    try {
      _lastMissedAppOpen = await _appOpenTracker.getLastMissedDate();

      // Session RAM: widget + strip window only (not full habit_records).
      habits = await _dbService.getAllHabits(isArchived: false);
      records = await _loadSessionRecords();
      _recomputePercentages();
      await _refreshStreak();

      // Якщо в нас вже є локальні дані, відключаємо індикатор загрузки
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }

      if (!syncRemote) {
        return;
      }

      // 2. Фонова синхронізація з бекендом
      await _habitService.syncFromBackend();

      // 3. Оновлюємо дані після фонової синхронізації
      habits = await _dbService.getAllHabits(isArchived: false);
      records = await _loadSessionRecords();
      _recomputePercentages();
      await _refreshStreak();
    } finally {
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
      // Обов'язково сповіщаємо UI про можливі нові дані з фонової синхронізації
      notifyListeners();
    }
  }

  void clear() {
    habits = [];
    records = [];
    _percentages.clear();
    currentStreak = 0;
    _lastMissedAppOpen = null;
    filtersVisible = false;
    dayStatusFilter = HabitDayStatusFilter.notDone;
    dueFilter = HabitDueFilter.due;
    selectedGoalFilter = null;
    _cancelCompletionHolds();
    isLoading = false;
    notifyListeners();
  }

  /// Habits-tab banner numerator — manual completes only (`YES_MANUAL`).
  int get completedHabitsCount =>
      countManuallyCompletedHabitsOn(habits, records, selectedDate);

  int get totalHabitsCount => countHabitsOn(habits, records, selectedDate);

  /// Unique goal keys among current habits, for filter chips only.
  List<HabitGoalFilterOption> get goalFilterOptions =>
      habitGoalFilterOptions(habits);

  List<Habit> get filteredHabits {
    final result = habits.where(_matchesFilters).toList();
    sortHabitsByNameAndReminder(result);
    return result;
  }

  bool _matchesFilters(Habit habit) {
    final id = habit.id;
    if (id == null) return false;
    return habitMatchesProgressFilters(
      habit: habit,
      dayStatus: dayStatusFilter,
      due: dueFilter,
      goalKey: selectedGoalFilter,
      status: getStatusForHabitAndDate(id, selectedDate),
      appliesOnSelectedDay: habitAppliesOnDate(
        frequency: habit.frequency,
        records: _recordsForHabit(records, id),
        date: selectedDate,
      ),
      keepVisible: isHeldCompletedHabit(id),
    );
  }

  double getPercentageAchieved(Habit habit) {
    final id = habit.id;
    if (id == null) return 0;
    return _percentages[id] ?? 0;
  }

  String percentageLabel(Habit habit) =>
      '${roundScoreToPercent(getPercentageAchieved(habit))}%';

  void _recomputePercentages({int? habitId}) {
    final today = dateOnly(DateTime.now());
    final targets = habitId == null
        ? habits
        : habits.where((h) => h.id == habitId);

    for (final habit in targets) {
      final id = habit.id;
      if (id == null) continue;
      _percentages[id] = recomputeHabitPercentageFromRecords(
        records: records.where((r) => r.habitId == id).toList(),
        frequency: habit.frequency,
        complexity: habit.difficulty,
        now: today,
      );
    }
  }

  int progressValueForHabitAndDate(int habitId, DateTime date) {
    final habit = habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return kProgressUnknown;
    return habitProgressValueOnDate(
      frequency: habit.frequency,
      records: records.where((r) => r.habitId == habitId),
      date: date,
    );
  }

  HabitStatus getStatusForHabitAndDate(int habitId, DateTime date) {
    return habitStatusFromProgressValue(
      progressValueForHabitAndDate(habitId, date),
    );
  }

  bool isHabitAutoCompleted(int habitId, DateTime date) {
    return progressValueForHabitAndDate(habitId, date) == kProgressYesAuto;
  }

  int completedHabitsOn(DateTime date) =>
      countCompletedHabitsOn(habits, records, date);

  /// Share of habits marked completed on [date], from 0 to 1.
  double completionRatioOn(DateTime date) => habitDayCompletionRatio(
    completedHabitsOn(date),
    countHabitsOn(habits, records, date),
  );

  /// Habits-tab checkbox — MAUI [ProgressValue.NextToggled] (skip / ? off).
  ///
  /// `completed → none → completed` (not via skipped). Auto-fill first becomes
  /// a manual complete, then clears on the next tap.
  Future<void> toggleHabitStatus(int habitId, DateTime date) async {
    final value = progressValueForHabitAndDate(habitId, date);

    final HabitStatus nextStatus;
    if (value == kProgressYesAuto) {
      nextStatus = HabitStatus.completed;
    } else if (value == kProgressYesManual || value == kProgressSkip) {
      nextStatus = HabitStatus.none;
    } else {
      nextStatus = HabitStatus.completed;
    }

    if (nextStatus == HabitStatus.completed &&
        dayStatusFilter == HabitDayStatusFilter.notDone) {
      _holdCompletedHabit(habitId);
    } else {
      _releaseCompletedHabit(habitId);
    }

    await _applyHabitStatus(habitId, date, nextStatus);
  }

  /// Task-list checkbox: done ↔ not done. Returns false for future days.
  Future<bool> toggleHabitCompleted(
    int habitId,
    DateTime date, {
    DateTime? now,
  }) async {
    final day = dateOnly(date);
    final today = dateOnly(now ?? DateTime.now());
    if (day.isAfter(today)) return false;

    final value = progressValueForHabitAndDate(habitId, day);
    final HabitStatus next;
    if (value == kProgressYesAuto) {
      // Auto-fill cannot be cleared by deleting a row; skip overrides it.
      next = HabitStatus.skipped;
    } else if (value == kProgressYesManual) {
      next = HabitStatus.none;
    } else {
      next = HabitStatus.completed;
    }
    await _applyHabitStatus(habitId, day, next);
    return true;
  }

  Future<void> _applyHabitStatus(
    int habitId,
    DateTime date,
    HabitStatus nextStatus,
  ) async {
    final day = dateOnly(date);
    final dateString = day.toIso8601String().substring(0, 10);

    records.removeWhere(
      (r) =>
          r.habitId == habitId &&
          r.date.toIso8601String().substring(0, 10) == dateString,
    );

    if (nextStatus != HabitStatus.none) {
      records.add(HabitRecord(habitId: habitId, date: day, status: nextStatus));
    }

    _recomputePercentages(habitId: habitId);
    unawaited(_refreshStreak(preferSessionRecords: true));
    notifyListeners();

    await _dbService.setHabitRecordStatus(habitId, day, nextStatus);
    unawaited(
      _habitService.pushProgress(habitId, day, nextStatus).catchError((
        Object e,
      ) {
        debugPrint('Failed to sync habit progress: $e');
        return false;
      }),
    );
  }

  Future<void> archiveHabit(Habit habit) async {
    final updatedHabit = habit.copyWith(isArchived: true);
    await _dbService.updateHabit(updatedHabit);
    habits.removeWhere((h) => h.id == habit.id);
    if (habit.id != null) {
      _percentages.remove(habit.id);
    }
    unawaited(_refreshStreak(preferSessionRecords: true));
    notifyListeners();

    try {
      final synced = await _habitService.setArchiveStatus(updatedHabit);
      if (!synced) {
        debugPrint('Failed to sync archive');
      }
    } catch (e) {
      debugPrint('Failed to sync archive: $e');
    }
  }

  Future<bool> deleteHabit(Habit habit) async {
    final habitId = habit.id;
    if (habitId == null) return false;

    final serverId = confirmedServerHabitId(habit);
    await _dbService.deleteHabit(habitId);
    habits.removeWhere((h) => h.id == habitId);
    _percentages.remove(habitId);
    unawaited(_refreshStreak(preferSessionRecords: true));
    notifyListeners();

    unawaited(
      _habitService.deleteHabit(habitId, serverId: serverId).catchError((
        Object e,
      ) {
        debugPrint('Failed to sync habit delete: $e');
        return false;
      }),
    );
    return true;
  }
}

Iterable<HabitRecord> _recordsForHabit(List<HabitRecord> records, int habitId) {
  return records.where((record) => record.habitId == habitId);
}

String habitGoalGroupKey(Habit habit) {
  final name = habit.targetGoal.trim();
  final isUndefined = habit.targetGoalId == null && name.isEmpty;
  if (isUndefined) return kUndefinedHabitGoalKey;
  if (habit.targetGoalId != null) return 'id:${habit.targetGoalId}';
  return 'name:${name.toLowerCase()}';
}

bool habitMatchesProgressFilters({
  required Habit habit,
  required HabitDayStatusFilter dayStatus,
  required HabitDueFilter due,
  required String? goalKey,
  required HabitStatus status,
  required bool appliesOnSelectedDay,
  bool keepVisible = false,
}) {
  final matchesDue = switch (due) {
    HabitDueFilter.all => true,
    HabitDueFilter.due => appliesOnSelectedDay,
    HabitDueFilter.notDue => !appliesOnSelectedDay,
  };
  if (!matchesDue) return false;
  if (goalKey != null && habitGoalGroupKey(habit) != goalKey) return false;
  return switch (dayStatus) {
    HabitDayStatusFilter.all => true,
    HabitDayStatusFilter.notDone => status == HabitStatus.none || keepVisible,
    HabitDayStatusFilter.done => status == HabitStatus.completed,
  };
}

int countHabitsOn(
  List<Habit> habits,
  List<HabitRecord> records,
  DateTime date,
) {
  var count = 0;
  for (final habit in habits) {
    final id = habit.id;
    if (id == null) continue;
    if (habitAppliesOnDate(
      frequency: habit.frequency,
      records: _recordsForHabit(records, id),
      date: date,
    )) {
      count++;
    }
  }
  return count;
}

int countCompletedHabitsOn(
  List<Habit> habits,
  List<HabitRecord> records,
  DateTime date,
) {
  var count = 0;
  for (final habit in habits) {
    final id = habit.id;
    if (id == null) continue;
    if (isHabitSatisfiedOnDate(
      frequency: habit.frequency,
      records: _recordsForHabit(records, id),
      date: date,
    )) {
      count++;
    }
  }
  return count;
}

/// Banner-style day total: only explicit user completes (`YES_MANUAL`).
int countManuallyCompletedHabitsOn(
  List<Habit> habits,
  List<HabitRecord> records,
  DateTime date,
) {
  var count = 0;
  for (final habit in habits) {
    final id = habit.id;
    if (id == null) continue;
    if (habitProgressValueOnDate(
          frequency: habit.frequency,
          records: _recordsForHabit(records, id),
          date: date,
        ) ==
        kProgressYesManual) {
      count++;
    }
  }
  return count;
}

double habitDayCompletionRatio(int completed, int total) {
  if (total <= 0) return 0;
  return (completed / total).clamp(0.0, 1.0);
}

bool habitBelongsToGoal(Habit habit, UserGoal goal) {
  if (goal.id != null &&
      habit.targetGoalId != null &&
      habit.targetGoalId == goal.id) {
    return true;
  }
  final goalName = goal.name.trim();
  if (goalName.isEmpty) return false;
  return habit.targetGoal.trim().toLowerCase() == goalName.toLowerCase();
}

List<Habit> habitsForGoal(List<Habit> habits, UserGoal goal) {
  final result = habits
      .where((habit) => habitBelongsToGoal(habit, goal))
      .toList();
  sortHabitsByNameAndReminder(result);
  return result;
}

List<Habit> habitsUnassignedToGoals(List<Habit> habits, List<UserGoal> goals) {
  final result = habits
      .where((habit) => !goals.any((goal) => habitBelongsToGoal(habit, goal)))
      .toList();
  sortHabitsByNameAndReminder(result);
  return result;
}

void sortHabitsByNameAndReminder(List<Habit> habits) {
  habits.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    if (a.reminderTime == null && b.reminderTime == null) return 0;
    if (a.reminderTime == null) return 1;
    if (b.reminderTime == null) return -1;
    return a.reminderTime!.compareTo(b.reminderTime!);
  });
}

List<HabitGoalFilterOption> habitGoalFilterOptions(List<Habit> habits) {
  final names = <String, String?>{};

  for (final habit in habits) {
    final name = habit.targetGoal.trim();
    final isUndefined = habit.targetGoalId == null && name.isEmpty;
    final key = habitGoalGroupKey(habit);
    final existingName = names[key];
    if (existingName == null || existingName.isEmpty) {
      names[key] = isUndefined ? null : name;
    }
  }

  final options = names.entries
      .map(
        (entry) => HabitGoalFilterOption(key: entry.key, goalName: entry.value),
      )
      .toList();

  options.sort((a, b) {
    if (a.isUndefined && !b.isUndefined) return -1;
    if (!a.isUndefined && b.isUndefined) return 1;
    return (a.goalName ?? '').toLowerCase().compareTo(
      (b.goalName ?? '').toLowerCase(),
    );
  });

  return options;
}
