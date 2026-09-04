import 'dart:io';

import 'package:flutter/foundation.dart';

/// Конфігурація API (аналог `LOCALDEBUG` у MAUI).
///
/// **З продакшн-бекендом (за замовчуванням):**
/// `flutter run` — REST + JWT на `principles-server`.
/// AI (helper chat, parse-task) іде через бекенд `/ai/*`; ключ OpenAI лишається на сервері.
///
/// **Локальний бекенд:**
/// `flutter run --dart-define=API_ENV=local` або `--dart-define=LOCALDEBUG=true`
/// + `dotnet run --project SET.WebAPI --launch-profile https`
///
/// **Без бекенду:**
/// `flutter run --dart-define=DATA_SOURCE=local`
class AppConfig {
  AppConfig._();

  /// `local` — SQLite / SharedPreferences, offline-логін.
  /// `api` — REST + JWT.
  static const dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: 'api',
  );

  static const apiEnv = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'production',
  );

  static const _localDebug = bool.fromEnvironment('LOCALDEBUG');

  /// Test-only override for [useLocalData]. Cleared between tests.
  @visibleForTesting
  static bool? debugUseLocalDataOverride;

  static bool get useLocalData =>
      debugUseLocalDataOverride ?? dataSource == 'local';

  static bool get isLocal => _localDebug || apiEnv == 'local';

  static String get apiBaseUrl {
    if (isLocal) {
      const configured = String.fromEnvironment('API_BASE_URL');
      if (configured.isNotEmpty) return configured;
      if (!kIsWeb && Platform.isAndroid) {
        return 'https://10.0.2.2:6001/api';
      }
      return 'https://localhost:6001/api';
    }
    return productionApiBaseUrl;
  }

  static const productionApiBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: 'https://principles-server.ckwavh.easypanel.host/api',
  );

  static bool get useSimpleAuth => isLocal;

  static String get tokenStorageKey => useLocalData
      ? 'offline_access_token'
      : (isLocal ? 'local_access_token' : 'auth_access_token');

  static const offlineToken = 'offline_demo_token';

  static bool get allowBadCertificates => isLocal && !kIsWeb;

  /// MAUI production `EncryptionSettings` — шифрування пароля для `/authorization`.
  static const passwordEncryptionFirstKey = 'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  static const passwordEncryptionSecondKey = 'M%m5Vy9R(_k74t^M';

  static const productionAuthTokenKey = 'auth_access_token';
}
