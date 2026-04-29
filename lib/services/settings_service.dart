import '../core/storage/secure_store.dart';

class SettingsService {
  SettingsService(this._secureStore);

  final SecureStore _secureStore;

  Future<void> setThemeMode(String mode) => _secureStore.write('theme_mode', mode);
  Future<String?> getThemeMode() => _secureStore.read('theme_mode');

  Future<void> setLocaleOverride(String? localeCode) async {
    if (localeCode == null) {
      await _secureStore.delete('locale_override');
      return;
    }
    await _secureStore.write('locale_override', localeCode);
  }

  Future<String?> getLocaleOverride() => _secureStore.read('locale_override');
}
