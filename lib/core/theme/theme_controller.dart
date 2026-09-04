import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/settings_service.dart';
import 'app_icon_controller.dart';
import 'task_theme_palette.dart';

/// App-wide color theme: four palettes (dark/light × orange/blue).
class ThemeController extends ChangeNotifier {
  ThemeController({SettingsService? settingsService})
    : _settingsService = settingsService;

  static const tasksPrefsKey = 'tasks_module_ui_theme_v1';

  final SettingsService? _settingsService;
  TasksUiTheme _uiTheme = TasksUiTheme.darkOrange;
  Future<void>? _restoreFuture;

  TasksUiTheme get uiTheme => _uiTheme;

  TasksUiPalette get palette => TasksUiPalette.of(_uiTheme);

  ThemeData get theme => palette.toThemeData();

  ThemeData get lightTheme => TasksUiPalette.of(
    _uiTheme.isOrange ? TasksUiTheme.lightOrange : TasksUiTheme.lightBlue,
  ).toThemeData();

  ThemeData get darkTheme => TasksUiPalette.of(
    _uiTheme.isOrange ? TasksUiTheme.darkOrange : TasksUiTheme.darkBlue,
  ).toThemeData();

  ThemeMode get themeMode => _uiTheme.isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> restore() {
    return _restoreFuture ??= _restoreImpl();
  }

  Future<void> _restoreImpl() async {
    try {
      final fromSettings = await _settingsService?.getUiTheme();
      if (fromSettings != null && fromSettings.isNotEmpty) {
        _setTheme(TasksUiTheme.fromStorage(fromSettings), persist: false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final fromTasks = prefs.getString(tasksPrefsKey);
      if (fromTasks != null && fromTasks.isNotEmpty) {
        _setTheme(TasksUiTheme.fromStorage(fromTasks), persist: true);
        return;
      }

      final legacy = await _settingsService?.getThemeMode();
      final migrated = switch (legacy) {
        'light' => TasksUiTheme.lightBlue,
        'dark' => TasksUiTheme.darkBlue,
        _ => TasksUiTheme.darkOrange,
      };
      _setTheme(migrated, persist: true);
    } catch (_) {
      // Keep the default dark-orange palette if storage is unavailable.
    }
    // Do not apply the themed app icon here. setAlternateIconName / Dock
    // icon swaps emit paused→resumed and would dismiss the launch video.
  }

  /// Match the home-screen / Dock icon to [uiTheme]. Call after the splash
  /// so icon-change lifecycle events cannot skip epic_start.
  Future<void> applyAppIcon() => AppIconController.apply(_uiTheme);

  Future<void> setUiTheme(TasksUiTheme theme) async {
    _setTheme(theme, persist: false);
    await _persist(theme);
    await AppIconController.apply(theme);
  }

  void _setTheme(TasksUiTheme theme, {required bool persist}) {
    final changed = _uiTheme != theme;
    _uiTheme = theme;
    if (changed) notifyListeners();
    if (persist) {
      _persist(theme);
    }
  }

  Future<void> _persist(TasksUiTheme theme) async {
    try {
      await _settingsService?.setUiTheme(theme.storageKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tasksPrefsKey, theme.storageKey);
    } catch (_) {
      // Persistence is best-effort; the in-memory theme still applies.
    }
  }
}
