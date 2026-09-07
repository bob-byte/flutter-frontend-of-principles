import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../core/habit_score.dart';
import '../l10n/app_localizations.dart';
import '../models/frequency_config.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/habit_reminder.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';

class StreakStat {
  StreakStat({required this.start, required this.end, required this.days});

  final DateTime start;
  final DateTime end;
  final int days;
}

class StabilityPoint {
  StabilityPoint({required this.date, required this.percent});

  final DateTime date;
  final double percent;
}

enum CalendarDayTapResult { updated, futureDate, ignored }

/// MAUI [ProgressValue.NextToggled] with skip and question-mark flags off.
HabitStatus nextCalendarStatus(HabitStatus current) {
  if (current == HabitStatus.completed || current == HabitStatus.skipped) {
    return HabitStatus.none;
  }
  return HabitStatus.completed;
}

class HabitDetailViewModel extends ChangeNotifier {
  HabitDetailViewModel({HabitService? habitService, DatabaseService? dbService})
    : _habitService = habitService,
      _dbService = dbService ?? DatabaseService();

  final HabitService? _habitService;
  final DatabaseService _dbService;

  Habit? habit;
  bool isLoading = false;
  int completedDays = 0;
  int longestStreak = 0;
  double completionRate = 0;

  String get percentageLabel => '${roundScoreToPercent(completionRate)}%';
  List<StreakStat> topFiveStreaks = [];
  List<int> weekDayExecution = List.filled(7, 0);
  List<StabilityPoint> stabilitySeries = [];
  Set<DateTime> completedCalendarDays = <DateTime>{};
  Set<DateTime> skippedCalendarDays = <DateTime>{};
  List<HabitRecord> _records = [];

