import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _secondaryBlue = Color(0xFF7CB6FA);

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: Brightness.light,
          primary: _primaryBlue,
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      );

  ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primaryBlue,
          secondary: _secondaryBlue,
          surface: Color(0xFF000000),
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        useMaterial3: true,
      );

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
