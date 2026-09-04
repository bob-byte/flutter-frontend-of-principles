import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../models/habit.dart';
import 'tasks_glass.dart';

class HabitTaskTile extends StatelessWidget {
  const HabitTaskTile({
    super.key,
    required this.habit,
    required this.palette,
    required this.isCompleted,
    required this.onTap,
    required this.onToggle,
    required this.strings,
    this.onLongPress,
  });

  final Habit habit;
  final TasksUiPalette palette;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final TaskStrings strings;
  final ValueChanged<Rect?>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _habitTimeLabel(habit);
    final markColor = palette.primary;

    return TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(20),
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
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCompleted ? palette.primaryGradient : null,
                color: isCompleted ? null : palette.glassChipFill,
                border: isCompleted
                    ? null
                    : Border.all(color: palette.glassBorder, width: 1.5),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: palette.onPrimary,
                    )
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
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isCompleted
                        ? palette.textMuted
                        : palette.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel == null
                      ? strings.taskHabitLabel
                      : '${strings.taskHabitLabel} · $timeLabel',
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
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
