import 'package:flutter/material.dart';

import '../core/utils/date_helpers.dart';
import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../models/task.dart';
import 'tasks_glass.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.palette,
    required this.themeColor,
    required this.onTap,
    required this.onToggle,
    required this.strings,
    this.onMoveToToday,
  });

  final Task task;
  final TasksUiPalette palette;
  final Color themeColor;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onMoveToToday;
  final TaskStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final isOverdue = !task.isDone &&
        task.dueDate != null &&
        task.dueDate!.isBefore(today);
    final markColor = isOverdue ? scheme.error : themeColor;

    return TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: task.isDone ? palette.primaryGradient : null,
                color: task.isDone ? null : palette.glassChipFill,
                border: task.isDone
                    ? null
                    : Border.all(
                        color: isOverdue
                            ? scheme.error.withValues(alpha: 0.75)
                            : palette.glassBorder,
                        width: 1.5,
                      ),
                boxShadow: task.isDone
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: task.isDone
                  ? Icon(Icons.check_rounded, size: 16, color: palette.onPrimary)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: markColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: markColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOverdue) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 6),
                        child: Icon(
                          Icons.priority_high_rounded,
                          size: 18,
                          color: scheme.error,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: task.isDone
                              ? palette.textMuted
                              : palette.textPrimary,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_taskMetaLine(task, strings).isNotEmpty)
                  Text(
                    _taskMetaLine(task, strings),
                    style: TextStyle(
                      fontSize: 12,
                      color: task.priority != null
                          ? priorityColor(task.priority!, scheme)
                          : palette.textMuted,
                    ),
                  ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule,
                        size: 13,
                        color: isOverdue ? scheme.error : palette.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOverdue
                            ? '${strings.taskOverdue} · ${formatTaskDate(task.dueDate!)}'
                            : formatTaskDate(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isOverdue ? FontWeight.w600 : FontWeight.w400,
                          color: isOverdue ? scheme.error : palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isOverdue && onMoveToToday != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onMoveToToday,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.today_outlined, size: 16),
                      label: Text(strings.taskMoveToToday),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: palette.textMuted.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

String _taskMetaLine(Task task, TaskStrings strings) {
  final parts = <String>[
    if (task.priority != null) task.priority!.label(strings),
    if (task.theme != null) task.theme!,
  ];
  return parts.join(' · ');
}
