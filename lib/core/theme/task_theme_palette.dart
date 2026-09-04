import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/task_strings.dart';
import '../../models/task_priority.dart';

/// Кольорові теми з [principles.top](https://principles.top) (`data-theme`).
enum TasksUiTheme {
  darkOrange,
  darkBlue,
  lightOrange,
  lightBlue;

  bool get isDark => this == darkOrange || this == darkBlue;

  bool get isOrange => this == darkOrange || this == lightOrange;

  /// Orange vs blue fire loop used on startup / signup.
  String get fireLottieAsset => isOrange
      ? 'assets/lottie/orange_fire_loading.json'
      : 'assets/lottie/blue_fire_loading.json';

  /// App mark used on login and in branded alerts.
  String get logoAsset => isOrange
      ? 'assets/images/orange_logo.png'
      : 'assets/images/blue_logo.png';

  /// H.264 splash clip used on cold start. Video-only: iOS AVPlayer
  /// rejects the muxed H.264+AAC file with OSStatus -12746.
  String get splashVideoAsset => isOrange
      ? 'assets/splash/epic_start_orange.mp4'
      : 'assets/splash/epic_start_blue.mp4';

  /// Soundtrack played beside [splashVideoAsset] via AVAudioPlayer.
  /// iOS AVPlayer cannot load the muxed or AAC-only splash files.
  static const splashAudioAsset = 'assets/splash/epic_start.wav';

  /// Matches the first frame of [splashVideoAsset] so the native/Flutter
  /// splash does not flash a different color before the video starts.
  Color get splashBackground =>
      isOrange ? const Color(0xFF0A0602) : const Color(0xFF00002F);

  String get storageKey => name;

  static TasksUiTheme fromStorage(String? value) => switch (value) {
    'darkBlue' => darkBlue,
    'lightOrange' => lightOrange,
    'lightBlue' => lightBlue,
    _ => darkOrange,
  };

  String label(TaskStrings strings) => switch (this) {
    darkOrange => strings.uiThemeDarkOrange,
    darkBlue => strings.uiThemeDarkBlue,
    lightOrange => strings.uiThemeLightOrange,
    lightBlue => strings.uiThemeLightBlue,
  };
}

@immutable
class TasksUiPalette {
  const TasksUiPalette({
    required this.pageBg,
    required this.cardBg,
    required this.textPrimary,
    required this.textMuted,
    required this.primary,
    required this.primaryGradientStart,
    required this.primaryGradientEnd,
    required this.onPrimary,
    required this.accentMuted,
    required this.cardBorder,
    required this.softBg,
    required this.headerBorder,
    required this.isDark,
  });

  final Color pageBg;
  final Color cardBg;
  final Color textPrimary;
  final Color textMuted;
  final Color primary;
  final Color primaryGradientStart;
  final Color primaryGradientEnd;
  final Color onPrimary;
  final Color accentMuted;
  final Color cardBorder;
  final Color softBg;
  final Color headerBorder;
  final bool isDark;

