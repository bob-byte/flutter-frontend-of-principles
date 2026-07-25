import 'package:flutter/widgets.dart';

class TaskStrings {
  const TaskStrings._({
    required this.tasksTitle,
    required this.taskNewTitle,
    required this.taskEditTitle,
    required this.taskName,
    required this.taskNameHint,
    required this.taskNameRequired,
    required this.taskDescriptionOptional,
    required this.taskDescriptionHint,
    required this.taskDescriptionEmpty,
    required this.taskDueDate,
    required this.taskPickDate,
    required this.taskImportance,
    required this.taskPriorityLow,
    required this.taskPriorityMedium,
    required this.taskPriorityHigh,
    required this.taskPriorityNone,
    required this.taskThemeOptional,
    required this.taskNoTheme,
    required this.taskExistingTheme,
    required this.taskNewTheme,
    required this.taskThemeColor,
    required this.taskThemes,
    required this.taskFilterPriority,
    required this.taskFilterStatus,
    required this.taskStatusActive,
    required this.taskStatusDone,
    required this.taskClearFilters,
    required this.taskAdd,
    required this.taskEdit,
    required this.taskDelete,
    required this.taskDeleteConfirm,
    required this.taskCancel,
    required this.taskNotFound,
    required this.taskProgress,
    required this.taskProgressToday,
    required this.taskFilters,
    required this.taskShow,
    required this.taskHide,
    required this.taskAll,
    required this.taskNoTasks,
    required this.taskNoTasksHint,
    required this.taskMenuToday,
    required this.taskMenuCalendar,
    required this.taskMenuInbox,
    required this.taskListMenuTitle,
    required this.taskWhatNeedsToBeDone,
    required this.taskNoDueDate,
    required this.taskNoTasksInbox,
    required this.taskNoTasksInboxHint,
    required this.saveButton,
    required this.uiThemeDarkOrange,
    required this.uiThemeDarkBlue,
    required this.uiThemeLightOrange,
    required this.uiThemeLightBlue,
    required this.taskUiThemeTooltip,
    required this.taskCreateHowTitle,
    required this.taskCreateHowHint,
    required this.taskCreateManual,
    required this.taskCreateManualHint,
    required this.taskCreateWithAi,
    required this.taskCreateWithAiHint,
    required this.taskAiAssistTitle,
    required this.taskAiAssistHint,
    required this.taskAiPromptHint,
    required this.taskAiMicTooltip,
    required this.taskAiSendTooltip,
    required this.taskAiListening,
    required this.taskAiProcessing,
    required this.taskAiEmptyPrompt,
    required this.taskAiMicUnavailable,
    required this.taskAiProcessError,
  });

  final String tasksTitle;
  final String taskNewTitle;
  final String taskEditTitle;
  final String taskName;
  final String taskNameHint;
  final String taskNameRequired;
  final String taskDescriptionOptional;
  final String taskDescriptionHint;
  final String taskDescriptionEmpty;
  final String taskDueDate;
  final String taskPickDate;
  final String taskImportance;
  final String taskPriorityLow;
  final String taskPriorityMedium;
  final String taskPriorityHigh;
  final String taskPriorityNone;
  final String taskThemeOptional;
  final String taskNoTheme;
  final String taskExistingTheme;
  final String taskNewTheme;
  final String taskThemeColor;
  final String taskThemes;
  final String taskFilterPriority;
  final String taskFilterStatus;
  final String taskStatusActive;
  final String taskStatusDone;
  final String taskClearFilters;
  final String taskAdd;
  final String taskEdit;
  final String taskDelete;
  final String taskDeleteConfirm;
  final String taskCancel;
  final String taskNotFound;
  final String taskProgress;
  final String taskProgressToday;
  final String taskFilters;
  final String taskShow;
  final String taskHide;
  final String taskAll;
  final String taskNoTasks;
  final String taskNoTasksHint;
  final String taskMenuToday;
  final String taskMenuCalendar;
  final String taskMenuInbox;
  final String taskListMenuTitle;
  final String taskWhatNeedsToBeDone;
  final String taskNoDueDate;
  final String taskNoTasksInbox;
  final String taskNoTasksInboxHint;
  final String saveButton;
  final String uiThemeDarkOrange;
  final String uiThemeDarkBlue;
  final String uiThemeLightOrange;
  final String uiThemeLightBlue;
  final String taskUiThemeTooltip;
  final String taskCreateHowTitle;
  final String taskCreateHowHint;
  final String taskCreateManual;
  final String taskCreateManualHint;
  final String taskCreateWithAi;
  final String taskCreateWithAiHint;
  final String taskAiAssistTitle;
  final String taskAiAssistHint;
  final String taskAiPromptHint;
  final String taskAiMicTooltip;
  final String taskAiSendTooltip;
  final String taskAiListening;
  final String taskAiProcessing;
  final String taskAiEmptyPrompt;
  final String taskAiMicUnavailable;
  final String taskAiProcessError;

