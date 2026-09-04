import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/recommended_habit.dart';
import '../../viewmodels/edit_habit_viewmodel.dart';
import '../../widgets/themed_lottie.dart';

class RecommendedHabitsSheet {
  static Future<RecommendedHabit?> show(BuildContext context) {
    return showModalBottomSheet<RecommendedHabit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      builder: (_) => const _RecommendedHabitsSheetContent(),
    );
  }
}

class _RecommendedHabitsSheetContent extends StatelessWidget {
  const _RecommendedHabitsSheetContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditHabitViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final media = MediaQuery.of(context);
    final heightFactor = media.size.height < 700 ? 0.86 : 0.78;
    final sheetHeight = math.min(media.size.height * heightFactor, 720.0);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: palette.cardBorder.withValues(
            alpha: palette.isDark ? 0.32 : 0.55,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _SheetHeader(
                palette: palette,
                title: l10n.recommendedHabitsByAi,
                subtitle: vm.targetGoal.trim().isEmpty
                    ? l10n.recommendedHabitsCaptionNoGoal
                    : l10n.recommendedHabitsCaptionWithGoal(
                        vm.targetGoal.trim(),
                      ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody(context, vm, l10n, palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    EditHabitViewModel vm,
    AppLocalizations l10n,
    TasksUiPalette palette,
  ) {
    if (vm.isRecommendedHabitsLoading) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(
                    alpha: palette.isDark ? 0.10 : 0.07,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: ThemedLottie.fire(width: 112, height: 112),
                ),
              ),
            ),
          ),
          Text(
            l10n.loadingLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              l10n.recommendedHabitsLoadingHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    if (vm.recommendedHabitsError != null) {
      return _SheetStateMessage(
        icon: Icons.cloud_off_rounded,
        message: vm.recommendedHabitsError!,
        palette: palette,
      );
    }

    if (vm.recommendedHabits.isEmpty) {
      return _SheetStateMessage(
        icon: Icons.auto_awesome_outlined,
        message: l10n.recommendedHabitsEmpty,
        palette: palette,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: vm.recommendedHabits.length,
      itemBuilder: (context, index) {
        final habit = vm.recommendedHabits[index];
        return _RecommendationTile(
          habit: habit,
          index: index,
          palette: palette,
          onTap: () => Navigator.of(context).pop(habit),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.palette,
    required this.title,
    required this.subtitle,
  });

  final TasksUiPalette palette;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: palette.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: palette.onPrimary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.2,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.habit,
    required this.index,
    required this.palette,
    required this.onTap,
  });

  final RecommendedHabit habit;
  final int index;
  final TasksUiPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                color: palette.primary.withValues(
                  alpha: palette.isDark ? 0.075 : 0.045,
                ),
                borderRadius: radius,
                border: Border.all(
                  color: palette.primary.withValues(
                    alpha: palette.isDark ? 0.24 : 0.18,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(
                          alpha: palette.isDark ? 0.22 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                              height: 1.28,
                            ),
                          ),
                          if (habit.reasonToFollow.trim().isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              habit.reasonToFollow,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: palette.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: palette.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetStateMessage extends StatelessWidget {
  const _SheetStateMessage({
    required this.icon,
    required this.message,
    required this.palette,
  });

  final IconData icon;
  final String message;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.primary.withValues(
                  alpha: palette.isDark ? 0.12 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: palette.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
