import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_reminder.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';
import '../models/task_repeat_config.dart';
import '../core/utils/date_helpers.dart';

enum ScheduleTab { date, duration }

/// One reminder time and the weekdays it applies to (habits only).
class HabitTimeSlot {
  HabitTimeSlot({required this.time, Set<int>? weekdays})
    : weekdays = Set.of(weekdays ?? allWeekdays);

  static const Set<int> allWeekdays = {1, 2, 3, 4, 5, 6, 7};

  TimeOfDay time;
  final Set<int> weekdays;
}

/// Editable schedule draft shared by tasks and habits.
class ScheduleDraft extends ChangeNotifier {
  ScheduleDraft({
    this.showRepeat = true,
    this.showDateDuration = true,
    this.showDuration = false,
    DateTime? dueDate,
    DateTime? endDate,
    bool allDay = false,
    List<ScheduleReminderOffset>? reminders,
    bool constantReminder = false,
    TaskRepeatConfig? repeat,
    bool hasTime = false,
    List<HabitTimeSlot>? timeSlots,
  }) : _dueDate = dueDate,
       _endDate = showDateDuration && showDuration ? endDate : null,
       _allDay = showDateDuration && showDuration ? allDay : false,
       _reminders = List.of(reminders ?? const []),
       _constantReminder = constantReminder,
       _repeat = repeat ?? const TaskRepeatConfig(),
       _hasTime = hasTime,
       _timeSlots = List.of(timeSlots ?? const []),
       _tab = showDateDuration && showDuration && endDate != null
           ? ScheduleTab.duration
           : ScheduleTab.date;

  factory ScheduleDraft.fromTask(
    Task task, {
    bool showRepeat = true,
    bool showDuration = false,
  }) {
    final due = task.dueDate;
    final hasTime =
        due != null &&
        !task.allDay &&
        (due.hour != 0 || due.minute != 0 || task.reminders.isNotEmpty);
    return ScheduleDraft(
      showRepeat: showRepeat,
      showDuration: showDuration,
      dueDate: due,
      endDate: showDuration ? task.endDate : null,
      allDay: showDuration ? task.allDay : false,
      reminders: task.reminders.isEmpty && hasTime
          ? [const ScheduleReminderOffset(offsetMinutes: 0)]
          : task.reminders,
      constantReminder: task.constantReminder,
      repeat: task.repeat,
      hasTime: hasTime && !(showDuration && task.allDay),
    );
  }

  factory ScheduleDraft.fromHabit(Habit habit) {
    final reminder = habit.reminders.isEmpty ? null : habit.reminders.first;
    final now = DateTime.now();
    DateTime? start;
    if (reminder != null) {
      start = DateTime(
        now.year,
        now.month,
        now.day,
        reminder.time.hour,
        reminder.time.minute,
      );
    } else if (habit.reminderTime != null) {
      start = habit.reminderTime;
    }
    final slots = [
      for (final r in habit.reminders)
        HabitTimeSlot(
          time: r.time,
          weekdays: r.daysOfWeek.isEmpty
              ? HabitTimeSlot.allWeekdays
              : {for (final d in r.daysOfWeek) _uiWeekday(d.type)},
        ),
    ];
    if (slots.isEmpty && start != null) {
      slots.add(
        HabitTimeSlot(
          time: TimeOfDay(hour: start.hour, minute: start.minute),
        ),
      );
    }
    final hasTime = slots.isNotEmpty;
    return ScheduleDraft(
      showRepeat: false,
      showDateDuration: false,
      showDuration: false,
      dueDate: start,
      reminders: reminder?.offsets ?? const [],
      constantReminder:
          habit.constantReminder || (reminder?.constantReminder ?? false),
      hasTime: hasTime,
      timeSlots: slots,
    );
  }

  factory ScheduleDraft.defaults({
    bool showRepeat = true,
    bool showDateDuration = true,
    bool showDuration = false,
  }) {
    final now = DateTime.now();
    // Habits: default reminder time. Tasks: date only until the user picks a time.
    if (!showDateDuration) {
      final start = DateTime(now.year, now.month, now.day, 10, 0);
      return ScheduleDraft(
        showRepeat: showRepeat,
        showDateDuration: showDateDuration,
        showDuration: showDuration,
        dueDate: start,
        reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        hasTime: true,
        timeSlots: [HabitTimeSlot(time: const TimeOfDay(hour: 10, minute: 0))],
      );
    }
    return ScheduleDraft(
      showRepeat: showRepeat,
      showDateDuration: showDateDuration,
      showDuration: showDuration,
      dueDate: dateOnly(now),
      hasTime: false,
    );
  }