  String taskProgressCount(int completed, int total) {
    if (identical(this, uk)) {
      return '$completed з $total виконано';
    }
    return '$completed of $total completed';
  }

  String taskNoTasksForDayLabel(String date) {
    if (identical(this, uk)) {
      return 'Немає завдань на $date';
    }
    return 'No tasks for $date';
  }

  static TaskStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'uk' ? uk : en;
  }

  static final en = TaskStrings._(
    tasksTitle: 'Tasks',
    taskNewTitle: 'New task',
    taskEditTitle: 'Edit task',
    taskName: 'Task name',
    taskNameHint: 'Enter task name',
    taskNameRequired: 'Enter a name',
    taskDescriptionOptional: 'Description (optional)',
    taskDescriptionHint: 'Add a description',
    taskDescriptionEmpty: 'No description',
    taskDueDate: 'Due date',
    taskPickDate: 'Pick a date',
    taskImportance: 'Priority',
    taskPriorityLow: 'Low',
    taskPriorityMedium: 'Medium',
    taskPriorityHigh: 'High',
    taskPriorityNone: 'No priority',
    taskThemeOptional: 'Category (optional)',
    taskNoTheme: 'No category',
    taskExistingTheme: 'Existing',
    taskNewTheme: 'New category',
    taskThemeColor: 'Category color',
    taskThemes: 'Categories',
    taskFilterPriority: 'Priority',
    taskFilterStatus: 'Status',
    taskStatusActive: 'Active',
    taskStatusDone: 'Completed',
    taskClearFilters: 'Clear',
    taskAdd: 'Add task',
    taskEdit: 'Edit',
    taskDelete: 'Delete task',
    taskDeleteConfirm: 'Delete this task permanently?',
    taskCancel: 'Cancel',
    taskNotFound: 'Task not found',
    taskProgress: 'Progress',
    taskProgressToday: "Today's progress",
    taskFilters: 'Filters',
    taskShow: 'Show',
    taskHide: 'Hide',
    taskAll: 'All',
    taskNoTasks: 'No tasks yet',
    taskNoTasksHint: 'Tap + to add your first task',
    taskMenuToday: 'Today',
    taskMenuCalendar: 'Calendar',
    taskMenuInbox: 'Inbox',
    taskListMenuTitle: 'Show tasks',
    taskWhatNeedsToBeDone: 'What needs to be done?',
    taskNoDueDate: 'No date',
    taskNoTasksInbox: 'Inbox is empty',
    taskNoTasksInboxHint: 'Tasks without a due date appear here',
    saveButton: 'Save',
    uiThemeDarkOrange: 'Dark orange',
    uiThemeDarkBlue: 'Dark blue',
    uiThemeLightOrange: 'Light orange',
    uiThemeLightBlue: 'Light blue',
    taskUiThemeTooltip: 'Color theme',
    taskCreateHowTitle: 'How do you want to add a task?',
    taskCreateHowHint: 'Choose manual entry or describe it to the AI assistant.',
    taskCreateManual: 'Create myself',
    taskCreateManualHint: 'Fill in the task details manually',
    taskCreateWithAi: 'With AI assistant',
    taskCreateWithAiHint: 'Describe the task in text or by voice',
    taskAiAssistTitle: 'AI task assistant',
    taskAiAssistHint:
        'Example: “Buy groceries tomorrow, high priority, category home — don’t forget milk”',
    taskAiPromptHint: 'Describe the task…',
    taskAiMicTooltip: 'Dictate',
    taskAiSendTooltip: 'Create draft',
    taskAiListening: 'Listening…',
    taskAiProcessing: 'AI is preparing the task…',
    taskAiEmptyPrompt: 'Enter or say what needs to be done',
    taskAiMicUnavailable: 'Microphone is unavailable',
    taskAiProcessError: 'Could not process the request. Try again.',
  );

  static final uk = TaskStrings._(
    tasksTitle: 'Завдання',
    taskNewTitle: 'Нове завдання',
    taskEditTitle: 'Редагувати завдання',
    taskName: 'Назва завдання',
    taskNameHint: 'Введіть назву',
    taskNameRequired: 'Введіть назву',
    taskDescriptionOptional: 'Опис (необов\'язково)',
    taskDescriptionHint: 'Додайте опис',
    taskDescriptionEmpty: 'Опис відсутній',
    taskDueDate: 'Термін',
    taskPickDate: 'Оберіть дату',
    taskImportance: 'Пріоритет',
    taskPriorityLow: 'Низький',
    taskPriorityMedium: 'Середній',
    taskPriorityHigh: 'Високий',
    taskPriorityNone: 'Без пріоритету',
    taskThemeOptional: 'Категорія (необов\'язково)',
    taskNoTheme: 'Без категорії',
    taskExistingTheme: 'Існуюча',
    taskNewTheme: 'Нова категорія',
    taskThemeColor: 'Колір категорії',
    taskThemes: 'Категорії',
    taskFilterPriority: 'Пріоритет',
    taskFilterStatus: 'Статус',
    taskStatusActive: 'Активні',
    taskStatusDone: 'Виконані',
    taskClearFilters: 'Скинути',
    taskAdd: 'Додати завдання',
    taskEdit: 'Редагувати',
    taskDelete: 'Видалити завдання',
    taskDeleteConfirm: 'Видалити це завдання назавжди?',
    taskCancel: 'Скасувати',
    taskNotFound: 'Завдання не знайдено',
    taskProgress: 'Прогрес',
    taskProgressToday: 'Прогрес на сьогодні',
    taskFilters: 'Фільтри',
    taskShow: 'Показати',
    taskHide: 'Сховати',
    taskAll: 'Усі',
    taskNoTasks: 'Завдань поки немає',
    taskNoTasksHint: 'Натисніть +, щоб додати перше завдання',
    taskMenuToday: 'Сьогодні',
    taskMenuCalendar: 'Календар',
    taskMenuInbox: 'Вхідні',
    taskListMenuTitle: 'Показати завдання',
    taskWhatNeedsToBeDone: 'Що потрібно зробити?',
    taskNoDueDate: 'Без дати',
    taskNoTasksInbox: 'Вхідні порожні',
    taskNoTasksInboxHint: 'Тут з\'являться завдання без терміну',
    saveButton: 'Зберегти',
    uiThemeDarkOrange: 'Темна помаранчева',
    uiThemeDarkBlue: 'Темна синя',
    uiThemeLightOrange: 'Світла помаранчева',
    uiThemeLightBlue: 'Світла синя',
    taskUiThemeTooltip: 'Кольорова тема',
    taskCreateHowTitle: 'Як додати завдання?',
    taskCreateHowHint:
        'Оберіть ручне створення або опишіть завдання помічнику.',
    taskCreateManual: 'Створити власноруч',
    taskCreateManualHint: 'Заповнити поля завдання самостійно',
    taskCreateWithAi: 'За допомогою ШІ',
    taskCreateWithAiHint: 'Опишіть завдання текстом або голосом',
    taskAiAssistTitle: 'ШІ-помічник завдань',
    taskAiAssistHint:
        'Наприклад: «Купити продукти завтра, пріоритет високий, категорія дім. Опис: не забути молоко»',
    taskAiPromptHint: 'Опишіть завдання…',
    taskAiMicTooltip: 'Диктувати',
    taskAiSendTooltip: 'Створити чернетку',
    taskAiListening: 'Слухаю…',
    taskAiProcessing: 'ШІ готує завдання…',
    taskAiEmptyPrompt: 'Введіть або скажіть, що потрібно зробити',
    taskAiMicUnavailable: 'Мікрофон недоступний',
    taskAiProcessError: 'Не вдалося обробити запит. Спробуйте ще раз.',
  );
}
