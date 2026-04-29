// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Принципи';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get themeLabel => 'Тема';

  @override
  String get themeSubtitle => 'Перемикайте між темною та світлою';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна (чорна + помаранчева)';

  @override
  String get themeSystem => 'Системна';

  @override
  String get languageLabel => 'Мова';

  @override
  String get languageSubtitle =>
      'Використовуйте системну мову або оберіть вручну';

  @override
  String get languageSystem => 'Системна';

  @override
  String get languageEnglish => 'Англійська';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get editHabitTitle => 'Редагувати звичку';

  @override
  String get habitNameLabel => 'Назва звички';

  @override
  String get habitDescriptionLabel => 'Опис';

  @override
  String get saveButton => 'Зберегти';

  @override
  String get recommendedHabitsButton => 'Рекомендовані звички';

  @override
  String get openHabitDetailsButton => 'Відкрити деталі звички';

  @override
  String get habitDetailsFallbackTitle => 'Деталі звички';

  @override
  String get unarchiveTooltip => 'Розархівувати';

  @override
  String get archiveTooltip => 'Архівувати';

  @override
  String get deleteTooltip => 'Видалити';

  @override
  String get noHabitSelected => 'Звичку не вибрано';

  @override
  String get overallProgress => 'Загальний прогрес';

  @override
  String executionCount(int count) {
    return 'Кількість виконань: $count';
  }

  @override
  String longestStreak(int count) {
    return 'Найдовша серія: $count';
  }

  @override
  String get topFiveStreaks => 'Топ 5 серій';

  @override
  String get noStreaksYet => 'Серій поки немає';

  @override
  String streakDays(int days) {
    return '$days днів';
  }

  @override
  String get stabilityTitle => 'Стабільність';

  @override
  String get noStabilityData => 'Немає даних про стабільність';

  @override
  String get habitByWeekdays => 'Звичка за днями тижня';

  @override
  String get calendarTitle => 'Календар';

  @override
  String get weekdayMon => 'Пн';

  @override
  String get weekdayTue => 'Вт';

  @override
  String get weekdayWed => 'Ср';

  @override
  String get weekdayThu => 'Чт';

  @override
  String get weekdayFri => 'Пт';

  @override
  String get weekdaySat => 'Сб';

  @override
  String get weekdaySun => 'Нд';

  @override
  String get progressTitle => 'Прогрес';

  @override
  String get progressNo => 'Ні';

  @override
  String get progressYes => 'Так';

  @override
  String get progressNumeric500 => 'Числове +500';

  @override
  String progressValue(String value) {
    return 'Значення: $value';
  }

  @override
  String progressDateInt(int value) {
    return 'ДатаInt: $value';
  }

  @override
  String get loginTitle => 'Вхід';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get signInButton => 'Увійти';

  @override
  String get goalsTitle => 'Цілі';

  @override
  String get newGoalLabel => 'Нова ціль';

  @override
  String get helperTitle => 'Чат з помічником';

  @override
  String get helperInputHint => 'Введіть текст';

  @override
  String get invalidCredentialsError => 'Невірні облікові дані';

  @override
  String get genericErrorOccurred => 'Сталася помилка';

  @override
  String get chatFallbackAnswer =>
      'Я вас чую. Давайте розіб\'ємо це на одну невелику дію на сьогодні.';

  @override
  String get defaultFrequencyEveryDay => 'Щодня';

  @override
  String get recommendedHabitName1 =>
      'Після пробудження записуйте 3 пріоритети';

  @override
  String get recommendedHabitReason1 =>
      'Це перетворює намір на фокус до початку відволікань.';

  @override
  String get recommendedHabitName2 => 'Гуляйте 15 хвилин після обіду';

  @override
  String get recommendedHabitReason2 =>
      'Це покращує енергію та регулярність із мінімальними зусиллями.';

  @override
  String get recommendedHabitName3 =>
      'Перед сном переглядайте одну виконану задачу';

  @override
  String get recommendedHabitReason3 =>
      'Це закріплює прогрес і підтримує стабільну мотивацію.';

  @override
  String get recommendedHabitName4 => 'Читайте 5 сторінок перед сном';

  @override
  String get recommendedHabitReason4 =>
      'Це створює повторюваний сигнал для навчання та спокою.';
}
