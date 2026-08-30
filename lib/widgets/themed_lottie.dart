import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';

/// Lottie that follows the active orange/blue × dark/light theme.
class ThemedLottie extends StatelessWidget {
  const ThemedLottie({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.recolorOrange = true,
  });

  /// Orange vs blue fire loops — no hue remap.
  const ThemedLottie.fire({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
  }) : assetPath = null,
       recolorOrange = false;

  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;

  /// When true, hue-rotates baked-in blue artwork for orange themes.
  final bool recolorOrange;

  static TasksUiTheme themeOf(BuildContext context) {
    try {
      return Provider.of<ThemeController>(context, listen: true).uiTheme;
    } on ProviderNotFoundException {
      return TasksUiTheme.darkOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeOf(context);
    final path = assetPath ?? theme.fireLottieAsset;
    Widget child = Lottie.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      animate: true,
    );
    if (recolorOrange && theme.isOrange) {
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix(_hueRotate(180)),
        child: child,
      );
    }
    return child;
  }
}

/// Soft radial wash behind fire / carousel loops, tinted by the palette.
class ThemedLottieHalo extends StatelessWidget {
  const ThemedLottieHalo({super.key, required this.child, this.size = 320});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemedLottie.themeOf(context);
    final palette = TasksUiPalette.of(theme);
    final colors = theme.isOrange
        ? _orangeHalo(palette)
        : [
            palette.pageBg.withValues(alpha: palette.isDark ? 0.0 : 0.93),
            palette.primary.withValues(alpha: palette.isDark ? 0.38 : 0.28),
            palette.primary.withValues(alpha: palette.isDark ? 0.55 : 0.42),
            palette.accentMuted.withValues(alpha: palette.isDark ? 0.22 : 0.18),
            Colors.transparent,
          ];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
      child: child,
    );
  }
}

/// Ember wash that stays darker/cooler than the yellow–orange flame.
List<Color> _orangeHalo(TasksUiPalette palette) {
  if (palette.isDark) {
    return [
      const Color(0xFF1A0A06).withValues(alpha: 0.55),
      const Color(0xFF4A1408).withValues(alpha: 0.42),
      const Color(0xFF2A0C08).withValues(alpha: 0.28),
      Colors.transparent,
    ];
  }
  return [
    const Color(0xFFFFF6E8).withValues(alpha: 0.95),
    const Color(0xFFFFD9A8).withValues(alpha: 0.40),
    const Color(0xFFFFC07A).withValues(alpha: 0.18),
    Colors.transparent,
  ];
}

List<double> _hueRotate(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a);
  final s = math.sin(a);
  const lumR = 0.213, lumG = 0.715, lumB = 0.072;
  return [
    lumR + c * (1 - lumR) + s * (-lumR),
    lumG + c * (-lumG) + s * (-lumG),
    lumB + c * (-lumB) + s * (1 - lumB),
    0,
    0,
    lumR + c * (-lumR) + s * 0.143,
    lumG + c * (1 - lumG) + s * 0.140,
    lumB + c * (-lumB) + s * (-0.283),
    0,
    0,
    lumR + c * (-lumR) + s * (-(1 - lumR)),
    lumG + c * (-lumG) + s * lumG,
    lumB + c * (1 - lumB) + s * lumB,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
