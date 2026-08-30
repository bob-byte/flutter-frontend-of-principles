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
  String get logoutLabel => 'Logout';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSubtitle => 'Dark or light, orange or blue';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark (black + blue)';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDarkOrange => 'Dark orange';

  @override
  String get themeDarkBlue => 'Dark blue';

  @override
  String get themeLightOrange => 'Light orange';

  @override
  String get themeLightBlue => 'Light blue';

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
  String get tabChat => 'Chat';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabGoals => 'Goals';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabHabits => 'Habits';

  @override
  String get tabSettings => 'Settings';

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

  @override
  String get startupTitle => 'Let\'s get started now!';

  @override
  String get startupGoogleBtn => 'Continue with Google';

  @override
  String get startupAppleBtn => 'Continue with Apple';

  @override
  String get startupRegisterBtn => 'Sign up';

  @override
  String get startupRegisterWithEmailBtn => 'Sign up with email';

  @override
  String get startupLoginBtn => 'Login';

  @override
  String get startupErrorGeneric => 'Something went wrong';

  @override
  String get transformAreasOfLifeTitle => 'Improve lagging life areas';

  @override
  String get transformAreasOfLifeDescription =>
      'Set goals correctly and build your habits.';

  @override
  String get chatWithHelperTitle => 'Chat with AI assistant';

  @override
  String get chatWithHelperDescription =>
      'Get answers to various questions from AI assistant that takes your mission, habits, etc. into account.';

  @override
  String get groupHabitsByGoalsTitle => 'Continuous progress';

  @override
  String get groupHabitsByGoalsDescription =>
      'Systematize your goals by grouping habits under goals.';

  @override
  String get getRecommendationsByAITitle => 'AI recommendations';

  @override
  String get getRecommendationsByAIDescription =>
      'Get AI recommendations formed based on your mission, life motto, goals, etc.';

  @override
  String get becomeTruePersonalityTitle => 'Become a true personality';

  @override
  String get becomeTruePersonalityDescription =>
      'Set goals aligned with your identity. Ahead!';

  @override
  String get ahead => 'Ahead';

  @override
  String get aboutProgram => 'About program';

  @override
  String get nameLabel => 'Name';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get missionLabel => 'Mission';

  @override
  String get sloganLabel => 'Main slogan';

  @override
  String get optionalLabel => '(Optional)';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String signupDisclaimer(String userAgreement, String privacyPolicy) {
    return 'By clicking \'Sign up\', you agree to the $userAgreement and $privacyPolicy';
  }

  @override
  String get errorEmailAlreadyExists => 'User with this Email already exists.';

  @override
  String loginDisclaimer(String userAgreement, String privacyPolicy) {
    return 'By clicking \'Log in\', you agree to the $userAgreement and $privacyPolicy';
  }

  @override
  String tryAgainIn(int seconds) {
    return 'Try again in $seconds s.';
  }

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get principlesAppTitle => 'Principles';

  @override
  String get loginButton => 'Log in';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get passwordMinLength => 'Minimum 6 characters';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and new password. We will send a confirmation code.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get sendCodeBtn => 'Send code';

  @override
  String get confirmCodeTitle => 'Confirmation Code';

  @override
  String get confirmCodeSubtitle =>
      'Please enter the code we just sent to your email.';

  @override
  String get codeLabel => 'Code';

  @override
  String get confirmBtn => 'Confirm';

  @override
  String get wrongCodeError => 'Wrong confirmation code';

  @override
  String get passwordChangedSuccess =>
      'Success! Your password was changed successfully.';

  @override
  String get errorTitle => 'Error';

  @override
  String get okButton => 'OK';

  @override
  String get yesButton => 'Yes';

  @override
  String get noButton => 'No';

  @override
  String get appleAuthUnknownError =>
      'Couldn\'t complete Sign in with Apple. Make sure you\'re signed into iCloud on this device, then try again.';

  @override
  String get appleAuthUnavailableOnDevice =>
      'Sign in with Apple is unavailable. Please sign in to iCloud and try again.';

  @override
  String get somethingWentWrongWhenUserAuthsUsingExternalService =>
      'Something went wrong. Please use the \"Sign up with email\" or \"Log in\" option.';
}
