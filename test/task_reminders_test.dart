import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/utils/date_helpers.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/models/task_item_dto.dart';
import 'package:principles_app/models/task_priority.dart';
import 'package:principles_app/models/task_repeat_config.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/viewmodels/edit_task_viewmodel.dart';
import 'package:principles_app/viewmodels/schedule_draft.dart';
import 'package:principles_app/views/widgets/schedule/reminder_recents_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('ScheduleReminderOffset', () {
    test('round-trips JSON including notification id', () {
      const offset = ScheduleReminderOffset(
        offsetMinutes: 30,
        notificationRequestId: 42,
      );

      final decoded = ScheduleReminderOffset.fromJson(offset.toJson());
      expect(decoded.offsetMinutes, 30);
      expect(decoded.notificationRequestId, 42);
    });

    test('parses PascalCase keys from the backend', () {
      final decoded = ScheduleReminderOffset.fromJson({
        'OffsetMinutes': 1440,
        'NotificationRequestId': 7,
      });
      expect(decoded.offsetMinutes, 1440);
      expect(decoded.notificationRequestId, 7);
    });
  });

  group('ReminderService.prepareTaskNotifications', () {
    late ReminderService reminders;

    setUp(() {
      reminders = ReminderService(forceLocalOnly: true);
    });

    test('assigns notification ids to offsets that lack them', () async {
      final prepared = await reminders.prepareTaskNotifications(
        Task(
          id: '1',
          title: 'Call',
          createdAt: DateTime(2026, 9, 4),
          dueDate: DateTime(2026, 9, 10, 10),
          reminders: const [
            ScheduleReminderOffset(offsetMinutes: 0),
            ScheduleReminderOffset(offsetMinutes: 60, notificationRequestId: 9),
          ],
        ),
      );

      expect(prepared.reminders, hasLength(2));
      expect(prepared.reminders.first.notificationRequestId, isNotNull);
      expect(prepared.reminders.last.notificationRequestId, 9);
    });

    test(
      'allocates constant notification id when constant reminder is on',
      () async {
        final prepared = await reminders.prepareTaskNotifications(
          Task(
            id: '2',
            title: 'Focus',
            createdAt: DateTime(2026, 9, 4),
            dueDate: DateTime(2026, 9, 10, 9),
            reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
            constantReminder: true,
          ),
        );

        expect(prepared.constantReminder, isTrue);
        expect(prepared.constantNotificationRequestId, isNotNull);
      },
    );

    test(
      'clears constant notification id when constant reminder is off',
      () async {
        final prepared = await reminders.prepareTaskNotifications(
          Task(
            id: '3',
            title: 'Focus',
            createdAt: DateTime(2026, 9, 4),
            dueDate: DateTime(2026, 9, 10, 9),
            reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
            constantReminder: false,
            constantNotificationRequestId: 55,
          ),
        );

        expect(prepared.constantNotificationRequestId, isNull);
      },
    );

    test('syncTaskNotifications is a no-op when forceLocalOnly', () async {
      await reminders.syncTaskNotifications(
        Task(
          id: '4',
          title: 'Quiet',
          createdAt: DateTime(2026, 9, 4),
          dueDate: DateTime(2026, 9, 10, 10),
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
      );
    });
  });

  group('ScheduleDraft task defaults', () {
    test('defaults leave time and reminders empty for tasks', () {
      final draft = ScheduleDraft.defaults(showDuration: false);

      expect(draft.showDateDuration, isTrue);
      expect(draft.hasTime, isFalse);
      expect(draft.reminders, isEmpty);
      expect(draft.constantReminder, isFalse);
      expect(draft.dueDate, isNotNull);
    });

    test('selecting a date keeps time and reminders empty', () {
      final draft = ScheduleDraft.defaults(showDuration: false);
      draft.selectDate(DateTime(2026, 9, 12));

      expect(draft.dueDate, DateTime(2026, 9, 12));
      expect(draft.hasTime, isFalse);
      expect(draft.reminders, isEmpty);
    });

    test('setTime enables reminder On time by default', () {
      final draft = ScheduleDraft.defaults(showDuration: false);
      draft.selectDate(DateTime(2026, 9, 12));
      draft.setTime(const TimeOfDay(hour: 14, minute: 30));

      expect(draft.hasTime, isTrue);
      expect(draft.dueDate, DateTime(2026, 9, 12, 14, 30));
      expect(draft.reminders.map((e) => e.offsetMinutes), [0]);
    });

    test('clearTime removes reminders and constant flag', () {
      final draft = ScheduleDraft.defaults(showDuration: false);
      draft.setTime(const TimeOfDay(hour: 10, minute: 0));
      draft.setConstantReminder(true);
      draft.clearTime();

      expect(draft.hasTime, isFalse);
      expect(draft.reminders, isEmpty);
      expect(draft.constantReminder, isFalse);
    });

    test('setReminders without time defaults to nearest next hour', () {
      final draft = ScheduleDraft.defaults(showDuration: false);
      draft.selectDate(DateTime(2026, 9, 12));
      draft.setReminders(const [ScheduleReminderOffset(offsetMinutes: 0)]);

      final expected = nearestNextHour();
      expect(draft.hasTime, isTrue);
      expect(draft.dueDate!.hour, expected.hour);
      expect(draft.dueDate!.minute, 0);
      expect(draft.dueDate!.day, 12);
    });
  });

  group('nearestNextHour', () {
    test('rounds partial hour up', () {
      expect(
        nearestNextHour(DateTime(2026, 9, 8, 19, 24)),
        DateTime(2026, 9, 8, 20),
      );
    });

    test('keeps exact hour', () {
      expect(
        nearestNextHour(DateTime(2026, 9, 8, 19)),
        DateTime(2026, 9, 8, 19),
      );
    });

    test('rolls to next day after 23', () {
      expect(
        nearestNextHour(DateTime(2026, 9, 8, 23, 15)),
        DateTime(2026, 9, 9, 0),
      );
    });
  });

  group('EditTaskViewModel schedule reminders', () {
    late EditTaskViewModel vm;

    setUp(() {
      vm = EditTaskViewModel(
        TaskService(apiClient: ApiClient(SecureStore()), taskDb: null),
        reminderService: ReminderService(forceLocalOnly: true),
      );
    });

    test('applySchedule stores multi reminders and constant flag', () {
      final draft = ScheduleDraft(
        showDuration: false,
        dueDate: DateTime(2026, 9, 15, 8, 0),
        hasTime: true,
        reminders: const [
          ScheduleReminderOffset(offsetMinutes: 0),
          ScheduleReminderOffset(offsetMinutes: 30),
        ],
        constantReminder: true,
        repeat: TaskRepeatConfig.daily(),
      );

      vm.applySchedule(draft);

      expect(vm.hasDueDate, isTrue);
      expect(vm.dueDate, DateTime(2026, 9, 15, 8, 0));
      expect(vm.reminders.map((e) => e.offsetMinutes), [0, 30]);
      expect(vm.constantReminder, isTrue);
      expect(vm.repeat.preset, TaskRepeatPreset.daily);
    });

    test('applySchedule clear empties reminders', () {
      vm.applySchedule(
        ScheduleDraft(
          dueDate: DateTime(2026, 9, 15, 8),
          hasTime: true,
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
      );
      vm.applySchedule(ScheduleDraft(showDuration: false)..clear());

      expect(vm.hasDueDate, isFalse);
      expect(vm.reminders, isEmpty);
      expect(vm.constantReminder, isFalse);
    });

    test('toScheduleDraft preserves reminders when editing', () {
      vm.applySchedule(
        ScheduleDraft(
          showDuration: false,
          dueDate: DateTime(2026, 9, 15, 9, 15),
          hasTime: true,
          reminders: const [
            ScheduleReminderOffset(offsetMinutes: 5),
            ScheduleReminderOffset(offsetMinutes: 60),
          ],
          constantReminder: true,
        ),
      );

      final draft = vm.toScheduleDraft();
      expect(draft.hasTime, isTrue);
      expect(draft.reminders.map((e) => e.offsetMinutes), [5, 60]);
      expect(draft.constantReminder, isTrue);
    });
    test('load uses seed when storage lookup misses', () async {
      await vm.load(
        taskId: 'missing-local-id',
        seed: Task(
          id: 'missing-local-id',
          title: 'From list',
          description: 'Seeded body',
          priority: TaskPriority.high,
          createdAt: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 9, 5),
        ),
      );

      expect(vm.editingId, 'missing-local-id');
      expect(vm.title, 'From list');
      expect(vm.description, 'Seeded body');
      expect(vm.priority, TaskPriority.high);
      expect(vm.hasDueDate, isTrue);
    });
  });

  group('TaskItemDto reminder encoding', () {
    test('date-only task omits time and reminders stay empty', () {
      final dto = TaskItemDto.fromTask(
        Task(
          id: '11',
          title: 'Ship',
          createdAt: DateTime(2026, 9, 4),
          dueDate: DateTime(2026, 9, 20),
        ),
      );

      expect(dto.date, '2026-09-20');
      expect(dto.time, isNull);
      expect(dto.reminders, isEmpty);
      expect(dto.toJson().containsKey('repeat'), isFalse);
    });

    test('timed task with reminders encodes offsets', () {
      final dto = TaskItemDto.fromTask(
        Task(
          id: '12',
          title: 'Dentist',
          createdAt: DateTime(2026, 9, 4),
          dueDate: DateTime(2026, 9, 20, 16, 0),
          reminders: const [
            ScheduleReminderOffset(offsetMinutes: 0),
            ScheduleReminderOffset(
              offsetMinutes: 1440,
              notificationRequestId: 3,
            ),
          ],
          constantReminder: true,
          constantNotificationRequestId: 88,
        ),
      );

      final json = dto.toJson();
      expect(json['time'], '16:00:00');
      expect(json['constantReminder'], isTrue);
      expect(json['constantNotificationRequestId'], 88);
      expect(json['reminders'], [
        {'offsetMinutes': 0},
        {'offsetMinutes': 1440, 'notificationRequestId': 3},
      ]);
    });
  });

  group('ReminderRecentsStore', () {
    test('keeps newest unique offsets and caps at five', () async {
      await ReminderRecentsStore.add(20);
      await ReminderRecentsStore.add(30);
      await ReminderRecentsStore.add(20);
      await ReminderRecentsStore.add(40);
      await ReminderRecentsStore.add(50);
      await ReminderRecentsStore.add(60);
      await ReminderRecentsStore.add(70);

      expect(await ReminderRecentsStore.load(), [70, 60, 50, 40, 20]);
    });
  });
}
