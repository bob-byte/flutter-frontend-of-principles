import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';

/// iOS-style liquid glass для модуля завдань.
class TasksGlassBackground extends StatelessWidget {
  const TasksGlassBackground({
    super.key,
    required this.palette,
    required this.child,
  });

  final TasksUiPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: palette.pageBg),
        Positioned(
          top: -90,
          right: -50,
          child: _GlowOrb(
            color: palette.primary.withValues(alpha: palette.isDark ? 0.45 : 0.28),
            size: 260,
          ),
        ),
        Positioned(
          top: 180,
          left: -70,
          child: _GlowOrb(
            color: palette.accentMuted.withValues(alpha: palette.isDark ? 0.28 : 0.22),
            size: 200,
          ),
        ),
        Positioned(
          bottom: 80,
          right: -30,
          child: _GlowOrb(
            color: palette.primaryGradientEnd
                .withValues(alpha: palette.isDark ? 0.22 : 0.18),
            size: 220,
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class TasksGlassPanel extends StatelessWidget {
  const TasksGlassPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.onTap,
    this.blur = 26,
    this.tint,
  });

  final TasksUiPalette palette;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? palette.glassFill,
            borderRadius: borderRadius,
            border: Border.all(color: palette.glassBorder, width: 0.85),
            boxShadow: [
              BoxShadow(
                color: palette.glassShadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: palette.primary.withValues(alpha: 0.12),
        highlightColor: palette.primary.withValues(alpha: 0.06),
        child: panel,
      ),
    );
  }
}

class TasksGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TasksGlassAppBar({
    super.key,
    required this.palette,
    required this.title,
    this.actions = const [],
  });

  final TasksUiPalette palette;
  final Widget title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.pageBg,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.glassBarFill,
              border: Border(
                bottom: BorderSide(
                  color: palette.glassBorder.withValues(alpha: 0.65),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: NavigationToolbar(
                  centerMiddle: false,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: palette.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  middle: title,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TasksGlassBottomBar extends StatelessWidget {
  const TasksGlassBottomBar({
    super.key,
    required this.palette,
    required this.child,
  });

  final TasksUiPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TasksGlassPanel(
        palette: palette,
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        blur: 30,
        tint: palette.glassBarFill,
        child: child,
      ),
    );
  }
}

class TasksGlassSheet extends StatelessWidget {
  const TasksGlassSheet({
    super.key,
    required this.palette,
    required this.child,
    this.maxHeightFactor = 0.88,
  });

  final TasksUiPalette palette;
  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
          ),
          decoration: BoxDecoration(
            color: palette.glassSheetFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: palette.glassBorder.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.glassShadow,
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class TasksGlassChip extends StatelessWidget {
  const TasksGlassChip({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final TasksUiPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? palette.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: TasksGlassPanel(
            palette: palette,
            borderRadius: BorderRadius.circular(999),
            blur: selected ? 18 : 22,
            tint: selected
                ? accent.withValues(alpha: palette.isDark ? 0.38 : 0.72)
                : palette.glassChipFill,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (color != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? palette.onPrimary : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? (palette.isDark ? Colors.white : palette.textPrimary)
                        : palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TasksGlassCircleButton extends StatelessWidget {
  const TasksGlassCircleButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isPrimary = false,
    this.size = 48,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isPrimary;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: TasksGlassPanel(
          palette: palette,
          borderRadius: BorderRadius.circular(size / 2),
          blur: isPrimary ? 16 : 22,
          tint: isPrimary
              ? palette.primary.withValues(alpha: palette.isDark ? 0.82 : 0.88)
              : palette.glassChipFill,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: isPrimary ? 28 : 24,
              color: isPrimary ? palette.onPrimary : palette.textPrimary,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
