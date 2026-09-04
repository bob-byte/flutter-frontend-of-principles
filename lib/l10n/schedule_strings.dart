import 'package:flutter/material.dart';

/// EN/UK strings for the schedule sheet (TickTick-style).
class ScheduleStrings {
  const ScheduleStrings._({
    required this.cancel,
    required this.done,
    required this.date,
    required this.duration,
    required this.time,
    required this.reminder,
    required this.repeat,
    required this.clear,
    required this.none,
    required this.onTime,
    required this.minutesEarly,
    required this.hourEarly,
    required this.dayEarly,
    required this.custom,
    required this.recents,
    required this.constantReminder,
    required this.allDay,
    required this.start,
    required this.end,
    required this.today,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.everyWeekday,
    required this.customRepeat,
    required this.repeatType,
    required this.byDueDates,
    required this.byCompletion,
    required this.frequency,
    required this.every,
    required this.dayUnit,
    required this.weekUnit,
    required this.monthUnit,
    required this.yearUnit,
    required this.week,
    required this.add,
    required this.addTime,
    required this.weekdayPills,
    required this.customReminder,
    required this.remindAt,
    required this.durationLabel,
  });

  final String cancel;
  final String done;
  final String date;
  final String duration;
  final String time;
  final String reminder;
  final String repeat;
  final String clear;
  final String none;
  final String onTime;
  final String Function(int n) minutesEarly;
  final String hourEarly;
  final String dayEarly;
  final String custom;
  final String recents;
  final String constantReminder;
  final String allDay;
  final String start;
  final String end;
  final String today;
  final String daily;
  final String weekly;
  final String monthly;
  final String yearly;
  final String everyWeekday;
  final String customRepeat;
  final String repeatType;
  final String byDueDates;
  final String byCompletion;
  final String frequency;
  final String every;
  final String dayUnit;
  final String weekUnit;
  final String monthUnit;
  final String yearUnit;
  final String week;
  final String add;
  final String addTime;
  final List<String> weekdayPills;
  final String customReminder;
  final String Function(String when) remindAt;
  final String Function(String text) durationLabel;

  static ScheduleStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'uk') return uk;
    return en;
  }

  static final en = ScheduleStrings._(
    cancel: 'Cancel',
    done: 'Done',
    date: 'Date',
    duration: 'Duration',
    time: 'Time',
    reminder: 'Reminder',
    repeat: 'Repeat',
    clear: 'Clear',
    none: 'None',
    onTime: 'On time',
    minutesEarly: (n) => '$n minutes early',
    hourEarly: '1 hour early',
    dayEarly: '1 day early',
    custom: 'Custom',
    recents: 'Recents',
    constantReminder: 'Constant Reminder',
    allDay: 'All Day',
    start: 'Start',
    end: 'End',
    today: 'Today',
    daily: 'Daily',
    weekly: 'Weekly',
    monthly: 'Monthly',
    yearly: 'Yearly',
    everyWeekday: 'Every Weekday (Mon - Fri)',
    customRepeat: 'Custom Repeat',
    repeatType: 'Repeat Type',
    byDueDates: 'By Due Dates',
    byCompletion: 'By Completion Date',
    frequency: 'Frequency',
    every: 'Every',
    dayUnit: 'Day',
    weekUnit: 'Week',
    monthUnit: 'Month',
    yearUnit: 'Year',
    week: 'Week',
    add: 'Add',
    addTime: 'Add time',
    weekdayPills: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    customReminder: 'Custom Reminder',
    remindAt: (when) => 'Remind at $when',
    durationLabel: (text) => 'Duration: $text',
  );

  static final uk = ScheduleStrings._(
    cancel: 'Скасувати',
    done: 'Готово',
    date: 'Дата',
    duration: 'Тривалість',
    time: 'Час',
    reminder: 'Нагадування',
    repeat: 'Повтор',
    clear: 'Очистити',
    none: 'Немає',
    onTime: 'Вчасно',
    minutesEarly: (n) => 'За $n хв',
    hourEarly: 'За 1 годину',
    dayEarly: 'За 1 день',
    custom: 'Власне',
    recents: 'Нещодавні',
    constantReminder: 'Постійне нагадування',
    allDay: 'Весь день',
    start: 'Початок',
    end: 'Кінець',
    today: 'Сьогодні',
    daily: 'Щодня',
    weekly: 'Щотижня',
    monthly: 'Щомісяця',
    yearly: 'Щороку',
    everyWeekday: 'Будні (Пн - Пт)',
    customRepeat: 'Власний повтор',
    repeatType: 'Тип повтору',
    byDueDates: 'За датою виконання',
    byCompletion: 'За датою завершення',
    frequency: 'Частота',
    every: 'Кожні',
    dayUnit: 'День',
    weekUnit: 'Тиждень',
    monthUnit: 'Місяць',
    yearUnit: 'Рік',
    week: 'Тиждень',
    add: 'Додати',
    addTime: 'Додати час',
    weekdayPills: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
    customReminder: 'Власне нагадування',
    remindAt: (when) => 'Нагадати о $when',
    durationLabel: (text) => 'Тривалість: $text',
  );
}
