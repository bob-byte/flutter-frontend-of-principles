import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/reminder.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/global_reminder_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reminder JSON', () {
    test('parses UserReminderDto camelCase and TimeOnly string', () {
      final reminder = Reminder.fromJson({
        'id': 12,
        'title': 'Remember today',
        'description': 'Ada, time to note',
        'time': '07:30:00',
        'isEnabled': true,
        'userNotificationRequestId': 1,
      });

      expect(reminder.id, 12);
      expect(reminder.title, 'Remember today');
      expect(reminder.description, 'Ada, time to note');
      expect(reminder.time, const TimeOfDay(hour: 7, minute: 30));
      expect(reminder.isEnabled, isTrue);
      expect(reminder.isUnset, isFalse);
      expect(reminder.toApiJson()['time'], '07:30:00');
    });

    test('parses PascalCase empty DTO as unset', () {
      final reminder = Reminder.fromJson({
        'Id': 0,
        'Title': null,
        'Description': null,
        'Time': '00:00:00',
        'IsEnabled': false,
        'UserNotificationRequestId': 0,
      });

      expect(reminder.isUnset, isTrue);
      expect(reminder.time, const TimeOfDay(hour: 0, minute: 0));
      expect(
        reminder.userNotificationRequestId,
        kHabitsReportNotificationRequestId,
      );
    });
  });

  group('applyHabitsReportDefaults', () {
    const title = 'Remember your day';
    const body = 'time to review your goals, habits, and tasks';

    test('prefixes the user name when the server has no reminder', () {
      final result = applyHabitsReportDefaults(
        reminder: Reminder(),
        defaultTitle: title,
        defaultDescription: body,
        userName: 'Ada',
      );

      expect(result.title, title);
      expect(result.description, 'Ada, $body');
      expect(result.isEnabled, isTrue);
      expect(result.time, const TimeOfDay(hour: 7, minute: 0));
    });

    test('omits the name when it is blank', () {
      final result = applyHabitsReportDefaults(
        reminder: Reminder(),
        defaultTitle: title,
        defaultDescription: body,
        userName: '  ',
      );

      expect(result.description, body);
    });

    test('keeps server copy instead of mock defaults', () {
      final saved = Reminder(
        id: 9,
        title: 'Custom title',
        description: 'Custom body',
        time: const TimeOfDay(hour: 21, minute: 15),
        isEnabled: false,
      );

      final result = applyHabitsReportDefaults(
        reminder: saved,
        defaultTitle: title,
        defaultDescription: body,
        userName: 'Mykola',
      );

      expect(result.title, 'Custom title');
      expect(result.description, 'Custom body');
      expect(result.time, const TimeOfDay(hour: 21, minute: 15));
      expect(result.isEnabled, isFalse);
    });
  });

  group('ReminderService local cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns an unset reminder when nothing is cached', () async {
      final service = ReminderService(forceLocalOnly: true);
      final reminder = await service.habitsReportReminder();
      expect(reminder.isUnset, isTrue);
    });

    test('round-trips a saved reminder without hitting the network', () async {
      final service = ReminderService(forceLocalOnly: true);
      await service.saveHabitsReportReminder(
        Reminder(
          id: 4,
          title: 'Remember today',
          description: 'Ada, time to note',
          time: const TimeOfDay(hour: 6, minute: 45),
          isEnabled: true,
        ),
      );

      final loaded = await service.habitsReportReminder();
      expect(loaded.id, 4);
      expect(loaded.title, 'Remember today');
      expect(loaded.description, 'Ada, time to note');
      expect(loaded.time, const TimeOfDay(hour: 6, minute: 45));
      expect(loaded.isEnabled, isTrue);
    });
  });

  group('GlobalReminderViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        UserService.prefsKey: jsonEncode(User(name: 'Ada').toJson()),
      });
    });

    test('loads default copy with the current user name', () async {
      final vm = GlobalReminderViewModel(
        reminderService: ReminderService(forceLocalOnly: true),
        userService: UserService(forceLocalOnly: true),
      );

      await vm.load(
        defaultTitle: 'Remember your day',
        defaultDescription: 'time to review your goals, habits, and tasks',
      );

      expect(vm.isLoading, isFalse);
      expect(vm.reminder.title, 'Remember your day');
      expect(
        vm.reminder.description,
        'Ada, time to review your goals, habits, and tasks',
      );
      expect(vm.time, const TimeOfDay(hour: 7, minute: 0));
      expect(vm.isEnabled, isTrue);
    });

    test('save persists edited fields locally', () async {
      final service = ReminderService(forceLocalOnly: true);
      final vm = GlobalReminderViewModel(
        reminderService: service,
        userService: UserService(forceLocalOnly: true),
      );
      await vm.load(
        defaultTitle: 'Remember your day',
        defaultDescription: 'time to review your goals, habits, and tasks',
      );
      vm.setTime(const TimeOfDay(hour: 8, minute: 0));
      vm.setEnabled(false);

      final result = await vm.save(
        title: '  Evening check  ',
        description: 'Wrap up the day',
      );

      expect(result, GlobalReminderSaveResult.saved);
      final stored = await service.habitsReportReminder();
      expect(stored.title, 'Evening check');
      expect(stored.description, 'Wrap up the day');
      expect(stored.time, const TimeOfDay(hour: 8, minute: 0));
      expect(stored.isEnabled, isFalse);
    });

    test('save returns notSupported when local notifications are unavailable', () async {
      final service = ReminderService(forceLocalOnly: true)
        ..localNotificationSupportedOverride = false;
      final vm = GlobalReminderViewModel(
        reminderService: service,
        userService: UserService(forceLocalOnly: true),
      );
      await vm.load(
        defaultTitle: 'Remember your day',
        defaultDescription: 'time to review your goals, habits, and tasks',
      );
      vm.setEnabled(true);

      final result = await vm.save(
        title: 'Remember your day',
        description: 'time to review your goals, habits, and tasks',
      );

      expect(result, GlobalReminderSaveResult.notSupported);
    });
  });
}
