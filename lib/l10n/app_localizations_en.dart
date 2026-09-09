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
  String get settingsSectionProfile => 'Profile';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get logoutLabel => 'Logout';

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
  String get themeLabel => 'Theme';

  @override
  String get themeSubtitle => 'Choose the app color theme';

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
  String get recommendedHabitsByAi => 'Recommended habits by AI';

  @override
  String get confirmRecommendedHabitsTitle =>
      'Based on goal, mission and slogan';

  @override
  String get confirmRecommendedHabitsMessage =>
      'Are you sure you want to load recommended habits based on your chosen goal, mission and main slogan?';

  @override
  String get recommendedHabitsLoadingHint =>
      'If you don\'t want to wait, you can change the other fields for now.';

  @override
  String get recommendedHabitsEmpty => 'No recommendations yet.';

  @override
  String get recommendedHabitsCaptionNoGoal =>
      'Select a Goal above — we can recommend habits for it.';

  @override
  String recommendedHabitsCaptionWithGoal(String goal) {
    return 'Recommendations will be for \"$goal\" achievement.';
  }

  @override
  String recommendedHabitsGoalPopover(String goal) {
    return 'We can recommend habits for achieving the selected goal: \"$goal\".';
  }

  @override
  String get loadingLabel => 'Loading';

  @override
  String get loadingContent => 'Loading content...';

  @override
  String get openHabitDetailsButton => 'Open habit details';

  @override
  String get habitDetailsFallbackTitle => 'Habit details';

  @override
  String get habitComplexityLabel => 'Complexity';

  @override
  String get habitNotesEmpty => 'No notes';

  @override
  String get habitTypeLabel => 'Type';

  @override
  String get habitGoalEmpty => 'No goal';

  @override
  String get unarchiveTooltip => 'Unarchive';

  @override
  String get archiveTooltip => 'Archive';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get habitMenuEdit => 'Edit';

  @override
  String get habitMenuDetails => 'Details';

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
  String get topFiveStreaks => 'Top-5 streaks';

  @override
  String get topFiveStreaksInfo =>
      'The Top 5 habit streaks reflect the most consistent periods of personal discipline. This feature helps recognize your ability to take sustained action, supports motivation during times of doubt, and serves as a foundation for forming stable, recommended habits.';

  @override
  String get noStreaksYet => 'No streaks yet';

  @override
  String streakDays(int days) {
    return '$days days';
  }

  @override
  String get stabilityTitle => 'Stability';

  @override
  String get stabilityInfo =>
      'The Stability chart measures how consistently you maintain your habit without missing days. It highlights your overall adherence patterns, helping you see where you’re most reliable and where you might need extra focus. By tracking stability, you can celebrate steady progress, identify moments that challenge your routine, and build confidence in sustaining long‑term behavior change.';

  @override
  String get noStabilityData => 'No stability data';

  @override
  String get habitByWeekdays => 'Habit by days of the week';

  @override
  String get habitByWeekdaysInfo =>
      'The Habit by Day of the Week chart shows how often you complete your habit on each day. It helps you spot which days you\'re most consistent and which ones tend to be missed. By understanding these patterns, you can adjust your routine, address weak spots, and create a more balanced and sustainable habit rhythm throughout the week.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarInfo =>
      'The execution of habits by day is displayed:\n- Blue - habit completed;\n- Cyan - it is not necessary to follow the habit.\nYou can change the status with a press.';

  @override
  String get executionCountAxis => 'Number of completions';

  @override
  String get frequencyEveryDay => 'Every day';

  @override
  String frequencyEveryXDays(int count) {
    return 'Every $count day(s)';
  }

  @override
  String frequencyTimesPerPeriod(int count, String period) {
    return '$count time(s) per $period';
  }

  @override
  String get periodWeek => 'week';

  @override
  String get periodMonth => 'month';

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
  String get goalsEmptyList => 'No goals yet. Add one above.';

  @override
  String get addGoalTitle => 'Add goal';

  @override
  String get editGoalTitle => 'Edit goal';

  @override
  String get goalExamplesHint =>
      'Examples of identity-oriented goals: be an Olympic champion, be confident, be free from smoking.';

  @override
  String get deleteGoalQuestion => 'Delete goal?';

  @override
  String get deleteGoalMessage =>
      'The goal will be deleted permanently. This action cannot be undone.';

  @override
  String get markGoalCompleted => 'Mark as completed';

  @override
  String get markGoalIncomplete => 'Mark as not completed';

  @override
  String get completedGoalsHeader => 'Completed';

  @override
  String goalHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habits',
      one: '$count habit',
    );
    return '$_temp0';
  }

  @override
  String get goalMarkedCompleted => 'Goal marked as completed';

  @override
  String get goalMarkedIncomplete => 'Goal marked as not completed';

  @override
  String get helperTitle => 'Chat With Helper';

  @override
  String get helperWarning =>
      'The AI-assistant knows your habits, goals, mission, gender, and slogan. So you can ask anything about them. For example, “What should I set as my next goal?” Note that it can sometimes make mistakes. Check important information!';

  @override
  String get helperEmptyDescription =>
      'I am an AI assistant for self-development. You can ask me about different questions. For example, \"How does my personality affect my life?\"';

  @override
  String get copyMessage => 'Copy';

  @override
  String get successfulCopy => 'Text successfully copied';

  @override
  String get helperChatsTitle => 'Chats';

  @override
  String get helperNewChat => 'New chat';

  @override
  String get helperSearchChatsHint => 'Search chats';

  @override
  String get helperNoChats => 'No chats yet';

  @override
  String get helperUntitledChat => 'New chat';

  @override
  String get helperOpenChats => 'Open chats';

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
  String get noInternetConnection => 'No internet connection';

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
  String get startupLoginBtn => 'Log in';

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
  String get genderLabel => 'Gender';

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
  String get cancelButton => 'Cancel';

  @override
  String get yourName => 'Your Name';

  @override
  String get yourGender => 'Your Gender';

  @override
  String get yourMainSlogan => 'Your Main Slogan';

  @override
  String get yourMission => 'Your Mission';

  @override
  String get missionExplanation =>
      'A mission is a life goal that keeps your motivation high and helps you make the best choices in a variety of situations. For example, a mission might be: “I create IT applications to make the world a better place.” It will be used to generate habit suggestions that are more relevant to you.';

  @override
  String get mainSloganExplanation =>
      'A main slogan is the most important idea that guides you through life. It helps you decide how to act when you don’t feel like doing something, or when you face certain challenges or temptations. An example of a core motto: a relationship with God and a strong character determine the quality of life. A motto is used to cultivate the best recommended habits.';

  @override
  String get nameSavedSuccess => 'Your name successfully saved';

  @override
  String get genderSavedSuccess => 'Your gender successfully saved';

  @override
  String get sloganSavedSuccess => 'Your main slogan successfully saved';

  @override
  String get missionSavedSuccess => 'Your mission successfully saved';

  @override
  String get fieldIsNotEditable => 'This field is not editable.';

  @override
  String get joinTelegramLabel => 'Join our Telegram channel';

  @override
  String get rateUsLabel => 'Rate us';

  @override
  String get appUpdateAvailable => 'Update Available';

  @override
  String get appUpdateCloseButton => 'Close';

  @override
  String get dontShowUpdateCheckBoxText => 'Don\'t remind me of it again';

  @override
  String get updateButton => 'Update';

  @override
  String get shareAppLabel => 'Share app';

  @override
  String get shareAppMessage =>
      'Build better habits with Principles: https://principles.top';

  @override
  String get contactEmailLabel => 'Send an email to us';

  @override
  String get contactEmailSubtitle => 'Support and Feedback';

  @override
  String get cannotOpenEmailApp =>
      'Cannot open an app to send an email. Maybe a mail program is not installed.';

  @override
  String get settingsPrivacyPolicy => 'Our privacy policy';

  @override
  String get settingsUserAgreement => 'User agreement';

  @override
  String get changePasswordLabel => 'Change password';

  @override
  String get deleteAccountLabel => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete account?';

  @override
  String get deleteAccountConfirm => 'Once you delete, it\'s gone for good.';

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
  String get retryButton => 'Retry';

  @override
  String get serverTechnicalWorkIsInProgress =>
      'Technical work on our server is in progress. Please try again later.';

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

  @override
  String get tabAssistant => 'AI Assistant';

  @override
  String get tabProfile => 'Profile';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveEmptyDescription =>
      'This section displays the habits you have archived. You can return to them whenever you are ready to work on them again.';

  @override
  String get archiveInfoDescription =>
      'Why do you need an archive?\n✅ Plan habits you want to add or change in the future.\n🔁 Analyze reasons - which habits worked and which ones were too complicated or irrelevant.\n🌱 Try again - sometimes it\'s good to go back to an old habit by changing the difficulty or approach. For example, train in the morning instead of the evening.\n\nTip: before creating a new habit, look at the archive - maybe something similar has already happened, and now you know how to do it better.';

  @override
  String get archiveInfoTooltip => 'Why do you need an archive?';

  @override
  String get unarchiveHabitQuestion => 'Unarchive Habit?';

  @override
  String get unarchiveHabitMessage =>
      'This action will restore the habit to your active list.';

  @override
  String get habitScreenTitle => 'Habit';

  @override
  String get habitDataTab => 'Data';

  @override
  String get habitHowToKeepTab => 'How to maintain';

  @override
  String get habitNameField => 'Name';

  @override
  String get habitNameInfo =>
      'Specify the habit name and the time or place you will do it. This increases the chance you will stick to it. Example: I pray as soon as I wake up.';

  @override
  String get habitGoalLabel => 'Goal';

  @override
  String get selectHabitGoalTitle => 'Select habit goal';

  @override
  String get selectHabitGoalRecommendation =>
      'Recommendation: pick a concrete goal or an identity-oriented one — it shapes your life.';

  @override
  String get habitFlexible => 'Flexible';

  @override
  String get habitFlexibleInfo =>
      'This is a habit type that a person follows most of the time, but may make exceptions in special situations. For example, it may be the habit of telling the truth but being able to keep silent or deceive when it could cause serious harm to others.';

  @override
  String get habitNoExceptions => 'Without exceptions';

  @override
  String get habitNoExceptionsInfo =>
      'This is a habit type that a person adheres to strictly and never makes exceptions, even in emergency situations. For example, refusal to drink alcohol or tobacco, regardless of the circumstances.';

  @override
  String get habitFrequency => 'Frequency';

  @override
  String get habitReminder => 'Reminder';

  @override
  String get habitNotes => 'Notes';

  @override
  String get habitDifficulty => 'Difficulty (1 - 10)';

  @override
  String get habitDifficultyInfo =>
      'How difficult is it to stick to the habit in terms of effort, time and self-control';

  @override
  String habitAutomationExplanation(int days) {
    return 'Habit automation requires regular performance for $days day(s).';
  }

  @override
  String get habitAlreadyAutomated => 'The habit is already automated';

  @override
  String habitDaysToGoUntilAutomaticJust(int days) {
    return 'Just $days days to go until your habit becomes fully automatic.';
  }

  @override
  String habitDaysToGoUntilAutomaticStill(int days) {
    return 'There are still $days days to go until your habit becomes fully automatic.';
  }

  @override
  String get habitMenuViewDetails => 'View details';

  @override
  String get habitMenuRestore => 'Restore';

  @override
  String get habitMenuDelete => 'Delete habit';

  @override
  String get deleteHabitQuestion => 'Delete habit?';

  @override
  String get deleteHabitMessage =>
      'The habit will be deleted permanently. This action cannot be undone.';

  @override
  String get habitsTodayLabel => 'Today';

  @override
  String get habitsCompletedToday => 'Completed this day';

  @override
  String get habitsEmptyList => 'No habits. Tap + to add.';

  @override
  String get undefinedGoalLabel => '*Goal not defined';

  @override
  String get habitStreakExplanation =>
      'Shows how many days in a row you opened the app and completed habits. If you skip even one day, the streak resets.';

  @override
  String get habitFiltersTooltip => 'Filters';

  @override
  String get habitFilters => 'Filters';

  @override
  String get habitFilterDayStatus => 'Day status';

  @override
  String get habitFilterDue => 'On this day';

  @override
  String get habitFilterGoal => 'Goal';

  @override
  String get habitFilterAll => 'All';

  @override
  String get habitFilterNotDone => 'Not done';

  @override
  String get habitFilterDone => 'Done';

  @override
  String get habitFilterDueOnly => 'Due';

  @override
  String get habitFilterNotDue => 'Not due';

  @override
  String get habitClearFilters => 'Clear';

  @override
  String get habitFiltersEmpty => 'No habits match the filters.';

  @override
  String get archiveHabitQuestion => 'Move habit to archive?';

  @override
  String get archiveHabitMessage =>
      'This will move the habit to the archive. You can resume working on it later.';

  @override
  String get cannotCompleteHabitInTheFuture =>
      'You can\'t mark a habit as done for future days';

  @override
  String get reminderTitleLabel => 'Title';

  @override
  String get reminderDescriptionLabel => 'Description';

  @override
  String get reminderTimeLabel => 'Time';

  @override
  String get reminderEnableLabel => 'Enable';

  @override
  String get doneButton => 'Done';

  @override
  String get habitsReportReminderSheetTitle => 'Daily reminder';

  @override
  String get habitsReportReminderSubtitle =>
      'A daily nudge to review your goals, habits, and tasks';

  @override
  String get habitsReportReminderCustomize => 'Customize message';

  @override
  String habitsReportReminderSavedOn(String time) {
    return 'Daily reminder on · $time';
  }

  @override
  String get habitsReportReminderSavedOff => 'Daily reminder off';

  @override
  String get habitsReportReminderTitleText => 'Remember your day';

  @override
  String get habitsReportReminderDescriptionText =>
      'time to review your goals, habits, and tasks';

  @override
  String habitsReportReminderOnTooltip(String time) {
    return 'Daily reminder on · $time';
  }

  @override
  String get habitsReportReminderOffTooltip => 'Daily reminder off';

  @override
  String get habitsReportReminderMenuHint =>
      'Remind me to check goals, habits, and tasks';

  @override
  String get notificationTargetNotFound =>
      'This reminder is no longer available';

  @override
  String get deviceDoesNotSupportNotifications =>
      'Oops.. It looks like your operating system doesn\'t support notifications. Please try updating it.';

  @override
  String get afterLoginWhenUserAccountHaveReminders =>
      'Your account has motivating reminders. They can be restore on your device.';

  @override
  String get restoreReminders => 'Restore reminders';

  @override
  String get notificationsDisabledTitle => 'Notifications are off';

  @override
  String get notificationsDisabledMessage =>
      'To receive reminders, allow notifications in device settings. Open settings now?';

  @override
  String get scheduleDate => 'Date';

  @override
  String get scheduleDuration => 'Duration';

  @override
  String get scheduleTime => 'Time';

  @override
  String get scheduleReminder => 'Reminder';

  @override
  String get scheduleRepeat => 'Repeat';

  @override
  String get scheduleClear => 'Clear';

  @override
  String get scheduleOnTime => 'On time';

  @override
  String get scheduleCustom => 'Custom';

  @override
  String get scheduleRecents => 'Recents';

  @override
  String get scheduleConstantReminder => 'Constant Reminder';

  @override
  String get scheduleConstantReminderExplanation =>
      'Keeps reminding you until you mark this as done.';

  @override
  String get scheduleAllDay => 'All Day';

  @override
  String get scheduleByDueDates => 'By Due Dates';

  @override
  String get scheduleByCompletion => 'By Completion Date';

  @override
  String get roadGuideSkip => 'Skip';

  @override
  String get roadGuideBack => 'Back';

  @override
  String get roadGuideNext => 'Next';

  @override
  String get roadGuideDone => 'Done';

  @override
  String get roadGuideReplayLabel => 'App road guide';

  @override
  String get roadGuideReplaySubtitle =>
      'Walk through goals, habits, tasks, and settings';

  @override
  String get roadGuideExampleBadge => 'example';

  @override
  String get roadGuideDemoGoalName => 'Get fit';

  @override
  String get roadGuideDemoHabitName => 'Morning workout';

  @override
  String get roadGuideDemoTaskName => 'Book a training session';

  @override
  String get roadGuideGoalsTabTitle => 'Start with a goal';

  @override
  String get roadGuideGoalsTabBody =>
      'Principles automates goal achievement. Open Goals to define what you want to reach.';

  @override
  String get roadGuideGoalsComposerTitle => 'Create your goal';

  @override
  String get roadGuideGoalsComposerBody =>
      'Write the outcome you want — habits will be organized under it.';

  @override
  String get roadGuideGoalsDemoTitle => 'Goals organize habits';

  @override
  String get roadGuideGoalsDemoBody =>
      'Each goal becomes a container for the habits that move you toward it.';

  @override
  String get roadGuideHabitsTabTitle => 'Habits get you there';

  @override
  String get roadGuideHabitsTabBody =>
      'Habits are the repeating actions that automate progress toward your goal.';

  @override
  String get roadGuideHabitsFabTitle => 'Add a habit to a goal';

  @override
  String get roadGuideHabitsFabBody =>
      'Create habits and link them to a goal so every completion counts toward achievement.';

  @override
  String get roadGuideRecommendTitle => 'Get habit recommendations';

  @override
  String get roadGuideRecommendBody =>
      'Tap Recommended Habits here. AI suggests habits from your goal, mission, and slogan.';

  @override
  String get roadGuideHabitsDemoTitle => 'Track habits under a goal';

  @override
  String get roadGuideHabitsDemoBody =>
      'Complete habits consistently — that is how goal achievement becomes automatic.';

  @override
  String get roadGuideHabitDetailTitle => 'Habit details';

  @override
  String get roadGuideHabitDetailBody =>
      'Open a habit to see progress, streaks, and stability — how consistently you are following through.';

  @override
  String get roadGuideTasksTabTitle => 'Tasks free your head';

  @override
  String get roadGuideTasksTabBody =>
      'Write down what you must not forget. Tasks hold the details so you can focus on habits and the goal.';

  @override
  String get roadGuideTasksAddTitle => 'Add a task';

  @override
  String get roadGuideTasksAddBody =>
      'Use + for one-off work, reminders, and steps that sit beside your habits.';

  @override
  String get roadGuideTasksDemoTitle => 'Remember everything';

  @override
  String get roadGuideTasksDemoBody =>
      'Tasks hold the details habits do not cover — so nothing slips while you work toward the goal.';

  @override
  String get roadGuideTasksHabitsTitle => 'Habits stay obvious';

  @override
  String get roadGuideTasksHabitsBody =>
      'Today’s habits appear here with tasks, so the next action is always in front of you.';

  @override
  String get roadGuideChatTabTitle => 'AI Helper';

  @override
  String get roadGuideChatTabBody =>
      'The Helper is here for support — questions about habits, goals, time management, and building a plan. The AI Helper can also answer other kinds of questions.';

  @override
  String get roadGuideChatInputTitle => 'Ask anything about your plan';

  @override
  String get roadGuideChatInputBody =>
      'Type a question or describe what you need: habits, goals, scheduling, or a plan to follow.';

  @override
  String get roadGuideSettingsTabTitle => 'Settings';

  @override
  String get roadGuideSettingsTabBody =>
      'Profile, theme, language, home-screen calendar, password, and support live here. Slogan and mission also help AI recommend habits.';

  @override
  String get roadGuideSettingsProfileTitle => 'Profile fuels recommendations';

  @override
  String get roadGuideSettingsProfileBody =>
      'Name, slogan, and mission describe who you are becoming — AI uses them when suggesting habits.';

  @override
  String get roadGuideSettingsReplayTitle => 'Replay anytime';

  @override
  String get roadGuideSettingsReplayBody =>
      'You can run this road guide again from Settings → About. Theme, language, and the calendar widget are just above.';

  @override
  String get calendarWidgetToday => 'Today';

  @override
  String get calendarWidgetAdd => 'Add';

  @override
  String get calendarWidgetEmpty => 'No tasks or habits';

  @override
  String get calendarWidgetSettingsSection => 'Home screen';

  @override
  String get calendarWidgetSettingsTitle => 'Calendar widget';

  @override
  String get calendarWidgetSettingsSubtitle =>
      'Show tasks and habits on the Home Screen';

  @override
  String get calendarWidgetHowToIos =>
      '1. Long-press the Home Screen\n2. Tap +\n3. Search Principles\n4. Choose Month, Week, or Today';

  @override
  String get calendarWidgetHowToAndroid =>
      '1. Long-press the Home Screen\n2. Open Widgets\n3. Find Principles\n4. Choose Month, Week, or Today';

  @override
  String get calendarWidgetAddToHome => 'Add to Home Screen';

  @override
  String get roadGuideSettingsCalendarTitle => 'Calendar on your Home Screen';

  @override
  String get roadGuideSettingsCalendarBody =>
      'Add a month, week, or today widget from here so tasks and habits stay visible without opening the app.';
}
