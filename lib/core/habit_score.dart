import 'dart:math' as math;

import '../models/frequency_config.dart';
import '../models/habit_record.dart';
import '../models/progress_value.dart';
import 'utils/date_helpers.dart';

/// One day's known progress used to recompute MAUI [PercentageAchieved].
class HabitProgressMark {
  const HabitProgressMark({required this.date, required this.value});

  final DateTime date;
  final int value;
}

/// .NET [Score.Compute] exponential smoothing.
double computeHabitScore({
  required double frequency,
  required double previousScore,
  required double checkmarkValue,
  required int complexity,
}) {
  final coefOfComplexity = _complexityCoefficient(complexity);
  const exponentialSmoothingFactor = 0.5;
  const scalingFactor = 13.0;
  final decayFactor = math
      .pow(
        exponentialSmoothingFactor,
        math.sqrt(frequency) * coefOfComplexity / scalingFactor,
      )
      .toDouble();
  return previousScore * decayFactor + checkmarkValue * (1 - decayFactor);
}

/// .NET [Score.Round] with MidpointRounding.ToEven.
int roundScoreToPercent(double score) {
  final scaled = score * 100.0;
  final floor = scaled.floor();
  final fraction = scaled - floor;
  if (fraction > 0.5) return floor + 1;
  if (fraction < 0.5) return floor;
  return floor.isEven ? floor : floor + 1;
}

