import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../models/habit.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../views/edit_habit_view.dart';
import '../views/habit_detail_view.dart';
import 'context_menu_overlay.dart';

Color _primarySoft(TasksUiPalette palette) =>
    palette.primary.withValues(alpha: palette.isDark ? 0.22 : 0.14);

void showHabitContextMenu({
  required BuildContext context,
  required Habit habit,
  required HabitProgressViewModel vm,
  required TasksUiPalette palette,
  Rect? anchor,
}) {
  final l10n = AppLocalizations.of(context)!;
  final weeklyProgress = vm.getPercentageAchieved(habit);
  final percentLabel = vm.percentageLabel(habit);

  ContextMenuOverlay.show(
    context: context,
    builder: (dialogContext, animation) => ContextMenuOverlay(
      animation: animation,
      palette: palette,
      anchor: anchor,
      estimatedHeight: 308,
      child: Column(
        key: const Key('habitContextMenu'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ContextMenuHeader(
            palette: palette,
            leading: CircularPercentIndicator(
              radius: 20,
              lineWidth: 3.5,
              percent: weeklyProgress.clamp(0.0, 1.0),
              center: Text(
                percentLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: palette.primary,
                ),
              ),
              progressColor: palette.primary,
              backgroundColor: _primarySoft(palette),
            ),
            title: habit.name,
          ),
          const SizedBox(height: 12),
          ContextMenuActionList(
            palette: palette,
            actions: [
              ContextMenuAction(
                label: l10n.habitMenuEdit,
                icon: Icons.edit_outlined,
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await EditHabitView.show(context, habit: habit);
                  if (context.mounted) {
                    context.read<HabitProgressViewModel>().load();
                  }
                },
              ),
              ContextMenuAction(
                label: l10n.habitMenuDetails,
                icon: Icons.bar_chart_outlined,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context)
                      .pushNamed(HabitDetailView.routeName, arguments: habit.id)
                      .then((_) {
                        if (context.mounted) vm.load(silent: true);
                      });
                },
              ),
              ContextMenuAction(
                label: l10n.archiveTooltip,
                icon: Icons.archive_outlined,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _confirmArchive(context, habit, vm, palette);
                },
              ),
              ContextMenuAction(
                label: l10n.deleteTooltip,
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _confirmDelete(context, habit, vm, palette);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void _confirmArchive(
  BuildContext context,
  Habit habit,
  HabitProgressViewModel vm,
  TasksUiPalette palette,
) {
  final l10n = AppLocalizations.of(context)!;
  showContextMenuConfirmDialog(
    context: context,
    palette: palette,
    title: l10n.archiveHabitQuestion,
    message: l10n.archiveHabitMessage,
    onConfirm: () => vm.archiveHabit(habit),
  );
}

void _confirmDelete(
  BuildContext context,
  Habit habit,
  HabitProgressViewModel vm,
  TasksUiPalette palette,
) {
  final l10n = AppLocalizations.of(context)!;
  showContextMenuConfirmDialog(
    context: context,
    palette: palette,
    title: l10n.deleteHabitQuestion,
    message: l10n.deleteHabitMessage,
    onConfirm: () => vm.deleteHabit(habit),
  );
}
