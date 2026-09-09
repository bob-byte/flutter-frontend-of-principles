import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/edit_habit_viewmodel.dart';
import 'package:principles_app/viewmodels/schedule_draft.dart';
import 'package:principles_app/views/widgets/schedule/schedule_format.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HabitReminder model', () {
    test('round-trips offsets and constant reminder fields', () {
      final reminder = HabitReminder(
        id: 3,
        title: 'Stretch',
        description: 'Neck',
        time: const TimeOfDay(hour: 7, minute: 45),
        isEnabled: true,
        daysOfWeek: [
          WeekDay(type: DateTime.monday, userNotificationRequestId: 11),
          WeekDay(type: DateTime.wednesday, userNotificationRequestId: 12),
        ],
        offsets: const [
          ScheduleReminderOffset(offsetMinutes: 0),
          ScheduleReminderOffset(offsetMinutes: 15, notificationRequestId: 99),
        ],
        constantReminder: true,
        constantNotificationRequestId: 44,
        allDay: false,
      );

      final copy = HabitReminder.fromMap(reminder.toMap());
      expect(copy.id, 3);
      expect(copy.time, const TimeOfDay(hour: 7, minute: 45));
      expect(copy.offsets.map((e) => e.offsetMinutes), [0, 15]);
      expect(copy.offsets.last.notificationRequestId, 99);
      expect(copy.constantReminder, isTrue);
      expect(copy.constantNotificationRequestId, 44);
      expect(copy.daysOfWeek.map((d) => d.type), [
        DateTime.monday,
        DateTime.wednesday,
      ]);
    });
  });

  group('ScheduleDraft.fromHabit', () {
    test('loads time, offsets, and constant without date duration', () {
      final habit = Habit(
        id: 1,
        name: 'Read',
        constantReminder: true,
        reminders: [
          HabitReminder(
            title: 'Read goal',
            description: 'Evening chapter',
            time: const TimeOfDay(hour: 21, minute: 0),
            isEnabled: true,
            daysOfWeek: [
              WeekDay(type: DateTime.tuesday, userNotificationRequestId: 1),
            ],
            offsets: const [
              ScheduleReminderOffset(offsetMinutes: 0),
              ScheduleReminderOffset(offsetMinutes: 30),
            ],
            constantReminder: true,
          ),
        ],
      );

      final draft = ScheduleDraft.fromHabit(habit);
      expect(draft.showDateDuration, isFalse);
      expect(draft.showRepeat, isFalse);
      expect(draft.hasTime, isTrue);
      expect(draft.dueDate?.hour, 21);
      expect(draft.reminders.map((e) => e.offsetMinutes), [0, 30]);
      expect(draft.constantReminder, isTrue);
      expect(draft.habitTimeSlots, hasLength(1));
      expect(draft.habitTimeSlots.single.weekdays, {DateTime.tuesday});
      expect(draft.notificationTitle, 'Read goal');
      expect(draft.notificationDescription, 'Evening chapter');
    });

    test('loads a separate time slot per weekday group', () {
      final habit = Habit(
        name: 'Train',
        reminders: [
          HabitReminder(
            title: 'Train',
            description: '',
            time: const TimeOfDay(hour: 7, minute: 0),
            isEnabled: true,
            daysOfWeek: [
              WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
              WeekDay(type: DateTime.wednesday, userNotificationRequestId: 2),
              WeekDay(type: DateTime.friday, userNotificationRequestId: 3),
            ],
          ),
          HabitReminder(
            title: 'Train',
            description: '',
            time: const TimeOfDay(hour: 10, minute: 0),
            isEnabled: true,
            daysOfWeek: [
              WeekDay(type: DateTime.saturday, userNotificationRequestId: 4),
              WeekDay(type: DateTime.sunday, userNotificationRequestId: 5),
            ],
          ),
        ],
      );

      final draft = ScheduleDraft.fromHabit(habit);
      expect(draft.habitTimeSlots, hasLength(2));
      expect(draft.habitTimeSlots[0].time, const TimeOfDay(hour: 7, minute: 0));
      expect(draft.habitTimeSlots[0].weekdays, {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
      expect(
        draft.habitTimeSlots[1].time,
        const TimeOfDay(hour: 10, minute: 0),
      );
      expect(draft.habitTimeSlots[1].weekdays, {
        DateTime.saturday,
        DateTime.sunday,
      });
    });

    test('moving a weekday assigns it to only one time', () {
      final draft = ScheduleDraft.defaults(showDateDuration: false);
      draft.addTimeSlot();
      expect(draft.habitTimeSlots, hasLength(2));
      draft.toggleSlotDay(1, DateTime.saturday);
      expect(
        draft.habitTimeSlots[0].weekdays.contains(DateTime.saturday),
        isFalse,
      );
      expect(
        draft.habitTimeSlots[1].weekdays.contains(DateTime.saturday),
        isTrue,
      );
    });
  });

  group('formatHabitReminderSummary', () {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    test('omits days when every weekday shares one time', () {
      final summary = formatHabitReminderSummary([
        HabitReminder(
          title: 'Walk',
          description: '',
          time: const TimeOfDay(hour: 10, minute: 0),
          isEnabled: true,
          daysOfWeek: [
            for (var d = 1; d <= 7; d++)
              WeekDay(type: d, userNotificationRequestId: d),
          ],
        ),
      ], labels);
      expect(summary, '10:00');
    });

    test('shows each time with its days', () {
      final summary = formatHabitReminderSummary([
        HabitReminder(
          title: 'Train',
          description: '',
          time: const TimeOfDay(hour: 7, minute: 0),
          isEnabled: true,
          daysOfWeek: [
            WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
            WeekDay(type: DateTime.wednesday, userNotificationRequestId: 2),
            WeekDay(type: DateTime.friday, userNotificationRequestId: 3),
          ],
        ),
        HabitReminder(
          title: 'Train',
          description: '',
          time: const TimeOfDay(hour: 10, minute: 0),
          isEnabled: true,
          daysOfWeek: [
            WeekDay(type: DateTime.saturday, userNotificationRequestId: 4),
            WeekDay(type: DateTime.sunday, userNotificationRequestId: 5),
          ],
        ),
      ], labels);
      expect(summary, '07:00 Mon, Wed, Fri, 10:00 Sat, Sun');
    });
  });

  group('EditHabitViewModel.applySchedule', () {
    late EditHabitViewModel vm;
    late DatabaseService db;
    late LocalDb localDb;
    late String dbPath;

    setUp(() async {
      final created = await createTestDatabaseService();
      db = created.db;
      localDb = created.localDb;
      dbPath = created.path;
      final auth = AuthService(
        _TokenStore(),
        dio: Dio()..httpClientAdapter = _Noop(),
      );
      final api = ApiClient(
        _TokenStore(),
        dio: Dio()..httpClientAdapter = _Noop(),
      );
      vm = EditHabitViewModel(
        HabitService(auth),
        ReminderService(forceLocalOnly: true),
        GoalService(auth),
        AiRecommendationService(api),
        UserService(forceLocalOnly: true),
        dbService: db,
      )..init(null);
      vm.habitName = 'Meditate';
    });

    tearDown(() async {
      await disposeTestDatabase(localDb: localDb, path: dbPath);
    });

    test('applies time, multi offsets, and constant reminder', () {
      final draft = ScheduleDraft(
        showRepeat: false,
        showDateDuration: false,
        dueDate: DateTime(2026, 9, 4, 6, 30),
        hasTime: true,
        reminders: const [
          ScheduleReminderOffset(offsetMinutes: 0),
          ScheduleReminderOffset(offsetMinutes: 10),
        ],
        constantReminder: true,
      );

      vm.applySchedule(draft);

      expect(vm.reminders, hasLength(1));
      final reminder = vm.reminders.single;
      expect(reminder.time, const TimeOfDay(hour: 6, minute: 30));
      expect(reminder.isEnabled, isTrue);
      expect(reminder.offsets.map((e) => e.offsetMinutes), [0, 10]);
      expect(
        reminder.offsets.every((e) => e.notificationRequestId != null),
        isTrue,
      );
      expect(reminder.daysOfWeek, hasLength(7));
      expect(reminder.constantReminder, isTrue);
      expect(vm.constantReminder, isTrue);
      expect(vm.endDate, isNull);
      expect(vm.allDay, isFalse);
      // Empty draft copy → title falls back to Reminder, description to habit name.
      expect(reminder.title, 'Reminder');
      expect(reminder.description, 'Meditate');
    });

    test('applies custom notification title and description', () {
      final draft = ScheduleDraft(
        showRepeat: false,
        showDateDuration: false,
        dueDate: DateTime(2026, 9, 4, 8),
        hasTime: true,
        reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        notificationTitle: '  Stay focused  ',
        notificationDescription: '  Five minutes  ',
      );

      vm.targetGoal = 'Deep work';
      vm.applySchedule(draft, reminderFallbackTitle: 'Reminder');

      expect(vm.reminders.single.title, 'Stay focused');
      expect(vm.reminders.single.description, 'Five minutes');
    });

    test('empty title falls back to goal then Reminder label', () {
      vm.targetGoal = 'Health';
      vm.applySchedule(
        ScheduleDraft(
          showDateDuration: false,
          dueDate: DateTime(2026, 9, 4, 8),
          hasTime: true,
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
        reminderFallbackTitle: 'Reminder',
      );
      expect(vm.reminders.single.title, 'Health');
      expect(vm.reminders.single.description, 'Meditate');

      vm.targetGoal = '';
      vm.applySchedule(
        ScheduleDraft(
          showDateDuration: false,
          dueDate: DateTime(2026, 9, 4, 9),
          hasTime: true,
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
          notificationTitle: '',
          notificationDescription: '',
        ),
        reminderFallbackTitle: 'Reminder',
      );
      expect(vm.reminders.single.title, 'Reminder');
      expect(vm.reminders.single.description, 'Meditate');
    });

    test('seedReminderCopyDefaults fills goal and habit name', () async {
      vm.targetGoal = 'Fitness';
      vm.habitName = 'Push-ups';
      final draft = ScheduleDraft.defaults(
        showRepeat: false,
        showDateDuration: false,
      );

      await vm.seedReminderCopyDefaults(
        draft,
        personalityFallbackTitle: 'Become a true personality',
      );

      expect(draft.notificationTitle, 'Fitness');
      expect(draft.notificationDescription, 'Push-ups');
    });

    test('seedReminderCopyDefaults keeps existing copy', () async {
      final draft = ScheduleDraft(
        showDateDuration: false,
        notificationTitle: 'Custom',
        notificationDescription: 'Body',
      );
      vm.targetGoal = 'Ignored';
      vm.habitName = 'Ignored';

      await vm.seedReminderCopyDefaults(
        draft,
        personalityFallbackTitle: 'Become a true personality',
      );

      expect(draft.notificationTitle, 'Custom');
      expect(draft.notificationDescription, 'Body');
    });

    test('clearing schedule removes reminders', () {
      vm.applySchedule(
        ScheduleDraft(
          showDateDuration: false,
          dueDate: DateTime(2026, 9, 4, 8),
          hasTime: true,
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
      );
      vm.applySchedule(ScheduleDraft(showDateDuration: false)..clear());

      expect(vm.reminders, isEmpty);
      expect(vm.constantReminder, isFalse);
    });

    test('preserves existing weekday notification ids on re-apply', () {
      vm.applySchedule(
        ScheduleDraft(
          showDateDuration: false,
          dueDate: DateTime(2026, 9, 4, 8),
          hasTime: true,
          reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        ),
      );
      final firstIds = vm.reminders.single.daysOfWeek
          .map((d) => d.userNotificationRequestId)
          .toList();

      vm.applySchedule(
        ScheduleDraft(
          showDateDuration: false,
          dueDate: DateTime(2026, 9, 4, 9),
          hasTime: true,
          reminders: const [
            ScheduleReminderOffset(offsetMinutes: 0),
            ScheduleReminderOffset(offsetMinutes: 5),
          ],
        ),
      );

      expect(
        vm.reminders.single.daysOfWeek.map((d) => d.userNotificationRequestId),
        firstIds,
      );
      expect(vm.reminders.single.time, const TimeOfDay(hour: 9, minute: 0));
      expect(vm.reminders.single.offsets.map((e) => e.offsetMinutes), [0, 5]);
    });

    test('stores a different time per weekday group', () {
      final draft = ScheduleDraft(
        showRepeat: false,
        showDateDuration: false,
        hasTime: true,
        reminders: const [ScheduleReminderOffset(offsetMinutes: 0)],
        timeSlots: [
          HabitTimeSlot(
            time: const TimeOfDay(hour: 7, minute: 0),
            weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
          ),
          HabitTimeSlot(
            time: const TimeOfDay(hour: 10, minute: 0),
            weekdays: {DateTime.saturday, DateTime.sunday},
          ),
        ],
      );

      vm.applySchedule(draft);

      expect(vm.reminders, hasLength(2));
      expect(vm.reminders[0].time, const TimeOfDay(hour: 7, minute: 0));
      expect(vm.reminders[0].daysOfWeek.map((d) => d.type), [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      ]);
      expect(vm.reminders[1].time, const TimeOfDay(hour: 10, minute: 0));
      expect(vm.reminders[1].daysOfWeek.map((d) => d.type), [
        DateTime.saturday,
        DateTime.sunday,
      ]);
    });
  });

  group('Habit reminder API DTO', () {
    test('serializes offsets and constant reminder flags', () {
      final dto = buildEditUserHabitDto(
        Habit(
          name: 'Journal',
          constantReminder: true,
          reminders: [
            HabitReminder(
              title: 'Write',
              description: 'One page',
              time: const TimeOfDay(hour: 8, minute: 5),
              isEnabled: true,
              daysOfWeek: [
                WeekDay(type: DateTime.monday, userNotificationRequestId: 100),
              ],
              offsets: const [
                ScheduleReminderOffset(offsetMinutes: 0),
                ScheduleReminderOffset(
                  offsetMinutes: 60,
                  notificationRequestId: 5,
                ),
              ],
              constantReminder: true,
              constantNotificationRequestId: 77,
            ),
          ],
        ),
        isNew: true,
      );

      expect(dto['constantReminder'], isTrue);
      final reminders = dto['reminders'] as List<Map<String, dynamic>>;
      expect(reminders, hasLength(1));
      expect(reminders.first['constantReminder'], isTrue);
      expect(reminders.first['constantNotificationRequestId'], 77);
      expect(reminders.first['offsets'], [
        {'offsetMinutes': 0},
        {'offsetMinutes': 60, 'notificationRequestId': 5},
      ]);
    });

    test('skips reminder entries without title or weekdays', () {
      final dto = buildEditUserHabitDto(
        Habit(
          name: 'Broken',
          reminders: [
            HabitReminder(
              title: '   ',
              description: '',
              time: const TimeOfDay(hour: 8, minute: 0),
              isEnabled: true,
              daysOfWeek: [
                WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
              ],
            ),
            HabitReminder(
              title: 'OK title',
              description: '',
              time: const TimeOfDay(hour: 9, minute: 0),
              isEnabled: true,
              daysOfWeek: const [],
            ),
          ],
        ),
        isNew: true,
      );

      expect(dto['reminders'], isEmpty);
    });
  });

  group('ReminderService habit sync', () {
    test('syncHabitNotifications is a no-op when forceLocalOnly', () async {
      final service = ReminderService(forceLocalOnly: true);
      await service.syncHabitNotifications(
        Habit(
          id: 9,
          name: 'Walk',
          frequency: const FrequencyConfig(type: FrequencyType.daily),
          reminders: [
            HabitReminder(
              title: 'Walk',
              description: '',
              time: const TimeOfDay(hour: 7, minute: 0),
              isEnabled: true,
              daysOfWeek: [
                WeekDay(type: DateTime.monday, userNotificationRequestId: 1),
              ],
              offsets: const [ScheduleReminderOffset(offsetMinutes: 0)],
            ),
          ],
        ),
      );
    });
  });
}

class _TokenStore extends SecureStore {
  @override
  Future<String?> read(String key) async => 'token';

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class _Noop implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
