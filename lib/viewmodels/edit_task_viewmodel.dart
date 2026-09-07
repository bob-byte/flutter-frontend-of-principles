import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/ai_task_draft.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_repeat_config.dart';
import '../models/task_subtask.dart';
import '../services/dialog_service.dart';
import '../services/reminder_service.dart';
import '../services/task_service.dart';
import '../viewmodels/schedule_draft.dart';
import '../widgets/theme_picker_section.dart';

class EditTaskViewModel extends ChangeNotifier {
  EditTaskViewModel(this._taskService, {ReminderService? reminderService})
    : _reminderService = reminderService;

  final TaskService _taskService;
  final ReminderService? _reminderService;
  final DialogService _dialogService = DialogService();

  String? editingId;
  String title = '';
  String description = '';
  TaskPriority? priority;
  ThemePickerMode themeMode = ThemePickerMode.none;
  String? selectedTheme;
  String newThemeName = '';
  Color themeColor = taskCategoryPalette.first;
  bool hasDueDate = false;
  DateTime? dueDate;
  DateTime? endDate;
  bool allDay = false;
  List<ScheduleReminderOffset> reminders = const [];
  bool constantReminder = false;
  TaskRepeatConfig repeat = const TaskRepeatConfig();
  int? constantNotificationRequestId;
  List<TaskSubtask> subtasks = const [];
  bool isLoading = false;
  bool isSaving = false;
  Map<String, int> themeColors = {};

  bool get isEditing => editingId != null;

  Set<String> get allThemes {
    final themes = themeColors.keys.toSet();
    if (selectedTheme != null && selectedTheme!.isNotEmpty) {
      themes.add(selectedTheme!);
    }
    if (newThemeName.trim().isNotEmpty) themes.add(newThemeName.trim());
    return themes;
  }

  List<String> get sortedThemes => allThemes.toList()..sort();

  Color colorForTheme(String theme) {
    final stored = themeColors[theme];
    if (stored != null) return Color(stored);
    return fallbackThemeColor(theme);
  }

