import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/utils/date_helpers.dart';
import '../l10n/task_strings.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'task_calendar_sheet.dart';
import 'tasks_glass.dart';

Future<void> showTasksListMenuSheet(BuildContext context) {
  final vm = context.read<TasksViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        Theme(data: vm.themeData, child: const TasksListMenuSheet()),
  );
}

class TasksListMenuSheet extends StatelessWidget {
  const TasksListMenuSheet({super.key});

  Future<void> _pickDay(BuildContext context, TasksViewModel vm) async {
    final picked = await showTaskCalendarSheet(
      context,
      initialDay: vm.selectedDay,
      daysWithTasks: vm.daysWithTasks,
    );
    if (picked == null || !context.mounted) return;
    vm.setListModeDay(picked);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    final vm = context.watch<TasksViewModel>();
    final palette = vm.palette;
    final isDayMode = vm.listMode == TasksListMode.day;

    return TasksGlassSheet(
      palette: palette,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.taskListMenuTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
            _MenuTile(
              palette: palette,
              icon: Icons.today_outlined,
              label: strings.taskMenuToday,
              selected: vm.listMode == TasksListMode.today,
              onTap: () {
                vm.setListModeToday();
                Navigator.pop(context);
              },
            ),
            _MenuTile(
              palette: palette,
              icon: Icons.event_outlined,
              label: strings.taskMenuTomorrow,
              selected: vm.listMode == TasksListMode.tomorrow,
              onTap: () {
                vm.setListModeTomorrow();
                Navigator.pop(context);
              },
            ),
            _MenuTile(
              palette: palette,
              icon: Icons.calendar_month_outlined,
              label: isDayMode
                  ? formatTaskDate(vm.selectedDay)
                  : strings.taskMenuCalendar,
              subtitle: isDayMode ? strings.taskMenuCalendar : null,
              selected: isDayMode,
              onTap: () => _pickDay(context, vm),
            ),
            _MenuTile(
              palette: palette,
              icon: Icons.inbox_outlined,
              label: strings.taskMenuInbox,
              subtitle: strings.taskMenuInboxHint,
              selected: vm.listMode == TasksListMode.inbox,
              onTap: () {
                vm.setListModeInbox();
                Navigator.pop(context);
              },
            ),
            _MenuTile(
              palette: palette,
              icon: Icons.check_circle_outline,
              label: strings.taskMenuCompleted,
              subtitle: strings.taskMenuCompletedHint,
              selected: vm.listMode == TasksListMode.completed,
              onTap: () {
                vm.setListModeCompleted();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TasksGlassPanel(
            palette: palette,
            borderRadius: BorderRadius.circular(16),
            blur: selected ? 20 : 24,
            tint: selected
                ? palette.primary.withValues(
                    alpha: palette.isDark ? 0.28 : 0.55,
                  )
                : palette.glassChipFill,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? palette.primary : palette.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check, size: 20, color: palette.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
