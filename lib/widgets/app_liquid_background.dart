import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';

/// Soft orbs behind glass chrome so Liquid Glass can refract real color.
class AppLiquidBackground extends StatelessWidget {
  const AppLiquidBackground({super.key});

  @override
  Widget build(BuildContext context) {
    TasksUiPalette? palette;
    try {
      palette = context.watch<ThemeController>().palette;
    } on ProviderNotFoundException {
      palette = null;
    }
    final isDark =
        palette?.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final pageBg =
        palette?.pageBg ??
        (isDark ? const Color(0xFF070707) : const Color(0xFFF8F4EE));
    final primary = palette?.primary ?? Theme.of(context).colorScheme.primary;
    final accent = palette?.accentMuted ?? primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: pageBg),
        Positioned(
          top: -80,
          right: -40,
          child: _GlowOrb(
            color: primary.withValues(alpha: isDark ? 0.42 : 0.26),
            size: 260,
          ),
        ),
        Positioned(
          top: 220,
          left: -90,
          child: _GlowOrb(
            color: accent.withValues(alpha: isDark ? 0.28 : 0.20),
            size: 210,
          ),
        ),
        Positioned(
          bottom: 40,
          right: -20,
          child: _GlowOrb(
            color: primary.withValues(alpha: isDark ? 0.20 : 0.14),
            size: 200,
          ),
        ),
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
