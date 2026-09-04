import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/habit_score.dart';
import 'package:principles_app/l10n/app_localizations_en.dart';
import 'package:principles_app/l10n/app_localizations_uk.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/progress_value.dart';
import 'package:principles_app/viewmodels/edit_habit_viewmodel.dart';

void main() {
  const daily = FrequencyConfig(type: FrequencyType.daily);
  final today = DateTime(2026, 9, 3);
  final l10n = AppLocalizationsEn();

  List<HabitProgressMark> completedDays(int count) => [
    for (var i = 0; i < count; i++)
      HabitProgressMark(
        date: today.subtract(Duration(days: i)),
        value: kProgressYesManual,
      ),
  ];

  test('new-habit day counts match MAUI HabitComplexity.ToDaysCount', () {
    expect(daysCountForComplexity(1), 18);
    expect(daysCountForComplexity(5), 66);
    expect(daysCountForComplexity(10), 254);
  });

  test(
    'existing daily habit with no history needs the full complexity window',
    () {
      expect(
        getDaysUntilFullAutomation(
          marks: const [],
          frequency: daily,
          complexity: 5,
          now: today,
        ),
        daysCountForComplexity(5),
      );
    },
  );

  test('66 completed days at complexity 5 is already automated', () {
    expect(
      getDaysUntilFullAutomation(
        marks: completedDays(66),
        frequency: daily,
        complexity: 5,
        now: today,
      ),
      0,
    );
  });

  test('65 completed days at complexity 5 leaves one day to 100%', () {
    expect(
      getDaysUntilFullAutomation(
        marks: completedDays(65),
        frequency: daily,
        complexity: 5,
        now: today,
      ),
      1,
    );
  });

  test('partial history reports fewer remaining days than a new habit', () {
    final remaining = getDaysUntilFullAutomation(
      marks: completedDays(40),
      frequency: daily,
      complexity: 5,
      now: today,
    );
    expect(remaining, greaterThan(0));
    expect(remaining, lessThan(daysCountForComplexity(5)));
  });

  test(
    'help text matches MAUI converter for new, remaining, and automated habits',
    () {
      expect(
        formatHabitAutomationHelpText(l10n: l10n, isNewHabit: true, days: 66),
        'Habit automation requires regular performance for 66 day(s).',
      );
      expect(
        formatHabitAutomationHelpText(l10n: l10n, isNewHabit: false, days: 0),
        'The habit is already automated',
      );
      expect(
        formatHabitAutomationHelpText(l10n: l10n, isNewHabit: false, days: 12),
        'Just 12 days to go until your habit becomes fully automatic.',
      );
      expect(
        formatHabitAutomationHelpText(l10n: l10n, isNewHabit: false, days: 40),
        'There are still 40 days to go until your habit becomes fully automatic.',
      );
      expect(
        formatHabitAutomationHelpText(
          l10n: AppLocalizationsUk(),
          isNewHabit: false,
          days: 0,
        ),
        'Звичка вже автоматична',
      );
    },
  );
}