  Color get glassFill => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.58);

  Color get glassBarFill =>
      isDark ? const Color(0xE6101010) : Colors.white.withValues(alpha: 0.52);

  Color get glassSheetFill =>
      isDark ? const Color(0xCC141414) : const Color(0xD9F5F8FC);

  Color get glassChipFill => isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.white.withValues(alpha: 0.42);

  Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.24)
      : Colors.white.withValues(alpha: 0.92);

  Color get glassShadow => isDark
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.08);

  /// Unselected tab glyphs. Light orange orbs make adaptive brightness pick
  /// white icons, so light themes share light-blue's dark label color.
  Color? get tabBarUnselectedIconColor =>
      isDark ? null : const Color(0xFF101820);

  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  static TasksUiPalette of(TasksUiTheme theme) => switch (theme) {
    TasksUiTheme.darkOrange => const TasksUiPalette(
      pageBg: Color(0xFF070707),
      cardBg: Color(0xFF121212),
      textPrimary: Color(0xFFFFFFFF),
      textMuted: Color(0x80FFFFFF),
      primary: Color(0xFFFF6B00),
      primaryGradientStart: Color(0xFFFF8A00),
      primaryGradientEnd: Color(0xFFFF6B00),
      onPrimary: Color(0xFF180C06),
      accentMuted: Color(0xFFFF9A40),
      cardBorder: Color(0x80FFFFFF),
      softBg: Color(0x0DFFFFFF),
      headerBorder: Color(0xFF222222),
      isDark: true,
    ),
    TasksUiTheme.darkBlue => const TasksUiPalette(
      pageBg: Color(0xFF070707),
      cardBg: Color(0xFF121212),
      textPrimary: Color(0xFFFFFFFF),
      textMuted: Color(0x80FFFFFF),
      primary: Color(0xFF007BFF),
      primaryGradientStart: Color(0xFF3E9BFF),
      primaryGradientEnd: Color(0xFF007BFF),
      onPrimary: Color(0xFF041018),
      accentMuted: Color(0xFF7EB8FF),
      cardBorder: Color(0x80FFFFFF),
      softBg: Color(0x0DFFFFFF),
      headerBorder: Color(0xFF222222),
      isDark: true,
    ),
    TasksUiTheme.lightOrange => const TasksUiPalette(
      pageBg: Color(0xFFF8F4EE),
      cardBg: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF18130F),
      textMuted: Color(0x80000000),
      primary: Color(0xFFFF6B00),
      primaryGradientStart: Color(0xFFFF8A00),
      primaryGradientEnd: Color(0xFFFF6B00),
      onPrimary: Color(0xFFFFFFFF),
      accentMuted: Color(0xFFC45600),
      cardBorder: Color(0xFFDDCFBF),
      softBg: Color(0x14000000),
      headerBorder: Color(0xFFE8DDD0),
      isDark: false,
    ),
    TasksUiTheme.lightBlue => const TasksUiPalette(
      pageBg: Color(0xFFEFF6FF),
      cardBg: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF101820),
      textMuted: Color(0x80000000),
      primary: Color(0xFF007BFF),
      primaryGradientStart: Color(0xFF3E9BFF),
      primaryGradientEnd: Color(0xFF007BFF),
      onPrimary: Color(0xFFFFFFFF),
      accentMuted: Color(0xFF2F72B8),
      cardBorder: Color(0xFFC8D9EC),
      softBg: Color(0x14000000),
      headerBorder: Color(0xFFD6E4F4),
      isDark: false,
    ),
  };

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: accentMuted,
        onSecondary: textPrimary,
        surface: cardBg,
        onSurface: textPrimary,
        onSurfaceVariant: textMuted,
        outline: cardBorder,
        error: const Color(0xFFE85D4C),
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: pageBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.45)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: TextStyle(color: onPrimary),
        actionTextColor: onPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: primary.withValues(alpha: isDark ? 0.35 : 0.22),
          ),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        contentTextStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: cardBorder.withValues(alpha: 0.45)),
  );
}

/// Кольори категорій завдань (не плутати з UI-темами).
const taskCategoryPalette = [
  Color(0xFFFF6B00),
  Color(0xFF007BFF),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF06B6D4),
];

@Deprecated('Use taskCategoryPalette')
const taskThemePalette = taskCategoryPalette;

Color fallbackThemeColor(String theme) {
  final hash = theme.codeUnits.fold<int>(0, (h, c) => h + c);
  return taskCategoryPalette[hash % taskCategoryPalette.length];
}

Color priorityColor(TaskPriority priority, ColorScheme scheme) {
  return switch (priority) {
    TaskPriority.low =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFF7EB8FF)
          : const Color(0xFF2563EB),
    TaskPriority.medium =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFFACC15)
          : const Color(0xFFCA8A04),
    TaskPriority.high =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFEF4444)
          : const Color(0xFFDC2626),
  };
}

const kTasksProgressAnimDuration = Duration(milliseconds: 420);
const kTasksProgressAnimCurve = Curves.easeInOutCubic;

Widget tasksGradientProgress({
  required TasksUiPalette palette,
  required double value,
  double height = 8,
  Duration duration = kTasksProgressAnimDuration,
  Curve curve = kTasksProgressAnimCurve,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: palette.glassChipFill),
            TweenAnimationBuilder<double>(
              duration: duration,
              curve: curve,
              tween: Tween<double>(end: value.clamp(0.0, 1.0)),
              builder: (context, animated, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
