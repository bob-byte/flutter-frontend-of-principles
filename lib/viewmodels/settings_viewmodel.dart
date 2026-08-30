import 'package:flutter/material.dart';

import '../core/locale/locale_controller.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../services/settings_service.dart';
import '../views/app_benefits_view.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsService settingsService,
    required ThemeController themeController,
    required LocaleController localeController,
  }) : _settingsService = settingsService,
       _themeController = themeController,
       _localeController = localeController;

  final SettingsService _settingsService;
  final ThemeController _themeController;
  final LocaleController _localeController;

  TasksUiTheme get uiTheme => _themeController.uiTheme;
  Locale? get localeOverride => _localeController.localeOverride;

  Future<void> loadTheme() async {
    await _themeController.restore();
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

  Future<void> setUiTheme(TasksUiTheme theme) async {
    await _themeController.setUiTheme(theme);
    notifyListeners();
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    _localeController.setLocaleOverride(locale);
    await _settingsService.setLocaleOverride(locale?.languageCode);
    notifyListeners();
  }

  void showAppBenefits(BuildContext context) {
    Navigator.of(context).pushNamed(AppBenefitsView.routeName);
  }
}
