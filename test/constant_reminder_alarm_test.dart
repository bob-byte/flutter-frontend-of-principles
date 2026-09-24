import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/reminder/constant_reminder_alarm.dart';
import 'package:principles_app/models/habit_reminder.dart';

void main() {
  group('constantAlarmFireTime', () {
    test('keeps a future scheduled time', () {
      final now = DateTime(2026, 9, 15, 10);
      final scheduled = DateTime(2026, 9, 15, 18);
      expect(constantAlarmFireTime(scheduled: scheduled, now: now), scheduled);
    });

    test('rings soon when the scheduled time has passed', () {
      final now = DateTime(2026, 9, 15, 18, 5);
      final scheduled = DateTime(2026, 9, 15, 18);
      expect(
        constantAlarmFireTime(scheduled: scheduled, now: now),
        now.add(kConstantReminderSoon),
      );
    });
  });

  group('nextConstantHabitFire', () {
    final reminder = HabitReminder(
      title: 'Walk',
      description: '',
      time: const TimeOfDay(hour: 8, minute: 0),
      isEnabled: true,
      daysOfWeek: [
        WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
      ],
    );

    test('uses today’s reminder time when it is still ahead', () {
      final now = DateTime(2026, 3, 9, 7, 0); // Monday
      expect(
        nextConstantHabitFire(
          reminders: [reminder],
          now: now,
          satisfiedToday: false,
        ),
        DateTime(2026, 3, 9, 8),
      );
    });

    test('rings soon when today’s slot passed and the habit is open', () {
      final now = DateTime(2026, 3, 9, 9, 0); // Monday after 8:00
      expect(
        nextConstantHabitFire(
          reminders: [reminder],
          now: now,
          satisfiedToday: false,
        ),
        now.add(kConstantReminderSoon),
      );
    });

    test(
      'skips to next week when today’s slot passed and the habit is done',
      () {
        final now = DateTime(2026, 3, 9, 9, 0);
        expect(
          nextConstantHabitFire(
            reminders: [reminder],
            now: now,
            satisfiedToday: true,
          ),
          DateTime(2026, 3, 16, 8),
        );
      },
    );
  });
}
