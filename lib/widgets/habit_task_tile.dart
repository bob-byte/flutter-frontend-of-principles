import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import '../models/habit.dart';
import 'completion_check.dart';
import 'tasks_glass.dart';

class HabitTaskTile extends StatelessWidget {
  const HabitTaskTile({
    super.key,
    required this.habit,
    required this.palette,
    required this.isCompleted,
    required this.onTap,
    required this.onToggle,
    this.onLongPress,
    this.keepActiveAppearance = false,
  });

  final Habit habit;
  final TasksUiPalette palette;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<Rect?>? onLongPress;

  /// During the completion burst: check fills, but title stays active.
  final bool keepActiveAppearance;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _habitTimeLabel(habit);
    final markColor = palette.primary;
    final appearanceDone = isCompleted && !keepActiveAppearance;

    return TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(20),
      blur: 0,
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              final box = context.findRenderObject() as RenderBox?;
              Rect? anchor;
              if (box != null && box.hasSize) {
                anchor = box.localToGlobal(Offset.zero) & box.size;
              }
              onLongPress!(anchor);
            },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompletionCheckButton(
            isDone: isCompleted,
            palette: palette,
            onToggle: onToggle,
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
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: appearanceDone
                        ? palette.textMuted
                        : palette.textPrimary,
                    decoration: appearanceDone
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (timeLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.insights_outlined,
            size: 18,
            color: palette.textMuted.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

String? _habitTimeLabel(Habit habit) {
  for (final reminder in habit.reminders) {
    if (reminder.isEnabled) {
      return _formatTimeOfDay(reminder.time);
    }
  }
  final reminderTime = habit.reminderTime;
  if (reminderTime == null) return null;
  return '${reminderTime.hour.toString().padLeft(2, '0')}:'
      '${reminderTime.minute.toString().padLeft(2, '0')}';
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
