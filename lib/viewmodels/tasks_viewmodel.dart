import 'package:flutter/material.dart';

import '../core/schedule/task_repeat_math.dart';
import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/task_strings.dart';
import '../models/habit.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../services/reminder_service.dart';
import '../services/task_service.dart';

enum TasksListMode { today, tomorrow, day, inbox, completed }

enum TaskStatusFilter { all, active, done }

/// Фільтр «без категорії» (не null — окреме значення в UI).
const taskNoCategoryFilterKey = '__no_category__';

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(
    this._taskService,
    this._themeController, {
    ReminderService? reminderService,
  }) : _reminderService = reminderService {
    _themeController.addListener(_onThemeChanged);
  }

  final TaskService _taskService;
  final ThemeController _themeController;
  final ReminderService? _reminderService;

  final List<Task> tasks = [];
  Map<String, int> themeColors = {};
  String? selectedThemeFilter;
  TaskPriority? selectedPriorityFilter;
  TaskStatusFilter statusFilter = TaskStatusFilter.all;
  TasksListMode listMode = TasksListMode.today;
  DateTime selectedDay = dateOnly(DateTime.now());

  TasksUiTheme get uiTheme => _themeController.uiTheme;

  TasksUiPalette get palette => _themeController.palette;

  bool filtersVisible = false;
  bool tasksSectionExpanded = true;
  bool habitsSectionExpanded = true;
  bool isLoading = false;
  String? loadError;

  ThemeData get themeData => palette.toThemeData();

  Set<String> get allThemes {
    final themes = themeColors.keys.toSet();
    for (final task in tasks) {
      final value = task.theme?.trim();
      if (value != null && value.isNotEmpty) themes.add(value);
    }
    return themes;
  }

  bool get hasTasksWithoutCategory =>
      tasks.any((t) => t.theme == null || t.theme!.trim().isEmpty);

  List<Task> get filteredTasks {
    var result = List<Task>.from(tasks);
    result = result.where(_matchesListMode).toList();
    if (selectedThemeFilter == taskNoCategoryFilterKey) {
      result = result
          .where((t) => t.theme == null || t.theme!.trim().isEmpty)
          .toList();
    } else if (selectedThemeFilter != null) {
      result = result.where((t) => t.theme == selectedThemeFilter).toList();
    }
    if (selectedPriorityFilter != null) {
      result = result
          .where((t) => t.priority == selectedPriorityFilter)
          .toList();
    }
    result = result.where(_matchesStatusFilter).toList();
    final today = dateOnly(DateTime.now());
    result.sort((a, b) {
      if (listMode == TasksListMode.completed) {
        final aDone = a.completedAt ?? a.createdAt;
        final bDone = b.completedAt ?? b.createdAt;
        return bDone.compareTo(aDone);
      }
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final aOverdue =
          !a.isDone && a.dueDate != null && a.dueDate!.isBefore(today);
      final bOverdue =
          !b.isDone && b.dueDate != null && b.dueDate!.isBefore(today);
      if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
      final priorityCmp = _priorityRank(
        b.priority,
      ).compareTo(_priorityRank(a.priority));
      if (priorityCmp != 0) return priorityCmp;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  int get completedCount => filteredTasks.where((t) => t.isDone).length;

  double get progressPercent {
    if (filteredTasks.isEmpty) return 0;
    return (completedCount / filteredTasks.length) * 100;
  }

  List<Task> get todayTasks {
    final today = dateOnly(DateTime.now());
    return tasks.where((t) => isSameDay(t.dueDate, today)).toList();
  }

  /// Дні, на які є хоча б одне завдання (для крапок у календарі).
  Set<DateTime> get daysWithTasks {
    final days = <DateTime>{};
    for (final task in tasks) {
      final due = task.dueDate;
      if (due != null) days.add(dateOnly(due));
    }
    return days;
  }

  int get todayCompletedCount => todayTasks.where((t) => t.isDone).length;

  double get todayProgressPercent {
    if (todayTasks.isEmpty) return 0;
    return (todayCompletedCount / todayTasks.length) * 100;
  }

  Color colorForTheme(String theme) {
    final stored = themeColors[theme];
    if (stored != null) return Color(stored);
    return fallbackThemeColor(theme);
  }

  String listModeTitle(TaskStrings strings) => switch (listMode) {
    TasksListMode.today => strings.taskMenuToday,
    TasksListMode.tomorrow => strings.taskMenuTomorrow,
    TasksListMode.day => formatTaskDate(selectedDay),
    TasksListMode.inbox => strings.taskMenuInbox,
    TasksListMode.completed => strings.taskMenuCompleted,
  };

  void toggleFiltersVisible() {
    filtersVisible = !filtersVisible;
    notifyListeners();
  }

  void toggleTasksSectionExpanded() {
    tasksSectionExpanded = !tasksSectionExpanded;
    notifyListeners();
  }

  void toggleHabitsSectionExpanded() {
    habitsSectionExpanded = !habitsSectionExpanded;
    notifyListeners();
  }

  void setThemeFilter(String? theme) {
    selectedThemeFilter = theme;
    notifyListeners();
  }

  void setPriorityFilter(TaskPriority? priority) {
    selectedPriorityFilter = priority;
    notifyListeners();
  }

  void setStatusFilter(TaskStatusFilter status) {
    statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    selectedThemeFilter = null;
    selectedPriorityFilter = null;
    statusFilter = TaskStatusFilter.all;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      selectedThemeFilter != null ||
      selectedPriorityFilter != null ||
      statusFilter != TaskStatusFilter.all;

  void setListModeToday() {
    listMode = TasksListMode.today;
    notifyListeners();
  }

  void setListModeTomorrow() {
    listMode = TasksListMode.tomorrow;
    notifyListeners();
  }

  void setListModeInbox() {
    listMode = TasksListMode.inbox;
    notifyListeners();
  }

  void setListModeCompleted() {
    listMode = TasksListMode.completed;
    notifyListeners();
  }

  void setListModeDay(DateTime day) {
    listMode = TasksListMode.day;
    selectedDay = dateOnly(day);
    notifyListeners();
  }

  bool _matchesListMode(Task task) {
    final today = dateOnly(DateTime.now());
    return switch (listMode) {
      // Сьогодні + протерміновані (незавершені), щоб можна було перенести або виконати.
      TasksListMode.today =>
        isSameDay(task.dueDate, today) ||
            (!task.isDone &&
                task.dueDate != null &&
                task.dueDate!.isBefore(today)),
      TasksListMode.tomorrow => isSameDay(
        task.dueDate,
        tomorrowDate(now: today),
      ),
      TasksListMode.day => isSameDay(task.dueDate, selectedDay),
      // Усі незавершені, незалежно від дати.
      TasksListMode.inbox => !task.isDone,
      TasksListMode.completed => task.isDone,
    };
  }

  bool _matchesStatusFilter(Task task) => switch (statusFilter) {
    TaskStatusFilter.all => true,
    TaskStatusFilter.active => !task.isDone,
    TaskStatusFilter.done => task.isDone,
  };

  Future<void> load({bool silent = false}) async {
    final showSpinner = !silent && tasks.isEmpty;
    if (showSpinner) {
      isLoading = true;
      loadError = null;
      notifyListeners();
    }
    try {
      tasks
        ..clear()
        ..addAll(await _taskService.getTasks());
      themeColors = await _taskService.getThemeColors();
    } catch (e) {
      loadError = e.toString();
    } finally {
      if (isLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  void clear() {
    tasks.clear();
    themeColors = {};
    selectedThemeFilter = null;
    selectedPriorityFilter = null;
    statusFilter = TaskStatusFilter.all;
    loadError = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> setUiTheme(TasksUiTheme theme) async {
    await _themeController.setUiTheme(theme);
    await _taskService.setUiTheme(theme);
  }

  void _onThemeChanged() => notifyListeners();

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> toggleTask(String id) async {
    final task = _findTask(id);
    if (task == null) return;

    final done = !task.isDone;
    await _taskService.updateTaskStatus(id, done);
    final updated = await _taskService.getTask(id) ?? task.copyWith(isDone: done);
    if (done) {
      await _reminderService?.cancelTaskNotifications(updated);
      await _reminderService?.syncTaskNotifications(
        updated.copyWith(isDone: true),
      );
      if (!updated.repeat.isNone && updated.dueDate != null) {
        await _spawnNextOccurrence(updated);
      }
    } else {
      await _reminderService?.syncTaskNotifications(updated);
    }
    await load();
  }

  Future<void> _spawnNextOccurrence(Task completed) async {
    final nextStart = nextOccurrenceStart(
      fromStart: completed.dueDate!,
      repeat: completed.repeat,
      completedAt: completed.completedAt ?? DateTime.now(),
    );
    if (nextStart == null) return;
    final span = durationBetween(completed.dueDate, completed.endDate);
    final nextEnd = span == null ? null : nextStart.add(span);
    var next = Task(
      id: '0',
      title: completed.title,
      description: completed.description,
      theme: completed.theme,
      priority: completed.priority,
      createdAt: DateTime.now(),
      dueDate: nextStart,
      endDate: nextEnd,
      allDay: completed.allDay,
      reminders: [
        for (final offset in completed.reminders)
          ScheduleReminderOffset(offsetMinutes: offset.offsetMinutes),
      ],
      constantReminder: completed.constantReminder,
      repeat: completed.repeat,
    );
    next = await _reminderService?.prepareTaskNotifications(next) ?? next;
    await _taskService.saveTask(next, isNew: true);
    await _reminderService?.syncTaskNotifications(next);
  }

  Future<void> moveTaskToToday(String id) async {
    final task = _findTask(id);
    if (task == null) return;

    await _taskService.saveTask(
      task.copyWith(dueDate: dateOnly(DateTime.now())),
      isNew: false,
    );
    await load();
  }

  Future<void> deleteTask(String id) async {
    final existing = _findTask(id);
    if (existing != null) {
      await _reminderService?.cancelTaskNotifications(existing);
    }
    await _taskService.deleteTask(id);
    await load();
  }

  Task? taskById(String id) => _findTask(id);

  Task? _findTask(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
}

int _priorityRank(TaskPriority? priority) => switch (priority) {
  TaskPriority.high => 3,
  TaskPriority.medium => 2,
  TaskPriority.low => 1,
  null => 0,
};

bool showsHabitsOnTasksTab(TasksListMode mode) => true;

DateTime habitsDayForTasksTab(TasksViewModel vm, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  return switch (vm.listMode) {
    TasksListMode.day => dateOnly(vm.selectedDay),
    TasksListMode.tomorrow => tomorrowDate(now: today),
    _ => today,
  };
}

/// Habits listed on the tasks tab, respecting all active filters.
///
/// Priority and category filters are task-specific; when either is active
/// habit items are hidden so the user sees only matching tasks.
List<Habit> habitsVisibleOnTasksTab({
  required TasksListMode listMode,
  required List<Habit> habits,
  required TaskStatusFilter statusFilter,
  required TaskPriority? priorityFilter,
  required String? themeFilter,
  required bool Function(Habit habit) isCompleted,
}) {
  if (!showsHabitsOnTasksTab(listMode)) return const [];

  // Priority / category filters don't apply to habits — hide the items
  // so only matching tasks are shown. Section headers stay visible.
  if (priorityFilter != null || themeFilter != null) return const [];

  final effectiveStatus = switch (listMode) {
    TasksListMode.completed => TaskStatusFilter.done,
    TasksListMode.inbox when statusFilter == TaskStatusFilter.all =>
      TaskStatusFilter.active,
    _ => statusFilter,
  };

  final result = habits.where((habit) {
    if (habit.id == null) return false;
    final done = isCompleted(habit);
    return switch (effectiveStatus) {
      TaskStatusFilter.all => true,
      TaskStatusFilter.active => !done,
      TaskStatusFilter.done => done,
    };
  }).toList();

  result.sort((a, b) {
    final aDone = isCompleted(a);
    final bDone = isCompleted(b);
    if (aDone != bDone) return aDone ? 1 : -1;
    final aTime = a.reminderTime;
    final bTime = b.reminderTime;
    if (aTime != null && bTime != null) {
      final byTime = aTime.compareTo(bTime);
      if (byTime != 0) return byTime;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  });
  return result;
}
