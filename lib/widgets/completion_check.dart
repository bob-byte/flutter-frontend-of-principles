import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import 'completion_burst.dart';

/// Circular check used on tasks, subtasks, and habit task tiles.
class CompletionCheck extends StatelessWidget {
  const CompletionCheck({
    super.key,
    required this.isDone,
    required this.palette,
    this.size = 26,
    this.iconSize = 16,
    this.borderColor,
    this.doneColor,
    this.showShadow = true,
    this.burstRadius,
  });

  final bool isDone;
  final TasksUiPalette palette;
  final double size;
  final double iconSize;
  final Color? borderColor;
  final Color? doneColor;
  final bool showShadow;
  final double? burstRadius;

  @override
  Widget build(BuildContext context) {
    final filledColor = doneColor ?? palette.primary;
    return CompletionCelebrate(
      isCompleted: isDone,
      color: filledColor,
      burstRadius: burstRadius ?? (size * 1.55).clamp(28, 52),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDone && doneColor == null
              ? palette.primaryGradient
              : null,
          color: isDone ? doneColor : palette.glassChipFill,
          border: isDone
              ? null
              : Border.all(
                  color: borderColor ?? palette.glassBorder,
                  width: size >= 24 ? 1.5 : 1.2,
                ),
          boxShadow: isDone && showShadow
              ? [
                  BoxShadow(
                    color: filledColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: isDone
            ? Icon(
                Icons.check_rounded,
                size: iconSize,
                color: palette.onPrimary,
              )
            : null,
      ),
    );
  }
}

/// Wraps a row/control so the overlay check is drawn on [anchorKey], not the
/// whole tap target.
class CelebrateCompleteTap extends StatefulWidget {
  const CelebrateCompleteTap({
    super.key,
    required this.isDone,
    required this.palette,
    required this.builder,
    this.onToggle,
    this.checkSize = 26,
    this.burstRadius,
    this.doneColor,
  });

  final bool isDone;
  final TasksUiPalette palette;
  final Widget Function(GlobalKey anchorKey) builder;
  final VoidCallback? onToggle;
  final double checkSize;
  final double? burstRadius;
  final Color? doneColor;

  @override
  State<CelebrateCompleteTap> createState() => _CelebrateCompleteTapState();
}

class _CelebrateCompleteTapState extends State<CelebrateCompleteTap> {
  final _anchor = GlobalKey();

  void _handleTap() {
    if (widget.onToggle == null) return;
    if (!widget.isDone) {
      final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
      Offset? origin;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(box.size.center(Offset.zero));
      }
      playCompletionCelebration(
        _anchor.currentContext ?? context,
        origin: origin,
        color: widget.doneColor ?? widget.palette.primary,
        onColor: widget.palette.onPrimary,
        fillGradient: widget.doneColor == null
            ? widget.palette.primaryGradient
            : null,
        checkSize: widget.checkSize,
        radius: widget.burstRadius ?? (widget.checkSize * 1.85).clamp(32, 56),
      );
    }
    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle == null ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: widget.builder(_anchor),
    );
  }
}

/// Tappable check that plays the overlay check in this circle, then toggles.
class CompletionCheckButton extends StatelessWidget {
  const CompletionCheckButton({
    super.key,
    required this.isDone,
    required this.palette,
    required this.onToggle,
    this.size = 26,
    this.iconSize = 16,
    this.borderColor,
    this.doneColor,
    this.showShadow = true,
    this.burstRadius,
  });

  final bool isDone;
  final TasksUiPalette palette;
  final VoidCallback onToggle;
  final double size;
  final double iconSize;
  final Color? borderColor;
  final Color? doneColor;
  final bool showShadow;
  final double? burstRadius;

  @override
  Widget build(BuildContext context) {
    return CompletionBurstTarget(
      child: Builder(
        builder: (linkedContext) {
          return GestureDetector(
            onTap: () {
              if (!isDone) {
                playCompletionCelebration(
                  linkedContext,
                  color: doneColor ?? palette.primary,
                  onColor: palette.onPrimary,
                  fillGradient: doneColor == null
                      ? palette.primaryGradient
                      : null,
                  checkSize: size,
                  radius: burstRadius ?? (size * 1.85).clamp(32, 56),
                );
              }
              onToggle();
            },
            child: CompletionCheck(
              isDone: isDone,
              palette: palette,
              size: size,
              iconSize: iconSize,
              borderColor: borderColor,
              doneColor: doneColor,
              showShadow: showShadow,
              burstRadius: burstRadius,
            ),
          );
        },
      ),
    );
  }
}
