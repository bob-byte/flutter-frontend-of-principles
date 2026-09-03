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
  String get logoutLabel => 'Вийти';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна (чорна + синя)';

  @override
  String get themeSystem => 'Системна';

  @override
  String get themeDarkOrange => 'Темна помаранчева';

  @override
  String get themeDarkBlue => 'Темна синя';

  @override
  String get themeLightOrange => 'Світла помаранчева';

  @override
  String get themeLightBlue => 'Світла синя';

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
  String get tabChat => 'Чат';

  @override
  String get tabTasks => 'Завдання';

  @override
  String get tabGoals => 'Цілі';

  @override
  String get tabProgress => 'Прогрес';

  @override
  String get tabHabits => 'Звички';

  @override
  String get tabSettings => 'Налаштування';

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

  @override
  String get startupTitle => 'Давай почнемо зараз!';

  @override
  String get startupGoogleBtn => 'Продовжити через Google';

  @override
  String get startupAppleBtn => 'Продовжити через Apple';

  @override
  String get startupRegisterBtn => 'Зареєструватись';

  @override
  String get startupRegisterWithEmailBtn => 'Зареєструватись';

  @override
  String get startupLoginBtn => 'Вхід';

  @override
  String get startupErrorGeneric => 'Щось пішло не так';

  @override
  String get transformAreasOfLifeTitle => 'Покращ відстаючі сфери життя';

  @override
  String get transformAreasOfLifeDescription =>
      'Встановлюй цілі правильно та будуй свої звички.';

  @override
  String get chatWithHelperTitle => 'Чат з ШІ-помічником';

  @override
  String get chatWithHelperDescription =>
      'Отримай відповідь на різноманітні питання від ШІ-асистента, який зважає на твою місію, звички й т.д.';

  @override
  String get groupHabitsByGoalsTitle => 'Безперервний прогрес';

  @override
  String get groupHabitsByGoalsDescription =>
      'Систематизуй досягнення цілей, групувавши звички за цілями.';

  @override
  String get getRecommendationsByAITitle => 'ШІ-рекомендації';

  @override
  String get getRecommendationsByAIDescription =>
      'Отримай ШІ-рекомендації, що сформовані на основі твоєї місії, гасла по життю, цілях і т.д.';

  @override
  String get becomeTruePersonalityTitle => 'Стань справжньою особистістю';

  @override
  String get becomeTruePersonalityDescription =>
      'Встанови цілі, що орієнтовані на твою ідентичність. Вперед!';

  @override
  String get ahead => 'Вперед';

  @override
  String get aboutProgram => 'Про програму';

  @override
  String get nameLabel => 'Ім\'я';

  @override
  String get genderMale => 'Чоловік';

  @override
  String get genderFemale => 'Жінка';

  @override
  String get genderOther => 'Інша стать';

  @override
  String get missionLabel => 'Місія';

  @override
  String get sloganLabel => 'Основне гасло';

  @override
  String get optionalLabel => '(Необов\'язково)';

  @override
  String get cancelButton => 'Скасувати';

  @override
  String get yourName => 'Твоє Імʼя';

  @override
  String get yourMainSlogan => 'Твоє Основне Гасло';

  @override
  String get yourMission => 'Твоя Місія';

  @override
  String get missionExplanation =>
      'Вона буде використана для створення більш доцільних для вас рекомендованих звичок. Місія - це життєва мета, яка постійно підтримує високий рівень мотивації й допомагає зробити найкращий вибір у різноманітних ситуаціях. Наприклад, місія може звучати так: “Я створюю IT-додатки, щоб робити світ кращим\".';

  @override
  String get mainSloganExplanation =>
      'Основне гасло буде використано для формування кращих рекомендованих звичок. Воно допомагає визначити, як діяти, коли вам чогось не хочеться або виникають певні випробування чи спокуси. Приклад основного гасла: стосунки з Богом та сильний характер визначають якість життя.';

  @override
  String get nameSavedSuccess => 'Твоє імʼя успішно збережене';

  @override
  String get sloganSavedSuccess => 'Твоє основне гасло успішно збережене';

  @override
  String get missionSavedSuccess => 'Твоя місія успішно збережена';

  @override
  String get fieldIsNotEditable => 'Це поле не доступне для редагування.';

  @override
  String get joinTelegramLabel => 'Приєднуйтесь до нашого Telegram-каналу';

  @override
  String get rateUsLabel => 'Оцінити додаток';

  @override
  String get shareAppLabel => 'Поділитися додатком';

  @override
  String get shareAppMessage =>
      'Розвивай кращі звички з Principles: https://principles.top';

  @override
  String get contactEmailLabel => 'Напишіть нам лист';

  @override
  String get contactEmailSubtitle => 'Підтримка та відгуки';

  @override
  String get cannotOpenEmailApp =>
      'Не вдається відкрити програму для надсилання електронного листа. Можливо, її не встановлено.';

  @override
  String get settingsPrivacyPolicy => 'Політика конфіденційності';

  @override
  String get settingsUserAgreement => 'Угода користувача';

  @override
  String get changePasswordLabel => 'Змінити пароль';

  @override
  String get deleteAccountLabel => 'Видалити акаунт';

  @override
  String get deleteAccountQuestion => 'Видалити акаунт?';

  @override
  String get deleteAccountConfirm =>
      'Акаунт буде видалено назавжди. Ця дія не може бути скасована.';

  @override
  String get userAgreement => 'Угодою Користувача';

  @override
  String get privacyPolicy => 'Політикою Конфіденційності';

  @override
  String signupDisclaimer(String userAgreement, String privacyPolicy) {
    return 'Натискаючи кнопку \'Зареєструватись\', ви погоджуєтесь з $userAgreement та $privacyPolicy';
  }

  @override
  String get errorEmailAlreadyExists => 'Користувач з таким Email вже існує.';

  @override
  String loginDisclaimer(String userAgreement, String privacyPolicy) {
    return 'Натискаючи кнопку \'Вхід\', ви погоджуєтесь з $userAgreement та $privacyPolicy';
  }

  @override
  String tryAgainIn(int seconds) {
    return 'Спробуйте ще раз через $seconds с.';
  }

  @override
  String get forgotPassword => 'Забули пароль?';

  @override
  String get principlesAppTitle => 'Principles';

  @override
  String get loginButton => 'Вхід';

  @override
  String get fieldRequired => 'Поле обов\'язкове';

  @override
  String get invalidEmailFormat => 'Невірний формат пошти';

  @override
  String get passwordMinLength => 'Мінімум 6 символів';

  @override
  String get forgotPasswordTitle => 'Відновлення пароля';

  @override
  String get forgotPasswordSubtitle =>
      'Введіть вашу електронну пошту та новий пароль. Ми надішлемо код підтвердження.';

  @override
  String get newPasswordLabel => 'Новий пароль';

  @override
  String get sendCodeBtn => 'Надіслати код';

  @override
  String get confirmCodeTitle => 'Код підтвердження';

  @override
  String get confirmCodeSubtitle =>
      'Будь ласка, введіть код, який ми щойно відправили на вашу пошту.';

  @override
  String get codeLabel => 'Код';

  @override
  String get confirmBtn => 'Підтвердити';

  @override
  String get wrongCodeError => 'Невірний код підтвердження';

  @override
  String get passwordChangedSuccess => 'Успіх! Ваш пароль успішно змінено.';

  @override
  String get errorTitle => 'Помилка';

  @override
  String get okButton => 'ОК';

  @override
  String get yesButton => 'Так';

  @override
  String get noButton => 'Ні';

  @override
  String get appleAuthUnknownError =>
      'Не вдалося увійти через Apple. Переконайтесь, що ви увійшли в iCloud на цьому пристрої, і спробуйте ще раз.';

  @override
  String get appleAuthUnavailableOnDevice =>
      'Вхід через Apple недоступний. Увійдіть в iCloud і спробуйте ще раз.';

  @override
  String get somethingWentWrongWhenUserAuthsUsingExternalService =>
      'Щось пішло не так. Скористайтесь опцією «Зареєструватись через email» або «Вхід».';
}
