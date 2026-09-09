import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/sync/sync_bootstrap_snapshot.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/models/reminder.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('fromDotNetDayOfWeek', () {
    test('maps Sunday 0 to DateTime.sunday', () {
      expect(fromDotNetDayOfWeek(0), DateTime.sunday);
      expect(fromDotNetDayOfWeek(1), DateTime.monday);
      expect(fromDotNetDayOfWeek(6), DateTime.saturday);
      expect(toDotNetDayOfWeek(DateTime.sunday), 0);
    });
  });

  group('AllRemindersResponse', () {
    test('parses general and habit reminders (camelCase)', () {
      final parsed = AllRemindersResponse.fromJson({
        'generalReminders': [
          {
            'id': 1,
            'title': 'Habits report',
            'description': 'Check in',
            'time': '07:00:00',
            'isEnabled': true,
            'userNotificationRequestId': 1,
          },
        ],
        'userHabitReminders': [
          {
            'id': 42,
            'title': 'Walk',
            'description': 'Go outside',
            'time': '08:30:00',
            'isEnabled': true,
            'daysOfWeek': [
              {'type': 1, 'userNotificationRequestId': 101},
              {'type': 0, 'userNotificationRequestId': 102},
            ],
            'offsets': [
              {'offsetMinutes': 0, 'notificationRequestId': 200},
            ],
            'constantReminder': false,
          },
        ],
      });

      expect(parsed.generalReminders, hasLength(1));
      expect(parsed.generalReminders.single.isEnabled, isTrue);
      expect(
        parsed.generalReminders.single.time,
        const TimeOfDay(hour: 7, minute: 0),
      );

      expect(parsed.userHabitReminders, hasLength(1));
      final habit = parsed.userHabitReminders.single;
      expect(habit.id, 42);
      expect(habit.title, 'Walk');
      expect(habit.time, const TimeOfDay(hour: 8, minute: 30));
      expect(habit.daysOfWeek.map((d) => d.type), [
        DateTime.monday,
        DateTime.sunday,
      ]);
      expect(habit.offsets, hasLength(1));
      expect(habit.offsets.single.offsetMinutes, 0);
      expect(habit.offsets.single.notificationRequestId, 200);
    });

    test('parses PascalCase DayOfWeek names', () {
      final habit = HabitReminder.fromApiJson({
        'Id': 7,
        'Title': 'Read',
        'Description': '',
        'Time': '21:00:00',
        'IsEnabled': true,
        'DaysOfWeek': [
          {'Type': 'Wednesday', 'UserNotificationRequestId': 55},
        ],
      });

      expect(habit.daysOfWeek.single.type, DateTime.wednesday);
      expect(habit.daysOfWeek.single.userNotificationRequestId, 55);
    });
  });

  group('SyncBootstrapSnapshot reminders', () {
    test('parses generalReminders and userHabitReminders from bootstrap', () {
      final snapshot = SyncBootstrapSnapshot.fromJson({
        'habitsReportReminder': {
          'id': 1,
          'title': 'Habits report',
          'time': '07:00:00',
          'isEnabled': true,
          'userNotificationRequestId': 1,
        },
        'generalReminders': [
          {
            'id': 1,
            'title': 'Habits report',
            'time': '07:00:00',
            'isEnabled': true,
            'userNotificationRequestId': 1,
          },
        ],
        'userHabitReminders': [
          {
            'id': 42,
            'title': 'Walk',
            'time': '08:30:00',
            'isEnabled': true,
            'daysOfWeek': [
              {'type': 1, 'userNotificationRequestId': 101},
            ],
          },
        ],
      });

      expect(snapshot.remindersProvided, isTrue);
      expect(snapshot.reminders.generalReminders, hasLength(1));
      expect(snapshot.reminders.userHabitReminders, hasLength(1));
      expect(snapshot.reminders.userHabitReminders.single.id, 42);
    });

    test('leaves remindersProvided false when keys are omitted', () {
      final snapshot = SyncBootstrapSnapshot.fromJson({
        'goals': [
          {'id': 1, 'name': 'Health'},
        ],
      });
      expect(snapshot.remindersProvided, isFalse);
      expect(snapshot.reminders.generalReminders, isEmpty);
    });
  });

  group('ReminderService.rememberBootstrapReminders', () {
    test('stores bootstrap lists for SyncGate restore', () {
      final service = ReminderService(forceLocalOnly: true);
      service.rememberBootstrapReminders(
        AllRemindersResponse(
          generalReminders: [
            Reminder(
              id: 1,
              title: 'Habits report',
              description: '',
              time: const TimeOfDay(hour: 7, minute: 0),
              isEnabled: true,
              userNotificationRequestId: 1,
            ),
          ],
        ),
      );
      expect(service.bootstrapRemindersForTest?.generalReminders, hasLength(1));
    });

    test('clearBootstrapReminders drops the stash', () {
      final service = ReminderService(forceLocalOnly: true);
      service.rememberBootstrapReminders(
        const AllRemindersResponse(
          generalReminders: [],
        ),
      );
      service.clearBootstrapReminders();
      expect(service.bootstrapRemindersForTest, isNull);
    });
  });

  group('SyncBootstrapSnapshot changes', () {
    test('parses delta flags and deleted ids without prune trust', () {
      final snapshot = SyncBootstrapSnapshot.fromChangesJson({
        'serverTime': '2026-09-09T12:00:00Z',
        'requiresFullBootstrap': false,
        'goals': [
          {'id': 1, 'name': 'Health', 'lastModified': '2026-09-09T11:00:00Z'},
        ],
        'tasks': [
          {'id': 9, 'name': 'Call'},
        ],
        'deletedGoalIds': [3],
        'deletedHabitIds': [4],
        'deletedTaskIds': [5],
        'deletedConversationIds': [6],
      });

      expect(snapshot.isDelta, isTrue);
      expect(snapshot.requiresFullBootstrap, isFalse);
      expect(snapshot.tasksTrustedForPrune, isFalse);
      expect(snapshot.goals, hasLength(1));
      expect(snapshot.deletedGoalIds, [3]);
      expect(snapshot.deletedHabitIds, [4]);
      expect(snapshot.deletedTaskIds, [5]);
      expect(snapshot.deletedConversationIds, [6]);
      expect(snapshot.serverTime, isNotNull);
    });

    test('honors requiresFullBootstrap', () {
      final snapshot = SyncBootstrapSnapshot.fromChangesJson({
        'serverTime': '2026-09-09T12:00:00Z',
        'requiresFullBootstrap': true,
      });
      expect(snapshot.requiresFullBootstrap, isTrue);
      expect(snapshot.isDelta, isTrue);
      expect(snapshot.goals, isEmpty);
    });
  });

  group('ReminderService.tryToRecoverAllUserReminders', () {
    test('is a no-op when forceLocalOnly', () async {
      var explained = false;
      final service = ReminderService(forceLocalOnly: true);
      await service.tryToRecoverAllUserReminders(
        knownTasks: const [],
        onExplainRestore: () async => explained = true,
      );
      expect(explained, isFalse);
    });
  });

  group('NotificationPermissionGate', () {
    test('returns the cached grant without calling native again', () async {
      var nativeCalls = 0;
      final gate = NotificationPermissionGate();

      Future<bool> native() async {
        nativeCalls += 1;
        return true;
      }

      expect(await gate.run(native), isTrue);
      expect(await gate.run(native), isTrue);
      expect(nativeCalls, 1);
    });

    test('joins an in-flight native request', () async {
      var nativeCalls = 0;
      final started = Completer<void>();
      final release = Completer<bool>();
      final gate = NotificationPermissionGate();

      Future<bool> native() async {
        nativeCalls += 1;
        started.complete();
        return release.future;
      }

      final first = gate.run(native);
      await started.future;
      final second = gate.run(native);
      release.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(nativeCalls, 1);
    });
  });

  group('mergeHabitRemindersFromLocal', () {
    test('fills API gaps from hydrated local habits', () {
      final merged = ReminderService.mergeHabitRemindersFromLocalForTest(
        const [],
        [
          Habit(
            id: 9,
            name: 'Walk',
            reminders: [
              HabitReminder(
                id: 9,
                title: '',
                description: '',
                time: const TimeOfDay(hour: 8, minute: 0),
                isEnabled: true,
                daysOfWeek: [
                  WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
                ],
              ),
            ],
          ),
        ],
      );
      expect(merged, hasLength(1));
      expect(merged.single.id, 9);
      expect(merged.single.title, 'Walk');
    });
  });
}
