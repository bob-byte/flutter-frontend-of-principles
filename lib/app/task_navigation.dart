import 'package:flutter/material.dart';

import '../models/ai_task_draft.dart';
import '../widgets/task_ai_assist_sheet.dart';
import '../widgets/task_create_choice_sheet.dart';
import '../widgets/task_edit_sheet.dart';
import '../widgets/tasks_list_menu_sheet.dart';

/// Навігація всередині модуля завдань.
class TasksNavigation {
  TasksNavigation._();

  static Future<bool?> openEditTask(
    BuildContext context, {
    String? taskId,
    AiTaskDraft? draft,
  }) {
    return showTaskEditSheet(context, taskId: taskId, draft: draft);
  }

  /// Кнопка «+»: вибір ручного створення або ШІ-помічника.
  static Future<bool?> openCreateTask(BuildContext context) async {
    final mode = await showTaskCreateChoiceSheet(context);
    if (!context.mounted || mode == null) return null;

    switch (mode) {
      case TaskCreateMode.manual:
        return openEditTask(context);
      case TaskCreateMode.ai:
        final draft = await showTaskAiAssistSheet(context);
        if (!context.mounted || draft == null) return null;
        return openEditTask(context, draft: draft);
    }
  }

  static Future<void> openListMenu(BuildContext context) {
    return showTasksListMenuSheet(context);
  }
}
