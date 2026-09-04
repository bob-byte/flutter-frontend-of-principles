import '../../models/task_repeat_config.dart';

/// Computes the next occurrence start for a repeating task.
DateTime? nextOccurrenceStart({
  required DateTime fromStart,
  required TaskRepeatConfig repeat,
  DateTime? completedAt,
}) {
  if (repeat.isNone) return null;

  final base = repeat.anchor == TaskRepeatAnchor.completion
      ? (completedAt ?? DateTime.now())
      : fromStart;

  switch (repeat.preset) {
    case TaskRepeatPreset.none:
      return null;
    case TaskRepeatPreset.daily:
      return _addCalendar(base, days: repeat.interval.clamp(1, 365));
    case TaskRepeatPreset.weekly:
      return _nextWeekly(base, repeat.weekdays, intervalWeeks: 1);
    case TaskRepeatPreset.monthly:
      return _addCalendar(base, months: repeat.interval.clamp(1, 120));
    case TaskRepeatPreset.yearly:
      return _addCalendar(base, years: repeat.interval.clamp(1, 50));
    case TaskRepeatPreset.weekday:
      return _nextWeekly(
        base,
        const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ],
        intervalWeeks: 1,
      );
    case TaskRepeatPreset.custom:
      switch (repeat.unit) {
        case TaskRepeatUnit.day:
          return _addCalendar(base, days: repeat.interval.clamp(1, 365));
        case TaskRepeatUnit.week:
          return _nextWeekly(
            base,
            repeat.weekdays.isEmpty ? [base.weekday] : repeat.weekdays,
            intervalWeeks: repeat.interval.clamp(1, 52),
          );
        case TaskRepeatUnit.month:
          return _addCalendar(base, months: repeat.interval.clamp(1, 120));
        case TaskRepeatUnit.year:
          return _addCalendar(base, years: repeat.interval.clamp(1, 50));
      }
  }
}

DateTime _addCalendar(
  DateTime base, {
  int days = 0,
  int months = 0,
  int years = 0,
}) {
  if (days != 0 && months == 0 && years == 0) {
    return DateTime(
      base.year,
      base.month,
      base.day,
      base.hour,
      base.minute,
      base.second,
    ).add(Duration(days: days));
  }
  var year = base.year + years;
  var month = base.month + months;
  while (month > 12) {
    month -= 12;
    year++;
  }
  while (month < 1) {
    month += 12;
    year--;
  }
  final day = base.day.clamp(1, _daysInMonth(year, month));
  return DateTime(
    year,
    month,
    day,
    base.hour,
    base.minute,
    base.second,
  );
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Next matching weekday strictly after [base] (or same day if matching and
/// we are advancing from completion — always move at least to next day slot).
DateTime _nextWeekly(
  DateTime base,
  List<int> weekdays, {
  required int intervalWeeks,
}) {
  final days =
      weekdays.isEmpty ? [base.weekday] : (List<int>.from(weekdays)..sort());
  var cursor = DateTime(base.year, base.month, base.day).add(const Duration(days: 1));
  final startWeek = _weekStart(base);
  for (var i = 0; i < 400; i++) {
    if (days.contains(cursor.weekday)) {
      final weeks = _weekStart(cursor).difference(startWeek).inDays ~/ 7;
      if (intervalWeeks <= 1 || weeks % intervalWeeks == 0) {
        return DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          base.hour,
          base.minute,
          base.second,
        );
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return base.add(Duration(days: 7 * intervalWeeks));
}

DateTime _weekStart(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

Duration? durationBetween(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final d = end.difference(start);
  if (d.isNegative) return null;
  return d;
}
