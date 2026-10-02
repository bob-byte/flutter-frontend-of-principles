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
import '../views/common/theme_picker_section.dart';

class EditTaskViewModel extends ChangeNotifier {
  EditTaskViewModel(this._taskService, {ReminderService? reminderService})
    : _reminderService = reminderService;

  final TaskService _taskService;
  final ReminderService? _reminderService;
  final DialogService _dialogService = DialogService();

  static const _textAutosaveDelay = Duration(milliseconds: 450);

  String? editingId;
  String title = '';
  String description = '';
  bool isDone = false;
  DateTime? completedAt;
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

  /// When true, discrete/text edits persist immediately (TickTick-style edit).
  bool liveSave = false;

  /// Last task written by [autosave] / [flushAutosave] during an edit session.
  Task? lastAutosaved;

  /// Invoked after a successful live save so the tasks list can upsert.
  void Function(Task task)? onAutosaved;

  Timer? _autosaveTimer;
  bool _promptNotificationsOnNextSave = false;
  String? _lastSavedSignature;
  Future<Task?> _autosaveChain = Future<Task?>.value();

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

    _stopLiveSave();
    isLoading = true;
    notifyListeners();
    try {
      // Prefer in-memory seed so edit opens immediately; refresh from DB after.
      if (seed != null) {
        themeColors = Map<String, int>.from(themeColors);
        _applyTask(seed);
        _beginLiveSave(seed);
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
      _beginLiveSave(task);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sync create form so the sheet can open without awaiting DB/themes.
  void prepareCreate({AiTaskDraft? aiDraft}) {
    _stopLiveSave();
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

  void _beginLiveSave(Task baseline) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _autosaveChain = Future<Task?>.value();
    liveSave = true;
    lastAutosaved = baseline;
    _lastSavedSignature = _formSignature();
    _promptNotificationsOnNextSave = false;
  }

  void _stopLiveSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _autosaveChain = Future<Task?>.value();
    liveSave = false;
    lastAutosaved = null;
    _lastSavedSignature = null;
    _promptNotificationsOnNextSave = false;
    onAutosaved = null;
  }

  void _markDirty({
    bool immediate = false,
    bool promptForNotifications = false,
  }) {
    if (!liveSave || !isEditing) return;
    if (promptForNotifications) _promptNotificationsOnNextSave = true;
    _autosaveTimer?.cancel();
    if (immediate) {
      _autosaveTimer = null;
      _enqueueAutosave();
      return;
    }
    _autosaveTimer = Timer(_textAutosaveDelay, () {
      _autosaveTimer = null;
      _enqueueAutosave();
    });
  }

  void _enqueueAutosave() {
    _autosaveChain = _autosaveChain
        .catchError((_) => lastAutosaved)
        .then((_) => autosave());
  }

  /// Keeps the ids [prepareTaskNotifications] just stored so the next edit
  /// cancels that alarm instead of scheduling a second one.
  void _adoptScheduledNotifications(Task saved) {
    reminders = List.of(saved.reminders);
    constantNotificationRequestId = saved.constantNotificationRequestId;
  }

  /// Persists the current edit form if live-save is active.
  Future<Task?> autosave() async {
    if (!liveSave || !isEditing) return lastAutosaved;
    if (title.trim().isEmpty) return lastAutosaved;
    if (_lastSavedSignature == _formSignature()) return lastAutosaved;

    final prompt = _promptNotificationsOnNextSave;
    _promptNotificationsOnNextSave = false;
    final saved = await save(promptForNotifications: prompt);
    if (saved != null) {
      lastAutosaved = saved;
      // [save] records the signature before notification scheduling. Refreshing
      // it here would hide edits typed while that scheduling was in flight.
      onAutosaved?.call(saved);
    }
    return saved ?? lastAutosaved;
  }

  /// Cancels the debounce and writes any pending edit immediately.
  Future<Task?> flushAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _enqueueAutosave();
    return _autosaveChain;
  }

