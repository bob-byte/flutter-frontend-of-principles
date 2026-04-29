// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Principles';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSubtitle => 'Switch between dark and light';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark (black + orange)';

  @override
  String get themeSystem => 'System';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSubtitle => 'Use system language or choose manually';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get editHabitTitle => 'Edit Habit';

  @override
  String get habitNameLabel => 'Habit name';

  @override
  String get habitDescriptionLabel => 'Description';

  @override
  String get saveButton => 'Save';

  @override
  String get recommendedHabitsButton => 'Recommended Habits';

  @override
  String get openHabitDetailsButton => 'Open habit details';

  @override
  String get habitDetailsFallbackTitle => 'Habit details';

  @override
  String get unarchiveTooltip => 'Unarchive';

  @override
  String get archiveTooltip => 'Archive';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get noHabitSelected => 'No habit selected';

  @override
  String get overallProgress => 'Overall Progress';

  @override
  String executionCount(int count) {
    return 'Number of execution: $count';
  }

  @override
  String longestStreak(int count) {
    return 'Longest streak: $count';
  }

  @override
  String get topFiveStreaks => 'Top Five Streaks';

  @override
  String get noStreaksYet => 'No streaks yet';

  @override
  String streakDays(int days) {
    return '$days days';
  }

  @override
  String get stabilityTitle => 'Stability';

  @override
  String get noStabilityData => 'No stability data';

  @override
  String get habitByWeekdays => 'Habit By Weekdays';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get progressTitle => 'Progress';

  @override
  String get progressNo => 'No';

  @override
  String get progressYes => 'Yes';

  @override
  String get progressNumeric500 => 'Numeric +500';

  @override
  String progressValue(String value) {
    return 'Value: $value';
  }

  @override
  String progressDateInt(int value) {
    return 'DateInt: $value';
  }

  @override
  String get loginTitle => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get goalsTitle => 'Goals';

  @override
  String get newGoalLabel => 'New goal';

  @override
  String get helperTitle => 'Chat With Helper';

  @override
  String get helperInputHint => 'Enter text';

  @override
  String get invalidCredentialsError => 'Invalid credentials';

  @override
  String get genericErrorOccurred => 'Error occurred';

  @override
  String get chatFallbackAnswer =>
      'I hear you. Let us break this down into one small action for today.';

  @override
  String get defaultFrequencyEveryDay => 'Every day';

  @override
  String get recommendedHabitName1 => 'Write 3 priorities after waking up';

  @override
  String get recommendedHabitReason1 =>
      'It turns intention into focus before distractions start.';

  @override
  String get recommendedHabitName2 => 'Walk 15 minutes after lunch';

  @override
  String get recommendedHabitReason2 =>
      'It improves energy and consistency with minimal friction.';

  @override
  String get recommendedHabitName3 => 'Review one completed task before sleep';

  @override
  String get recommendedHabitReason3 =>
      'It reinforces progress and keeps motivation stable.';

  @override
  String get recommendedHabitName4 => 'Read 5 pages before bed';

  @override
  String get recommendedHabitReason4 =>
      'It creates a repeatable cue for learning and calm.';
}
