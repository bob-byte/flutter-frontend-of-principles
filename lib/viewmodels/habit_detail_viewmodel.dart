import 'package:flutter/foundation.dart';

import '../models/progress_of_habit.dart';
import '../models/user_habit.dart';
import '../services/habit_service.dart';
import '../services/progress_service.dart';

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
  HabitDetailViewModel({
    required HabitService habitService,
    required ProgressService progressService,
  })  : _habitService = habitService,
        _progressService = progressService;

  final HabitService _habitService;
  final ProgressService _progressService;

  UserHabit? habit;
  bool isLoading = false;
  int completedDays = 0;
  int longestStreak = 0;
  double completionRate = 0;
  List<StreakStat> topFiveStreaks = [];
  List<int> weekDayExecution = List.filled(7, 0);
  List<double> stabilitySeries = [];
  Set<DateTime> completedCalendarDays = <DateTime>{};

  Future<void> load({int? localHabitId}) async {
    isLoading = true;
    notifyListeners();
    try {
      final habits = await _habitService.getHabits();
      if (habits.isEmpty) {
        habit = null;
        _resetStats();
        return;
      }

      if (localHabitId != null) {
        final matching = habits.where((h) => h.localId == localHabitId);
        habit = matching.isNotEmpty ? matching.first : null;
      }
      habit ??= habits.first;

      final progresses = await _progressService.getProgresses();
      final localId = habit!.localId;
      final filtered = progresses
          .where((p) => localId != null && p.userHabitLocalId == localId)
          .toList();

      _computeStats(filtered);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteHabit() async {
    final localId = habit?.localId;
    if (localId == null) return;
    await _habitService.deleteHabit(localId);
    habit = null;
    _resetStats();
    notifyListeners();
  }

  Future<void> toggleArchived() async {
    final localId = habit?.localId;
    if (localId == null || habit == null) return;
    await _habitService.setArchived(localId: localId, archived: !habit!.isArchived);
    habit = await _habitService.getHabitByLocalId(localId);
    notifyListeners();
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

  void _computeStats(List<ProgressOfHabit> progresses) {
    if (progresses.isEmpty) {
      _resetStats();
      return;
    }

    progresses.sort((a, b) => a.dateAsInt.compareTo(b.dateAsInt));
    final completed = progresses.where((p) => p.value > 0).toList();

    completedDays = completed.length;
    completionRate = progresses.isEmpty ? 0 : completed.length / progresses.length;
    completionRate = completionRate.clamp(0, 1);

    weekDayExecution = List.filled(7, 0);
    completedCalendarDays = <DateTime>{};
    for (final p in completed) {
      final dt = _fromEpochDays(p.dateAsInt);
      completedCalendarDays.add(DateTime(dt.year, dt.month, dt.day));
      final mondayFirstIndex = (dt.weekday + 6) % 7;
      weekDayExecution[mondayFirstIndex] += 1;
    }

    final streaks = <StreakStat>[];
    longestStreak = 0;
    int current = 0;
    DateTime? prev;
    DateTime? streakStart;

    for (final p in completed) {
      final dt = _fromEpochDays(p.dateAsInt);
      if (prev == null || dt.difference(prev).inDays == 1) {
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
      if (p.value > 0) rollingDone += 1;
      stabilitySeries.add((rollingDone / rollingAll) * 100);
    }
  }

  DateTime _fromEpochDays(int epochDays) {
    final ms = epochDays * Duration.millisecondsPerDay;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
