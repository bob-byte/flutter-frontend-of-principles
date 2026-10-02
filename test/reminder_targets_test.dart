import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/reminder/reminder_restore_isolate.dart';
import 'package:principles_app/core/reminder/reminder_targets.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/reminder_service.dart';

HabitReminder _reminder({int? id, List<ScheduleReminderOffset>? offsets}) {
  return HabitReminder(
    id: id,
    title: 'Read',
    description: '',
    time: const TimeOfDay(hour: 8, minute: 0),
    isEnabled: true,
    daysOfWeek: [
      WeekDay(type: DateTime.monday, userNotificationRequestId: 501),
      WeekDay(type: DateTime.friday, userNotificationRequestId: 505),
    ],
    offsets: offsets ?? const [],
  );
}

void main() {
  group('ReminderTargets.isOrphanPayload', () {
    final targets = ReminderTargets.from(
      openTasks: [
        Task(id: 'L1', title: 'Local', createdAt: DateTime(2026)),
        Task(
          id: 'L2',
          serverId: 77,
          title: 'Synced',
          createdAt: DateTime(2026),
        ),
      ],
      activeHabits: [
        Habit(
          id: 5,
          serverId: 5,
          name: 'Walk',
          reminders: [_reminder(id: 300)],
        ),
      ],
    );

    test('keeps reminders of open tasks by local or server id', () {
      expect(targets.isOrphanPayload('task:L1'), isFalse);
      expect(targets.isOrphanPayload('task_constant:L1'), isFalse);
      expect(targets.isOrphanPayload('task:77'), isFalse);
    });

    test('flags tasks that are gone or done', () {
      expect(targets.isOrphanPayload('task:L9'), isTrue);
      expect(targets.isOrphanPayload('task_constant:88'), isTrue);
    });

    test('keeps habits by id or legacy reminder id', () {
      expect(targets.isOrphanPayload('habit:5'), isFalse);
      expect(targets.isOrphanPayload('habit_constant:5'), isFalse);
      expect(targets.isOrphanPayload('habit:300'), isFalse);
    });

    test('flags deleted or archived habits', () {
      expect(targets.isOrphanPayload('habit:6'), isTrue);
      expect(targets.isOrphanPayload('habit_constant:6'), isTrue);
    });

    test('drops an older alarm id after the task kept a new one', () {
      final moved = ReminderTargets.from(
        openTasks: [
          Task(
            id: 'L1',
            serverId: 77,
            title: 'Tomorrow',
            createdAt: DateTime(2026, 10, 2),
            dueDate: DateTime(2026, 10, 3, 15),
            reminders: const [
              ScheduleReminderOffset(
                offsetMinutes: 0,
                notificationRequestId: 42,
              ),
            ],
          ),
        ],
        activeHabits: const [],
      );

      expect(moved.shouldCancelNotification('task:L1', 42), isFalse);
      expect(moved.shouldCancelNotification('task:77', 42), isFalse);
      expect(moved.shouldCancelNotification('task:L1', 7), isTrue);
      expect(moved.shouldCancelNotification('task_constant:L1', 7), isTrue);
    });

    test('keeps alarms when the task has no stored notification id yet', () {
      final fresh = ReminderTargets.from(
        openTasks: [
          Task(
            id: 'L1',
            title: 'Tomorrow',
            createdAt: DateTime(2026, 10, 2),
            dueDate: DateTime(2026, 10, 3, 15),
            reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
          ),
        ],
        activeHabits: const [],
      );

      expect(fresh.shouldCancelNotification('task:L1', 7), isFalse);
    });

    test('never flags daily report, unknown, or malformed payloads', () {
      expect(targets.isOrphanPayload(null), isFalse);
      expect(targets.isOrphanPayload(''), isFalse);
      expect(targets.isOrphanPayload('habits_report'), isFalse);
      expect(targets.isOrphanPayload('habit:x'), isFalse);
      expect(targets.isOrphanPayload('task:'), isFalse);
      expect(targets.isOrphanPayload('other:1'), isFalse);
    });
  });

  group('habitReminderNotificationIds', () {
    test('matches ids used when scheduling offsets', () {
      final reminder = _reminder(
        offsets: const [
          ScheduleReminderOffset(offsetMinutes: 0),
          ScheduleReminderOffset(offsetMinutes: 15, notificationRequestId: 900),
        ],
      );

      expect(habitReminderNotificationIds(reminder), {
        501,
        505,
        900 + DateTime.monday,
        900 + DateTime.friday,
      });
    });

    test('falls back to weekday ids without offsets', () {
      expect(habitReminderNotificationIds(_reminder()), {501, 505});
    });
  });

  group('restore job habit ids', () {
    test('maps server reminder ids to local habit ids', () {
      expect(
        ReminderService.habitIdsByReminderId([
          Habit(id: 5, name: 'Walk', reminders: [_reminder(id: 300)]),
          Habit(id: 6, name: 'Read', reminders: [_reminder()]),
        ]),
        {300: 5},
      );
    });

    test('payloads use the habit id instead of the reminder id', () {
      final job = buildReminderRestoreJob(
        generalReminders: const [],
        habitReminders: [_reminder(id: 300)],
        tasks: const [],
        now: DateTime(2026, 9, 27, 7),
        habitIdByReminderId: const {300: 5},
      );
      final ops = (job['ops'] as List).cast<Map<String, Object?>>();
      final payloads = {
        for (final op in ops)
          if (op['payload'] != null) op['payload'],
      };

      expect(payloads, {'habit:5', 'habit_constant:5'});
    });
  });
}
