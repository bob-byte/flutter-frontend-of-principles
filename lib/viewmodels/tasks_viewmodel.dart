import 'package:flutter/material.dart';

import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/task_strings.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../services/task_service.dart';

enum TasksListMode { today, day, inbox, completed }

enum TaskStatusFilter { all, active, done }

/// Фільтр «без категорії» (не null — окреме значення в UI).
const taskNoCategoryFilterKey = '__no_category__';

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(this._taskService, this._themeController) {
    _themeController.addListener(_onThemeChanged);
  }

  final TaskService _taskService;
  final ThemeController _themeController;

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
    TasksListMode.day => formatTaskDate(selectedDay),
    TasksListMode.inbox => strings.taskMenuInbox,
    TasksListMode.completed => strings.taskMenuCompleted,
  };

  void toggleFiltersVisible() {
    filtersVisible = !filtersVisible;
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
      TasksListMode.day => isSameDay(task.dueDate, selectedDay),
      TasksListMode.inbox => task.dueDate == null,
      TasksListMode.completed => task.isDone,
    };
  }

  bool _matchesStatusFilter(Task task) => switch (statusFilter) {
    TaskStatusFilter.all => true,
    TaskStatusFilter.active => !task.isDone,
    TaskStatusFilter.done => task.isDone,
  };

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      tasks
        ..clear()
        ..addAll(await _taskService.getTasks());
      themeColors = await _taskService.getThemeColors();
    } catch (e) {
      loadError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
    await load();
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
