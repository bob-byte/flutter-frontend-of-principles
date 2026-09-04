import 'package:flutter/material.dart';

import '../../../core/utils/date_helpers.dart';
import '../../../l10n/schedule_strings.dart';
import '../../../models/habit_reminder.dart';
import '../../../models/schedule_reminder_offset.dart';
import '../../../models/task.dart';
import '../../../models/task_repeat_config.dart';

String formatOffsetLabel(ScheduleStrings s, int minutes) {
  if (minutes == 0) return s.onTime;
  if (minutes == 60) return s.hourEarly;
  if (minutes == 24 * 60) return s.dayEarly;
  if (minutes > 0 && minutes < 1440) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? s.hourEarly : s.minutesEarly(minutes);
    }
    return s.minutesEarly(minutes);
  }
  final days = minutes ~/ 1440;
  final rest = minutes % 1440;
  if (rest == 0) {
    return days == 1 ? s.dayEarly : s.minutesEarly(minutes);
  }
  return s.minutesEarly(minutes);
}

String formatRepeatLabel(ScheduleStrings s, TaskRepeatConfig r, DateTime? day) {
  final d = day ?? DateTime.now();
  switch (r.preset) {
    case TaskRepeatPreset.none:
      return s.none;
    case TaskRepeatPreset.daily:
      return s.daily;
    case TaskRepeatPreset.weekly:
      return '${s.weekly} (${weekdayShort(d.weekday)})';
    case TaskRepeatPreset.monthly:
      return '${s.monthly} (${d.day})';
    case TaskRepeatPreset.yearly:
      return '${s.yearly} (${d.day} ${monthShort(d.month)})';
    case TaskRepeatPreset.weekday:
      return s.everyWeekday;
    case TaskRepeatPreset.custom:
      return s.custom;
  }
}

String formatScheduleChip(Task task, {required String noDate}) {
  if (task.dueDate == null) return noDate;
  final due = task.dueDate!;
  final date = formatTaskDate(due);
  if (task.allDay) {
    if (task.endDate != null && !isSameDay(due, task.endDate)) {
      return '$date – ${formatTaskDate(task.endDate!)}';
    }
    return date;
  }
  final time = _hhmm(due);
  if (task.endDate != null) {
    final end = task.endDate!;
    if (isSameDay(due, end)) {
      return '$date, $time–${_hhmm(end)}';
    }
    return '$date $time – ${formatTaskDate(end)} ${_hhmm(end)}';
  }
  if (due.hour != 0 || due.minute != 0) {
    return '$date, $time';
  }
  return date;
}

String formatDurationText(Duration d) {
  if (d.inDays >= 1 && d.inMinutes % (24 * 60) == 0) {
    return d.inDays == 1 ? '1 day' : '${d.inDays} days';
  }
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (m == 0) return h == 1 ? '1 hr' : '$h hrs';
    return '${h}h ${m}m';
  }
  return '${d.inMinutes} min';
}

String monthName(int m) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[m - 1];
}

String monthShort(int m) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[m - 1];
}

String weekdayShort(int w) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(w - 1).clamp(0, 6)];
}

String weekdayPill(int w) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(w - 1).clamp(0, 6)];
}

/// Compact weekday ranges, e.g. `Mon–Fri` or `Sat, Sun`. Empty when all 7 days.
String formatWeekdayRanges(Set<int> days, List<String> labels) {
  if (days.length >= 7) return '';
  final sorted = (days.map((d) => d == 0 ? 7 : d).toList()..sort());
  final parts = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    final startLabel = labels[(sorted[i] - 1).clamp(0, labels.length - 1)];
    final endLabel = labels[(sorted[j] - 1).clamp(0, labels.length - 1)];
    if (i == j) {
      parts.add(startLabel);
    } else if (j == i + 1) {
      parts.add('$startLabel, $endLabel');
    } else {
      parts.add('$startLabel–$endLabel');
    }
    i = j + 1;
  }
  return parts.join(', ');
}

String formatHabitTimeHHmm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String formatHabitReminderSummary(
  List<HabitReminder> reminders,
  List<String> weekdayLabels,
) {
  if (reminders.isEmpty) return '';
  return reminders
      .map((r) {
        final time = formatHabitTimeHHmm(r.time);
        final days = formatWeekdayRanges({
          for (final d in r.daysOfWeek) d.type,
        }, weekdayLabels);
        return days.isEmpty ? time : '$time $days';
      })
      .join(', ');
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime reminderFireAt(DateTime start, int offsetMinutes) {
  return start.subtract(Duration(minutes: offsetMinutes));
}
