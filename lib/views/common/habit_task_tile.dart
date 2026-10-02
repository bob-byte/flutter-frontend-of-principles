import 'package:flutter/material.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../models/habit.dart';
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

    void handleLongPress() {
      if (onLongPress == null) return;
      final box = context.findRenderObject() as RenderBox?;
      Rect? anchor;
      if (box != null && box.hasSize) {
        anchor = box.localToGlobal(Offset.zero) & box.size;
      }
      onLongPress!(anchor);
    }

    // Keep open-on-tap off the check column so near-miss taps still toggle
    // instead of opening habit detail.
    return GestureDetector(
      onLongPress: onLongPress == null ? null : handleLongPress,
      child: TasksGlassPanel(
        palette: palette,
        borderRadius: BorderRadius.circular(20),
        blur: 0,
        padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompletionCheckButton(
                isDone: isCompleted,
                palette: palette,
                expandToHeight: true,
                padding: const EdgeInsets.only(left: 8, right: 4),
                onToggle: onToggle,
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(20),
                    ),
                    splashColor: palette.primary.withValues(alpha: 0.12),
                    highlightColor: palette.primary.withValues(alpha: 0.06),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: 4),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textMuted,
                                  ),
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
                  ),
                ),
              ),
            ],
          ),
        ),
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
