import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/habit_score.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/progress_value.dart';

HabitRecord _manual(DateTime date, {int habitId = 1}) {
  return HabitRecord(
    habitId: habitId,
    date: date,
    status: HabitStatus.completed,
  );
}

void main() {
  const daily = FrequencyConfig(type: FrequencyType.daily);
  const everyThreeDays = FrequencyConfig(
    type: FrequencyType.everyXDays,
    interval: 3,
  );
  const threeTimesPerWeek = FrequencyConfig(
    type: FrequencyType.timesPerPeriod,
    interval: 3,
    period: PeriodType.week,
  );

  test('daily habit is required every day except a manual completion', () {
    final records = [_manual(DateTime(2026, 9, 1))];

    expect(
      habitProgressValueOnDate(
        frequency: daily,
        records: records,
        date: DateTime(2026, 9, 1),
      ),
      kProgressYesManual,
    );
    expect(
      isHabitExecutionRequiredOnDate(
        frequency: daily,
        records: records,
        date: DateTime(2026, 9, 2),
      ),
      isTrue,
    );
    expect(
      isHabitSatisfiedOnDate(
        frequency: daily,
        records: records,
        date: DateTime(2026, 9, 2),
      ),
      isFalse,
    );
  });

  test('every 3 days fills the rest of the interval with YES_AUTO', () {
    final records = [_manual(DateTime(2026, 9, 1))];

    expect(
      habitProgressValueOnDate(
        frequency: everyThreeDays,
        records: records,
        date: DateTime(2026, 9, 1),
      ),
      kProgressYesManual,
    );
    expect(
      habitProgressValueOnDate(
        frequency: everyThreeDays,
        records: records,
        date: DateTime(2026, 9, 2),
      ),
      kProgressYesAuto,
    );
    expect(
      habitProgressValueOnDate(
        frequency: everyThreeDays,
        records: records,
        date: DateTime(2026, 9, 3),
      ),
      kProgressYesAuto,
    );
    expect(
      isHabitExecutionRequiredOnDate(
        frequency: everyThreeDays,
        records: records,
        date: DateTime(2026, 9, 4),
      ),
      isTrue,
    );
  });

  test('3x per week auto-fills remaining days after three manuals', () {
    final records = [
      _manual(DateTime(2026, 8, 31)),
      _manual(DateTime(2026, 9, 1)),
      _manual(DateTime(2026, 9, 2)),
    ];

    expect(
      isHabitSatisfiedOnDate(
        frequency: threeTimesPerWeek,
        records: records,
        date: DateTime(2026, 9, 3),
      ),
      isTrue,
    );
    expect(
      habitProgressValueOnDate(
        frequency: threeTimesPerWeek,
        records: records,
        date: DateTime(2026, 9, 3),
      ),
      kProgressYesAuto,
    );
    expect(
      isHabitExecutionRequiredOnDate(
        frequency: threeTimesPerWeek,
        records: records,
        date: DateTime(2026, 9, 7),
      ),
      isTrue,
    );
  });

  test('stored skip overrides an auto-filled day', () {
    final records = [
      _manual(DateTime(2026, 9, 1)),
      HabitRecord(
        habitId: 1,
        date: DateTime(2026, 9, 2),
        status: HabitStatus.skipped,
      ),
    ];

    expect(
      habitProgressValueOnDate(
        frequency: everyThreeDays,
        records: records,
        date: DateTime(2026, 9, 2),
      ),
      kProgressSkip,
    );
  });

  test('habit with no records is required', () {
    expect(
      isHabitExecutionRequiredOnDate(
        frequency: everyThreeDays,
        records: const [],
        date: DateTime(2026, 9, 2),
      ),
      isTrue,
    );
    expect(
      habitAppliesOnDate(
        frequency: everyThreeDays,
        records: const [],
        date: DateTime(2026, 9, 2),
      ),
      isTrue,
    );
  });
}