/// MAUI [ServiceOfHabit.RecomputedScoreAchieved] for boolean habits.
///
/// Returns 0.0–1.0, matching [UserHabit.PercentageAchieved].
double recomputeHabitPercentage({
  required List<HabitProgressMark> marks,
  required FrequencyConfig frequency,
  required int complexity,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final range = _scoreDateRange(marks, today);
  final from = range.from;
  final to = range.to;

  final known =
      marks
          .where((m) => m.value == kProgressYesManual || m.value == kProgressNo)
          .map((m) => HabitProgressMark(date: dateOnly(m.date), value: m.value))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final computed = _recomputeFrom(known, frequency);
  return _scoreListValue(
    complexity: complexity,
    frequency: frequency,
    computed: computed,
    from: from,
    to: to,
  );
}

double recomputeHabitPercentageFromRecords({
  required List<HabitRecord> records,
  required FrequencyConfig frequency,
  required int complexity,
  DateTime? now,
}) {
  return recomputeHabitPercentage(
    marks: [
      for (final record in records)
        HabitProgressMark(date: record.date, value: record.value),
    ],
    frequency: frequency,
    complexity: complexity,
    now: now,
  );
}

/// MAUI [ListOfProgressOfHabit.RecomputeFrom] for boolean habits.
///
/// [marks] should be stored days (manual / no / skip). Intervals are built
/// from `YES_MANUAL` only, matching [ServiceOfHabit.RecomputedScoreAchieved].
List<HabitProgressMark> computeHabitProgress({
  required List<HabitProgressMark> marks,
  required FrequencyConfig frequency,
}) {
  final known =
      marks
          .where((m) => m.value == kProgressYesManual || m.value == kProgressNo)
          .map((m) => HabitProgressMark(date: dateOnly(m.date), value: m.value))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  return _recomputeFrom(known, frequency);
}

/// MAUI [ComputedProgresses.Get] plus stored skip / manual overlays.
int computedProgressValueForDate({
  required List<HabitProgressMark> marks,
  required FrequencyConfig frequency,
  required DateTime date,
}) {
  final day = dateOnly(date);
  HabitProgressMark? stored;
  for (final mark in marks) {
    if (dateOnly(mark.date) == day) {
      stored = mark;
      break;
    }
  }
  if (stored != null &&
      (stored.value == kProgressSkip || stored.value == kProgressYesManual)) {
    return stored.value;
  }

  for (final mark in computeHabitProgress(marks: marks, frequency: frequency)) {
    if (dateOnly(mark.date) == day) return mark.value;
  }
  return stored?.value ?? kProgressUnknown;
}

int habitProgressValueOnDate({
  required FrequencyConfig frequency,
  required Iterable<HabitRecord> records,
  required DateTime date,
}) {
  return computedProgressValueForDate(
    marks: [
      for (final record in records)
        HabitProgressMark(date: record.date, value: record.value),
    ],
    frequency: frequency,
    date: date,
  );
}

/// Open check: [kProgressUnknown] or [kProgressNo].
bool isHabitExecutionRequiredValue(int value) =>
    value == kProgressUnknown || value == kProgressNo;

/// Frequency already met: manual or auto-filled completion.
bool isHabitSatisfiedValue(int value) =>
    value == kProgressYesManual || value == kProgressYesAuto;

bool isHabitExecutionRequiredOnDate({
  required FrequencyConfig frequency,
  required Iterable<HabitRecord> records,
  required DateTime date,
}) {
  return isHabitExecutionRequiredValue(
    habitProgressValueOnDate(
      frequency: frequency,
      records: records,
      date: date,
    ),
  );
}

bool isHabitSatisfiedOnDate({
  required FrequencyConfig frequency,
  required Iterable<HabitRecord> records,
  required DateTime date,
}) {
  return isHabitSatisfiedValue(
    habitProgressValueOnDate(
      frequency: frequency,
      records: records,
      date: date,
    ),
  );
}

/// Habit counts toward that day's list / completion ratio.
bool habitAppliesOnDate({
  required FrequencyConfig frequency,
  required Iterable<HabitRecord> records,
  required DateTime date,
}) {
  final value = habitProgressValueOnDate(
    frequency: frequency,
    records: records,
    date: date,
  );
  return isHabitExecutionRequiredValue(value) ||
      isHabitSatisfiedValue(value) ||
      value == kProgressSkip;
}

/// MAUI [HabitComplexity.ToDaysCount] — calendar days a new habit needs.
int daysCountForComplexity(int complexity) {
  return switch (complexity) {
    1 => 18,
    2 => 30,
    3 => 44,
    4 => 59,
    5 => 66,
    6 => 71,
    7 => 100,
    8 => 130,
    9 => 190,
    10 => 254,
    _ => 66,
  };
}

/// MAUI [ServiceOfHabit.GetDaysUntilFullAutomation].
///
/// Projects extra completed days until [roundScoreToPercent] reaches 100.
int getDaysUntilFullAutomation({
  required List<HabitProgressMark> marks,
  required FrequencyConfig frequency,
  required int complexity,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final range = _scoreDateRange(marks, today);
  final known =
      marks
          .where((m) => m.value == kProgressYesManual || m.value == kProgressNo)
          .map((m) => HabitProgressMark(date: dateOnly(m.date), value: m.value))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final values = _dailyProgressValues(
    computed: _recomputeFrom(known, frequency),
    from: range.from,
    to: range.to,
  );

  var extraDays = 0;
  while (true) {
    final rounded = roundScoreToPercent(
      _scoreFromProgressValues(
        complexity: complexity,
        frequency: frequency,
        values: values,
      ),
    );
    if (rounded >= 100) break;

    values.insert(0, kProgressYesManual);
    extraDays++;
    if (extraDays > 1000) {
      throw StateError('Cannot define days until the habit is complete.');
    }
  }
  return extraDays;
}

double _complexityCoefficient(int complexity) {
  switch (complexity) {
    case 1:
      return 5.6;
    case 2:
      return 3.33;
    case 3:
      return 2.3;
    case 4:
      return 1.7;
    case 5:
      return 1.525;
    case 6:
      return 1.4;
    case 7:
      return 1.0;
    case 8:
      return 0.77;
    case 9:
      return 0.524;
    case 10:
      return 0.392;
    default:
      return 1.525;
  }
}

int _daysUntil(DateTime from, DateTime to) => to.difference(from).inDays;

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

class _Interval {
  const _Interval({
    required this.begin,
    required this.center,
    required this.end,
  });

  final DateTime begin;
  final DateTime center;
  final DateTime end;

  _Interval shifted(int days) => _Interval(
    begin: begin.add(Duration(days: days)),
    center: center,
    end: end.add(Duration(days: days)),
  );
}

List<HabitProgressMark> _recomputeFrom(
  List<HabitProgressMark> originalKnown,
  FrequencyConfig frequency,
) {
  final intervals = _buildIntervals(frequency, originalKnown);
  _snapIntervalsTogether(intervals);
  return _buildProgressesFromInterval(originalKnown, intervals);
}

List<_Interval> _buildIntervals(
  FrequencyConfig frequency,
  List<HabitProgressMark> progresses,
) {
  final filtered = progresses
      .where((p) => p.value == kProgressYesManual)
      .toList();
  final repeats = frequency.repeats;
  final intervalInDays = frequency.intervalLengthInDays;
  final result = <_Interval>[];

  for (var i = repeats - 1; i < filtered.length; i++) {
    final begin = filtered[i].date;
    final center = filtered[i - repeats + 1].date;
    var size = intervalInDays;

    if (intervalInDays == 30) {
      size = begin.day == _daysInMonth(begin.year, begin.month)
          ? _daysInMonth(
              begin.month == 12 ? begin.year + 1 : begin.year,
              begin.month == 12 ? 1 : begin.month + 1,
            )
          : _daysInMonth(begin.year, begin.month);
    } else if (intervalInDays == 365) {
      final year = begin.day == 31 && begin.month == 12
          ? begin.year + 1
          : begin.year;
      size = _isLeapYear(year) ? 366 : 365;
    }

    if (_daysUntil(begin, center) < size) {
      result.add(
        _Interval(
          begin: begin,
          center: center,
          end: begin.add(Duration(days: size - 1)),
        ),
      );
    }
  }
  return result;
}

void _snapIntervalsTogether(List<_Interval> intervals) {
  for (var numInterval = 1; numInterval < intervals.length; numInterval++) {
    final current = intervals[numInterval];
    final next = intervals[numInterval - 1];
    final gapOfNextToCurrent = _daysUntil(current.end, next.begin);
    if (gapOfNextToCurrent >= 0) {
      final gapOfCenterToEnd = _daysUntil(current.center, current.end);
      final shift = math.min(gapOfCenterToEnd, gapOfNextToCurrent + 1);
      intervals[numInterval] = current.shifted(-shift);
    }
  }
}

List<HabitProgressMark> _buildProgressesFromInterval(
  List<HabitProgressMark> original,
  List<_Interval> intervalList,
) {
  if (original.isEmpty) return const [];

  var from = original.first.date;
  var to = original.first.date;
  for (final progress in original) {
    if (progress.date.isBefore(from)) from = progress.date;
    if (progress.date.isAfter(to)) to = progress.date;
  }
  for (final interval in intervalList) {
    if (interval.begin.isBefore(from)) from = interval.begin;
    if (interval.end.isAfter(to)) to = interval.end;
  }

  final result = <HabitProgressMark>[];
  var current = to;
  while (!current.isBefore(from)) {
    result.add(HabitProgressMark(date: current, value: kProgressUnknown));
    current = current.subtract(const Duration(days: 1));
  }

  for (final interval in intervalList) {
    current = interval.end;
    while (!current.isBefore(interval.begin)) {
      final offset = _daysUntil(current, to);
      if (offset >= 0 && offset < result.length) {
        result[offset] = HabitProgressMark(
          date: current,
          value: kProgressYesAuto,
        );
      }
      current = current.subtract(const Duration(days: 1));
    }
  }

  for (final progress in original) {
    final offset = _daysUntil(progress.date, to);
    if (offset < 0 || offset >= result.length) continue;
    if (result[offset].value == kProgressUnknown ||
        progress.value == kProgressSkip ||
        progress.value == kProgressYesManual) {
      result[offset] = progress;
    }
  }
  return result;
}

({DateTime from, DateTime to}) _scoreDateRange(
  List<HabitProgressMark> marks,
  DateTime today,
) {
  var from = today.subtract(const Duration(days: kNumberOfDaysInProgress - 1));
  var to = today;
  for (final mark in marks) {
    final day = dateOnly(mark.date);
    if (day.isBefore(from)) from = day;
    if (day.isAfter(to)) to = day;
  }
  return (from: from, to: to);
}

List<int> _dailyProgressValues({
  required List<HabitProgressMark> computed,
  required DateTime from,
  required DateTime to,
}) {
  final byDate = <DateTime, int>{
    for (final mark in computed) dateOnly(mark.date): mark.value,
  };
  final values = <int>[];
  var current = to;
  while (!current.isBefore(from)) {
    values.add(byDate[current] ?? kProgressUnknown);
    current = current.subtract(const Duration(days: 1));
  }
  return values;
}

double _scoreListValue({
  required int complexity,
  required FrequencyConfig frequency,
  required List<HabitProgressMark> computed,
  required DateTime from,
  required DateTime to,
}) {
  return _scoreFromProgressValues(
    complexity: complexity,
    frequency: frequency,
    values: _dailyProgressValues(computed: computed, from: from, to: to),
  );
}

/// .NET [Score.Get] — [values] are newest-first daily progress values.
double _scoreFromProgressValues({
  required int complexity,
  required FrequencyConfig frequency,
  required List<int> values,
}) {
  var repeats = frequency.repeats;
  var intervalInDays = frequency.intervalLengthInDays;
  final frequencyValue = frequency.frequencyValue;
  if (frequencyValue < 1.0) {
    repeats *= 2;
    intervalInDays *= 2;
  }

  var rollingSum = 0.0;
  var previousValue = 0.0;
  for (var numValue = 0; numValue < values.length; numValue++) {
    final offset = values.length - numValue - 1;
    if (values[offset] == kProgressYesManual) {
      rollingSum += 1.0;
    }
    if (offset + intervalInDays < values.length &&
        values[offset + intervalInDays] == kProgressYesManual) {
      rollingSum -= 1.0;
    }
    if (values[offset] != kProgressSkip) {
      final percentageAchieved = math.min(1.0, rollingSum / repeats);
      previousValue = computeHabitScore(
        frequency: frequencyValue,
        previousScore: previousValue,
        checkmarkValue: percentageAchieved,
        complexity: complexity,
      );
    }
  }
  return previousValue;
}

bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
