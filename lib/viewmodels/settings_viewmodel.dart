import 'package:flutter/material.dart';

import '../core/locale/locale_controller.dart';
import '../core/theme/theme_controller.dart';
import '../services/settings_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsService settingsService,
    required ThemeController themeController,
    required LocaleController localeController,
  })  : _settingsService = settingsService,
        _themeController = themeController,
        _localeController = localeController;

  final SettingsService _settingsService;
  final ThemeController _themeController;
  final LocaleController _localeController;

  ThemeMode get themeMode => _themeController.themeMode;
  Locale? get localeOverride => _localeController.localeOverride;

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

  Future<void> loadLocale() async {
    final value = await _settingsService.getLocaleOverride();
    if (value == null) {
      _localeController.setLocaleOverride(null);
      return;
    }
    if (value == 'en' || value == 'uk') {
      _localeController.setLocaleOverride(Locale(value));
      return;
    }
    _localeController.setLocaleOverride(null);
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

  Future<void> setLocaleOverride(Locale? locale) async {
    _localeController.setLocaleOverride(locale);
    await _settingsService.setLocaleOverride(locale?.languageCode);
    notifyListeners();
  }
}
