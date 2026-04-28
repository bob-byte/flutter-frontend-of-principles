import '../core/storage/secure_store.dart';

class SettingsService {
  SettingsService(this._secureStore);

  final SecureStore _secureStore;

  Future<void> setThemeMode(String mode) => _secureStore.write('theme_mode', mode);
  Future<String?> getThemeMode() => _secureStore.read('theme_mode');
}
