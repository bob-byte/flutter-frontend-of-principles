import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/habit_score.dart';
import '../core/habit_streak.dart';
import '../core/utils/date_helpers.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/user_goal.dart';
import '../services/app_open_tracker_service.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';

class HabitGoalGroup {
  const HabitGoalGroup({
    required this.key,
    required this.habits,
    this.goalName,
  });

  final String key;
  final String? goalName;
  final List<Habit> habits;

  bool get isUndefined => goalName == null || goalName!.trim().isEmpty;
}

class HabitProgressViewModel extends ChangeNotifier {
  HabitProgressViewModel(
    this._habitService, {
    AppOpenTrackerService? appOpenTracker,
    DatabaseService? dbService,
  }) : _appOpenTracker = appOpenTracker ?? AppOpenTrackerService(),
       _dbService = dbService ?? DatabaseService() {
    selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  final HabitService _habitService;
  final AppOpenTrackerService _appOpenTracker;
  final DatabaseService _dbService;
  DateTime? _lastMissedAppOpen;

  bool isLoading = false;

  List<Habit> habits = [];
  List<HabitRecord> records = [];
  final Map<int, double> _percentages = {};

  // генеруємо останні 14 днів для відображення
  List<DateTime> dates = List.generate(
    14,
    (index) => DateTime.now().subtract(Duration(days: 13 - index)),
  );

  late DateTime selectedDate;

  final Set<String> _collapsedGoalKeys = {};

  void selectDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  bool isGoalGroupExpanded(String key) => !_collapsedGoalKeys.contains(key);

  void toggleGoalGroup(String key) {
    if (_collapsedGoalKeys.contains(key)) {
      _collapsedGoalKeys.remove(key);
    } else {
      _collapsedGoalKeys.add(key);
    }
    notifyListeners();
  }

  int currentStreak = 0;

  Future<void> load({bool silent = false, bool syncRemote = true}) async {
    if (!silent && habits.isEmpty) {
      isLoading = true;
      notifyListeners();
    }

    try {
      _lastMissedAppOpen = await _appOpenTracker.getLastMissedDate();

      // 1. Одразу завантажуємо локальні дані
      habits = await _dbService.getAllHabits(isArchived: false);
      records = await _dbService.getAllRecords();
      _recomputePercentages();
      _calculateStreak();

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
      records = await _dbService.getAllRecords();
      _recomputePercentages();
      _calculateStreak();
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
    _collapsedGoalKeys.clear();
    isLoading = false;
    notifyListeners();
  }

  void _calculateStreak() {
    currentStreak = calculateUserHabitsStreak(
      habitIds: [
        for (final habit in habits)
          if (habit.id != null) habit.id!,
      ],
      records: records,
      lastMissedAppOpen: _lastMissedAppOpen,
    );
  }

  int get completedHabitsCount {
    int count = 0;
    for (var habit in habits) {
      if (getStatusForHabitAndDate(habit.id ?? 0, selectedDate) ==
          HabitStatus.completed) {
        count++;
      }
    }
    return count;
  }

  int get totalHabitsCount {
    return habits
        .length; // TODO: filter by habits that are scheduled for selectedDate
  }

  List<HabitGoalGroup> get groupedHabits => groupHabitsByGoal(habits);

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

  HabitStatus getStatusForHabitAndDate(int habitId, DateTime date) {
    final dateString = date.toIso8601String().substring(0, 10);
    final record = records
        .where(
          (r) =>
              r.habitId == habitId &&
              r.date.toIso8601String().substring(0, 10) == dateString,
        )
        .firstOrNull;

    return record?.status ?? HabitStatus.none;
  }

  int completedHabitsOn(DateTime date) =>
      countCompletedHabitsOn(habits, records, date);

  /// Share of habits marked completed on [date], from 0 to 1.
  double completionRatioOn(DateTime date) =>
      habitDayCompletionRatio(completedHabitsOn(date), totalHabitsCount);

  Future<void> toggleHabitStatus(int habitId, DateTime date) async {
    final currentStatus = getStatusForHabitAndDate(habitId, date);

    final HabitStatus nextStatus;
    if (currentStatus == HabitStatus.none) {
      nextStatus = HabitStatus.completed;
    } else if (currentStatus == HabitStatus.completed) {
      nextStatus = HabitStatus.skipped;
    } else {
      nextStatus = HabitStatus.none;
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

    final current = getStatusForHabitAndDate(habitId, day);
    final next = current == HabitStatus.completed
        ? HabitStatus.none
        : HabitStatus.completed;
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
    _calculateStreak();
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
    _calculateStreak();
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

    await _dbService.deleteHabit(habitId);
    habits.removeWhere((h) => h.id == habitId);
    _percentages.remove(habitId);
    _calculateStreak();
    notifyListeners();

    unawaited(
      _habitService.deleteHabit(habitId).catchError((Object e) {
        debugPrint('Failed to sync habit delete: $e');
        return false;
      }),
    );
    return true;
  }
}

int countCompletedHabitsOn(
  List<Habit> habits,
  List<HabitRecord> records,
  DateTime date,
) {
  final dateString = dateOnly(date).toIso8601String().substring(0, 10);
  var count = 0;
  for (final habit in habits) {
    final id = habit.id;
    if (id == null) continue;
    final completed = records.any(
      (r) =>
          r.habitId == id &&
          r.date.toIso8601String().substring(0, 10) == dateString &&
          r.status == HabitStatus.completed,
    );
    if (completed) count++;
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
  _sortHabitsInGoal(result);
  return result;
}

List<Habit> habitsUnassignedToGoals(List<Habit> habits, List<UserGoal> goals) {
  final result = habits
      .where((habit) => !goals.any((goal) => habitBelongsToGoal(habit, goal)))
      .toList();
  _sortHabitsInGoal(result);
  return result;
}

void _sortHabitsInGoal(List<Habit> habits) {
  habits.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    if (a.reminderTime == null && b.reminderTime == null) return 0;
    if (a.reminderTime == null) return 1;
    if (b.reminderTime == null) return -1;
    return a.reminderTime!.compareTo(b.reminderTime!);
  });
}

List<HabitGoalGroup> groupHabitsByGoal(List<Habit> habits) {
  final buckets = <String, List<Habit>>{};
  final names = <String, String?>{};

  for (final habit in habits) {
    final name = habit.targetGoal.trim();
    final isUndefined = habit.targetGoalId == null && name.isEmpty;
    final key = isUndefined
        ? 'undefined'
        : (habit.targetGoalId != null
              ? 'id:${habit.targetGoalId}'
              : 'name:${name.toLowerCase()}');

    buckets.putIfAbsent(key, () => []).add(habit);
    final existingName = names[key];
    if (existingName == null || existingName.isEmpty) {
      names[key] = isUndefined ? null : name;
    }
  }

  final groups = buckets.entries.map((entry) {
    final groupHabits = List<Habit>.from(entry.value);
    _sortHabitsInGoal(groupHabits);
    return HabitGoalGroup(
      key: entry.key,
      goalName: names[entry.key],
      habits: groupHabits,
    );
  }).toList();

  groups.sort((a, b) {
    if (a.isUndefined && !b.isUndefined) return -1;
    if (!a.isUndefined && b.isUndefined) return 1;
    return (a.goalName ?? '').toLowerCase().compareTo(
      (b.goalName ?? '').toLowerCase(),
    );
  });

  return groups;
}
