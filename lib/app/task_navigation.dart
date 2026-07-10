import 'package:flutter/material.dart';

import '../widgets/task_edit_sheet.dart';
import '../widgets/tasks_list_menu_sheet.dart';
/// Навігація всередині модуля завдань.
class TasksNavigation {
  TasksNavigation._();

  static Future<bool?> openEditTask(
    BuildContext context, {
    String? taskId,
  }) {
    return showTaskEditSheet(context, taskId: taskId);
  }

  static Future<void> openListMenu(BuildContext context) {
    return showTasksListMenuSheet(context);
  }
}
