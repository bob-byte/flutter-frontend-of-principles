import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/habit.dart';
import '../../services/database_service.dart';
import '../../services/habit_service.dart';
import '../../viewmodels/archive_viewmodel.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/context_menu_overlay.dart';
import '../../widgets/expandable_bottom_sheet.dart';
import '../../widgets/themed_lottie.dart';
import '../edit_habit_view.dart';
import '../habit_detail_view.dart';

class ArchiveBottomSheet extends StatelessWidget {
  const ArchiveBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ArchiveViewModel(
        ctx.read<DatabaseService>(),
        ctx.read<HabitService>(),
      ),
      child: const _ArchiveBottomSheetShell(),
    );
  }
}

class _ArchiveBottomSheetShell extends StatelessWidget {
  const _ArchiveBottomSheetShell();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: ExpandableSheetDefaults.maxChildSize,
      snap: true,
      snapSizes: const [0.6, ExpandableSheetDefaults.maxChildSize],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return _ArchiveBottomSheetContent(scrollController: scrollController);
      },
    );
  }
}

class _ArchiveBottomSheetContent extends StatelessWidget {
  const _ArchiveBottomSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArchiveViewModel>();
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
                      tooltip: l10n.archiveInfoTooltip,
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
                    _HeaderCircleButton(
                      icon: Icons.add_circle,
                      color: palette.textPrimary,
                      tooltip: l10n.editHabitTitle,
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        EditHabitView.show(navigator.context);
                      },
                    ),
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
                              l10n.archiveInfoDescription,
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
    ArchiveViewModel vm,
    AppLocalizations l10n,
    TasksUiPalette palette,
  ) {
    if (vm.isLoading) {
      return const AppLoadingIndicator();
    }

    if (vm.archivedHabits.isEmpty) {
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
                    recolorOrange: false,
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
                l10n.archiveEmptyDescription,
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
      itemCount: vm.archivedHabits.length,
      itemBuilder: (context, index) {
        final habit = vm.archivedHabits[index];
        return _ArchivedHabitCard(
          habit: habit,
          palette: palette,
          onOpenMenu: (anchor) =>
              _showHabitMenu(context, habit, vm, palette, anchor: anchor),
          onOpenDetails: () => _openDetails(context, habit, vm),
        );
      },
    );
  }

  String? _habitSubtitle(Habit habit) {
    final notes = habit.notes.trim();
    if (notes.isNotEmpty) return notes;
    if (habit.reminderTime != null) {
      return DateFormat('HH:mm').format(habit.reminderTime!);
    }
    return null;
  }

  void _openDetails(BuildContext context, Habit habit, ArchiveViewModel vm) {
    Navigator.of(
      context,
    ).pushNamed(HabitDetailView.routeName, arguments: habit.id).then((_) {
      if (context.mounted) vm.loadHabits();
    });
  }

  Future<void> _openEdit(
    BuildContext context,
    Habit habit,
    ArchiveViewModel vm,
  ) async {
    await EditHabitView.show(context, habit: habit);
    if (context.mounted) await vm.loadHabits();
  }

  void _showHabitMenu(
    BuildContext context,
    Habit habit,
    ArchiveViewModel vm,
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
        estimatedHeight: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuHeader(
              palette: palette,
              leading: ContextMenuLeadingIcon(
                icon: Icons.archive_outlined,
                palette: palette,
              ),
              title: habit.name,
              subtitle: _habitSubtitle(habit),
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
                    _openEdit(context, habit, vm);
                  },
                ),
                ContextMenuAction(
                  label: l10n.habitMenuViewDetails,
                  icon: Icons.bar_chart_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _openDetails(context, habit, vm);
                  },
                ),
                ContextMenuAction(
                  label: l10n.habitMenuRestore,
                  icon: Icons.unarchive_outlined,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    vm.unarchiveHabit(habit);
                  },
                ),
                ContextMenuAction(
                  label: l10n.habitMenuDelete,
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

  void _confirmDelete(
    BuildContext context,
    Habit habit,
    ArchiveViewModel vm,
    TasksUiPalette palette,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showAppConfirmDialog(
      context: context,
      palette: palette,
      title: l10n.deleteHabitQuestion,
      message: l10n.deleteHabitMessage,
      onConfirm: () => vm.deleteHabit(habit),
    );
  }
}

class _ArchivedHabitCard extends StatelessWidget {
  const _ArchivedHabitCard({
    required this.habit,
    required this.palette,
    required this.onOpenMenu,
    required this.onOpenDetails,
  });

  final Habit habit;
  final TasksUiPalette palette;
  final ValueChanged<Rect?> onOpenMenu;
  final VoidCallback onOpenDetails;

  String? get _subtitle {
    final notes = habit.notes.trim();
    if (notes.isNotEmpty) return notes;
    if (habit.reminderTime != null) {
      return DateFormat('HH:mm').format(habit.reminderTime!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenDetails,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
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

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        icon: Icon(icon, size: 40, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
  }
}