  final bool showRepeat;

  /// When false (habits), hide calendar / Date|Duration and keep times + weekdays + Reminder.
  final bool showDateDuration;

  /// When false, hide the Duration tab (Date calendar only for tasks).
  final bool showDuration;

  ScheduleTab _tab;
  ScheduleTab get tab => _tab;

  DateTime? _dueDate;
  DateTime? get dueDate => _dueDate;

  DateTime? _endDate;
  DateTime? get endDate => _endDate;

  bool _allDay;
  bool get allDay => _allDay;

  bool _hasTime;
  bool get hasTime => !showDateDuration ? habitTimeSlots.isNotEmpty : _hasTime;

  final List<HabitTimeSlot> _timeSlots;

  /// Habit reminder times. Each slot can cover different weekdays.
  List<HabitTimeSlot> get habitTimeSlots {
    if (_timeSlots.isNotEmpty) return List.unmodifiable(_timeSlots);
    if (!showDateDuration && _hasTime && _dueDate != null) {
      return [
        HabitTimeSlot(
          time: TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute),
        ),
      ];
    }
    return const [];
  }

  final List<ScheduleReminderOffset> _reminders;
  List<ScheduleReminderOffset> get reminders => List.unmodifiable(_reminders);

  bool _constantReminder;
  bool get constantReminder => _constantReminder;

  TaskRepeatConfig _repeat;
  TaskRepeatConfig get repeat => _repeat;

  DateTime get calendarMonth => DateTime(
    (_dueDate ?? DateTime.now()).year,
    (_dueDate ?? DateTime.now()).month,
  );

  void setTab(ScheduleTab value) {
    _tab = value;
    if (value == ScheduleTab.duration) {
      _ensureDurationDefaults();
    }
    notifyListeners();
  }

  void _ensureDurationDefaults() {
    final start = _dueDate ?? DateTime.now();
    _dueDate ??= DateTime(start.year, start.month, start.day, 9, 0);
    _endDate ??= (_dueDate ?? start).add(const Duration(hours: 1));
    if (!_hasTime && !_allDay) {
      _hasTime = true;
      _dueDate = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        9,
        0,
      );
      _endDate = _dueDate!.add(const Duration(hours: 1));
    }
  }

  void selectDate(DateTime day) {
    final d = dateOnly(day);
    if (_dueDate == null || !_hasTime) {
      _dueDate = d;
      _hasTime = false;
    } else {
      _dueDate = DateTime(
        d.year,
        d.month,
        d.day,
        _dueDate!.hour,
        _dueDate!.minute,
      );
    }
    if (_endDate != null && _dueDate != null) {
      final duration = durationOrDefault();
      _endDate = _dueDate!.add(duration);
    }
    notifyListeners();
  }

  Duration durationOrDefault() {
    if (_dueDate != null && _endDate != null) {
      final d = _endDate!.difference(_dueDate!);
      if (!d.isNegative && d.inMinutes > 0) return d;
    }
    return const Duration(hours: 1);
  }

  void setStart(DateTime value) {
    _dueDate = value;
    _hasTime = !_allDay;
    if (_endDate != null && !_endDate!.isAfter(value)) {
      _endDate = value.add(durationOrDefault());
    }
    notifyListeners();
  }

  void setEnd(DateTime value) {
    _endDate = value;
    if (_dueDate != null && value.isBefore(_dueDate!)) {
      _dueDate = value.subtract(const Duration(hours: 1));
    }
    notifyListeners();
  }

  void setAllDay(bool value) {
    _allDay = value;
    if (value) {
      _hasTime = false;
      if (_dueDate != null) {
        _dueDate = dateOnly(_dueDate!);
      }
      if (_endDate != null) {
        _endDate = dateOnly(_endDate!);
      } else if (_dueDate != null) {
        _endDate = _dueDate;
      }
    } else {
      _hasTime = true;
      final d = _dueDate ?? DateTime.now();
      _dueDate = DateTime(d.year, d.month, d.day, 9, 0);
      _endDate = _dueDate!.add(const Duration(hours: 1));
    }
    notifyListeners();
  }

  void setTime(TimeOfDay time) {
    final d = _dueDate ?? dateOnly(DateTime.now());
    _dueDate = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    _hasTime = true;
    _allDay = false;
    if (!showDateDuration) {
      _ensureSlots();
      if (_timeSlots.isEmpty) {
        _timeSlots.add(HabitTimeSlot(time: time));
      } else {
        _timeSlots.first.time = time;
      }
    }
    if (_reminders.isEmpty) {
      _reminders.add(const ScheduleReminderOffset(offsetMinutes: 0));
    }
    if (_endDate != null) {
      _endDate = _dueDate!.add(durationOrDefault());
    }
    notifyListeners();
  }

  void setSlotTime(int index, TimeOfDay time) {
    _ensureSlots();
    if (index < 0 || index >= _timeSlots.length) return;
    _timeSlots[index].time = time;
    if (index == 0) {
      final d = _dueDate ?? dateOnly(DateTime.now());
      _dueDate = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    }
    _hasTime = true;
    if (_reminders.isEmpty) {
      _reminders.add(const ScheduleReminderOffset(offsetMinutes: 0));
    }
    notifyListeners();
  }

  void addTimeSlot() {
    _ensureSlots();
    final used = <int>{};
    for (final slot in _timeSlots) {
      used.addAll(slot.weekdays);
    }
    final remaining = HabitTimeSlot.allWeekdays.difference(used);
    final last = _timeSlots.isEmpty
        ? const TimeOfDay(hour: 10, minute: 0)
        : _timeSlots.last.time;
    _timeSlots.add(
      HabitTimeSlot(
        time: TimeOfDay(hour: (last.hour + 1) % 24, minute: last.minute),
        weekdays: remaining,
      ),
    );
    _hasTime = true;
    if (_reminders.isEmpty) {
      _reminders.add(const ScheduleReminderOffset(offsetMinutes: 0));
    }
    _syncDueFromSlots();
    notifyListeners();
  }

  void removeTimeSlot(int index) {
    _ensureSlots();
    if (index < 0 || index >= _timeSlots.length) return;
    if (_timeSlots.length == 1) {
      clearTime();
      return;
    }
    _timeSlots.removeAt(index);
    _syncDueFromSlots();
    notifyListeners();
  }

  void toggleSlotDay(int index, int weekday) {
    _ensureSlots();
    if (index < 0 || index >= _timeSlots.length) return;
    final slot = _timeSlots[index];
    if (slot.weekdays.contains(weekday)) {
      slot.weekdays.remove(weekday);
    } else {
      for (final other in _timeSlots) {
        other.weekdays.remove(weekday);
      }
      slot.weekdays.add(weekday);
    }
    notifyListeners();
  }

  void clearTime() {
    if (_dueDate != null) {
      _dueDate = dateOnly(_dueDate!);
    }
    _hasTime = false;
    _timeSlots.clear();
    _reminders.clear();
    _constantReminder = false;
    notifyListeners();
  }

  void _ensureSlots() {
    if (_timeSlots.isNotEmpty || showDateDuration) return;
    if (_hasTime && _dueDate != null) {
      _timeSlots.add(
        HabitTimeSlot(
          time: TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute),
        ),
      );
    }
  }

  void _syncDueFromSlots() {
    if (_timeSlots.isEmpty) {
      _hasTime = false;
      return;
    }
    final t = _timeSlots.first.time;
    final d = _dueDate ?? dateOnly(DateTime.now());
    _dueDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    _hasTime = true;
  }

  void setReminders(List<ScheduleReminderOffset> value) {
    _reminders
      ..clear()
      ..addAll(value);
    if (_reminders.isNotEmpty && !_hasTime && !_allDay) {
      setTime(const TimeOfDay(hour: 9, minute: 0));
      return;
    }
    notifyListeners();
  }

  void setConstantReminder(bool value) {
    _constantReminder = value;
    notifyListeners();
  }

  void setRepeat(TaskRepeatConfig value) {
    _repeat = value;
    notifyListeners();
  }

  void clear() {
    _dueDate = null;
    _endDate = null;
    _allDay = false;
    _hasTime = false;
    _timeSlots.clear();
    _reminders.clear();
    _constantReminder = false;
    _repeat = const TaskRepeatConfig();
    _tab = ScheduleTab.date;
    notifyListeners();
  }

  bool get isEmpty {
    if (!showDateDuration) return habitTimeSlots.isEmpty && _dueDate == null;
    return _dueDate == null;
  }

  /// Apply draft onto a task (schedule fields only).
  Task applyToTask(Task task) {
    if (isEmpty) return task.clearedSchedule();
    final keepDuration =
        showDuration && (_tab == ScheduleTab.duration || _endDate != null);
    return task.copyWith(
      dueDate: _dueDate,
      endDate: keepDuration ? _endDate : null,
      clearEndDate: !keepDuration,
      allDay: keepDuration ? _allDay : false,
      reminders: List.of(_reminders),
      constantReminder: _constantReminder,
      repeat: showRepeat ? _repeat : const TaskRepeatConfig(),
    );
  }
}

int _uiWeekday(int storedType) =>
    storedType == 0 ? DateTime.sunday : storedType;