  DateTime currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  void changeMonth(int offset) {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + offset, 1);
    notifyListeners();
  }

  void showPreview(Habit preview) {
    habit = preview;
    isLoading = false;
    final today = DateTime.now();
    completedDays = 12;
    longestStreak = 5;
    completionRate = 0.48;
    topFiveStreaks = [
      StreakStat(
        start: today.subtract(const Duration(days: 20)),
        end: today.subtract(const Duration(days: 16)),
        days: 5,
      ),
      StreakStat(
        start: today.subtract(const Duration(days: 10)),
        end: today.subtract(const Duration(days: 8)),
        days: 3,
      ),
    ];
    weekDayExecution = [2, 3, 1, 4, 2, 1, 0];
    stabilitySeries = List.generate(
      8,
      (i) => StabilityPoint(
        date: today.subtract(Duration(days: 7 - i)),
        percent: 30 + i * 4.0,
      ),
    );
    // Called from HabitDetailView.didChangeDependencies during route push;
    // defer notify so Provider is not marked dirty mid-build.
    _notifySafe();
  }

  Future<void> load({int? localHabitId}) async {
    isLoading = true;
    _notifySafe();
    try {
      if (localHabitId != null) {
        habit = await _dbService.getHabitById(localHabitId);
      } else {
        final habits = await _dbService.getAllHabits();
        habit = habits.isNotEmpty ? habits.first : null;
      }

      if (habit == null) {
        _resetStats();
        return;
      }

      if (habit?.id != null) {
        final records = await _dbService.getAllRecordsForHabit(habit!.id!);
        _computeStats(records);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHabit() async {
    final localId = habit?.id;
    if (localId == null) return false;

    final service = _habitService;
    if (service != null) {
      final deletedRemotely = await service.deleteHabit(localId);
      if (!deletedRemotely) return false;
    }

    await _dbService.deleteHabit(localId);
    habit = null;
    _resetStats();
    notifyListeners();
    return true;
  }

  Future<void> toggleArchived() async {
    final current = habit;
    if (current?.id == null) return;
    final updated = current!.copyWith(isArchived: !current.isArchived);
    await _dbService.updateHabit(updated);
    habit = updated;
    notifyListeners();
    final service = _habitService;
    if (service == null) return;
    service.setArchiveStatus(updated).catchError((Object e) {
      debugPrint('Failed to sync archive: $e');
      return false;
    });
  }

  @visibleForTesting
  void computeStats(List<HabitRecord> progresses) => _computeStats(progresses);

  HabitStatus statusForDay(DateTime date) {
    final day = _dateOnly(date);
    for (final record in _records) {
      if (_dateOnly(record.date) == day) return record.status;
    }
    return HabitStatus.none;
  }

  @visibleForTesting
  CalendarDayTapResult applyCalendarToggle(DateTime date, {DateTime? now}) {
    final habitId = habit?.id;
    if (habitId == null) return CalendarDayTapResult.ignored;

    final day = _dateOnly(date);
    final today = _dateOnly(now ?? DateTime.now());
    if (day.isAfter(today)) return CalendarDayTapResult.futureDate;

    final next = nextCalendarStatus(statusForDay(day));
    _records.removeWhere((record) => _dateOnly(record.date) == day);
    if (next != HabitStatus.none) {
      _records.add(HabitRecord(habitId: habitId, date: day, status: next));
    }
    _computeStats(_records);
    notifyListeners();
    return CalendarDayTapResult.updated;
  }

  Future<CalendarDayTapResult> toggleCalendarDay(DateTime date) async {
    final result = applyCalendarToggle(date);
    if (result != CalendarDayTapResult.updated) return result;

    final habitId = habit!.id!;
    final day = _dateOnly(date);
    final status = statusForDay(day);
    await _dbService.setHabitRecordStatus(habitId, day, status);
    unawaited(
      (_habitService?.pushProgress(habitId, day, status) ?? Future.value(true))
          .catchError((Object e) {
            debugPrint('Failed to sync habit progress: $e');
            return false;
          }),
    );
    return result;
  }

  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _resetStats() {
    completedDays = 0;
    longestStreak = 0;
    completionRate = 0;
    topFiveStreaks = [];
    weekDayExecution = List.filled(7, 0);
    stabilitySeries = [];
    completedCalendarDays = <DateTime>{};
    skippedCalendarDays = <DateTime>{};
    _records = [];
  }

  void _computeStats(List<HabitRecord> progresses) {
    _records = List<HabitRecord>.from(progresses);
    if (progresses.isEmpty) {
      _resetStats();
      return;
    }

    progresses = List<HabitRecord>.from(progresses)
      ..sort((a, b) => a.date.compareTo(b.date));
    final completed = progresses
        .where((p) => p.status == HabitStatus.completed)
        .toList();

    completedDays = completed.length;

    final frequency =
        habit?.frequency ?? const FrequencyConfig(type: FrequencyType.daily);
    final firstDate = _dateOnly(progresses.first.date);
    final today = _dateOnly(DateTime.now());
    completionRate = recomputeHabitPercentageFromRecords(
      records: progresses,
      frequency: frequency,
      complexity: habit?.difficulty ?? 5,
      now: today,
    );

    weekDayExecution = List.filled(7, 0);
    completedCalendarDays = <DateTime>{};
    skippedCalendarDays = <DateTime>{};
    for (final p in progresses) {
      final day = _dateOnly(p.date);
      if (p.status == HabitStatus.completed) {
        completedCalendarDays.add(day);
        weekDayExecution[(day.weekday + 6) % 7] += 1;
      } else if (p.status == HabitStatus.skipped) {
        skippedCalendarDays.add(day);
      }
    }

    final streaks = <StreakStat>[];
    longestStreak = 0;
    var current = 0;
    DateTime? prev;
    DateTime? streakStart;

    var maxGapDays = 1;
    if (frequency.type == FrequencyType.everyXDays) {
      maxGapDays = frequency.interval ?? 1;
    } else if (frequency.type == FrequencyType.timesPerPeriod) {
      final interval = frequency.interval ?? 1;
      final period = frequency.period == PeriodType.month ? 30 : 7;
      maxGapDays = (period / interval).ceil() + 1;
    }

    for (final p in completed) {
      final dt = _dateOnly(p.date);
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

    stabilitySeries = _buildWeeklyStability(
      progresses: progresses,
      frequency: frequency,
      from: firstDate,
      to: today,
    );
  }

  List<StabilityPoint> _buildWeeklyStability({
    required List<HabitRecord> progresses,
    required FrequencyConfig frequency,
    required DateTime from,
    required DateTime to,
  }) {
    final completedByDay = <DateTime>{
      for (final p in progresses)
        if (p.status == HabitStatus.completed) _dateOnly(p.date),
    };

    final points = <StabilityPoint>[];
    var cursor = from.subtract(Duration(days: from.weekday - 1));
    while (!cursor.isAfter(to)) {
      final weekEnd = cursor.add(const Duration(days: 6));
      final rangeStart = cursor.isBefore(from) ? from : cursor;
      final rangeEnd = weekEnd.isAfter(to) ? to : weekEnd;
      final expected = expectedExecutionsInRange(
        rangeStart,
        rangeEnd,
        frequency,
      );
      if (expected > 0) {
        var done = 0;
        var day = rangeStart;
        while (!day.isAfter(rangeEnd)) {
          if (completedByDay.contains(day)) done += 1;
          day = day.add(const Duration(days: 1));
        }
        points.add(
          StabilityPoint(
            date: rangeEnd,
            percent: ((done / expected) * 100).clamp(0.0, 100.0),
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 7));
    }

    return _downsampleStability(points, 24);
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int expectedExecutionsInRange(
  DateTime start,
  DateTime endInclusive,
  FrequencyConfig frequency,
) {
  final from = _dateOnly(start);
  final to = _dateOnly(endInclusive);
  if (to.isBefore(from)) return 0;
  final days = to.difference(from).inDays + 1;
  switch (frequency.type) {
    case FrequencyType.daily:
      return days;
    case FrequencyType.everyXDays:
      final interval = (frequency.interval ?? 1).clamp(1, 365);
      return (days / interval).ceil();
    case FrequencyType.timesPerPeriod:
      final repeats = (frequency.interval ?? 1).clamp(1, 365);
      final period = frequency.period == PeriodType.month ? 30 : 7;
      return (days / period).ceil() * repeats;
  }
}

List<StabilityPoint> _downsampleStability(
  List<StabilityPoint> points,
  int maxPoints,
) {
  if (points.length <= maxPoints) return points;
  final result = <StabilityPoint>[];
  for (var i = 0; i < maxPoints; i++) {
    final index = (i * (points.length - 1) / (maxPoints - 1)).round();
    result.add(points[index]);
  }
  return result;
}

String formatFrequencyLabel(FrequencyConfig frequency, AppLocalizations l10n) {
  switch (frequency.type) {
    case FrequencyType.daily:
      return l10n.frequencyEveryDay;
    case FrequencyType.everyXDays:
      return l10n.frequencyEveryXDays(frequency.interval ?? 1);
    case FrequencyType.timesPerPeriod:
      final period = frequency.period == PeriodType.month
          ? l10n.periodMonth
          : l10n.periodWeek;
      return l10n.frequencyTimesPerPeriod(frequency.interval ?? 1, period);
  }
}

List<String> formatReminderChips(Habit habit, List<String> weekdayLabels) {
  final labels = <String>[];
  for (final reminder in habit.reminders) {
    final label = _formatReminderTimeAndDays(
      reminder.time,
      reminder.daysOfWeek,
      weekdayLabels,
    );
    if (label != null) labels.add(label);
  }
  if (labels.isEmpty && habit.reminderTime != null) {
    labels.add(_formatClock(TimeOfDay.fromDateTime(habit.reminderTime!)));
  }
  return labels;
}

String? formatReminderChip(Habit habit, List<String> weekdayLabels) {
  final labels = formatReminderChips(habit, weekdayLabels);
  if (labels.isEmpty) return null;
  return labels.join(' · ');
}

String _formatClock(TimeOfDay time) {
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String? _formatReminderTimeAndDays(
  TimeOfDay time,
  List<WeekDay> daysOfWeek,
  List<String> weekdayLabels,
) {
  final mondayFirstDays =
      daysOfWeek
          .map((day) => (toDotNetDayOfWeek(day.type) + 6) % 7)
          .toSet()
          .toList()
        ..sort();
  final clock = _formatClock(time);
  if (mondayFirstDays.isEmpty || weekdayLabels.length < 7) {
    return clock;
  }

  final groups = <String>[];
  var rangeStart = mondayFirstDays.first;
  var rangeEnd = rangeStart;
  for (var i = 1; i <= mondayFirstDays.length; i++) {
    final current = i < mondayFirstDays.length ? mondayFirstDays[i] : null;
    if (current == rangeEnd + 1) {
      rangeEnd = current!;
      continue;
    }
    if (rangeStart == rangeEnd) {
      groups.add(weekdayLabels[rangeStart]);
    } else {
      groups.add('${weekdayLabels[rangeStart]}-${weekdayLabels[rangeEnd]}');
    }
    if (current != null) {
      rangeStart = current;
      rangeEnd = current;
    }
  }
  return '$clock ${groups.join(', ')}';
}

String formatStreakRange(StreakStat streak, String locale) {
  final start = DateFormat('d MMM', locale).format(streak.start);
  final end = DateFormat('d MMM yy', locale).format(streak.end);
  return '$start - $end';
}

double niceChartMax(double maxValue) {
  if (maxValue <= 0) return 4;
  if (maxValue <= 4) return 4;
  if (maxValue <= 5) return 5;
  if (maxValue <= 10) return 10;
  if (maxValue <= 20) return 20;
  if (maxValue <= 25) return 25;
  if (maxValue <= 40) return 40;
  if (maxValue <= 50) return 50;
  if (maxValue <= 80) return 80;
  if (maxValue <= 100) return 100;
  final magnitude = math.pow(10, (math.log(maxValue) / math.ln10).floor());
  final normalized = maxValue / magnitude;
  final nice = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return (nice * magnitude).toDouble();
}

double chartInterval(double maxY) {
  if (maxY <= 5) return 1;
  if (maxY <= 20) return 5;
  if (maxY <= 50) return 10;
  if (maxY <= 100) return 20;
  return (maxY / 5).ceilToDouble();
}
