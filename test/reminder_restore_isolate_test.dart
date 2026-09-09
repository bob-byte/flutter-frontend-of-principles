import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/deep_link/notification_payload.dart';
import 'package:principles_app/core/reminder/reminder_restore_isolate.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/models/reminder.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/models/task.dart';

void main() {
  test('buildReminderRestoreJob emits daily, weekly, and task ops', () {
    final now = DateTime(2026, 3, 9, 10, 0); // Monday
    final job = buildReminderRestoreJob(
      generalReminders: [
        Reminder(
          title: 'Habits report',
          description: 'Check in',
          time: const TimeOfDay(hour: 7, minute: 30),
          isEnabled: true,
          userNotificationRequestId: kHabitsReportNotificationRequestId,
        ),
      ],
      habitReminders: [
        HabitReminder(
          id: 42,
          title: 'Walk',
          description: 'Outside',
          time: const TimeOfDay(hour: 8, minute: 0),
          isEnabled: true,
          daysOfWeek: [
            WeekDay(type: DateTime.monday, userNotificationRequestId: 101),
          ],
          offsets: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
      ],
      tasks: [
        Task(
          id: 't1',
          title: 'Call',
          description: '',
          createdAt: now,
          dueDate: now.add(const Duration(days: 1)),
          reminders: const [
            ScheduleReminderOffset(
              offsetMinutes: 30,
              notificationRequestId: 501,
            ),
          ],
        ),
      ],
      now: now,
    );

    expect(job['timezone'], kReminderRestoreTimezone);
    final ops = (job['ops'] as List).cast<Map>();
    expect(ops.any((op) => op['type'] == 'daily' && op['id'] == 1), isTrue);
    expect(
      ops.any(
        (op) =>
            op['type'] == 'weekly' &&
            op['weekday'] == DateTime.monday &&
            op['payload'] == '${NotificationPayloads.habit}42',
      ),
      isTrue,
    );
    expect(
      ops.any(
        (op) =>
            op['type'] == 'oneShot' &&
            op['id'] == 501 &&
            op['payload'] == '${NotificationPayloads.task}t1',
      ),
      isTrue,
    );
  });
}
