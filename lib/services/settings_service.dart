import '../core/storage/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService(this._secureStore);

  final SecureStore _secureStore;

  Future<void> setThemeMode(String mode) => _secureStore.write('theme_mode', mode);
  Future<String?> getThemeMode() => _secureStore.read('theme_mode');

  Future<void> setUiTheme(String theme) => _secureStore.write('ui_theme', theme);
  Future<String?> getUiTheme() => _secureStore.read('ui_theme');

  Future<void> setLocaleOverride(String? localeCode) async {
    if (localeCode == null) {
      await _secureStore.delete('locale_override');
      return;
    }
    await _secureStore.write('locale_override', localeCode);
  }

  Future<String?> getLocaleOverride() => _secureStore.read('locale_override');

  static const lastSuccessfulSyncKey = 'last_successful_sync_at';
  static const lastFailedSyncKey = 'last_failed_sync_at';

  Future<void> setLastSuccessfulSyncAt(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(lastSuccessfulSyncKey);
    } else {
      await prefs.setString(lastSuccessfulSyncKey, value.toUtc().toIso8601String());
    }
  }

  Future<DateTime?> getLastSuccessfulSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastSuccessfulSyncKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setLastFailedSyncAt(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(lastFailedSyncKey);
    } else {
      await prefs.setString(lastFailedSyncKey, value.toUtc().toIso8601String());
    }
  }

  Future<DateTime?> getLastFailedSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastFailedSyncKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }
}
