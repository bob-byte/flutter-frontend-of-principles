import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';

void main() {
  Habit habit(int id, {FrequencyConfig? frequency}) => Habit(
    id: id,
    name: 'Habit $id',
    frequency: frequency ?? const FrequencyConfig(type: FrequencyType.daily),
  );

  test('counts only completed habits on the given day', () {
    final today = DateTime(2026, 9, 3);
    final yesterday = DateTime(2026, 9, 2);
    final habits = [for (var i = 1; i <= 10; i++) habit(i)];
    final records = [
      HabitRecord(habitId: 1, date: today, status: HabitStatus.completed),
      HabitRecord(habitId: 2, date: today, status: HabitStatus.skipped),
      HabitRecord(habitId: 3, date: yesterday, status: HabitStatus.completed),
    ];

    expect(countCompletedHabitsOn(habits, records, today), 1);
    expect(countCompletedHabitsOn(habits, records, yesterday), 1);
    expect(habitDayCompletionRatio(1, 10), 0.1);
  });

  test('every-N-days auto-fill counts as completed and still applies', () {
    final doneOn = DateTime(2026, 9, 1);
    final autoDay = DateTime(2026, 9, 2);
    final nextRequired = DateTime(2026, 9, 4);
    final habits = [
      habit(1),
      habit(
        2,
        frequency: const FrequencyConfig(
          type: FrequencyType.everyXDays,
          interval: 3,
        ),
      ),
    ];
    final records = [
      HabitRecord(habitId: 2, date: doneOn, status: HabitStatus.completed),
    ];

    expect(countCompletedHabitsOn(habits, records, autoDay), 1);
    expect(countManuallyCompletedHabitsOn(habits, records, autoDay), 0);
    expect(countManuallyCompletedHabitsOn(habits, records, doneOn), 1);
    expect(countHabitsOn(habits, records, autoDay), 2);
    expect(countCompletedHabitsOn(habits, records, nextRequired), 0);
    expect(countHabitsOn(habits, records, nextRequired), 2);
  });

  test('empty and fully completed days', () {
    expect(habitDayCompletionRatio(0, 0), 0);
    expect(habitDayCompletionRatio(0, 8), 0);
    expect(habitDayCompletionRatio(8, 8), 1);
  });
}
