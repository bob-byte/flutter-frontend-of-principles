import 'package:flutter/material.dart';

import '../models/ai_task_draft.dart';
import '../models/task.dart';
import '../widgets/task_edit_sheet.dart';
import '../widgets/tasks_list_menu_sheet.dart';

/// Навігація всередині модуля завдань.
class TasksNavigation {
  TasksNavigation._();

  static Future<Task?> openEditTask(
    BuildContext context, {
    String? taskId,
    AiTaskDraft? aiDraft,
  }) {
    return showTaskEditSheet(context, taskId: taskId, aiDraft: aiDraft);
  }

  /// Кнопка «+»: одразу форма створення. ШІ доступний уже в ній.
  static Future<Task?> openCreateTask(BuildContext context) {
    return openEditTask(context);
  }

  static Future<TasksListMenuResult?> openListMenu(BuildContext context) {
    return showTasksListMenuSheet(context);
  }
}