  String _formSignature() {
    final themeName = resolvedTheme() ?? '';
    final themeColorValue = resolvedThemeColor(
      themeName.isEmpty ? null : themeName,
    );
    final due = hasDueDate ? dueDate?.toIso8601String() ?? '' : '';
    final end = hasDueDate ? endDate?.toIso8601String() ?? '' : '';
    final reminderSig = hasDueDate
        ? reminders.map((r) => r.offsetMinutes).join(',')
        : '';
    final subtaskSig = subtasks
        .map((s) => '${s.id}:${s.title}:${s.isDone ? 1 : 0}')
        .join('|');
    return [
      title.trim(),
      description.trim(),
      isDone ? '1' : '0',
      priority?.name ?? '',
      themeMode.name,
      themeName,
      themeColorValue?.toARGB32().toString() ?? '',
      hasDueDate ? '1' : '0',
      due,
      end,
      allDay ? '1' : '0',
      reminderSig,
      hasDueDate && constantReminder ? '1' : '0',
      hasDueDate ? repeat.toJson().toString() : '',
      subtaskSig,
    ].join('\u0001');
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
          isDone != seed.isDone ||
          !_sameSubtasks(subtasks, seed.subtasks)) {
        return;
      }
      _applyTask(task);
      if (liveSave) {
        lastAutosaved = task;
        _lastSavedSignature = _formSignature();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Task edit refresh failed: $e');
    }
  }

  void _clearForm() {
    title = '';
    description = '';
    isDone = false;
    completedAt = null;
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
    isDone = task.isDone;
    completedAt = task.completedAt;
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
    _markDirty(
      immediate: true,
      promptForNotifications: aiDraft.reminders.isNotEmpty,
    );
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
      dueDate = aiDraft.dueDate;
      allDay = aiDraft.allDay;
      reminders = List.of(aiDraft.reminders);
    } else if (overwriteDueDateIfMissing) {
      hasDueDate = aiDraft.hasDueDate;
      dueDate = aiDraft.dueDate ?? dateOnly(DateTime.now());
      allDay = false;
      reminders = List.of(aiDraft.reminders);
    }

    if (aiDraft.subtasks.isNotEmpty) {
      subtasks = [
        for (var i = 0; i < aiDraft.subtasks.length; i++)
          aiDraft.subtasks[i].copyWith(
            id: TaskSubtask.allocateId(),
            sortOrder: i,
            isDone: false,
          ),
      ];
    }
  }

  /// Text fields keep their own controllers — avoid sheet rebuilds while typing.
  void setTitle(String value) {
    title = value;
    _markDirty();
  }

  void setDescription(String value) {
    description = value;
    _markDirty();
  }

  /// Toggles completion while editing; persists via live-save.
  void toggleCompleted() {
    if (!isEditing) return;
    isDone = !isDone;
    completedAt = isDone ? DateTime.now() : null;
    notifyListeners();
    _markDirty(immediate: true);
  }

  String addSubtask() {
    final item = TaskSubtask(
      id: TaskSubtask.allocateId(),
      title: '',
      sortOrder: subtasks.length,
    );
    subtasks = [...subtasks, item];
    notifyListeners();
    _markDirty(immediate: true);
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
    _markDirty(immediate: true);
  }

  void setSubtaskTitle(String id, String title) {
    subtasks = [
      for (final item in subtasks)
        if (item.id == id) item.copyWith(title: title) else item,
    ];
    _markDirty();
  }

  void toggleSubtaskDone(String id) {
    subtasks = [
      for (final item in subtasks)
        if (item.id == id) item.copyWith(isDone: !item.isDone) else item,
    ];
    notifyListeners();
    _markDirty(immediate: true);
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
    _markDirty(immediate: true);
  }

  void setThemeMode(ThemePickerMode mode) {
    themeMode = mode;
    if (mode == ThemePickerMode.none) selectedTheme = null;
    notifyListeners();
    _markDirty(immediate: true);
  }

  void setSelectedTheme(String? value) {
    selectedTheme = value;
    notifyListeners();
    _markDirty(immediate: true);
  }

  void setNewThemeName(String value) {
    newThemeName = value;
    _markDirty();
  }

  void setThemeColor(Color value) {
    themeColor = value;
    notifyListeners();
    _markDirty(immediate: true);
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
    _markDirty(immediate: true, promptForNotifications: value);
  }

  void setDueDate(DateTime value) {
    dueDate = value;
    hasDueDate = true;
    notifyListeners();
    _markDirty(immediate: true);
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
    _markDirty(
      immediate: true,
      promptForNotifications:
          hasDueDate && (reminders.isNotEmpty || constantReminder),
    );
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

  Future<Task?> save({bool promptForNotifications = true}) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return null;

    final wantsNotifications =
        hasDueDate && (reminders.isNotEmpty || constantReminder);
    if (promptForNotifications && wantsNotifications) {
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

        final preparedSubtasks = _preparedSubtasks();
        // Auto-complete only when the parent was still open — never re-force
        // done after the user explicitly marks it incomplete in this sheet.
        final autoComplete =
            !isDone &&
            !existing.isDone &&
            preparedSubtasks.isNotEmpty &&
            preparedSubtasks.every((item) => item.isDone);
        final effectiveDone = isDone || autoComplete;

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
          subtasks: preparedSubtasks,
          isDone: effectiveDone,
          completedAt: effectiveDone
              ? (existing.isDone
                    ? existing.completedAt ?? completedAt ?? DateTime.now()
                    : completedAt ?? DateTime.now())
              : null,
          clearCompletedAt: !effectiveDone,
        );
        saved =
            await _reminderService?.prepareTaskNotifications(saved) ?? saved;
        saved = await _taskService.saveTask(saved, isNew: false);
        isDone = saved.isDone;
        completedAt = saved.completedAt;
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
      _adoptScheduledNotifications(saved);
      if (isEditing) {
        lastAutosaved = saved;
        _lastSavedSignature = _formSignature();
      }
      try {
        await _reminderService?.syncTaskNotifications(saved);
      } catch (e) {
        debugPrint('Task notification sync failed: $e');
      }
      return saved;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
