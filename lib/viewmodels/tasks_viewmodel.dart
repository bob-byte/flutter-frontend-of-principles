import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/day_change_notifier.dart';
import '../core/home_widget/home_calendar_constants.dart';
import '../core/schedule/task_repeat_math.dart';
import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/task_strings.dart';
import '../models/habit.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_subtask.dart';
import '../services/completion_feedback.dart';
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
    DayChangeNotifier? dayChange,
  }) : _reminderService = reminderService,
       _dayChange = dayChange {
    _themeController.addListener(_onThemeChanged);
    _dayChange?.addListener(_onCalendarDayChanged);
  }

  final TaskService _taskService;
  final ThemeController _themeController;
  final ReminderService? _reminderService;
  final DayChangeNotifier? _dayChange;

  final List<Task> tasks = [];

  /// Lazy-loaded when the user opens the Completed list mode.
  List<Task>? _completedTasks;
  Map<String, int> themeColors = {};
  String? selectedThemeFilter;
  TaskPriority? selectedPriorityFilter;

  /// Default: only incomplete tasks/habits (matches filter chip «Active»).
  TaskStatusFilter statusFilter = TaskStatusFilter.active;
  TasksListMode listMode = TasksListMode.today;
  DateTime selectedDay = dateOnly(DateTime.now());

  TasksUiTheme get uiTheme => _themeController.uiTheme;

  TasksUiPalette get palette => _themeController.palette;

  bool filtersVisible = false;
  bool tasksSectionExpanded = true;
  bool habitsSectionExpanded = true;
  bool isLoading = false;
  String? loadError;

  /// Completed ids kept in Active/inbox until the celebration animation ends.
  final Set<String> _heldCompletedTaskIds = {};
  final Map<String, Timer> _holdCompletedTimers = {};
  final Set<int> _heldCompletedHabitIds = {};
  final Map<int, Timer> _holdCompletedHabitTimers = {};

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
    var result = List<Task>.from(_tasksForCurrentMode);
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
    result = result.where(_matchesEffectiveStatusFilter).toList();
    final today = dateOnly(DateTime.now());
    result.sort((a, b) {
      if (listMode == TasksListMode.completed) {
        final aDone = a.completedAt ?? a.createdAt;
        final bDone = b.completedAt ?? b.createdAt;
        return bDone.compareTo(aDone);
      }
      final aDone = _sortsAsCompleted(a);
      final bDone = _sortsAsCompleted(b);
      if (aDone != bDone) return aDone ? 1 : -1;
      final aOverdue =
          !aDone && a.dueDate != null && a.dueDate!.isBefore(today);
      final bOverdue =
          !bDone && b.dueDate != null && b.dueDate!.isBefore(today);
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

  List<Task> get _tasksForCurrentMode {
    if (listMode == TasksListMode.completed) {
      return _completedTasks ?? const [];
    }
    return tasks;
  }

  int get completedCount => filteredTasks.where((t) => t.isDone).length;

  double get progressPercent {
    if (filteredTasks.isEmpty) return 0;
    return (completedCount / filteredTasks.length) * 100;
  }

  List<Task> get todayTasks {
    final today = dateOnly(DateTime.now());
    return tasks.where((t) => _belongsOnToday(t, today)).toList();
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
    statusFilter = TaskStatusFilter.active;
    notifyListeners();
  }

  /// Status chips are redundant on Inbox (always open) and Completed (always done).
  bool get showsStatusFilter => switch (listMode) {
    TasksListMode.inbox || TasksListMode.completed => false,
    _ => true,
  };

  bool get hasActiveFilters =>
      selectedThemeFilter != null ||
      selectedPriorityFilter != null ||
      (showsStatusFilter && statusFilter != TaskStatusFilter.active);

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
    // Show session done rows immediately; fill from SQLite in the background.
    _completedTasks ??= [
      for (final t in tasks)
        if (t.isDone) t,
    ];
    unawaited(_ensureCompletedLoaded());
    notifyListeners();
  }

  Future<void> _ensureCompletedLoaded() async {
    try {
      final fromDb = await _taskService.getCompletedTasks();
      final byId = <String, Task>{
        for (final t in _completedTasks ?? const <Task>[]) t.id: t,
      };
      for (final t in fromDb) {
        byId[t.id] = t;
      }
      _completedTasks = _sortedCompleted(byId.values);
      if (listMode == TasksListMode.completed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load completed tasks: $e');
      _completedTasks ??= const [];
    }
  }

  /// Replace the Completed cache from SQLite (used while that list stays open).
  Future<void> _reloadCompletedTasks() async {
    try {
      _completedTasks = _sortedCompleted(
        await _taskService.getCompletedTasks(),
      );
    } catch (e) {
      debugPrint('Failed to reload completed tasks: $e');
      _completedTasks ??= const [];
    }
  }

  static List<Task> _sortedCompleted(Iterable<Task> source) {
    return source.toList()..sort((a, b) {
      final aDone = a.completedAt ?? a.createdAt;
      final bDone = b.completedAt ?? b.createdAt;
      return bDone.compareTo(aDone);
    });
  }

  void setListModeDay(DateTime day) {
    listMode = TasksListMode.day;
    selectedDay = dateOnly(day);
    notifyListeners();
  }

  /// Today list: due today, open/held overdue, or overdue finished today.
  bool _belongsOnToday(Task task, DateTime today, {bool held = false}) {
    if (isSameDay(task.dueDate, today)) return true;
    final due = task.dueDate;
    if (due == null || !due.isBefore(today)) return false;
    if (!task.isDone || held) return true;
    return _completedOnDay(task, today);
  }

  static bool _completedOnDay(Task task, DateTime day) {
    if (!task.isDone) return false;
    final doneAt = task.completedAt;
    if (doneAt != null) return isSameDay(doneAt, day);
    // Legacy rows without completedAt: treat due-day completion as that day.
    return task.dueDate != null && isSameDay(task.dueDate, day);
  }

  bool _matchesListMode(Task task) {
    final today = dateOnly(DateTime.now());
    final held = isHeldCompletedTask(task.id);
    return switch (listMode) {
      // Today + overdue (open or finished today) so Done filter still lists them.
      TasksListMode.today => _belongsOnToday(task, today, held: held),
      TasksListMode.tomorrow => isSameDay(
        task.dueDate,
        tomorrowDate(now: today),
      ),
      TasksListMode.day => isSameDay(task.dueDate, selectedDay),
      // Усі незавершені, незалежно від дати.
      TasksListMode.inbox => !task.isDone || held,
      TasksListMode.completed => task.isDone,
    };
  }

  /// Completed / Inbox ignore the status chip (list mode already scopes rows).
  TaskStatusFilter get _effectiveStatusFilter => switch (listMode) {
    TasksListMode.completed => TaskStatusFilter.done,
    TasksListMode.inbox => TaskStatusFilter.all,
    _ => statusFilter,
  };

  bool _matchesEffectiveStatusFilter(Task task) =>
      switch (_effectiveStatusFilter) {
        TaskStatusFilter.all => true,
        TaskStatusFilter.active => !task.isDone || isHeldCompletedTask(task.id),
        TaskStatusFilter.done => task.isDone,
      };

  bool isHeldCompletedTask(String id) => _heldCompletedTaskIds.contains(id);

  /// Held rows stay among active items so the burst isn't left behind.
  bool _sortsAsCompleted(Task task) =>
      task.isDone && !isHeldCompletedTask(task.id);

  bool isHeldCompletedHabit(int habitId) =>
      _heldCompletedHabitIds.contains(habitId);

  void _holdCompletedTask(String id) {
    _heldCompletedTaskIds.add(id);
    _holdCompletedTimers[id]?.cancel();
    _holdCompletedTimers[id] = Timer(kCompletionCelebrationDuration, () {
      _heldCompletedTaskIds.remove(id);
      _holdCompletedTimers.remove(id);
      notifyListeners();
    });
  }

  @visibleForTesting
  void debugHoldCompletedTask(String id) => _holdCompletedTask(id);

  void _releaseHeldCompletedTask(String id) {
    _holdCompletedTimers.remove(id)?.cancel();
    _heldCompletedTaskIds.remove(id);
  }

  /// Keeps a just-completed habit on the Active tasks list during the burst.
  void holdCompletedHabit(int habitId) {
    _heldCompletedHabitIds.add(habitId);
    _holdCompletedHabitTimers[habitId]?.cancel();
    _holdCompletedHabitTimers[habitId] = Timer(
      kCompletionCelebrationDuration,
      () {
        _heldCompletedHabitIds.remove(habitId);
        _holdCompletedHabitTimers.remove(habitId);
        notifyListeners();
      },
    );
  }

  void releaseHeldCompletedHabit(int habitId) {
    _holdCompletedHabitTimers.remove(habitId)?.cancel();
    if (_heldCompletedHabitIds.remove(habitId)) {
      notifyListeners();
    }
  }

  Future<void> upsertTask(Task task) async {
    // Drop every prior row that is the same client id or server id so a
    // concurrent [load] cannot leave duplicate keys in the Tasks Column.
    tasks.removeWhere(
      (t) =>
          t.id == task.id ||
          (task.serverId != null &&
              (t.serverId == task.serverId || t.id == '${task.serverId}')) ||
          (t.serverId != null && task.id == '${t.serverId}'),
    );
    tasks.insert(0, task);
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    final showSpinner = !silent && tasks.isEmpty;
    if (showSpinner) {
      isLoading = true;
      loadError = null;
      notifyListeners();
    }
    try {
      // Fetch before mutating [tasks]. `..clear()..addAll(await …)` clears
      // first, then awaits — an [upsertTask] in that gap duplicated rows and
      // crashed the Tasks list with Duplicate keys (e.g. ValueKey('task-2')).
      final today = dateOnly(_dayChange?.today ?? DateTime.now());
      final rangeStart = DateTime(
        today.year,
        today.month - HomeCalendarWidgetConfig.monthsBack,
        1,
      );
      final rangeEnd = DateTime(
        today.year,
        today.month + HomeCalendarWidgetConfig.monthsForward + 1,
        0,
      );
      final loaded = await _taskService.getSessionTasks(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        today: today,
      );
      final colors = await _taskService.getThemeColors();
      tasks
        ..clear()
        ..addAll(_uniqueTasksByIdentity(loaded));
      themeColors = colors;
      if (listMode == TasksListMode.completed) {
        // Keep Completed open: refresh from DB instead of blanking the list.
        await _reloadCompletedTasks();
      } else {
        // Loaded on demand; invalidate so the next open sees fresh data.
        _completedTasks = null;
      }
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
    for (final timer in _holdCompletedTimers.values) {
      timer.cancel();
    }
    _holdCompletedTimers.clear();
    _heldCompletedTaskIds.clear();
    for (final timer in _holdCompletedHabitTimers.values) {
      timer.cancel();
    }
    _holdCompletedHabitTimers.clear();
    _heldCompletedHabitIds.clear();
    tasks.clear();
    _completedTasks = null;
    themeColors = {};
    selectedThemeFilter = null;
    selectedPriorityFilter = null;
    statusFilter = TaskStatusFilter.active;
    loadError = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> setUiTheme(TasksUiTheme theme) async {
    await _themeController.setUiTheme(theme);
    await _taskService.setUiTheme(theme);
  }

  void _onThemeChanged() => notifyListeners();

  /// Rebuild Today / Tomorrow filters after the local calendar day changes.
  void _onCalendarDayChanged() => notifyListeners();

  @override
  void dispose() {
    for (final timer in _holdCompletedTimers.values) {
      timer.cancel();
    }
    for (final timer in _holdCompletedHabitTimers.values) {
      timer.cancel();
    }
    _dayChange?.removeListener(_onCalendarDayChanged);
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> toggleTask(String id) async {
    final task = _findTask(id);
    if (task == null) return;

    final done = !task.isDone;
    if (done) {
      _holdCompletedTask(id);
    } else {
      _releaseHeldCompletedTask(id);
    }
    final updatedLocal = task.copyWith(
      isDone: done,
      completedAt: done ? DateTime.now() : null,
      clearCompletedAt: !done,
    );
    final index = tasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      tasks[index] = updatedLocal;
    } else if (!done) {
      // Historical Completed row may be absent from the session list.
      tasks.insert(0, updatedLocal);
    }
    if (done) {
      if (listMode == TasksListMode.completed) {
        _completedTasks ??= [];
        _completedTasks!.removeWhere((t) => t.id == id);
        _completedTasks!.insert(0, updatedLocal);
      } else {
        _completedTasks = null; // refresh on next Completed open
      }
    } else if (_completedTasks != null) {
      _completedTasks!.removeWhere((t) => t.id == id);
    }
    notifyListeners();
    await _taskService.updateTaskStatus(id, done);
    final updated =
        await _taskService.getTask(id) ?? task.copyWith(isDone: done);
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
    // Reloading during the burst freezes the last overlay frames.
    if (done) {
      unawaited(
        Future<void>.delayed(kCompletionCelebrationDuration, () {
          if (!hasListeners) return;
          unawaited(load(silent: true));
        }),
      );
    } else {
      await load(silent: true);
    }
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
      subtasks: TaskSubtask.templateForNextOccurrence(completed.subtasks),
    );
    next = await _reminderService?.prepareTaskNotifications(next) ?? next;
    next = await _taskService.saveTask(next, isNew: true);
    await _reminderService?.syncTaskNotifications(next);
    await upsertTask(next);
  }

  Future<void> moveTaskToToday(String id) async {
    final task = _findTask(id);
    if (task == null) return;

    final updated = await _taskService.saveTask(
      task.copyWith(dueDate: dateOnly(DateTime.now())),
      isNew: false,
    );
    await upsertTask(updated);
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final task = _findTask(taskId);
    if (task == null) return;

    final index = task.subtasks.indexWhere((item) => item.id == subtaskId);
    if (index < 0) return;

    final next = [...task.subtasks];
    next[index] = next[index].copyWith(isDone: !next[index].isDone);
    final saved = await _taskService.saveTask(
      task.copyWith(subtasks: next),
      isNew: false,
    );
    await upsertTask(saved);
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
    for (final list in [tasks, _completedTasks ?? const <Task>[]]) {
      for (final task in list) {
        if (task.id == id) return task;
        if (task.serverId != null && task.serverId.toString() == id) {
          return task;
        }
      }
    }
    return null;
  }
}

/// Keeps one row per client id / server id (last write wins).
List<Task> _uniqueTasksByIdentity(List<Task> source) {
  final byId = <String, Task>{};
  final serverToId = <int, String>{};
  for (final task in source) {
    final previousServerId = byId[task.id]?.serverId;
    if (previousServerId != null) {
      serverToId.remove(previousServerId);
    }
    final serverId = task.serverId ?? int.tryParse(task.id) ?? 0;
    if (serverId != 0) {
      final priorId = serverToId[serverId];
      if (priorId != null && priorId != task.id) {
        byId.remove(priorId);
      }
      serverToId[serverId] = task.id;
    }
    byId[task.id] = task;
  }
  return byId.values.toList();
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
  bool Function(Habit habit)? keepVisibleWhileCompleted,
}) {
  if (!showsHabitsOnTasksTab(listMode)) return const [];

  // Priority / category filters don't apply to habits — hide the items
  // so only matching tasks are shown. Section headers stay visible.
  if (priorityFilter != null || themeFilter != null) return const [];

  final effectiveStatus = switch (listMode) {
    TasksListMode.completed => TaskStatusFilter.done,
    // Inbox is open work only; status chips are hidden for this mode.
    TasksListMode.inbox => TaskStatusFilter.active,
    _ => statusFilter,
  };

  final result = habits.where((habit) {
    if (habit.id == null) return false;
    final done = isCompleted(habit);
    return switch (effectiveStatus) {
      TaskStatusFilter.all => true,
      TaskStatusFilter.active =>
        !done || (keepVisibleWhileCompleted?.call(habit) ?? false),
      TaskStatusFilter.done => done,
    };
  }).toList();

  result.sort((a, b) {
    final aHeld = keepVisibleWhileCompleted?.call(a) ?? false;
    final bHeld = keepVisibleWhileCompleted?.call(b) ?? false;
    final aDone = isCompleted(a) && !aHeld;
    final bDone = isCompleted(b) && !bHeld;
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
