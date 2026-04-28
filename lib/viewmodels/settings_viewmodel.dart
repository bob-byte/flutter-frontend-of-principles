import 'package:flutter/material.dart';

import '../core/theme/theme_controller.dart';
import '../services/settings_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsService settingsService,
    required ThemeController themeController,
  })  : _settingsService = settingsService,
        _themeController = themeController;

  final SettingsService _settingsService;
  final ThemeController _themeController;

  ThemeMode get themeMode => _themeController.themeMode;

  Future<void> loadTheme() async {
    final value = await _settingsService.getThemeMode();
    if (value == 'light') {
      _themeController.setThemeMode(ThemeMode.light);
    } else if (value == 'dark') {
      _themeController.setThemeMode(ThemeMode.dark);
    } else {
      _themeController.setThemeMode(ThemeMode.system);
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeController.setThemeMode(mode);
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _settingsService.setThemeMode(value);
    notifyListeners();
  }
}
