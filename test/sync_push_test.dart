import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/push/reminder_target_index.dart';
import 'package:principles_app/core/push/sync_push_message.dart';
import 'package:principles_app/core/reminder/reminder_schedule_change.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncPushMessage', () {
    test('parses deleted ids from the FCM data map', () {
      final push = SyncPushMessage.tryParse({
        'type': 'sync',
        'deletedTaskIds': '7, 8,x,-1',
        'deletedHabitIds': '',
      });

      expect(push!.deletedTaskIds, [7, 8]);
      expect(push.deletedHabitIds, isEmpty);
    });

    test('ignores other message types', () {
      expect(SyncPushMessage.tryParse({'type': 'chat'}), isNull);
      expect(SyncPushMessage.tryParse({}), isNull);
    });

    test('round-trips through toData', () {
      const push = SyncPushMessage(
        deletedTaskIds: [3],
        deletedHabitIds: [4, 5],
      );

      final parsed = SyncPushMessage.tryParse(push.toData())!;

      expect(parsed.deletedTaskIds, [3]);
      expect(parsed.deletedHabitIds, [4, 5]);
    });
  });

  group('ReminderTargetIndex', () {
    final tasks = [
      Task(id: 'L1', serverId: 7, title: 'Call', createdAt: DateTime(2026)),
      Task(id: 'L2', title: 'Local only', createdAt: DateTime(2026)),
    ];
    final habits = [
      Habit(
        id: 5,
        serverId: 50,
        name: 'Walk',
        reminders: [_habitReminder(id: 80), _habitReminder(id: 6)],
      ),
      Habit(id: 6, name: 'Local habit'),
    ];

    test('maps server ids to the payload ids used on this device', () {
      final index = ReminderTargetIndex.build(
        openTasks: tasks,
        activeHabits: habits,
      );

      expect(index.tasks, {
        7: {'L1', '7'},
      });
      // Reminder id 6 collides with another habit's local id.
      expect(index.habits, {
        50: {5, 80},
      });
    });

    test('resolves payloads for remote-deleted ids', () {
      final index = ReminderTargetIndex.build(
        openTasks: tasks,
        activeHabits: habits,
      );

      final payloads = index.payloadsForDeleted(
        taskIds: [7, 9],
        habitIds: [50, 5, 99],
      );

      expect(payloads, {
        'task:L1',
        'task_constant:L1',
        'task:7',
        'task_constant:7',
        'task:9',
        'task_constant:9',
        'habit:5',
        'habit_constant:5',
        'habit:80',
        'habit_constant:80',
        'habit:99',
        'habit_constant:99',
      });
    });

    test('survives a save/load round trip', () async {
      SharedPreferences.setMockInitialValues({});
      await ReminderTargetIndex.save(openTasks: tasks, activeHabits: habits);

      final loaded = await ReminderTargetIndex.load();

      expect(loaded.tasks, {
        7: {'L1', '7'},
      });
      expect(loaded.habits, {
        50: {5, 80},
      });
    });
  });

  group('reminder schedule change', () {
    Task task({DateTime? due, int offset = 10, bool isDone = false}) => Task(
      id: '7',
      title: 'Call',
      createdAt: DateTime(2026),
      dueDate: due ?? DateTime(2026, 9, 10, 9),
      isDone: isDone,
      reminders: [
        ScheduleReminderOffset(offsetMinutes: offset, notificationRequestId: 1),
      ],
    );

    test('flags task time, offset, and completion changes', () {
      expect(taskReminderScheduleChanged(task(), task()), isFalse);
      expect(
        taskReminderScheduleChanged(
          task(),
          task(due: DateTime(2026, 9, 10, 10)),
        ),
        isTrue,
      );
      expect(taskReminderScheduleChanged(task(), task(offset: 30)), isTrue);
      expect(taskReminderScheduleChanged(task(), task(isDone: true)), isTrue);
    });

    test('flags only new tasks that would notify', () {
      expect(taskReminderScheduleChanged(null, task()), isTrue);
      expect(taskReminderScheduleChanged(null, task(isDone: true)), isFalse);
      expect(
        taskReminderScheduleChanged(
          null,
          Task(id: '8', title: 'No reminders', createdAt: DateTime(2026)),
        ),
        isFalse,
      );
    });

    test('flags habit reminder edits', () {
      Habit habit({int hour = 8, bool enabled = true}) => Habit(
        id: 5,
        name: 'Walk',
        reminders: [_habitReminder(id: 5, hour: hour, enabled: enabled)],
      );

      expect(habitReminderScheduleChanged(habit(), habit()), isFalse);
      expect(habitReminderScheduleChanged(habit(), habit(hour: 9)), isTrue);
      expect(habitReminderScheduleChanged(null, habit()), isTrue);
      expect(
        habitReminderScheduleChanged(null, habit(enabled: false)),
        isFalse,
      );
    });
  });
}

HabitReminder _habitReminder({
  required int id,
  int hour = 8,
  bool enabled = true,
}) => HabitReminder(
  id: id,
  title: 'Walk',
  description: '',
  time: TimeOfDay(hour: hour, minute: 0),
  isEnabled: enabled,
  daysOfWeek: [WeekDay(type: 1, userNotificationRequestId: 100 + id)],
);
