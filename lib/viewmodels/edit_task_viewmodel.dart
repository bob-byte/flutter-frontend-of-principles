import 'package:flutter/material.dart';

import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/ai_task_draft.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../services/task_service.dart';
import '../widgets/theme_picker_section.dart';

class EditTaskViewModel extends ChangeNotifier {
  EditTaskViewModel(this._taskService);

  final TaskService _taskService;

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

  Future<void> load({String? taskId, AiTaskDraft? draft}) async {
    isLoading = true;
    notifyListeners();
    try {
      themeColors = await _taskService.getThemeColors();

      if (taskId == null) {
        editingId = null;
        title = draft?.title ?? '';
        description = draft?.description ?? '';
        priority = draft?.priority;
        themeMode = ThemePickerMode.none;
        selectedTheme = null;
        newThemeName = '';
        themeColor = taskCategoryPalette.first;
        hasDueDate = draft?.hasDueDate ?? true;
        dueDate = draft?.dueDate ?? dateOnly(DateTime.now());

        final themeName = draft?.theme?.trim();
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
    notifyListeners();
  }

  void setDueDate(DateTime value) {
    dueDate = dateOnly(value);
    notifyListeners();
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

    isSaving = true;
    notifyListeners();
    try {
      final themeName = resolvedTheme();
      final themeColorValue = resolvedThemeColor(themeName);
      await _taskService.registerTheme(themeName, themeColorValue?.toARGB32());

      if (isEditing) {
        final existing = await _taskService.getTask(editingId!);
        if (existing == null) return false;

        await _taskService.saveTask(
          existing.copyWith(
            title: trimmedTitle,
            description: description.trim(),
            priority: priority,
            clearPriority: priority == null,
            theme: themeName,
            clearTheme: themeName == null,
            dueDate: hasDueDate ? dueDate : null,
            clearDueDate: !hasDueDate,
          ),
          isNew: false,
        );
      } else {
        await _taskService.saveTask(
          Task(
            id: '0',
            title: trimmedTitle,
            description: description.trim(),
            theme: themeName,
            priority: priority,
            createdAt: DateTime.now(),
            dueDate: hasDueDate && dueDate != null ? dateOnly(dueDate!) : null,
          ),
          isNew: true,
        );
      }
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
