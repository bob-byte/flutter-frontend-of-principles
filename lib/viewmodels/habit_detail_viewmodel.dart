import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/frequency_config.dart';
import '../services/database_service.dart';

class StreakStat {
  StreakStat({
    required this.start,
    required this.end,
    required this.days,
  });

  final DateTime start;
  final DateTime end;
  final int days;
}

class HabitDetailViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  Habit? habit;
  bool isLoading = false;
  int completedDays = 0;
  int longestStreak = 0;
  double completionRate = 0;
  List<StreakStat> topFiveStreaks = [];
  List<int> weekDayExecution = List.filled(7, 0);
  List<double> stabilitySeries = [];
  Set<DateTime> completedCalendarDays = <DateTime>{};
  
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void changeMonth(int offset) {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + offset, 1);
    notifyListeners();
  }

  Future<void> load({int? localHabitId}) async {
    try {
      final habits = await _dbService.getAllHabits();
      if (habits.isEmpty) {
        habit = null;
        _resetStats();
        return;
      }

      if (localHabitId != null) {
        final matching = habits.where((h) => h.id == localHabitId);
        habit = matching.isNotEmpty ? matching.first : null;
      }
      habit ??= habits.first;

      if (habit?.id != null) {
        final records = await _dbService.getAllRecordsForHabit(habit!.id!);
        _computeStats(records);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteHabit() async {
    final localId = habit?.id;
    if (localId == null) return;
    await _dbService.deleteHabit(localId);
    habit = null;
    _resetStats();
    notifyListeners();
  }

  Future<void> toggleArchived() async {
    // TODO: add isArchived field if needed, for now just no-op
  }

  void _resetStats() {
    completedDays = 0;
    longestStreak = 0;
    completionRate = 0;
    topFiveStreaks = [];
    weekDayExecution = List.filled(7, 0);
    stabilitySeries = [];
    completedCalendarDays = <DateTime>{};
  }

  void _computeStats(List<HabitRecord> progresses) {
    if (progresses.isEmpty) {
      _resetStats();
      return;
    }

    progresses.sort((a, b) => a.date.compareTo(b.date));
    final completed = progresses.where((p) => p.status == HabitStatus.completed).toList();

    completedDays = completed.length;
    
    // Calculate expected executions
    int expected = 1;
    if (progresses.isNotEmpty) {
      final firstDate = progresses.first.date;
      final now = DateTime.now();
      final firstDay = DateTime(firstDate.year, firstDate.month, firstDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final daysDiff = today.difference(firstDay).inDays + 1; // +1 to include first day
      
      if (habit?.frequency.type == FrequencyType.everyXDays) {
        final interval = habit?.frequency.interval ?? 1;
        expected = (daysDiff / interval).ceil();
      } else if (habit?.frequency.type == FrequencyType.timesPerPeriod) {
        final interval = habit?.frequency.interval ?? 1;
        final period = habit?.frequency.period == PeriodType.month ? 30 : 7;
        expected = (daysDiff / period).ceil() * interval;
      } else {
        expected = daysDiff;
      }
    }
    
    if (expected < completed.length) expected = completed.length;
    if (expected <= 0) expected = 1;
    
    completionRate = progresses.isEmpty ? 0 : completed.length / expected;
    completionRate = completionRate.clamp(0.0, 1.0);

    weekDayExecution = List.filled(7, 0);
    completedCalendarDays = <DateTime>{};
    for (final p in completed) {
      final dt = p.date;
      completedCalendarDays.add(DateTime(dt.year, dt.month, dt.day));
      final mondayFirstIndex = (dt.weekday + 6) % 7;
      weekDayExecution[mondayFirstIndex] += 1;
    }

    final streaks = <StreakStat>[];
    longestStreak = 0;
    int current = 0;
    DateTime? prev;
    DateTime? streakStart;

    int maxGapDays = 1;
    if (habit?.frequency.type == FrequencyType.everyXDays) {
      maxGapDays = habit?.frequency.interval ?? 1;
    } else if (habit?.frequency.type == FrequencyType.timesPerPeriod) {
      final interval = habit?.frequency.interval ?? 1;
      final period = habit?.frequency.period == PeriodType.month ? 30 : 7;
      maxGapDays = (period / interval).ceil() + 1;
    }

    for (final p in completed) {
      final dt = p.date;
      if (prev == null || dt.difference(prev).inDays <= maxGapDays) {
        streakStart ??= dt;
        current += 1;
      } else {
        if (streakStart != null) {
          streaks.add(StreakStat(start: streakStart, end: prev, days: current));
        }
        streakStart = dt;
        current = 1;
      }
      prev = dt;
      if (current > longestStreak) longestStreak = current;
    }
    if (streakStart != null && prev != null) {
      streaks.add(StreakStat(start: streakStart, end: prev, days: current));
    }

    streaks.sort((a, b) => b.days.compareTo(a.days));
    topFiveStreaks = streaks.take(5).toList();

    var rollingDone = 0;
    var rollingAll = 0;
    stabilitySeries = [];
    for (final p in progresses.reversed.take(30).toList().reversed) {
      rollingAll += 1;
      if (p.status == HabitStatus.completed) rollingDone += 1;
      stabilitySeries.add((rollingDone / rollingAll) * 100);
    }
  }
}
