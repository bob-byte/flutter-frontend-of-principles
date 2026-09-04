import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/habit_streak.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/progress_value.dart';

void main() {
  final today = DateTime(2026, 9, 3);
  final yesterday = DateTime(2026, 9, 2);
  const habitIds = [1, 2, 3];

  HabitRecord mark(
    int habitId,
    DateTime date, {
    int value = kProgressYesManual,
  }) {
    return HabitRecord(habitId: habitId, date: date, value: value);
  }

  test('empty habits return 0', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: const [],
        records: [mark(1, today)],
        now: today,
      ),
      0,
    );
  });

  test('today YES_MANUAL counts after UNKNOWN days reset the streak', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: habitIds,
        records: [mark(1, today), mark(2, today), mark(3, today)],
        now: today,
      ),
      3,
    );
  });

  test('consecutive completed days add YES_MANUAL marks', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: habitIds,
        records: [
          mark(1, yesterday),
          mark(2, yesterday),
          mark(3, yesterday),
          mark(1, today),
          mark(2, today),
          mark(3, today),
        ],
        now: today,
      ),
      6,
    );
  });

  test('a fully missed day in the window resets then rebuilds', () {
    final twoDaysAgo = DateTime(2026, 9, 1);
    expect(
      calculateUserHabitsStreak(
        habitIds: habitIds,
        records: [
          mark(1, twoDaysAgo),
          mark(2, twoDaysAgo),
          mark(3, twoDaysAgo),
          mark(1, today),
          mark(2, today),
        ],
        now: today,
      ),
      2,
    );
  });

  test('last missed app-open date drops older progress', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: habitIds,
        records: [
          mark(1, yesterday),
          mark(2, yesterday),
          mark(3, yesterday),
          mark(1, today),
        ],
        lastMissedAppOpen: yesterday,
        now: today,
      ),
      1,
    );
  });

  test('SKIP and YES_AUTO do not reset or increment', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: habitIds,
        records: [
          mark(1, yesterday, value: kProgressSkip),
          mark(2, yesterday, value: kProgressYesAuto),
          mark(3, yesterday, value: kProgressUnknown),
          mark(1, today),
        ],
        now: today,
      ),
      1,
    );
  });

  test('a day of only UNKNOWN and NO resets the running total', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: const [1],
        records: [
          mark(1, yesterday),
          mark(1, today, value: kProgressNo),
        ],
        now: today,
      ),
      0,
    );
  });

  test('archived-habit records are ignored', () {
    expect(
      calculateUserHabitsStreak(
        habitIds: const [1],
        records: [mark(1, today), mark(99, today)],
        now: today,
      ),
      1,
    );
  });
}
