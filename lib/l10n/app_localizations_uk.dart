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
  String get settingsSectionProfile => 'Профіль';

  @override
  String get settingsSectionAbout => 'Про застосунок';

  @override
  String get settingsSectionAccount => 'Обліковий запис';

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
  String get themeLabel => 'Тема';

  @override
  String get themeSubtitle => 'Оберіть кольорову тему застосунку';

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
  String get recommendedHabitsByAi => 'Рекомендовані звички штучним інтелектом';

  @override
  String get confirmRecommendedHabitsTitle => 'На основі цілі, місії та гасла';

  @override
  String get confirmRecommendedHabitsMessage =>
      'Ви впевнені, що хочете завантажити звички на основі вибраної цілі, місії та основного гасла?';

  @override
  String get recommendedHabitsLoadingHint =>
      'Якщо ви не хочете чекати, ви можете поки що змінити інші поля.';

  @override
  String get recommendedHabitsEmpty => 'Рекомендацій ще немає.';

  @override
  String get recommendedHabitsCaptionNoGoal =>
      'Оберіть ціль вище — ми можемо рекомендувати звички на її основі.';

  @override
  String recommendedHabitsCaptionWithGoal(String goal) {
    return 'Рекомендації будуть для досягнення «$goal».';
  }

  @override
  String recommendedHabitsGoalPopover(String goal) {
    return 'Ми можемо рекомендувати звички для досягнення вибраної цілі: «$goal».';
  }

  @override
  String get loadingLabel => 'Завантаження';

  @override
  String get openHabitDetailsButton => 'Відкрити деталі звички';

  @override
  String get habitDetailsFallbackTitle => 'Деталі звички';

  @override
  String get habitComplexityLabel => 'Складність';

  @override
  String get habitNotesEmpty => 'Немає нотаток';

  @override
  String get habitTypeLabel => 'Тип';

  @override
  String get habitGoalEmpty => 'Ціль не вказана';

  @override
  String get unarchiveTooltip => 'Розархівувати';

  @override
  String get archiveTooltip => 'Архівувати';

  @override
  String get deleteTooltip => 'Видалити';

  @override
  String get habitMenuEdit => 'Змінити';

  @override
  String get habitMenuDetails => 'Деталі';

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
  String get topFiveStreaks => 'Топ-5 найтриваліших серій';

  @override
  String get topFiveStreaksInfo =>
      'Топ-5 серій виконання звички відображає найстабільніші періоди особистої дисципліни. Цей інструмент допомагає усвідомити власну здатність до послідовних дій, підтримує мотивацію в моменти сумнівів і слугує основою для формування стійких, рекомендованих звичок.';

  @override
  String get noStreaksYet => 'Серій поки немає';

  @override
  String streakDays(int days) {
    return '$days днів';
  }

  @override
  String get stabilityTitle => 'Стабільність';

  @override
  String get stabilityInfo =>
      'Діаграма стабільності показує, наскільки послідовно ви дотримуєтеся звички без пропусків. Вона висвітлює ваші загальні патерни дотримання, допомагаючи побачити, де ви найнадійніші, а де варто звернути додаткову увагу. Відстежуючи стабільність, ви можете святкувати стабільний прогрес, виявляти моменти, які ставлять під виклик вашу рутину, та нарощувати впевненість у здатності підтримувати довгострокові зміни поведінки.';

  @override
  String get noStabilityData => 'Немає даних про стабільність';

  @override
  String get habitByWeekdays => 'Звичка за днями тижня';

  @override
  String get habitByWeekdaysInfo =>
      'Діаграма звички за днями тижня показує, як часто ви виконуєте звичку в кожен конкретний день. Вона допомагає виявити дні, коли ви найпослідовніші, та ті, які частіше пропускаєте. Аналізуючи ці закономірності, ви можете скоригувати свій розклад, посилити слабкі сторони та вибудувати більш стабільний ритм звички протягом тижня.';

  @override
  String get calendarTitle => 'Календар';

  @override
  String get calendarInfo =>
      'Відображає виконання звичок за днями:\n- Синій – звичка виконана;\n- Голубий – дотримуватися звички не обов\'язково.\nВи можете змінити статус натисканням по дню.';

  @override
  String get executionCountAxis => 'Кількість виконань';

  @override
  String get frequencyEveryDay => 'Кожного дня';

  @override
  String frequencyEveryXDays(int count) {
    return 'Кожні $count дні(-ів)';
  }

  @override
  String frequencyTimesPerPeriod(int count, String period) {
    return '$count рази(-ів) на $period';
  }

  @override
  String get periodWeek => 'тиждень';

  @override
  String get periodMonth => 'місяць';

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
  String get goalsEmptyList => 'Ще немає цілей. Додайте одну вище.';

  @override
  String get addGoalTitle => 'Додати ціль';

  @override
  String get editGoalTitle => 'Редагувати ціль';

  @override
  String get goalExamplesHint =>
      'Приклади цілей спрямованих на вашу ідентичність: бути олімпійським чемпіоном, бути впевненим в собі, бути вільним від куріння.';

  @override
  String get deleteGoalQuestion => 'Видалити ціль?';

  @override
  String get deleteGoalMessage =>
      'Ціль буде видалено назавжди. Ця дія не може бути скасована.';

  @override
  String get markGoalCompleted => 'Позначити як виконану';

  @override
  String get markGoalIncomplete => 'Позначити як невиконану';

  @override
  String get completedGoalsHeader => 'Виконані';

  @override
  String goalHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count звички',
      many: '$count звичок',
      few: '$count звички',
      one: '$count звичка',
    );
    return '$_temp0';
  }

  @override
  String get goalMarkedCompleted => 'Ціль позначено як виконану';

  @override
  String get goalMarkedIncomplete => 'Ціль позначено як невиконану';

  @override
  String get helperTitle => 'Чат з помічником';

  @override
  String get helperWarning =>
      'ШІ-помічник знає ваші звички, цілі, місію, стать та гасло. Тому можете спитати щось стосовно них. Наприклад, “Яку поставити наступну ціль?” Зауважте: він може інколи помилятись. Перевіряйте важливу інформацію!';

  @override
  String get helperEmptyDescription =>
      'Я - ШІ-асистент зі саморозвитку. Ви можете звертатися до мене стосовно різних питань. Наприклад, \"Як моя особистість впливає на моє життя?\"';

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
  String get noInternetConnection => 'Немає з\'єднання з інтернетом';

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
  String get genderLabel => 'Стать';

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
  String get yourGender => 'Твоя Стать';

  @override
  String get yourMainSlogan => 'Твоє Основне Гасло';

  @override
  String get yourMission => 'Твоя Місія';

  @override
  String get missionExplanation =>
      'Місія - це життєва мета, яка постійно підтримує високий рівень мотивації й допомагає зробити найкращий вибір у різноманітних ситуаціях. Наприклад, місія може звучати так: “Я створюю IT-додатки, щоб робити світ кращим\". Вона буде використана для створення більш доцільних для вас рекомендованих звичок.';

  @override
  String get mainSloganExplanation =>
      'Основне гасло - це найважливіша ідея, якою Ви дотримуєтесь по житті. Воно допомагає визначити, як діяти, коли вам чогось не хочеться або виникають певні випробування чи спокуси. Приклад основного гасла: стосунки з Богом та сильний характер визначають якість життя. Гасло використовується для формування кращих рекомендованих звичок.';

  @override
  String get nameSavedSuccess => 'Твоє імʼя успішно збережене';

  @override
  String get genderSavedSuccess => 'Твою стать успішно збережено';

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
  @override
  @override
  @override
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

  @override
  String get tabAssistant => 'ШІ-Помічник';

  @override
  String get tabProfile => 'Профіль';

  @override
  String get archiveTitle => 'Архів';

  @override
  String get archiveEmptyDescription =>
      'Тут відображаються твої завершені або призупинені звички.';

  @override
  String get archiveInfoDescription =>
      'Навіщо потрібен архів?\n✅ Запланувати звички, які ви хочете додати чи змінити в майбутньому.\n🔁 Проаналізувати причини — які звички спрацювали, а які були занадто складними чи неактуальними.\n🌱 Спробувати знову — іноді корисно повернутись до старої звички, змінивши складність або підхід. Наприклад, тренуватись вранці, а не ввечері.\n\nПідказка: перед створенням нової звички подивіться архів — можливо, щось подібне вже було, і тепер ви знаєте, як зробити краще.';

  @override
  String get archiveInfoTooltip => 'Навіщо потрібен архів?';

  @override
  String get unarchiveHabitQuestion => 'Видалити звичку з архіву?';

  @override
  String get unarchiveHabitMessage =>
      'Ця дія відновить звичку у ваш активний список.';

  @override
  String get habitScreenTitle => 'Звичка';

  @override
  String get habitDataTab => 'Дані';

  @override
  String get habitHowToKeepTab => 'Як утримувати';

  @override
  String get habitNameField => 'Назва';

  @override
  String get habitNameInfo =>
      'Вкажіть назву звички та час або місце її виконання. Це збільшить ймовірність її дотримання. Приклад: я молюсь, як тільки прокинусь.';

  @override
  String get habitGoalLabel => 'Ціль';

  @override
  String get selectHabitGoalTitle => 'Оберіть ціль звички';

  @override
  String get selectHabitGoalRecommendation =>
      'Рекомендація: виберіть конкретну ціль або ту, яка орієнтована на вашу ідентичність, оскільки вона визначає ваше життя.';

  @override
  String get habitFlexible => 'Гнучка';

  @override
  String get habitFlexibleInfo =>
      'Зберігання у більшості випадків, але дозволено робити винятки у ситуаціях, коли існує більш важлива звичка. Наприклад, виконувати усі цілі за високим пріоритетом протягом дня, але оскільки звичка дотримання режиму є важливішою, то слід почати готуватись до сну у відмічений час.';

  @override
  String get habitNoExceptions => 'Без винятків';

  @override
  String get habitNoExceptionsInfo =>
      'Неухильне дотримування звички, навіть у надзвичайних ситуаціях. Наприклад, відмова від вживання алкоголю чи тютюну.';

  @override
  String get habitFrequency => 'Частота';

  @override
  String get habitReminder => 'Нагадування';

  @override
  String get habitNotes => 'Нотатки';

  @override
  String get habitDifficulty => 'Складність (1 - 10)';

  @override
  String get habitDifficultyInfo =>
      'Наскільки важко дотримуватися звички за зусиллями, часом і самоконтролем';

  @override
  String habitAutomationExplanation(int days) {
    return 'Для автоматизації звички потрібно регулярне виконання протягом $days дні(-ів).';
  }

  @override
  String get habitAlreadyAutomated => 'Звичка вже автоматична';

  @override
  String habitDaysToGoUntilAutomaticJust(int days) {
    return 'Тільки $days залишилось днів до повної автоматизації звички.';
  }

  @override
  String habitDaysToGoUntilAutomaticStill(int days) {
    return 'Ще $days залишилось днів до повної автоматизації звички.';
  }

  @override
  String get habitMenuViewDetails => 'Переглянути деталі';

  @override
  String get habitMenuRestore => 'Відновити';

  @override
  String get habitMenuDelete => 'Видалити звичку';

  @override
  String get deleteHabitQuestion => 'Видалити звичку?';

  @override
  String get deleteHabitMessage =>
      'Звичку буде видалено назавжди. Ця дія не може бути скасована.';

  @override
  String get habitsTodayLabel => 'Сьогодні';

  @override
  String get habitsCompletedToday => 'Виконано цього дня';

  @override
  String get habitsEmptyList => 'Немає звичок. Натисніть + щоб додати.';

  @override
  String get undefinedGoalLabel => '*Ціль не визначена';

  @override
  String get habitStreakExplanation =>
      'Показує кількість днів поспіль, коли ви відкривали додаток і виконували звички. Якщо пропустити хоча б один день — серія обнуляється.';

  @override
  String get archiveHabitQuestion => 'Перемістити звичку в архів?';

  @override
  String get archiveHabitMessage =>
      'Ця дія перемістить звичку в архів. Ви зможете відновити роботу над нею пізніше.';

  @override
  String get cannotCompleteHabitInTheFuture =>
      'Неможливо позначити звичку, як виконана для майбутніх днів';

  @override
  String get reminderTitleLabel => 'Заголовок';

  @override
  String get reminderDescriptionLabel => 'Опис';

  @override
  String get reminderTimeLabel => 'Час';

  @override
  String get reminderEnableLabel => 'Увімкнути';

  @override
  String get doneButton => 'Готово';

  @override
  String get habitsReportReminderTitleText => 'Нагадайте сьогоднішні звички';

  @override
  String get habitsReportReminderDescriptionText =>
      'час відзначити, які звички було виконано вчора, і нагадати про свої звички та цілі';

  @override
  String get deviceDoesNotSupportNotifications =>
      'Отакої.. Схоже, що ваша операційна система не підтримує сповіщення. Будь ласка, спробуйте оновити її.';

  @override
  String get notificationsDisabledTitle => 'Сповіщення вимкнено';

  @override
  String get notificationsDisabledMessage =>
      'Щоб отримувати нагадування, дозвольте сповіщення в налаштуваннях пристрою. Відкрити налаштування зараз?';

  @override
  String get scheduleDate => 'Дата';

  @override
  String get scheduleDuration => 'Тривалість';

  @override
  String get scheduleTime => 'Час';

  @override
  String get scheduleReminder => 'Нагадування';

  @override
  String get scheduleRepeat => 'Повтор';

  @override
  String get scheduleClear => 'Очистити';

  @override
  String get scheduleOnTime => 'Вчасно';

  @override
  String get scheduleCustom => 'Власне';

  @override
  String get scheduleRecents => 'Нещодавні';

  @override
  String get scheduleConstantReminder => 'Постійне нагадування';

  @override
  String get scheduleAllDay => 'Весь день';

  @override
  String get scheduleByDueDates => 'За датою виконання';

  @override
  String get scheduleByCompletion => 'За датою завершення';

  @override
  String get roadGuideSkip => 'Пропустити';

  @override
  String get roadGuideBack => 'Назад';

  @override
  String get roadGuideNext => 'Далі';

  @override
  String get roadGuideDone => 'Готово';

  @override
  String get roadGuideReplayLabel => 'Дорожній гід';

  @override
  String get roadGuideReplaySubtitle =>
      'Огляд цілей, звичок, завдань і налаштувань';

  @override
  String get roadGuideExampleBadge => 'приклад';

  @override
  String get roadGuideDemoGoalName => 'Стати в формі';

  @override
  String get roadGuideDemoHabitName => 'Ранкове тренування';

  @override
  String get roadGuideDemoTaskName => 'Записатися на тренування';

  @override
  String get roadGuideGoalsTabTitle => 'Почніть з цілі';

  @override
  String get roadGuideGoalsTabBody =>
      'Principles автоматизує досягнення цілей. Відкрийте Цілі, щоб визначити, чого хочете досягти.';

  @override
  String get roadGuideGoalsComposerTitle => 'Створіть ціль';

  @override
  String get roadGuideGoalsComposerBody =>
      'Опишіть результат — під ним будуть згруповані звички, які ведуть до нього.';

  @override
  String get roadGuideGoalsDemoTitle => 'Цілі організовують звички';

  @override
  String get roadGuideGoalsDemoBody =>
      'Кожна ціль стає контейнером для звичок, що наближають вас до результату.';

  @override
  String get roadGuideHabitsTabTitle => 'Звички ведуть до цілі';

  @override
  String get roadGuideHabitsTabBody =>
      'Звички — це повторювані дії, які автоматизують прогрес до вашої цілі.';

  @override
  String get roadGuideHabitsFabTitle => 'Додайте звичку до цілі';

  @override
  String get roadGuideHabitsFabBody =>
      'Створюйте звички й прив’язуйте їх до цілі — кожне виконання наближає досягнення.';

  @override
  String get roadGuideRecommendTitle => 'Отримайте рекомендації звичок';

  @override
  String get roadGuideRecommendBody =>
      'Натисніть «Рекомендовані звички». ШІ запропонує звички на основі цілі, місії та гасла.';

  @override
  String get roadGuideHabitsDemoTitle => 'Відстежуйте звички під ціллю';

  @override
  String get roadGuideHabitsDemoBody =>
      'Виконуйте звички стабільно — так досягнення цілі стає автоматичним.';

  @override
  String get roadGuideHabitDetailTitle => 'Деталі звички';

  @override
  String get roadGuideHabitDetailBody =>
      'Відкрийте звичку, щоб бачити прогрес, серії та стабільність — наскільки послідовно ви її виконуєте.';

  @override
  String get roadGuideTasksTabTitle => 'Завдання розвантажують голову';

  @override
  String get roadGuideTasksTabBody =>
      'Записуйте те, що не можна забути. Завдання тримають деталі, щоб ви зосередились на звичках і цілі.';

  @override
  String get roadGuideTasksAddTitle => 'Додайте завдання';

  @override
  String get roadGuideTasksAddBody =>
      'Кнопка + — для разових справ, нагадувань і кроків поруч зі звичками.';

  @override
  String get roadGuideTasksDemoTitle => 'Нічого не забути';

  @override
  String get roadGuideTasksDemoBody =>
      'У завданнях те, чого не покривають звички — щоб ніщо не випало, поки ви йдете до цілі.';

  @override
  String get roadGuideTasksHabitsTitle => 'Звички завжди на видноті';

  @override
  String get roadGuideTasksHabitsBody =>
      'Сьогоднішні звички з’являються тут разом із завданнями, тож наступна дія завжди перед очима.';

  @override
  String get roadGuideChatTabTitle => 'AI-помічник';

  @override
  String get roadGuideChatTabBody =>
      'Помічник — це підтримка: відповіді про звички, цілі, тайм-менеджмент і створення плану.';

  @override
  String get roadGuideChatInputTitle => 'Запитайте про свій план';

  @override
  String get roadGuideChatInputBody =>
      'Напишіть питання або опишіть, що потрібно: звички, цілі, розклад чи план дій.';

  @override
  String get roadGuideSettingsTabTitle => 'Налаштування';

  @override
  String get roadGuideSettingsTabBody =>
      'Тут профіль, тема, мова, пароль і підтримка. Гасло та місія також допомагають ШІ рекомендувати звички.';

  @override
  String get roadGuideSettingsProfileTitle => 'Профіль для рекомендацій';

  @override
  String get roadGuideSettingsProfileBody =>
      'Ім’я, гасло й місія описують, ким ви стаєте — ШІ бере їх, коли пропонує звички.';

  @override
  String get roadGuideSettingsReplayTitle => 'Запуск у будь-який час';

  @override
  String get roadGuideSettingsReplayBody =>
      'Цей гід можна пройти знову в Налаштуваннях → Про застосунок. Тема й мова — трохи вище.';
}
