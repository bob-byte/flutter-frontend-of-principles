import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/task_navigation.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/utils/date_helpers.dart';
import '../l10n/task_strings.dart';
import '../models/task.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'context_menu_overlay.dart';

void showTaskContextMenu({
  required BuildContext context,
  required Task task,
  required TasksViewModel vm,
  required TasksUiPalette palette,
  Rect? anchor,
}) {
  final strings = TaskStrings.of(context);
  final l10n = AppLocalizations.of(context)!;
  final canMoveToToday = _canMoveTaskToToday(task);
  final actionCount = canMoveToToday ? 3 : 2;

  ContextMenuOverlay.show(
    context: context,
    builder: (dialogContext, animation) => ContextMenuOverlay(
      animation: animation,
      palette: palette,
      anchor: anchor,
      estimatedHeight: 100 + 52.0 * actionCount,
      child: Column(
        key: const Key('taskContextMenu'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ContextMenuHeader(
            palette: palette,
            leading: ContextMenuLeadingIcon(
              icon: Icons.checklist_outlined,
              palette: palette,
            ),
            title: task.title,
            subtitle: _taskMenuSubtitle(task, strings),
          ),
          const SizedBox(height: 12),
          ContextMenuActionList(
            palette: palette,
            actions: [
              ContextMenuAction(
                label: strings.taskEdit,
                icon: Icons.edit_outlined,
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  final saved = await TasksNavigation.openEditTask(
                    context,
                    taskId: task.id,
                  );
                  if (!context.mounted || saved == null) return;
                  await context.read<TasksViewModel>().upsertTask(saved);
                },
              ),
              if (canMoveToToday)
                ContextMenuAction(
                  label: strings.taskMoveToToday,
                  icon: Icons.today_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    vm.moveTaskToToday(task.id);
                  },
                ),
              ContextMenuAction(
                label: l10n.deleteTooltip,
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  showContextMenuConfirmDialog(
                    context: context,
                    palette: palette,
                    title: strings.taskDelete,
                    message: strings.taskDeleteConfirm,
                    onConfirm: () => vm.deleteTask(task.id),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

bool _canMoveTaskToToday(Task task) {
  if (task.isDone) return false;
  return !isSameDay(task.dueDate, dateOnly(DateTime.now()));
}

String? _taskMenuSubtitle(Task task, TaskStrings strings) {
  final parts = <String>[
    if (task.priority != null) task.priority!.label(strings),
    if (task.theme != null && task.theme!.trim().isNotEmpty) task.theme!,
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  if (task.dueDate != null) return formatTaskDate(task.dueDate!);
  return null;
}
