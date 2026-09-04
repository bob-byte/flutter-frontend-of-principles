import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/services/habit_service.dart';

void main() {
  test('new habit DTO matches MAUI EditUserHabitDto (id 0, valid type/status)', () {
    final dto = buildEditUserHabitDto(
      Habit(
        id: 42,
        name: '  Morning walk  ',
        targetGoal: 'Be a walker',
        targetGoalId: 7,
        isFlexible: true,
        notes: 'Park loop',
        difficulty: 4,
      ),
      isNew: true,
    );

    expect(dto['id'], 0);
    expect(dto['name'], 'Morning walk');
    expect(dto['type'], kTypeOfHabitFlexible);
    expect(dto['status'], kStatusOfHabitInProgress);
    expect(dto['goal'], containsPair('id', 7));
    expect(dto['goal'], containsPair('name', 'Be a walker'));
    expect(dto.containsKey('goalId'), isFalse);
    expect(dto['defaultProgressValue'], kDefaultProgressSkip);
    expect((dto['frequency'] as Map)['type'], kFrequencyEveryDay);
    expect((dto['frequency'] as Map)['repeats'], 1);
    expect((dto['frequency'] as Map)['intervalLengthInDays'], 1);
  });

  test('unresolved local goal id is sent as 0 so the server skips the FK', () {
    final dto = buildEditUserHabitDto(
      Habit(
        name: 'Walk',
        targetGoal: 'Be a walker',
        targetGoalId: 3,
      ),
      isNew: true,
      goalId: 0,
    );

    expect(dto['goal'], containsPair('id', 0));
    expect(dto['goal'], containsPair('name', 'Be a walker'));
    expect(dto['colorName'], '#1C1C1C');
  });

  test('existing principled habit DTO keeps backend id and Principled type', () {
    final dto = buildEditUserHabitDto(
      Habit(
        id: 15,
        name: 'No sugar',
        isFlexible: false,
        frequency: const FrequencyConfig(
          type: FrequencyType.timesPerPeriod,
          interval: 3,
          period: PeriodType.week,
        ),
      ),
      isNew: false,
    );

    expect(dto['id'], 15);
    expect(dto['type'], kTypeOfHabitPrincipled);
    expect(dto['status'], kStatusOfHabitInProgress);
    expect(dto['goal'], isNull);
    expect(dto['defaultProgressValue'], kDefaultProgressUnknown);
    expect((dto['frequency'] as Map)['type'], kFrequencySeveralTimesPerPeriod);
    expect((dto['frequency'] as Map)['repeats'], 3);
    expect((dto['frequency'] as Map)['intervalLengthInDays'], 7);
  });

  test('reminders serialize TimeOnly and DayOfWeek Sunday as 0', () {
    final dto = buildEditUserHabitDto(
      Habit(
        name: 'Journal',
        reminders: [
          HabitReminder(
            title: 'Write',
            description: 'One page',
            time: const TimeOfDay(hour: 8, minute: 5),
            isEnabled: true,
            daysOfWeek: [
              WeekDay(type: DateTime.sunday, userNotificationRequestId: 99),
              WeekDay(type: DateTime.monday, userNotificationRequestId: 100),
            ],
          ),
        ],
      ),
      isNew: true,
    );

    final reminders = dto['reminders'] as List<Map<String, dynamic>>;
    expect(reminders, hasLength(1));
    expect(reminders.first['time'], '08:05:00');
    final days = reminders.first['daysOfWeek'] as List<Map<String, dynamic>>;
    expect(days.map((d) => d['type']), [0, 1]);
  });

  test('weekday conversion maps Sunday 7 to DayOfWeek 0', () {
    expect(toDotNetDayOfWeek(DateTime.sunday), 0);
    expect(toDotNetDayOfWeek(DateTime.monday), 1);
    expect(toDotNetDayOfWeek(0), 0);
  });
}
