import 'package:flutter/material.dart';

import '../../../core/theme/task_theme_palette.dart';
import '../../../l10n/schedule_strings.dart';
import '../../../models/task_repeat_config.dart';
import 'custom_repeat_sheet.dart';
import 'schedule_format.dart';

Future<TaskRepeatConfig?> showRepeatPickerSheet(
  BuildContext context, {
  required TasksUiPalette palette,
  required TaskRepeatConfig selected,
  required DateTime selectedDay,
}) {
  return showModalBottomSheet<TaskRepeatConfig>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RepeatPickerSheet(
      palette: palette,
      selected: selected,
      selectedDay: selectedDay,
    ),
  );
}

class _RepeatPickerSheet extends StatelessWidget {
  const _RepeatPickerSheet({
    required this.palette,
    required this.selected,
    required this.selectedDay,
  });

  final TasksUiPalette palette;
  final TaskRepeatConfig selected;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final strings = ScheduleStrings.of(context);
    final weekly = TaskRepeatConfig.weekly(selectedDay);
    final monthly = TaskRepeatConfig.monthly();
    final yearly = TaskRepeatConfig.yearly();
    final weekday = TaskRepeatConfig.everyWeekday();

    Widget row(String label, TaskRepeatConfig value) {
      final isOn = selected.preset == value.preset &&
          value.preset != TaskRepeatPreset.custom;
      return ListTile(
        dense: true,
        title: Text(
          label,
          style: TextStyle(
            color: isOn ? palette.primary : palette.textPrimary,
            fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: isOn ? Icon(Icons.check, color: palette.primary, size: 20) : null,
        onTap: () => Navigator.pop(context, value),
      );
    }

    return Material(
      color: palette.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(strings.none, const TaskRepeatConfig()),
              row(strings.daily, TaskRepeatConfig.daily()),
              row(
                '${strings.weekly} (${weekdayShort(selectedDay.weekday)})',
                weekly,
              ),
              row(
                '${strings.monthly} (${selectedDay.day})',
                monthly,
              ),
              row(
                '${strings.yearly} (${selectedDay.day} ${monthShort(selectedDay.month)})',
                yearly,
              ),
              Divider(color: palette.cardBorder.withValues(alpha: 0.35)),
              row(strings.everyWeekday, weekday),
              ListTile(
                dense: true,
                title: Text(
                  strings.custom,
                  style: TextStyle(
                    color: selected.preset == TaskRepeatPreset.custom
                        ? palette.primary
                        : palette.textPrimary,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: palette.textMuted),
                onTap: () async {
                  final custom = await showCustomRepeatSheet(
                    context,
                    palette: palette,
                    initial: selected.preset == TaskRepeatPreset.custom
                        ? selected
                        : TaskRepeatConfig(
                            preset: TaskRepeatPreset.custom,
                            unit: TaskRepeatUnit.week,
                            weekdays: [selectedDay.weekday],
                          ),
                    selectedDay: selectedDay,
                  );
                  if (custom != null && context.mounted) {
                    Navigator.pop(context, custom);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
