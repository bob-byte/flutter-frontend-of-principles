import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/habit.dart';
import '../../models/habit_record.dart';
import '../../models/home_calendar_snapshot.dart';
import '../../models/task.dart';
import '../habit_score.dart';
import '../theme/task_theme_palette.dart';
import '../utils/date_helpers.dart';
import 'home_calendar_constants.dart';

HomeCalendarSnapshot buildHomeCalendarSnapshot({
  required List<Task> tasks,
  required Map<String, int> themeColors,
  required List<Habit> habits,
  required List<HabitRecord> records,
  required TasksUiPalette palette,
  required Locale locale,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final rangeStart = DateTime(
    today.year,
    today.month - HomeCalendarWidgetConfig.monthsBack,
    1,
  );
  final rangeEnd = DateTime(
    today.year,
    today.month + HomeCalendarWidgetConfig.monthsForward + 1,
    0,
  );

  final items = <HomeCalendarItem>[
    ..._taskItems(tasks, themeColors, rangeStart, rangeEnd),
    ..._habitItems(habits, records, palette, rangeStart, rangeEnd),
  ];

  final l10n = lookupAppLocalizations(locale);
  final language = locale.languageCode;
  final monthNames = [
    for (var month = 1; month <= 12; month++)
      _tryFormat(
        () => DateFormat.MMMM(language).format(DateTime(2020, month)),
        _enMonths[month - 1],
      ),
  ];
  final monthNamesShort = [
    for (var month = 1; month <= 12; month++)
      _tryFormat(
        () => DateFormat.MMM(language).format(DateTime(2020, month)),
        _enMonthsShort[month - 1],
      ),
  ];
  final monday = DateTime(2026, 1, 5);
  final weekdays = [
    for (var i = 0; i < 7; i++)
      _tryFormat(
        () => DateFormat.E(language).format(monday.add(Duration(days: i))),
        _enWeekdays[i],
      ).toUpperCase().replaceAll('.', '').characters.take(2).toString(),
  ];

  return HomeCalendarSnapshot(
    locale: language,
    today: today,
    weekStartsOn: DateTime.monday,
    theme: HomeCalendarThemeSnapshot(
      isDark: palette.isDark,
      background: homeCalendarArgbHex(palette.cardBg.toARGB32()),
      text: homeCalendarArgbHex(palette.textPrimary.toARGB32()),
      textMuted: homeCalendarArgbHex(palette.textMuted.toARGB32()),
      primary: homeCalendarArgbHex(palette.primary.toARGB32()),
      onPrimary: homeCalendarArgbHex(palette.onPrimary.toARGB32()),
      divider: homeCalendarArgbHex(palette.headerBorder.toARGB32()),
      sunday: homeCalendarArgbHex(palette.primary.toARGB32()),
      todayFill: palette.isDark
          ? homeCalendarArgbHex(const Color(0xFFFFFFFF).toARGB32())
          : homeCalendarArgbHex(palette.primary.toARGB32()),
      todayText: palette.isDark
          ? homeCalendarArgbHex(const Color(0xFF181818).toARGB32())
          : homeCalendarArgbHex(palette.onPrimary.toARGB32()),
    ),
    labels: HomeCalendarLabels(
      today: l10n.calendarWidgetToday,
      add: l10n.calendarWidgetAdd,
      empty: l10n.calendarWidgetEmpty,
      monthNames: monthNames,
      monthNamesShort: monthNamesShort,
      weekdays: weekdays,
    ),
    items: items,
  );
}

Iterable<HomeCalendarItem> _taskItems(
  List<Task> tasks,
  Map<String, int> themeColors,
  DateTime rangeStart,
  DateTime rangeEnd,
) sync* {
  for (final task in tasks) {
    if (task.isDeleted) continue;
    final due = task.dueDate;
    if (due == null) continue;
    final start = dateOnly(due);
    var end = task.endDate == null ? start : dateOnly(task.endDate!);
    if (end.isBefore(start)) end = start;
    if (end.isBefore(rangeStart) || start.isAfter(rangeEnd)) continue;

    final theme = task.theme?.trim();
    final stored = theme == null || theme.isEmpty ? null : themeColors[theme];
    final color = stored != null
        ? Color(stored)
        : (theme == null || theme.isEmpty
              ? const Color(0xFF007BFF)
              : fallbackThemeColor(theme));

    yield HomeCalendarItem(
      id: 'task-${task.id}',
      kind: 'task',
      title: task.title.trim().isEmpty ? task.id : task.title.trim(),
      start: start,
      end: end,
      allDay: task.allDay || !_hasClock(due),
      timed: !task.allDay && _hasClock(due),
      color: homeCalendarArgbHex(color.toARGB32()),
      done: task.isDone,
    );
  }
}

Iterable<HomeCalendarItem> _habitItems(
  List<Habit> habits,
  List<HabitRecord> records,
  TasksUiPalette palette,
  DateTime rangeStart,
  DateTime rangeEnd,
) sync* {
  final recordsByHabit = <int, List<HabitRecord>>{};
  for (final record in records) {
    recordsByHabit.putIfAbsent(record.habitId, () => []).add(record);
  }

  var cursor = rangeStart;
  while (!cursor.isAfter(rangeEnd)) {
    for (final habit in habits) {
      final id = habit.id;
      if (id == null || habit.isArchived) continue;
      final habitRecords = recordsByHabit[id] ?? const <HabitRecord>[];
      if (!habitAppliesOnDate(
        frequency: habit.frequency,
        records: habitRecords,
        date: cursor,
      )) {
        continue;
      }
      final color = taskCategoryPalette[id.abs() % taskCategoryPalette.length];
      final reminder = habit.reminderTime;
      yield HomeCalendarItem(
        id: 'habit-$id-${homeCalendarDateKey(cursor)}',
        kind: 'habit',
        title: habit.name.trim(),
        start: cursor,
        end: cursor,
        allDay: reminder == null,
        timed: reminder != null,
        color: homeCalendarArgbHex(color.toARGB32()),
        done: isHabitSatisfiedOnDate(
          frequency: habit.frequency,
          records: habitRecords,
          date: cursor,
        ),
      );
    }
    cursor = cursor.add(const Duration(days: 1));
  }
}

bool _hasClock(DateTime date) =>
    date.hour != 0 || date.minute != 0 || date.second != 0;

String _tryFormat(String Function() format, String fallback) {
  try {
    return format();
  } catch (_) {
    return fallback;
  }
}

const _enMonths = [
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

const _enMonthsShort = [
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

const _enWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
