import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../viewmodels/goal_archive_viewmodel.dart';
import '../common/app_loading_indicator.dart';
import '../common/context_menu_overlay.dart';
import '../common/expandable_bottom_sheet.dart';
import '../common/themed_lottie.dart';
import '../edit_goal_view.dart';

class GoalArchiveBottomSheet extends StatelessWidget {
  const GoalArchiveBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => GoalArchiveViewModel(ctx.read<GoalService>()),
      child: const _GoalArchiveBottomSheetShell(),
    );
  }
}

class _GoalArchiveBottomSheetShell extends StatelessWidget {
  const _GoalArchiveBottomSheetShell();

  @override
  Widget build(BuildContext context) {
    return ExpandableSheetFrame(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: ExpandableSheetDefaults.maxChildSize,
      snapSizes: const [0.6, ExpandableSheetDefaults.maxChildSize],
      builder: (context, scrollController) {
        return _GoalArchiveBottomSheetContent(
          scrollController: scrollController,
        );
      },
    );
  }
}

class _GoalArchiveBottomSheetContent extends StatelessWidget {
  const _GoalArchiveBottomSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalArchiveViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                BottomSheetDragHandle(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  width: 40,
                  topPadding: 0,
                  bottomPadding: 8,
                ),
                Row(
                  children: [
                    _HeaderCircleButton(
                      icon: Icons.info,
                      color: palette.textPrimary,
                      tooltip: l10n.goalArchiveInfoTooltip,
                      onPressed: vm.showBanner,
                    ),
                    Expanded(
                      child: Text(
                        l10n.archiveTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(context, vm, l10n, palette)),
              ],
            ),
            if (vm.showInfoBanner) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: vm.hideBanner,
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.45 : 0.28,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  color: palette.cardBg,
                  elevation: 8,
                  shadowColor: palette.glassShadow,
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.goalArchiveInfoDescription,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: vm.hideBanner,
                            child: Text(
                              l10n.okButton,
                              style: TextStyle(
                                color: palette.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    GoalArchiveViewModel vm,
    AppLocalizations l10n,
    TasksUiPalette palette,
  ) {
    if (vm.isLoading && vm.archivedGoals.isEmpty) {
      return const AppLoadingIndicator();
    }

    if (vm.archivedGoals.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest.shortestSide;
                return Center(
                  child: ThemedLottie(
                    assetPath: 'assets/lottie/archive.json',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 120,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.goalArchiveEmptyDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: vm.archivedGoals.length,
      itemBuilder: (context, index) {
        final goal = vm.archivedGoals[index];
        return _ArchivedGoalCard(
          goal: goal,
          palette: palette,
          onOpenMenu: (anchor) =>
              _showGoalMenu(context, goal, vm, palette, anchor: anchor),
          onOpen: () => _openEdit(context, goal, vm),
        );
      },
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    UserGoal goal,
    GoalArchiveViewModel vm,
  ) async {
    await EditGoalView.open(context, goal: goal);
    if (context.mounted) await vm.loadGoals();
  }

  void _showGoalMenu(
    BuildContext context,
    UserGoal goal,
    GoalArchiveViewModel vm,
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
        estimatedHeight: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuHeader(
              palette: palette,
              leading: ContextMenuLeadingIcon(
                icon: Icons.archive_outlined,
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
                    _openEdit(context, goal, vm);
                  },
                ),
                ContextMenuAction(
                  label: l10n.habitMenuRestore,
                  icon: Icons.unarchive_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    vm.unarchiveGoal(goal);
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

class _ArchivedGoalCard extends StatelessWidget {
  const _ArchivedGoalCard({
    required this.goal,
    required this.palette,
    required this.onOpenMenu,
    required this.onOpen,
  });

  final UserGoal goal;
  final TasksUiPalette palette;
  final ValueChanged<Rect?> onOpenMenu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
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
              color: palette.primary.withValues(
                alpha: palette.isDark ? 0.22 : 0.12,
              ),
              borderRadius: radius,
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(
                        alpha: palette.isDark ? 0.28 : 0.18,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.archive_outlined,
                      color: palette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final box = context.findRenderObject() as RenderBox?;
                      Rect? anchor;
                      if (box != null && box.hasSize) {
                        anchor = box.localToGlobal(Offset.zero) & box.size;
                      }
                      onOpenMenu(anchor);
                    },
                    icon: Icon(Icons.more_horiz, color: palette.textMuted),
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

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}
