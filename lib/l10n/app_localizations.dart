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

  /// Theme setting label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Theme setting helper text
  ///
  /// In en, this message translates to:
  /// **'Switch between dark and light'**
  String get themeSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark (black + orange)'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

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
  /// **'Top Five Streaks'**
  String get topFiveStreaks;

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

  /// No description provided for @noStabilityData.
  ///
  /// In en, this message translates to:
  /// **'No stability data'**
  String get noStabilityData;

  /// No description provided for @habitByWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Habit By Weekdays'**
  String get habitByWeekdays;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

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

  /// No description provided for @helperTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat With Helper'**
  String get helperTitle;

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
