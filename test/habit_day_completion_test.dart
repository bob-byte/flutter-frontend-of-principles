import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';

void main() {
  Habit habit(int id) => Habit(id: id, name: 'Habit $id');

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

  test('empty and fully completed days', () {
    expect(habitDayCompletionRatio(0, 0), 0);
    expect(habitDayCompletionRatio(0, 8), 0);
    expect(habitDayCompletionRatio(8, 8), 1);
  });
}
