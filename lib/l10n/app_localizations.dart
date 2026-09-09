import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Principles'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings grouped-section header for profile fields
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsSectionProfile;

  /// Settings grouped-section header for app information and support
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Settings grouped-section header for account actions
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutLabel;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark (black + blue)'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDarkOrange.
  ///
  /// In en, this message translates to:
  /// **'Dark orange'**
  String get themeDarkOrange;

  /// No description provided for @themeDarkBlue.
  ///
  /// In en, this message translates to:
  /// **'Dark blue'**
  String get themeDarkBlue;

  /// No description provided for @themeLightOrange.
  ///
  /// In en, this message translates to:
  /// **'Light orange'**
  String get themeLightOrange;

  /// No description provided for @themeLightBlue.
  ///
  /// In en, this message translates to:
  /// **'Light blue'**
  String get themeLightBlue;

  /// Theme setting label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Theme setting helper text
  ///
  /// In en, this message translates to:
  /// **'Choose the app color theme'**
  String get themeSubtitle;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// Language setting helper text
  ///
  /// In en, this message translates to:
  /// **'Use system language or choose manually'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// Edit habit screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Habit'**
  String get editHabitTitle;

  /// No description provided for @habitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get habitNameLabel;

  /// No description provided for @habitDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get habitDescriptionLabel;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @recommendedHabitsButton.
  ///
  /// In en, this message translates to:
  /// **'Recommended Habits'**
  String get recommendedHabitsButton;

  /// Title of the recommended-habits bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Recommended habits by AI'**
  String get recommendedHabitsByAi;

  /// Confirm-dialog title before loading AI habit recommendations
  ///
  /// In en, this message translates to:
  /// **'Based on goal, mission and slogan'**
  String get confirmRecommendedHabitsTitle;

  /// Confirm-dialog body before loading AI habit recommendations
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to load recommended habits based on your chosen goal, mission and main slogan?'**
  String get confirmRecommendedHabitsMessage;

  /// Hint shown while AI habit recommendations are loading
  ///
  /// In en, this message translates to:
  /// **'If you don\'t want to wait, you can change the other fields for now.'**
  String get recommendedHabitsLoadingHint;

  /// Empty-state text in the recommended-habits sheet
  ///
  /// In en, this message translates to:
  /// **'No recommendations yet.'**
  String get recommendedHabitsEmpty;

  /// Hint under Recommended Habits when no goal is selected
  ///
  /// In en, this message translates to:
  /// **'Select a Goal above — we can recommend habits for it.'**
  String get recommendedHabitsCaptionNoGoal;

  /// Hint under Recommended Habits when a goal is selected
  ///
  /// In en, this message translates to:
  /// **'Recommendations will be for \"{goal}\" achievement.'**
  String recommendedHabitsCaptionWithGoal(String goal);

  /// Popover shown on Recommended Habits after the user selects a goal
  ///
  /// In en, this message translates to:
  /// **'We can recommend habits for achieving the selected goal: \"{goal}\".'**
  String recommendedHabitsGoalPopover(String goal);

  /// Generic loading label
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// Post-sign-in SyncGate label while bootstrap sync runs (MAUI LoadingContent)
  ///
  /// In en, this message translates to:
  /// **'Loading content...'**
  String get loadingContent;

  /// No description provided for @openHabitDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'Open habit details'**
  String get openHabitDetailsButton;

  /// No description provided for @habitDetailsFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit details'**
  String get habitDetailsFallbackTitle;

  /// Complexity value label on the habit details screen
  ///
  /// In en, this message translates to:
  /// **'Complexity'**
  String get habitComplexityLabel;

  /// Placeholder on habit details when the habit has no notes
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get habitNotesEmpty;

  /// Habit type label on the habit details screen
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get habitTypeLabel;

  /// Placeholder on habit details when the habit has no goal
  ///
  /// In en, this message translates to:
  /// **'No goal'**
  String get habitGoalEmpty;

  /// No description provided for @unarchiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchiveTooltip;

  /// No description provided for @archiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// Short edit action in the habit long-press menu
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get habitMenuEdit;

  /// Open habit details from the habits-tab long-press menu
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get habitMenuDetails;

  /// No description provided for @noHabitSelected.
  ///
  /// In en, this message translates to:
  /// **'No habit selected'**
  String get noHabitSelected;

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get overallProgress;

  /// Completed habit executions counter
  ///
  /// In en, this message translates to:
  /// **'Number of execution: {count}'**
  String executionCount(int count);

  /// Longest streak metric value
  ///
  /// In en, this message translates to:
  /// **'Longest streak: {count}'**
  String longestStreak(int count);

  /// No description provided for @topFiveStreaks.
  ///
  /// In en, this message translates to:
  /// **'Top-5 streaks'**
  String get topFiveStreaks;

  /// MAUI TopFiveStreaksExplanation snackbar on the top-5 streaks info button
  ///
  /// In en, this message translates to:
  /// **'The Top 5 habit streaks reflect the most consistent periods of personal discipline. This feature helps recognize your ability to take sustained action, supports motivation during times of doubt, and serves as a foundation for forming stable, recommended habits.'**
  String get topFiveStreaksInfo;

  /// No description provided for @noStreaksYet.
  ///
  /// In en, this message translates to:
  /// **'No streaks yet'**
  String get noStreaksYet;

  /// Days count label for streak item
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String streakDays(int days);

  /// No description provided for @stabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Stability'**
  String get stabilityTitle;

  /// MAUI StabilityExplanation snackbar on the stability chart info button
  ///
  /// In en, this message translates to:
  /// **'The Stability chart measures how consistently you maintain your habit without missing days. It highlights your overall adherence patterns, helping you see where you’re most reliable and where you might need extra focus. By tracking stability, you can celebrate steady progress, identify moments that challenge your routine, and build confidence in sustaining long‑term behavior change.'**
  String get stabilityInfo;

  /// No description provided for @noStabilityData.
  ///
  /// In en, this message translates to:
  /// **'No stability data'**
  String get noStabilityData;

  /// No description provided for @habitByWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Habit by days of the week'**
  String get habitByWeekdays;

  /// MAUI HabitByDayweeksExplanation snackbar on the weekdays chart info button
  ///
  /// In en, this message translates to:
  /// **'The Habit by Day of the Week chart shows how often you complete your habit on each day. It helps you spot which days you\'re most consistent and which ones tend to be missed. By understanding these patterns, you can adjust your routine, address weak spots, and create a more balanced and sustainable habit rhythm throughout the week.'**
  String get habitByWeekdaysInfo;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// MAUI CalendarInfoExplanation snackbar on the calendar info button
  ///
  /// In en, this message translates to:
  /// **'The execution of habits by day is displayed:\n- Blue - habit completed;\n- Cyan - it is not necessary to follow the habit.\nYou can change the status with a press.'**
  String get calendarInfo;

  /// Y-axis title on habit detail bar charts
  ///
  /// In en, this message translates to:
  /// **'Number of completions'**
  String get executionCountAxis;

  /// Frequency chip text for a daily habit
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get frequencyEveryDay;

  /// Frequency chip text for every-N-days habits
  ///
  /// In en, this message translates to:
  /// **'Every {count} day(s)'**
  String frequencyEveryXDays(int count);

  /// Frequency chip text for N times per week/month
  ///
  /// In en, this message translates to:
  /// **'{count} time(s) per {period}'**
  String frequencyTimesPerPeriod(int count, String period);

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get periodMonth;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @progressNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get progressNo;

  /// No description provided for @progressYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get progressYes;

  /// No description provided for @progressNumeric500.
  ///
  /// In en, this message translates to:
  /// **'Numeric +500'**
  String get progressNumeric500;

  /// Progress item value label
  ///
  /// In en, this message translates to:
  /// **'Value: {value}'**
  String progressValue(String value);

  /// Progress item integer date label
  ///
  /// In en, this message translates to:
  /// **'DateInt: {value}'**
  String progressDateInt(int value);

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @newGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoalLabel;

  /// Empty-state message on the goals tab
  ///
  /// In en, this message translates to:
  /// **'No goals yet. Add one above.'**
  String get goalsEmptyList;

  /// Title of the dialog used to create a goal
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get addGoalTitle;

  /// Title of the dialog used to rename a goal
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoalTitle;

  /// Hint text in the add/edit goal dialog
  ///
  /// In en, this message translates to:
  /// **'Examples of identity-oriented goals: be an Olympic champion, be confident, be free from smoking.'**
  String get goalExamplesHint;

  /// Title of the delete-goal confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete goal?'**
  String get deleteGoalQuestion;

  /// Body of the delete-goal confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'The goal will be deleted permanently. This action cannot be undone.'**
  String get deleteGoalMessage;

  /// Context-menu action to mark a goal as completed
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get markGoalCompleted;

  /// Context-menu action to mark a completed goal as active again
  ///
  /// In en, this message translates to:
  /// **'Mark as not completed'**
  String get markGoalIncomplete;

  /// Section header for completed goals in the goals list
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedGoalsHeader;

  /// Subtitle on a goal showing how many habits are grouped under it
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} habit} other{{count} habits}}'**
  String goalHabitsCount(int count);

  /// Toast shown after marking a goal as completed
  ///
  /// In en, this message translates to:
  /// **'Goal marked as completed'**
  String get goalMarkedCompleted;

  /// Toast shown after marking a completed goal as active again
  ///
  /// In en, this message translates to:
  /// **'Goal marked as not completed'**
  String get goalMarkedIncomplete;

  /// No description provided for @helperTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat With Helper'**
  String get helperTitle;

  /// Information shown from the AI helper screen's info button
  ///
  /// In en, this message translates to:
  /// **'The AI-assistant knows your habits, goals, mission, gender, and slogan. So you can ask anything about them. For example, “What should I set as my next goal?” Note that it can sometimes make mistakes. Check important information!'**
  String get helperWarning;

  /// Empty-state text shown below the AI helper animation
  ///
  /// In en, this message translates to:
  /// **'I am an AI assistant for self-development. You can ask me about different questions. For example, \"How does my personality affect my life?\"'**
  String get helperEmptyDescription;

  /// Tooltip / semantics for copying an AI helper message
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyMessage;

  /// Toast after copying an AI helper message to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Text successfully copied'**
  String get successfulCopy;

  /// Title of the AI helper chat history sidebar
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get helperChatsTitle;

  /// Button that starts a blank AI helper conversation
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get helperNewChat;

  /// Search field placeholder in the AI helper chat sidebar
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get helperSearchChatsHint;

  /// Empty state in the AI helper chat sidebar
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get helperNoChats;

  /// Fallback title when a chat has no title yet
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get helperUntitledChat;

  /// Semantics for the hamburger that opens chat history
  ///
  /// In en, this message translates to:
  /// **'Open chats'**
  String get helperOpenChats;

  /// Bottom tab label for the AI chat screen
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// Bottom tab label for the tasks screen
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tabTasks;

  /// Bottom tab label for the goals screen
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get tabGoals;

  /// Bottom tab label for the progress screen
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// Bottom tab label for the habits screen
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get tabHabits;

  /// Bottom tab label for the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @helperInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get helperInputHint;

  /// No description provided for @invalidCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get invalidCredentialsError;

  /// No description provided for @genericErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get genericErrorOccurred;

  /// Toast when connectivity is lost
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// Fallback AI helper response used in demo mode
  ///
  /// In en, this message translates to:
  /// **'I hear you. Let us break this down into one small action for today.'**
  String get chatFallbackAnswer;

  /// Default habit frequency text
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get defaultFrequencyEveryDay;

  /// Seed recommendation title #1
  ///
  /// In en, this message translates to:
  /// **'Write 3 priorities after waking up'**
  String get recommendedHabitName1;

  /// Seed recommendation reason #1
  ///
  /// In en, this message translates to:
  /// **'It turns intention into focus before distractions start.'**
  String get recommendedHabitReason1;

  /// Seed recommendation title #2
  ///
  /// In en, this message translates to:
  /// **'Walk 15 minutes after lunch'**
  String get recommendedHabitName2;

  /// Seed recommendation reason #2
  ///
  /// In en, this message translates to:
  /// **'It improves energy and consistency with minimal friction.'**
  String get recommendedHabitReason2;

  /// Seed recommendation title #3
  ///
  /// In en, this message translates to:
  /// **'Review one completed task before sleep'**
  String get recommendedHabitName3;

  /// Seed recommendation reason #3
  ///
  /// In en, this message translates to:
  /// **'It reinforces progress and keeps motivation stable.'**
  String get recommendedHabitReason3;

  /// Seed recommendation title #4
  ///
  /// In en, this message translates to:
  /// **'Read 5 pages before bed'**
  String get recommendedHabitName4;

  /// Seed recommendation reason #4
  ///
  /// In en, this message translates to:
  /// **'It creates a repeatable cue for learning and calm.'**
  String get recommendedHabitReason4;

  /// No description provided for @startupTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get started now!'**
  String get startupTitle;

  /// No description provided for @startupGoogleBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get startupGoogleBtn;

  /// No description provided for @startupAppleBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get startupAppleBtn;

  /// No description provided for @startupRegisterBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get startupRegisterBtn;

  /// No description provided for @startupRegisterWithEmailBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign up with email'**
  String get startupRegisterWithEmailBtn;

  /// No description provided for @startupLoginBtn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get startupLoginBtn;

  /// No description provided for @startupErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get startupErrorGeneric;

  /// No description provided for @transformAreasOfLifeTitle.
  ///
  /// In en, this message translates to:
  /// **'Improve lagging life areas'**
  String get transformAreasOfLifeTitle;

  /// No description provided for @transformAreasOfLifeDescription.
  ///
  /// In en, this message translates to:
  /// **'Set goals correctly and build your habits.'**
  String get transformAreasOfLifeDescription;

  /// No description provided for @chatWithHelperTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat with AI assistant'**
  String get chatWithHelperTitle;

  /// No description provided for @chatWithHelperDescription.
  ///
  /// In en, this message translates to:
  /// **'Get answers to various questions from AI assistant that takes your mission, habits, etc. into account.'**
  String get chatWithHelperDescription;

  /// No description provided for @groupHabitsByGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Continuous progress'**
  String get groupHabitsByGoalsTitle;

  /// No description provided for @groupHabitsByGoalsDescription.
  ///
  /// In en, this message translates to:
  /// **'Systematize your goals by grouping habits under goals.'**
  String get groupHabitsByGoalsDescription;

  /// No description provided for @getRecommendationsByAITitle.
  ///
  /// In en, this message translates to:
  /// **'AI recommendations'**
  String get getRecommendationsByAITitle;

  /// No description provided for @getRecommendationsByAIDescription.
  ///
  /// In en, this message translates to:
  /// **'Get AI recommendations formed based on your mission, life motto, goals, etc.'**
  String get getRecommendationsByAIDescription;

  /// No description provided for @becomeTruePersonalityTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a true personality'**
  String get becomeTruePersonalityTitle;

  /// No description provided for @becomeTruePersonalityDescription.
  ///
  /// In en, this message translates to:
  /// **'Set goals aligned with your identity. Ahead!'**
  String get becomeTruePersonalityDescription;

  /// No description provided for @ahead.
  ///
  /// In en, this message translates to:
  /// **'Ahead'**
  String get ahead;

  /// No description provided for @aboutProgram.
  ///
  /// In en, this message translates to:
  /// **'About program'**
  String get aboutProgram;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Settings and signup label for gender
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @missionLabel.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get missionLabel;

  /// No description provided for @sloganLabel.
  ///
  /// In en, this message translates to:
  /// **'Main slogan'**
  String get sloganLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get optionalLabel;

  /// Cancel button on edit dialogs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Dialog title when editing the user's name
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// Dialog title when editing gender
  ///
  /// In en, this message translates to:
  /// **'Your Gender'**
  String get yourGender;

  /// Dialog title when editing the main slogan
  ///
  /// In en, this message translates to:
  /// **'Your Main Slogan'**
  String get yourMainSlogan;

  /// Dialog title when editing the mission
  ///
  /// In en, this message translates to:
  /// **'Your Mission'**
  String get yourMission;

  /// Help text explaining what a personal mission is
  ///
  /// In en, this message translates to:
  /// **'A mission is a life goal that keeps your motivation high and helps you make the best choices in a variety of situations. For example, a mission might be: “I create IT applications to make the world a better place.” It will be used to generate habit suggestions that are more relevant to you.'**
  String get missionExplanation;

  /// Help text explaining what a main slogan is
  ///
  /// In en, this message translates to:
  /// **'A main slogan is the most important idea that guides you through life. It helps you decide how to act when you don’t feel like doing something, or when you face certain challenges or temptations. An example of a core motto: a relationship with God and a strong character determine the quality of life. A motto is used to cultivate the best recommended habits.'**
  String get mainSloganExplanation;

  /// Toast after the user name is saved
  ///
  /// In en, this message translates to:
  /// **'Your name successfully saved'**
  String get nameSavedSuccess;

  /// Toast after gender is saved
  ///
  /// In en, this message translates to:
  /// **'Your gender successfully saved'**
  String get genderSavedSuccess;

  /// Toast after the main slogan is saved
  ///
  /// In en, this message translates to:
  /// **'Your main slogan successfully saved'**
  String get sloganSavedSuccess;

  /// Toast after the mission is saved
  ///
  /// In en, this message translates to:
  /// **'Your mission successfully saved'**
  String get missionSavedSuccess;

  /// Shown when the user tries to edit email
  ///
  /// In en, this message translates to:
  /// **'This field is not editable.'**
  String get fieldIsNotEditable;

  /// Settings row that opens the Telegram channel
  ///
  /// In en, this message translates to:
  /// **'Join our Telegram channel'**
  String get joinTelegramLabel;

  /// Settings row that opens the app store listing
  ///
  /// In en, this message translates to:
  /// **'Rate us'**
  String get rateUsLabel;

  /// Title of the in-app update dialog
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get appUpdateAvailable;

  /// Dismiss button on the in-app update dialog (remind later)
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get appUpdateCloseButton;

  /// Ignore this store version on the in-app update dialog
  ///
  /// In en, this message translates to:
  /// **'Don\'t remind me of it again'**
  String get dontShowUpdateCheckBoxText;

  /// Primary button that opens the store listing for an update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// Settings row that opens the system share sheet
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareAppLabel;

  /// Text copied into the system share sheet
  ///
  /// In en, this message translates to:
  /// **'Build better habits with Principles: https://principles.top'**
  String get shareAppMessage;

  /// Settings row that opens a mail draft to support
  ///
  /// In en, this message translates to:
  /// **'Send an email to us'**
  String get contactEmailLabel;

  /// Subtitle for the contact email settings row
  ///
  /// In en, this message translates to:
  /// **'Support and Feedback'**
  String get contactEmailSubtitle;

  /// Shown when mailto cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Cannot open an app to send an email. Maybe a mail program is not installed.'**
  String get cannotOpenEmailApp;

  /// Settings row that opens the privacy policy
  ///
  /// In en, this message translates to:
  /// **'Our privacy policy'**
  String get settingsPrivacyPolicy;

  /// Settings row that opens the user agreement
  ///
  /// In en, this message translates to:
  /// **'User agreement'**
  String get settingsUserAgreement;

  /// Settings row that opens change password
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordLabel;

  /// Settings row that deletes the account
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountLabel;

  /// Title of the delete-account confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountQuestion;

  /// Body of the delete-account confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Once you delete, it\'s gone for good.'**
  String get deleteAccountConfirm;

  /// Clickable User Agreement link label
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// Clickable Privacy Policy link label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @signupDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By clicking \'Sign up\', you agree to the {userAgreement} and {privacyPolicy}'**
  String signupDisclaimer(String userAgreement, String privacyPolicy);

  /// No description provided for @errorEmailAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'User with this Email already exists.'**
  String get errorEmailAlreadyExists;

  /// No description provided for @loginDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By clicking \'Log in\', you agree to the {userAgreement} and {privacyPolicy}'**
  String loginDisclaimer(String userAgreement, String privacyPolicy);

  /// No description provided for @tryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Try again in {seconds} s.'**
  String tryAgainIn(int seconds);

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @principlesAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Principles'**
  String get principlesAppTitle;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// Validation message when a required form field is empty
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// Validation message when email format is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmailFormat;

  /// Validation message when password is shorter than 6 characters
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get passwordMinLength;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and new password. We will send a confirmation code.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @sendCodeBtn.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCodeBtn;

  /// No description provided for @confirmCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmation Code'**
  String get confirmCodeTitle;

  /// No description provided for @confirmCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code we just sent to your email.'**
  String get confirmCodeSubtitle;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeLabel;

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBtn;

  /// No description provided for @wrongCodeError.
  ///
  /// In en, this message translates to:
  /// **'Wrong confirmation code'**
  String get wrongCodeError;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success! Your password was changed successfully.'**
  String get passwordChangedSuccess;

  /// Title for error dialog popups
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// Retry button on the server-down dialog (MAUI Retry)
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// MAUI ServerTechnicalWorkIsInProgress — HTTP 404/503 on server-required actions
  ///
  /// In en, this message translates to:
  /// **'Technical work on our server is in progress. Please try again later.'**
  String get serverTechnicalWorkIsInProgress;

  /// Dismiss button label on alert dialogs
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// Confirm button label on confirmation dialogs
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesButton;

  /// Cancel button label on confirmation dialogs
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noButton;

  /// Shown when Apple Sign-In fails with AuthorizationErrorCode.unknown (error 1000)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete Sign in with Apple. Make sure you\'re signed into iCloud on this device, then try again.'**
  String get appleAuthUnknownError;

  /// Shown when Sign in with Apple is not available on the device
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple is unavailable. Please sign in to iCloud and try again.'**
  String get appleAuthUnavailableOnDevice;

  /// Fallback message when Google or Apple sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please use the \"Sign up with email\" or \"Log in\" option.'**
  String get somethingWentWrongWhenUserAuthsUsingExternalService;

  /// Bottom tab label for the AI assistant
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get tabAssistant;

  /// Bottom tab label for the profile screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Title of the archived habits bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// Empty-state text shown when there are no archived habits
  ///
  /// In en, this message translates to:
  /// **'This section displays the habits you have archived. You can return to them whenever you are ready to work on them again.'**
  String get archiveEmptyDescription;

  /// Full archive explanation shown after tapping the info button
  ///
  /// In en, this message translates to:
  /// **'Why do you need an archive?\n✅ Plan habits you want to add or change in the future.\n🔁 Analyze reasons - which habits worked and which ones were too complicated or irrelevant.\n🌱 Try again - sometimes it\'s good to go back to an old habit by changing the difficulty or approach. For example, train in the morning instead of the evening.\n\nTip: before creating a new habit, look at the archive - maybe something similar has already happened, and now you know how to do it better.'**
  String get archiveInfoDescription;

  /// Tooltip for the archive info button
  ///
  /// In en, this message translates to:
  /// **'Why do you need an archive?'**
  String get archiveInfoTooltip;

  /// Title of the unarchive confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Unarchive Habit?'**
  String get unarchiveHabitQuestion;

  /// Body of the unarchive confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This action will restore the habit to your active list.'**
  String get unarchiveHabitMessage;

  /// Title of the add/edit habit page
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get habitScreenTitle;

  /// First tab on the add/edit habit page
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get habitDataTab;

  /// Second tab on the add/edit habit page
  ///
  /// In en, this message translates to:
  /// **'How to maintain'**
  String get habitHowToKeepTab;

  /// Habit name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get habitNameField;

  /// Info text shown next to the habit name field
  ///
  /// In en, this message translates to:
  /// **'Specify the habit name and the time or place you will do it. This increases the chance you will stick to it. Example: I pray as soon as I wake up.'**
  String get habitNameInfo;

  /// Goal picker field label on the habit page
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get habitGoalLabel;

  /// Title of the goal selection bottom sheet when editing a habit
  ///
  /// In en, this message translates to:
  /// **'Select habit goal'**
  String get selectHabitGoalTitle;

  /// Hint shown at the bottom of the goal selection sheet
  ///
  /// In en, this message translates to:
  /// **'Recommendation: pick a concrete goal or an identity-oriented one — it shapes your life.'**
  String get selectHabitGoalRecommendation;

  /// Flexible habit type chip
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get habitFlexible;

  /// Tooltip shown when tapping the Flexible habit type chip
  ///
  /// In en, this message translates to:
  /// **'This is a habit type that a person follows most of the time, but may make exceptions in special situations. For example, it may be the habit of telling the truth but being able to keep silent or deceive when it could cause serious harm to others.'**
  String get habitFlexibleInfo;

  /// Strict habit type chip
  ///
  /// In en, this message translates to:
  /// **'Without exceptions'**
  String get habitNoExceptions;

  /// Tooltip shown when tapping the Without exceptions habit type chip
  ///
  /// In en, this message translates to:
  /// **'This is a habit type that a person adheres to strictly and never makes exceptions, even in emergency situations. For example, refusal to drink alcohol or tobacco, regardless of the circumstances.'**
  String get habitNoExceptionsInfo;

  /// Frequency picker field label
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get habitFrequency;

  /// Reminder picker field label
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get habitReminder;

  /// Notes field label on the how-to-maintain tab
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get habitNotes;

  /// Difficulty stepper label
  ///
  /// In en, this message translates to:
  /// **'Difficulty (1 - 10)'**
  String get habitDifficulty;

  /// Tooltip shown when tapping the difficulty info icon
  ///
  /// In en, this message translates to:
  /// **'How difficult is it to stick to the habit in terms of effort, time and self-control'**
  String get habitDifficultyInfo;

  /// Help text under the difficulty control for how many days automation takes on a new habit
  ///
  /// In en, this message translates to:
  /// **'Habit automation requires regular performance for {days} day(s).'**
  String habitAutomationExplanation(int days);

  /// Help text under difficulty when an existing habit has already reached 100%
  ///
  /// In en, this message translates to:
  /// **'The habit is already automated'**
  String get habitAlreadyAutomated;

  /// Help text under difficulty when fewer than 30 days remain until 100%
  ///
  /// In en, this message translates to:
  /// **'Just {days} days to go until your habit becomes fully automatic.'**
  String habitDaysToGoUntilAutomaticJust(int days);

  /// Help text under difficulty when 30 or more days remain until 100%
  ///
  /// In en, this message translates to:
  /// **'There are still {days} days to go until your habit becomes fully automatic.'**
  String habitDaysToGoUntilAutomaticStill(int days);

  /// Open habit details from the archived habit long-press menu
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get habitMenuViewDetails;

  /// Restore an archived habit to the active list
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get habitMenuRestore;

  /// Delete habit action in the archived habit long-press menu
  ///
  /// In en, this message translates to:
  /// **'Delete habit'**
  String get habitMenuDelete;

  /// Title of the delete-habit confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete habit?'**
  String get deleteHabitQuestion;

  /// Body of the delete-habit confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'The habit will be deleted permanently. This action cannot be undone.'**
  String get deleteHabitMessage;

  /// Prefix for the selected date on the habits tab when it is today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get habitsTodayLabel;

  /// Summary banner on the habits tab showing how many habits are done for the selected day
  ///
  /// In en, this message translates to:
  /// **'Completed this day'**
  String get habitsCompletedToday;

  /// Empty-state message on the habits tab
  ///
  /// In en, this message translates to:
  /// **'No habits. Tap + to add.'**
  String get habitsEmptyList;

  /// Group header for habits that are not linked to a goal
  ///
  /// In en, this message translates to:
  /// **'*Goal not defined'**
  String get undefinedGoalLabel;

  /// Explanation shown when tapping the streak counter on the habits tab
  ///
  /// In en, this message translates to:
  /// **'Shows how many days in a row you opened the app and completed habits. If you skip even one day, the streak resets.'**
  String get habitStreakExplanation;

  /// Tooltip for the habits-tab header filter button
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get habitFiltersTooltip;

  /// Heading for the habits-tab filter panel
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get habitFilters;

  /// Habits filter section for completion status on the selected day
  ///
  /// In en, this message translates to:
  /// **'Day status'**
  String get habitFilterDayStatus;

  /// Habits filter section for whether the habit applies on the selected day
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get habitFilterDue;

  /// Habits filter section for the linked goal
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get habitFilterGoal;

  /// Show every habit in a habits-tab filter dimension
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get habitFilterAll;

  /// Habits day-status filter for habits not completed or skipped
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get habitFilterNotDone;

  /// Habits day-status filter for completed habits
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get habitFilterDone;

  /// Show only habits that apply on the selected day
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get habitFilterDueOnly;

  /// Show only habits that do not apply on the selected day
  ///
  /// In en, this message translates to:
  /// **'Not due'**
  String get habitFilterNotDue;

  /// Reset habits-tab filters to defaults
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get habitClearFilters;

  /// Empty-state when habits exist but filters hide them all
  ///
  /// In en, this message translates to:
  /// **'No habits match the filters.'**
  String get habitFiltersEmpty;

  /// Title of the archive confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Move habit to archive?'**
  String get archiveHabitQuestion;

  /// Body of the archive confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will move the habit to the archive. You can resume working on it later.'**
  String get archiveHabitMessage;

  /// Error shown when tapping a future day on the habit calendar
  ///
  /// In en, this message translates to:
  /// **'You can\'t mark a habit as done for future days'**
  String get cannotCompleteHabitInTheFuture;

  /// Label for the daily progress-reminder title field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reminderTitleLabel;

  /// Label for the daily progress-reminder description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get reminderDescriptionLabel;

  /// Label for the daily progress-reminder time field
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reminderTimeLabel;

  /// Toggle label to enable the daily progress reminder
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get reminderEnableLabel;

  /// Dismiss button on the reminder time picker
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// Sheet title and Tasks app-bar tooltip for the daily goals/habits/tasks check-in reminder
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get habitsReportReminderSheetTitle;

  /// Short explanation under the daily reminder sheet title
  ///
  /// In en, this message translates to:
  /// **'A daily nudge to review your goals, habits, and tasks'**
  String get habitsReportReminderSubtitle;

  /// Expands title/description fields on the daily reminder sheet
  ///
  /// In en, this message translates to:
  /// **'Customize message'**
  String get habitsReportReminderCustomize;

  /// SnackBar after enabling the daily reminder
  ///
  /// In en, this message translates to:
  /// **'Daily reminder on · {time}'**
  String habitsReportReminderSavedOn(String time);

  /// SnackBar after disabling the daily reminder
  ///
  /// In en, this message translates to:
  /// **'Daily reminder off'**
  String get habitsReportReminderSavedOff;

  /// Default notification title for the daily progress reminder when the server has none
  ///
  /// In en, this message translates to:
  /// **'Remember your day'**
  String get habitsReportReminderTitleText;

  /// Default notification body for the daily progress reminder. Prefixed with the user name when set.
  ///
  /// In en, this message translates to:
  /// **'time to review your goals, habits, and tasks'**
  String get habitsReportReminderDescriptionText;

  /// Tasks app-bar tooltip when the daily reminder is enabled
  ///
  /// In en, this message translates to:
  /// **'Daily reminder on · {time}'**
  String habitsReportReminderOnTooltip(String time);

  /// Tasks app-bar tooltip when the daily reminder is disabled or unset
  ///
  /// In en, this message translates to:
  /// **'Daily reminder off'**
  String get habitsReportReminderOffTooltip;

  /// Subtitle on the Tasks list-menu row for the daily reminder
  ///
  /// In en, this message translates to:
  /// **'Remind me to check goals, habits, and tasks'**
  String get habitsReportReminderMenuHint;

  /// SnackBar when a notification tap targets a deleted task or habit
  ///
  /// In en, this message translates to:
  /// **'This reminder is no longer available'**
  String get notificationTargetNotFound;

  /// Shown when enabling a reminder but the device cannot send notifications
  ///
  /// In en, this message translates to:
  /// **'Oops.. It looks like your operating system doesn\'t support notifications. Please try updating it.'**
  String get deviceDoesNotSupportNotifications;

  /// SyncGate body when the account has reminders but notification permission is off (MAUI AfterLoginWhenUserAccountHaveReminders)
  ///
  /// In en, this message translates to:
  /// **'Your account has motivating reminders. They can be restore on your device.'**
  String get afterLoginWhenUserAccountHaveReminders;

  /// SyncGate title while explaining reminder restore (MAUI RestoreReminders)
  ///
  /// In en, this message translates to:
  /// **'Restore reminders'**
  String get restoreReminders;

  /// Title when notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsDisabledTitle;

  /// Asks whether to open OS settings after notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'To receive reminders, allow notifications in device settings. Open settings now?'**
  String get notificationsDisabledMessage;

  /// No description provided for @scheduleDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scheduleDate;

  /// No description provided for @scheduleDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get scheduleDuration;

  /// No description provided for @scheduleTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduleTime;

  /// No description provided for @scheduleReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get scheduleReminder;

  /// No description provided for @scheduleRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get scheduleRepeat;

  /// No description provided for @scheduleClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get scheduleClear;

  /// No description provided for @scheduleOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get scheduleOnTime;

  /// No description provided for @scheduleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get scheduleCustom;

  /// No description provided for @scheduleRecents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get scheduleRecents;

  /// No description provided for @scheduleConstantReminder.
  ///
  /// In en, this message translates to:
  /// **'Constant Reminder'**
  String get scheduleConstantReminder;

  /// Popover explaining Constant Reminder on the reminder picker
  ///
  /// In en, this message translates to:
  /// **'Keeps reminding you until you mark this as done.'**
  String get scheduleConstantReminderExplanation;

  /// No description provided for @scheduleAllDay.
  ///
  /// In en, this message translates to:
  /// **'All Day'**
  String get scheduleAllDay;

  /// No description provided for @scheduleByDueDates.
  ///
  /// In en, this message translates to:
  /// **'By Due Dates'**
  String get scheduleByDueDates;

  /// No description provided for @scheduleByCompletion.
  ///
  /// In en, this message translates to:
  /// **'By Completion Date'**
  String get scheduleByCompletion;

  /// Skip the in-app road guide
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get roadGuideSkip;

  /// Go to the previous road guide step
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get roadGuideBack;

  /// Advance to the next road guide step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get roadGuideNext;

  /// Finish the road guide
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get roadGuideDone;

  /// Settings row to replay the road guide
  ///
  /// In en, this message translates to:
  /// **'App road guide'**
  String get roadGuideReplayLabel;

  /// Settings subtitle for replaying the road guide
  ///
  /// In en, this message translates to:
  /// **'Walk through goals, habits, tasks, and settings'**
  String get roadGuideReplaySubtitle;

  /// Badge on temporary demo items during the road guide
  ///
  /// In en, this message translates to:
  /// **'example'**
  String get roadGuideExampleBadge;

  /// Demo goal name shown during the road guide
  ///
  /// In en, this message translates to:
  /// **'Get fit'**
  String get roadGuideDemoGoalName;

  /// Demo habit name shown during the road guide
  ///
  /// In en, this message translates to:
  /// **'Morning workout'**
  String get roadGuideDemoHabitName;

  /// Demo task name shown during the road guide
  ///
  /// In en, this message translates to:
  /// **'Book a training session'**
  String get roadGuideDemoTaskName;

  /// No description provided for @roadGuideGoalsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with a goal'**
  String get roadGuideGoalsTabTitle;

  /// No description provided for @roadGuideGoalsTabBody.
  ///
  /// In en, this message translates to:
  /// **'Principles automates goal achievement. Open Goals to define what you want to reach.'**
  String get roadGuideGoalsTabBody;

  /// No description provided for @roadGuideGoalsComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your goal'**
  String get roadGuideGoalsComposerTitle;

  /// No description provided for @roadGuideGoalsComposerBody.
  ///
  /// In en, this message translates to:
  /// **'Write the outcome you want — habits will be organized under it.'**
  String get roadGuideGoalsComposerBody;

  /// No description provided for @roadGuideGoalsDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals organize habits'**
  String get roadGuideGoalsDemoTitle;

  /// No description provided for @roadGuideGoalsDemoBody.
  ///
  /// In en, this message translates to:
  /// **'Each goal becomes a container for the habits that move you toward it.'**
  String get roadGuideGoalsDemoBody;

  /// No description provided for @roadGuideHabitsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits get you there'**
  String get roadGuideHabitsTabTitle;

  /// No description provided for @roadGuideHabitsTabBody.
  ///
  /// In en, this message translates to:
  /// **'Habits are the repeating actions that automate progress toward your goal.'**
  String get roadGuideHabitsTabBody;

  /// No description provided for @roadGuideHabitsFabTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a habit to a goal'**
  String get roadGuideHabitsFabTitle;

  /// No description provided for @roadGuideHabitsFabBody.
  ///
  /// In en, this message translates to:
  /// **'Create habits and link them to a goal so every completion counts toward achievement.'**
  String get roadGuideHabitsFabBody;

  /// No description provided for @roadGuideRecommendTitle.
  ///
  /// In en, this message translates to:
  /// **'Get habit recommendations'**
  String get roadGuideRecommendTitle;

  /// No description provided for @roadGuideRecommendBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Recommended Habits here. AI suggests habits from your goal, mission, and slogan.'**
  String get roadGuideRecommendBody;

  /// No description provided for @roadGuideHabitsDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Track habits under a goal'**
  String get roadGuideHabitsDemoTitle;

  /// No description provided for @roadGuideHabitsDemoBody.
  ///
  /// In en, this message translates to:
  /// **'Complete habits consistently — that is how goal achievement becomes automatic.'**
  String get roadGuideHabitsDemoBody;

  /// No description provided for @roadGuideHabitDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit details'**
  String get roadGuideHabitDetailTitle;

  /// No description provided for @roadGuideHabitDetailBody.
  ///
  /// In en, this message translates to:
  /// **'Open a habit to see progress, streaks, and stability — how consistently you are following through.'**
  String get roadGuideHabitDetailBody;

  /// No description provided for @roadGuideTasksTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks free your head'**
  String get roadGuideTasksTabTitle;

  /// No description provided for @roadGuideTasksTabBody.
  ///
  /// In en, this message translates to:
  /// **'Write down what you must not forget. Tasks hold the details so you can focus on habits and the goal.'**
  String get roadGuideTasksTabBody;

  /// No description provided for @roadGuideTasksAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get roadGuideTasksAddTitle;

  /// No description provided for @roadGuideTasksAddBody.
  ///
  /// In en, this message translates to:
  /// **'Use + for one-off work, reminders, and steps that sit beside your habits.'**
  String get roadGuideTasksAddBody;

  /// No description provided for @roadGuideTasksDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Remember everything'**
  String get roadGuideTasksDemoTitle;

  /// No description provided for @roadGuideTasksDemoBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks hold the details habits do not cover — so nothing slips while you work toward the goal.'**
  String get roadGuideTasksDemoBody;

  /// No description provided for @roadGuideTasksHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits stay obvious'**
  String get roadGuideTasksHabitsTitle;

  /// No description provided for @roadGuideTasksHabitsBody.
  ///
  /// In en, this message translates to:
  /// **'Today’s habits appear here with tasks, so the next action is always in front of you.'**
  String get roadGuideTasksHabitsBody;

  /// No description provided for @roadGuideChatTabTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Helper'**
  String get roadGuideChatTabTitle;

  /// No description provided for @roadGuideChatTabBody.
  ///
  /// In en, this message translates to:
  /// **'The Helper is here for support — questions about habits, goals, time management, and building a plan. The AI Helper can also answer other kinds of questions.'**
  String get roadGuideChatTabBody;

  /// No description provided for @roadGuideChatInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your plan'**
  String get roadGuideChatInputTitle;

  /// No description provided for @roadGuideChatInputBody.
  ///
  /// In en, this message translates to:
  /// **'Type a question or describe what you need: habits, goals, scheduling, or a plan to follow.'**
  String get roadGuideChatInputBody;

  /// No description provided for @roadGuideSettingsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get roadGuideSettingsTabTitle;

  /// No description provided for @roadGuideSettingsTabBody.
  ///
  /// In en, this message translates to:
  /// **'Profile, theme, language, home-screen calendar, password, and support live here. Slogan and mission also help AI recommend habits.'**
  String get roadGuideSettingsTabBody;

  /// No description provided for @roadGuideSettingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile fuels recommendations'**
  String get roadGuideSettingsProfileTitle;

  /// No description provided for @roadGuideSettingsProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Name, slogan, and mission describe who you are becoming — AI uses them when suggesting habits.'**
  String get roadGuideSettingsProfileBody;

  /// No description provided for @roadGuideSettingsReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay anytime'**
  String get roadGuideSettingsReplayTitle;

  /// No description provided for @roadGuideSettingsReplayBody.
  ///
  /// In en, this message translates to:
  /// **'You can run this road guide again from Settings → About. Theme, language, and the calendar widget are just above.'**
  String get roadGuideSettingsReplayBody;

  /// Home-screen calendar widget Today control
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarWidgetToday;

  /// Home-screen calendar widget add-task control
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get calendarWidgetAdd;

  /// No description provided for @calendarWidgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks or habits'**
  String get calendarWidgetEmpty;

  /// Settings section for home-screen widgets
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get calendarWidgetSettingsSection;

  /// Settings row to add the calendar home-screen widget
  ///
  /// In en, this message translates to:
  /// **'Calendar widget'**
  String get calendarWidgetSettingsTitle;

  /// Subtitle for the calendar widget Settings row
  ///
  /// In en, this message translates to:
  /// **'Show tasks and habits on the Home Screen'**
  String get calendarWidgetSettingsSubtitle;

  /// Steps to add the calendar widget on iOS
  ///
  /// In en, this message translates to:
  /// **'1. Long-press the Home Screen\n2. Tap +\n3. Search Principles\n4. Choose Month, Week, or Today'**
  String get calendarWidgetHowToIos;

  /// Steps to add the calendar widget on Android
  ///
  /// In en, this message translates to:
  /// **'1. Long-press the Home Screen\n2. Open Widgets\n3. Find Principles\n4. Choose Month, Week, or Today'**
  String get calendarWidgetHowToAndroid;

  /// Android pin-widget button in the how-to dialog
  ///
  /// In en, this message translates to:
  /// **'Add to Home Screen'**
  String get calendarWidgetAddToHome;

  /// Road guide step title for the calendar widget Settings row
  ///
  /// In en, this message translates to:
  /// **'Calendar on your Home Screen'**
  String get roadGuideSettingsCalendarTitle;

  /// No description provided for @roadGuideSettingsCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'Add a month, week, or today widget from here so tasks and habits stay visible without opening the app.'**
  String get roadGuideSettingsCalendarBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
