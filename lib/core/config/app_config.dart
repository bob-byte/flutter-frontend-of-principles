import 'package:flutter/foundation.dart';

/// Конфігурація API (аналог `LOCALDEBUG` у MAUI).
///
/// **Без бекенду (за замовчуванням):**
/// `flutter run` — локальна БД, будь-який логін/пароль.
///
/// **З бекендом:**
/// `flutter run --dart-define=DATA_SOURCE=api`
/// + `dotnet run --project SET.WebAPI --launch-profile http`
class AppConfig {
  AppConfig._();

  /// `local` — SQLite / SharedPreferences, offline-логін.
  /// `api` — REST + JWT.
  static const dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: 'local',
  );

  static const apiEnv = String.fromEnvironment('API_ENV', defaultValue: 'local');

  static bool get useLocalData => dataSource != 'api';

  static bool get isLocal =>
      apiEnv == 'local' || (apiEnv.isEmpty && kDebugMode);

  static String get apiBaseUrl {
    if (isLocal) {
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:6001/api',
      );
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://principles-server.ckwavh.easypanel.host/api',
    );
  }

  static bool get useSimpleAuth => isLocal;

  static String get tokenStorageKey => useLocalData
      ? 'offline_access_token'
      : (isLocal ? 'local_access_token' : 'auth_access_token');

  static const offlineToken = 'offline_demo_token';

  static bool get allowBadCertificates => isLocal && !kIsWeb;
}
