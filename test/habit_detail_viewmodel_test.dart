import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/habit_score.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/habit_reminder.dart';
import 'package:principles_app/viewmodels/habit_detail_viewmodel.dart';

HabitRecord _record(
  DateTime date, {
  HabitStatus status = HabitStatus.completed,
}) {
  return HabitRecord(habitId: 1, date: date, status: status);
}

void main() {
  test('computes completion rate, streaks and weekday counts', () {
    final vm = HabitDetailViewModel();
    vm.habit = Habit(
      id: 1,
      name: 'Train',
      frequency: const FrequencyConfig(type: FrequencyType.daily),
    );

    final records = [
      _record(DateTime(2026, 3, 1)),
      _record(DateTime(2026, 3, 2)),
      _record(DateTime(2026, 3, 3)),
      _record(DateTime(2026, 3, 4)),
      _record(DateTime(2026, 3, 6)),
      _record(DateTime(2026, 3, 7)),
      _record(DateTime(2026, 3, 8), status: HabitStatus.skipped),
    ];

    // Freeze "today" by using records whose first date is known; expected
    // uses DateTime.now(), so assert relative invariants instead of exact %.
    vm.computeStats(records);

    expect(vm.completedDays, 6);
    expect(vm.longestStreak, 4);
    expect(vm.topFiveStreaks.length, 2);
    expect(vm.topFiveStreaks.first.days, 4);
    expect(vm.topFiveStreaks.first.start, DateTime(2026, 3, 1));
    expect(vm.topFiveStreaks.first.end, DateTime(2026, 3, 4));
    expect(
      vm.weekDayExecution[DateTime(2026, 3, 1).weekday - 1],
      greaterThan(0),
    );
    expect(vm.completedCalendarDays.contains(DateTime(2026, 3, 4)), isTrue);
    expect(vm.skippedCalendarDays.contains(DateTime(2026, 3, 8)), isTrue);
    expect(vm.stabilitySeries, isNotEmpty);
    expect(vm.completionRate, inInclusiveRange(0, 1));
  });

  test('expected executions for daily frequency counts each day', () {
    expect(
      expectedExecutionsInRange(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
        const FrequencyConfig(type: FrequencyType.daily),
      ),
      10,
    );
  });

  test('reminder chip groups consecutive weekdays', () {
    final habit = Habit(
      name: 'Train',
      reminders: [
        HabitReminder(
          title: 'Train',
          description: '',
          time: const TimeOfDay(hour: 17, minute: 10),
          isEnabled: true,
          daysOfWeek: [
            WeekDay(type: DateTime.wednesday, userNotificationRequestId: 1),
            WeekDay(type: DateTime.thursday, userNotificationRequestId: 2),
            WeekDay(type: DateTime.saturday, userNotificationRequestId: 3),
          ],
        ),
      ],
    );

    final label = formatReminderChip(habit, const [
      'Пн',
      'Вт',
      'Ср',
      'Чт',
      'Пт',
      'Сб',
      'Нд',
    ]);

    expect(label, '17:10 Ср-Чт, Сб');
  });

  test('nice chart max leaves room matching MAUI integer axes', () {
    expect(niceChartMax(4), 4);
    expect(niceChartMax(72), 80);
    expect(chartInterval(4), 1);
    expect(chartInterval(80), 20);
  });

  test('calendar tap toggles completed and uncompleted like MAUI', () {
    expect(nextCalendarStatus(HabitStatus.none), HabitStatus.completed);
    expect(nextCalendarStatus(HabitStatus.completed), HabitStatus.none);
    expect(nextCalendarStatus(HabitStatus.skipped), HabitStatus.none);

    final vm = HabitDetailViewModel();
    vm.habit = Habit(
      id: 1,
      name: 'Train',
      frequency: const FrequencyConfig(type: FrequencyType.daily),
    );
    vm.computeStats([]);

    final day = DateTime(2026, 9, 2);
    final today = DateTime(2026, 9, 3);

    expect(
      vm.applyCalendarToggle(DateTime(2026, 9, 10), now: today),
      CalendarDayTapResult.futureDate,
    );
    expect(vm.completedCalendarDays.contains(day), isFalse);

    expect(
      vm.applyCalendarToggle(day, now: today),
      CalendarDayTapResult.updated,
    );
    expect(vm.statusForDay(day), HabitStatus.completed);
    expect(vm.completedCalendarDays.contains(day), isTrue);
    expect(vm.completedDays, 1);

    expect(
      vm.applyCalendarToggle(day, now: today),
      CalendarDayTapResult.updated,
    );
    expect(vm.statusForDay(day), HabitStatus.none);
    expect(vm.completedCalendarDays.contains(day), isFalse);
    expect(vm.completedDays, 0);
  });

  test('detail percentage matches habits-list PercentageAchieved', () {
    final today = DateTime(2026, 9, 3);
    const frequency = FrequencyConfig(type: FrequencyType.daily);
    const complexity = 5;
    final records = [
      for (var i = 0; i < 40; i++)
        _record(today.subtract(Duration(days: i + 2))),
    ];

    final vm = HabitDetailViewModel();
    vm.habit = Habit(
      id: 1,
      name: 'Train',
      frequency: frequency,
      difficulty: complexity,
    );
    vm.computeStats(records);

    final listScore = recomputeHabitPercentageFromRecords(
      records: records,
      frequency: frequency,
      complexity: complexity,
      now: DateTime.now(),
    );
    expect(vm.completionRate, closeTo(listScore, 1e-9));
    expect(vm.percentageLabel, '${roundScoreToPercent(listScore)}%');
  });
}
