import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/habit_score.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/progress_value.dart';
import 'package:principles_app/services/habit_service.dart';

void main() {
  const daily = FrequencyConfig(type: FrequencyType.daily);

  test('score smoothing matches MAUI ProgressOfHabitServiceTest', () {
    const precision = 1e-6;
    expect(
      computeHabitScore(
        frequency: 1,
        previousScore: 0,
        checkmarkValue: 1,
        complexity: 7,
      ),
      closeTo(0.051922, precision),
    );
    expect(
      computeHabitScore(
        frequency: 1,
        previousScore: 0.5,
        checkmarkValue: 1,
        complexity: 7,
      ),
      closeTo(0.525961, precision),
    );
    expect(
      computeHabitScore(
        frequency: 1,
        previousScore: 0.75,
        checkmarkValue: 1,
        complexity: 7,
      ),
      closeTo(0.762981, precision),
    );
    expect(
      computeHabitScore(
        frequency: 1,
        previousScore: 0.5,
        checkmarkValue: 0,
        complexity: 7,
      ),
      closeTo(0.474039, precision),
    );
  });

  test('daily habit at complexity 5 is 100% after 66 completed days', () {
    final today = DateTime(2026, 9, 3);
    final marks = [
      for (var i = 0; i < 66; i++)
        HabitProgressMark(
          date: today.subtract(Duration(days: i)),
          value: kProgressYesManual,
        ),
    ];

    final score = recomputeHabitPercentage(
      marks: marks,
      frequency: daily,
      complexity: 5,
      now: today,
    );
    expect(roundScoreToPercent(score), 100);
  });

  test('YES_MANUAL history raises percentage even if this week is empty', () {
    final today = DateTime(2026, 9, 3);
    final marks = [
      for (var i = 10; i < 40; i++)
        HabitProgressMark(
          date: today.subtract(Duration(days: i)),
          value: kProgressYesManual,
        ),
    ];

    final score = recomputeHabitPercentage(
      marks: marks,
      frequency: daily,
      complexity: 5,
      now: today,
    );
    expect(roundScoreToPercent(score), greaterThan(0));
  });

  test('backend progress value 2 is completed, 0 is a miss, 3 is skip', () {
    expect(
      habitStatusFromProgressValue(kProgressYesManual),
      HabitStatus.completed,
    );
    expect(
      habitStatusFromProgressValue(kProgressYesAuto),
      HabitStatus.completed,
    );
    expect(habitStatusFromProgressValue(kProgressNo), HabitStatus.none);
    expect(habitStatusFromProgressValue(kProgressSkip), HabitStatus.skipped);
    expect(progressValueToApi(HabitStatus.completed), kProgressYesManual);
    expect(progressValueToApi(HabitStatus.skipped), kProgressSkip);
  });

  test('frequencyFromApi reads repeats and interval from in-progress DTO', () {
    expect(
      frequencyFromApi({
        'type': 0,
        'repeats': 1,
        'intervalLengthInDays': 1,
      })?.type,
      FrequencyType.daily,
    );
    expect(
      frequencyFromApi({
        'Type': 1,
        'Repeats': 1,
        'IntervalLengthInDays': 3,
      })?.interval,
      3,
    );
    final weekly = frequencyFromApi({
      'type': 2,
      'repeats': 3,
      'intervalLengthInDays': 7,
    });
    expect(weekly?.type, FrequencyType.timesPerPeriod);
    expect(weekly?.interval, 3);
    expect(weekly?.period, PeriodType.week);
  });

  test('progressDateFromApi keeps the calendar date from DateOnly JSON', () {
    expect(progressDateFromApi('2026-09-03'), DateTime(2026, 9, 3));
    expect(
      progressDateFromApi('2026-09-03T00:00:00+03:00'),
      DateTime(2026, 9, 3),
    );
    expect(progressDateFromApi(20260903), DateTime(2026, 9, 3));
  });

  test('legacy habit_records status 1 migrates to YES_MANUAL', () {
    expect(progressValueFromMap({'status': 1}), kProgressYesManual);
    expect(progressValueFromMap({'status': 2}), kProgressSkip);
    expect(progressValueFromMap({'value': 2, 'status': 2}), kProgressYesManual);
  });
}
