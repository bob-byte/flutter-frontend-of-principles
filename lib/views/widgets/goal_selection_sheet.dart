import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../viewmodels/goal_selection_viewmodel.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/context_menu_overlay.dart';
import '../../widgets/themed_lottie.dart';

class GoalSelectionSheetWidget extends StatelessWidget {
  final String currentTargetGoal;

  const GoalSelectionSheetWidget({super.key, required this.currentTargetGoal});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => GoalSelectionViewModel(
        ctx.read<GoalService>(),
        currentTargetGoal: currentTargetGoal,
      ),
      child: const _GoalSelectionSheetContent(),
    );
  }
}

class _GoalSelectionSheetContent extends StatelessWidget {
  const _GoalSelectionSheetContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalSelectionViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.72;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      l10n.selectHabitGoalTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        size: 28,
                        color: palette.primary,
                      ),
                      tooltip: l10n.addGoalTitle,
                      padding: EdgeInsets.zero,
                      onPressed: () => vm.showAddEditGoalDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context, vm, l10n, palette)),
              const SizedBox(height: 10),
              Text(
                l10n.selectHabitGoalRecommendation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    GoalSelectionViewModel vm,
    AppLocalizations l10n,
    TasksUiPalette palette,
  ) {
    if (vm.isLoading) {
      return const AppLoadingIndicator();
    }

    if (vm.goals.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: Center(
              child: ThemedLottie(
                assetPath: 'assets/lottie/goals.json',
                width: 160,
                height: 160,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              l10n.goalsEmptyList,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: vm.goals.length,
      itemBuilder: (context, index) {
        final goal = vm.goals[index];
        final isSelected = vm.currentTargetGoal == goal.name;
        return _GoalTile(
          goal: goal,
          palette: palette,
          isSelected: isSelected,
          onTap: () => vm.selectGoal(goal),
          onOpenMenu: (anchor) =>
              _showGoalMenu(context, goal, vm, palette, anchor: anchor),
        );
      },
    );
  }

  void _showGoalMenu(
    BuildContext context,
    UserGoal goal,
    GoalSelectionViewModel vm,
    TasksUiPalette palette, {
    Rect? anchor,
  }) {
    final l10n = AppLocalizations.of(context)!;

    ContextMenuOverlay.show(
      context: context,
      builder: (dialogContext, animation) => ContextMenuOverlay(
        animation: animation,
        palette: palette,
        anchor: anchor,
        estimatedHeight: 272,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuHeader(
              palette: palette,
              leading: ContextMenuLeadingIcon(
                icon: goal.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.flag_outlined,
                palette: palette,
              ),
              title: goal.name,
            ),
            const SizedBox(height: 12),
            ContextMenuActionList(
              palette: palette,
              actions: [
                ContextMenuAction(
                  label: l10n.habitMenuEdit,
                  icon: Icons.edit_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    vm.showAddEditGoalDialog(existingGoal: goal);
                  },
                ),
                ContextMenuAction(
                  label: goal.isCompleted
                      ? l10n.markGoalIncomplete
                      : l10n.markGoalCompleted,
                  icon: goal.isCompleted
                      ? Icons.restart_alt
                      : Icons.check_circle_outline,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    vm.setGoalCompleted(goal, isCompleted: !goal.isCompleted);
                  },
                ),
                ContextMenuAction(
                  label: l10n.deleteTooltip,
                  icon: Icons.delete_outline,
                  destructive: true,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final confirmed = await vm.confirmDeleteGoal(goal);
                    if (confirmed) {
                      await vm.deleteGoal(goal);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.palette,
    required this.isSelected,
    required this.onTap,
    required this.onOpenMenu,
  });

  final UserGoal goal;
  final TasksUiPalette palette;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<Rect?> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final fillAlpha = isSelected
        ? (palette.isDark ? 0.32 : 0.18)
        : (palette.isDark ? 0.18 : 0.10);
    final borderAlpha = isSelected ? 0.85 : 0.35;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () {
            final box = context.findRenderObject() as RenderBox?;
            Rect? anchor;
            if (box != null && box.hasSize) {
              anchor = box.localToGlobal(Offset.zero) & box.size;
            }
            onOpenMenu(anchor);
          },
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: fillAlpha),
              borderRadius: radius,
              border: Border.all(
                color: palette.primary.withValues(alpha: borderAlpha),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(
                        alpha: palette.isDark ? 0.28 : 0.16,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_rounded
                          : goal.isCompleted
                          ? Icons.check_circle_outline
                          : Icons.flag_outlined,
                      color: palette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: palette.textPrimary,
                        height: 1.25,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: palette.textMuted),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).moreButtonTooltip,
                    onPressed: () {
                      final box = context.findRenderObject() as RenderBox?;
                      Rect? anchor;
                      if (box != null && box.hasSize) {
                        anchor = box.localToGlobal(Offset.zero) & box.size;
                      }
                      onOpenMenu(anchor);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