  Future<void> load({String? taskId, AiTaskDraft? aiDraft, Task? seed}) async {
    if (taskId == null) {
      prepareCreate(aiDraft: aiDraft);
      unawaited(ensureThemesLoaded());
      return;
    }

    isLoading = true;
    notifyListeners();
    try {
      // Prefer in-memory seed so edit opens immediately; refresh from DB after.
      if (seed != null) {
        themeColors = Map<String, int>.from(themeColors);
        _applyTask(seed);
        isLoading = false;
        notifyListeners();
        unawaited(_refreshEditFromStorage(taskId, seed));
        return;
      }

      await ensureThemesLoaded();
      var task = await _taskService.getTask(taskId);
      if (task == null) {
        _clearForm();
        editingId = null;
        return;
      }
      _applyTask(task);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sync create form so the sheet can open without awaiting DB/themes.
  void prepareCreate({AiTaskDraft? aiDraft}) {
    _clearForm();
    editingId = null;
    hasDueDate = true;
    dueDate = dateOnly(DateTime.now());
    if (aiDraft != null) {
      _applyAiDraft(aiDraft, overwriteDueDateIfMissing: true);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> ensureThemesLoaded() async {
    if (themeColors.isNotEmpty) return;
    themeColors = await _taskService.getThemeColors();
    notifyListeners();
  }

  Future<void> _refreshEditFromStorage(String taskId, Task seed) async {
    try {
      await ensureThemesLoaded();
      var task = await _taskService.getTask(taskId);
      if (task == null && seed.serverId != null) {
        task = await _taskService.getTask(seed.serverId.toString());
      }
      if (task == null || !hasListeners) return;
      // Keep user edits if they already typed over the seed.
      if (title != seed.title ||
          description != seed.description ||
          !_sameSubtasks(subtasks, seed.subtasks)) {
        return;
      }
      _applyTask(task);
      notifyListeners();
    } catch (e) {
      debugPrint('Task edit refresh failed: $e');
    }
  }

  void _clearForm() {
    title = '';
    description = '';
    priority = null;
    themeMode = ThemePickerMode.none;
    selectedTheme = null;
    newThemeName = '';
    themeColor = taskCategoryPalette.first;
    hasDueDate = false;
    dueDate = null;
    endDate = null;
    allDay = false;
    reminders = const [];
    constantReminder = false;
    repeat = const TaskRepeatConfig();
    constantNotificationRequestId = null;
    subtasks = const [];
  }

  void _applyTask(Task task) {
    editingId = task.id;
    title = task.title;
    description = task.description;
    priority = task.priority;
    hasDueDate = task.dueDate != null;
    dueDate = task.dueDate ?? dateOnly(DateTime.now());
    endDate = task.endDate;
    allDay = task.allDay;
    reminders = task.reminders;
    constantReminder = task.constantReminder;
    repeat = task.repeat;
    constantNotificationRequestId = task.constantNotificationRequestId;
    subtasks = List<TaskSubtask>.from(task.subtasks);

    if (task.theme != null && task.theme!.isNotEmpty) {
      themeMode = ThemePickerMode.existing;
      selectedTheme = task.theme;
      newThemeName = '';
      themeColor = colorForTheme(task.theme!);
    } else {
      themeMode = ThemePickerMode.none;
      selectedTheme = null;
      newThemeName = '';
    }
  }

  /// Підставляє чернетку ШІ в уже відкриту форму.
  /// Дату з режиму списку не затирає, якщо ШІ її не визначив.
  void applyAiDraft(AiTaskDraft aiDraft) {
    _applyAiDraft(aiDraft, overwriteDueDateIfMissing: false);
    notifyListeners();
  }

  void _applyAiDraft(
    AiTaskDraft aiDraft, {
    required bool overwriteDueDateIfMissing,
  }) {
    title = aiDraft.title;
    description = aiDraft.description;
    priority = aiDraft.priority;

    themeMode = ThemePickerMode.none;
    selectedTheme = null;
    newThemeName = '';
    themeColor = taskCategoryPalette.first;

    final themeName = aiDraft.theme?.trim();
    if (themeName != null && themeName.isNotEmpty) {
      final themes = themeColors.keys.toSet();
      if (themes.contains(themeName)) {
        themeMode = ThemePickerMode.existing;
        selectedTheme = themeName;
        themeColor = colorForTheme(themeName);
      } else {
        themeMode = ThemePickerMode.newTheme;
        newThemeName = themeName;
        themeColor = fallbackThemeColor(themeName);
      }
    }

    if (aiDraft.hasDueDate && aiDraft.dueDate != null) {
      hasDueDate = true;
      dueDate = dateOnly(aiDraft.dueDate!);
      reminders = const [];
    } else if (overwriteDueDateIfMissing) {
      hasDueDate = aiDraft.hasDueDate;
      dueDate = aiDraft.dueDate ?? dateOnly(DateTime.now());
    }
  }

  /// Text fields keep their own controllers — avoid sheet rebuilds while typing.
  void setTitle(String value) {
    title = value;
  }

  void setDescription(String value) {
    description = value;
  }

  String addSubtask() {
    final item = TaskSubtask(
      id: TaskSubtask.allocateId(),
      title: '',
      sortOrder: subtasks.length,
    );
    subtasks = [...subtasks, item];
    notifyListeners();
    return item.id;
  }

  void removeSubtask(String id) {
    final next = [
      for (final item in subtasks)
        if (item.id != id) item,
    ];
    if (next.length == subtasks.length) return;
    subtasks = next;
    notifyListeners();
  }

  void setSubtaskTitle(String id, String title) {
    subtasks = [
      for (final item in subtasks)
        if (item.id == id) item.copyWith(title: title) else item,
    ];
  }

  void toggleSubtaskDone(String id) {
    subtasks = [
      for (final item in subtasks)
        if (item.id == id) item.copyWith(isDone: !item.isDone) else item,
    ];
    notifyListeners();
  }

  List<TaskSubtask> _preparedSubtasks() => TaskSubtask.sanitize(subtasks);

  bool _sameSubtasks(List<TaskSubtask> a, List<TaskSubtask> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void setPriority(TaskPriority? value) {
    priority = value;
    notifyListeners();
  }

  void setThemeMode(ThemePickerMode mode) {
    themeMode = mode;
    if (mode == ThemePickerMode.none) selectedTheme = null;
    notifyListeners();
  }

  void setSelectedTheme(String? value) {
    selectedTheme = value;
    notifyListeners();
  }

  void setNewThemeName(String value) {
    newThemeName = value;
  }

  void setThemeColor(Color value) {
    themeColor = value;
    notifyListeners();
  }

  void setHasDueDate(bool value) {
    hasDueDate = value;
    if (!value) {
      dueDate = null;
      endDate = null;
      allDay = false;
      reminders = const [];
      constantReminder = false;
      repeat = const TaskRepeatConfig();
    }
    notifyListeners();
  }

  void setDueDate(DateTime value) {
    dueDate = value;
    hasDueDate = true;
    notifyListeners();
  }

  void applySchedule(ScheduleDraft draft) {
    if (draft.isEmpty) {
      hasDueDate = false;
      dueDate = null;
      endDate = null;
      allDay = false;
      reminders = const [];
      constantReminder = false;
      repeat = const TaskRepeatConfig();
    } else {
      hasDueDate = true;
      dueDate = draft.dueDate;
      endDate = draft.showDuration && draft.tab == ScheduleTab.duration
          ? draft.endDate
          : null;
      allDay = draft.showDuration ? draft.allDay : false;
      reminders = List.of(draft.reminders);
      constantReminder = draft.constantReminder;
      repeat = draft.repeat;
    }
    notifyListeners();
  }

  ScheduleDraft toScheduleDraft() {
    if (!hasDueDate || dueDate == null) {
      return ScheduleDraft.defaults(showDuration: false);
    }
    return ScheduleDraft(
      showDuration: false,
      dueDate: dueDate,
      reminders: reminders,
      constantReminder: constantReminder,
      repeat: repeat,
      hasTime:
          dueDate!.hour != 0 || dueDate!.minute != 0 || reminders.isNotEmpty,
    );
  }

  String? resolvedTheme() {
    return switch (themeMode) {
      ThemePickerMode.none => null,
      ThemePickerMode.existing =>
        selectedTheme?.trim().isEmpty ?? true ? null : selectedTheme?.trim(),
      ThemePickerMode.newTheme =>
        newThemeName.trim().isEmpty ? null : newThemeName.trim(),
    };
  }

  Color? resolvedThemeColor(String? themeName) {
    if (themeName == null) return null;
    return themeMode == ThemePickerMode.existing
        ? colorForTheme(themeName)
        : themeColor;
  }

  Future<Task?> save() async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return null;

    final wantsNotifications =
        hasDueDate && (reminders.isNotEmpty || constantReminder);
    if (wantsNotifications) {
      final allowed =
          await _reminderService?.requestAccessToSendNotifications() ?? true;
      if (!allowed) {
        await _dialogService.promptOpenNotificationSettings();
      }
    }

    isSaving = true;
    notifyListeners();
    try {
      final themeName = resolvedTheme();
      final themeColorValue = resolvedThemeColor(themeName);
      await _taskService.registerTheme(themeName, themeColorValue?.toARGB32());

      Task saved;
      if (isEditing) {
        final existing = await _taskService.getTask(editingId!);
        if (existing == null) return null;

        saved = existing.copyWith(
          title: trimmedTitle,
          description: description.trim(),
          priority: priority,
          clearPriority: priority == null,
          theme: themeName,
          clearTheme: themeName == null,
          dueDate: hasDueDate ? dueDate : null,
          clearDueDate: !hasDueDate,
          endDate: hasDueDate ? endDate : null,
          clearEndDate: !hasDueDate || endDate == null,
          allDay: allDay,
          reminders: hasDueDate ? reminders : const [],
          constantReminder: hasDueDate && constantReminder,
          repeat: hasDueDate ? repeat : const TaskRepeatConfig(),
          constantNotificationRequestId: constantNotificationRequestId,
          clearConstantNotificationRequestId: !hasDueDate,
          subtasks: _preparedSubtasks(),
        );
        saved =
            await _reminderService?.prepareTaskNotifications(saved) ?? saved;
        saved = await _taskService.saveTask(saved, isNew: false);
      } else {
        saved = Task(
          id: '0',
          title: trimmedTitle,
          description: description.trim(),
          theme: themeName,
          priority: priority,
          createdAt: DateTime.now(),
          dueDate: hasDueDate ? dueDate : null,
          endDate: hasDueDate ? endDate : null,
          allDay: allDay,
          reminders: hasDueDate ? reminders : const [],
          constantReminder: hasDueDate && constantReminder,
          repeat: hasDueDate ? repeat : const TaskRepeatConfig(),
          subtasks: _preparedSubtasks(),
        );
        saved =
            await _reminderService?.prepareTaskNotifications(saved) ?? saved;
        saved = await _taskService.saveTask(saved, isNew: true);
      }
      unawaited(
        (_reminderService?.syncTaskNotifications(saved) ?? Future.value())
            .catchError((Object e) {
              debugPrint('Task notification sync failed: $e');
            }),
      );
      return saved;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
