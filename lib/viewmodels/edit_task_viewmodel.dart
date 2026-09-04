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

  Future<void> load({String? taskId, AiTaskDraft? aiDraft}) async {
    isLoading = true;
    notifyListeners();
    try {
      themeColors = await _taskService.getThemeColors();

      if (taskId == null) {
        editingId = null;
        title = '';
        description = '';
        priority = null;
        themeMode = ThemePickerMode.none;
        selectedTheme = null;
        newThemeName = '';
        themeColor = taskCategoryPalette.first;
        hasDueDate = true;
        dueDate = dateOnly(DateTime.now());
        endDate = null;
        allDay = false;
        reminders = const [];
        constantReminder = false;
        repeat = const TaskRepeatConfig();
        constantNotificationRequestId = null;
        if (aiDraft != null) {
          _applyAiDraft(aiDraft, overwriteDueDateIfMissing: true);
        }
        return;
      }

      final task = await _taskService.getTask(taskId);
      if (task == null) {
        editingId = null;
        return;
      }

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

      if (task.theme != null && task.theme!.isNotEmpty) {
        final themes = await _loadAllThemeNames(task);
        if (themes.contains(task.theme)) {
          themeMode = ThemePickerMode.existing;
          selectedTheme = task.theme;
          themeColor = colorForTheme(task.theme!);
        } else {
          themeMode = ThemePickerMode.newTheme;
          newThemeName = task.theme!;
          themeColor = colorForTheme(task.theme!);
        }
      } else {
        themeMode = ThemePickerMode.none;
        selectedTheme = null;
        newThemeName = '';
      }
    } finally {
      isLoading = false;
      notifyListeners();
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

  Future<Set<String>> _loadAllThemeNames(Task task) async {
    final themes = themeColors.keys.toSet();
    final value = task.theme?.trim();
    if (value != null && value.isNotEmpty) themes.add(value);
    return themes;
  }

  void setTitle(String value) {
    title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    description = value;
    notifyListeners();
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
    notifyListeners();
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
      hasTime: dueDate!.hour != 0 || dueDate!.minute != 0 || reminders.isNotEmpty,
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

  Future<bool> save() async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return false;

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
        if (existing == null) return false;

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
        );
        saved = await _reminderService?.prepareTaskNotifications(saved) ?? saved;
        await _taskService.saveTask(saved, isNew: false);
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
        );
        saved = await _reminderService?.prepareTaskNotifications(saved) ?? saved;
        await _taskService.saveTask(saved, isNew: true);
      }
      unawaited(
        (_reminderService?.syncTaskNotifications(saved) ?? Future.value())
            .catchError((Object e) {
              debugPrint('Task notification sync failed: $e');
            }),
      );
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
