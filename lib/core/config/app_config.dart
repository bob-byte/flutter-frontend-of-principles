import 'package:flutter/foundation.dart';

import 'ai_api_key.dart';

/// Конфігурація API (аналог `LOCALDEBUG` у MAUI).
///
/// **Без бекенду (за замовчуванням):**
/// `flutter run` — локальна БД, будь-який логін/пароль.
/// AI-ключ: `lib/core/config/ai_api_key.dart` (`kAiApiKey`).
///
/// **З бекендом:**
/// `flutter run --dart-define=DATA_SOURCE=api`
/// + `dotnet run --project SET.WebAPI --launch-profile http`
/// AI-ключ тоді з бекенду `AiApiKey` через `/account/apikey`.
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

  /// OpenAI model for chat + task assist (MAUI uses the same name).
  static const openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-5-nano',
  );

  /// OpenAI key: `--dart-define=OPENAI_API_KEY` або [kAiApiKey].
  static const openAiApiKey = kAiApiKey;

  /// AES keys to decrypt `/account/apikey` (MAUI `ApiKeyEncryptionSettings`).
  static String get aiApiKeyEncryptionFirstKey {
    const fromEnv = String.fromEnvironment('AI_API_KEY_FIRST');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Local backend / MAUI Development
    if (isLocal) return '9&KG6L#~UCea+Z4T&Jx4d8n5gr&)+b29';
    // Production MAUI appsettings.json
    return '6)e8Ar%8;5dd38E+BDYYUU%2;yaa5-z_';
  }

  static String get aiApiKeyEncryptionSecondKey {
    const fromEnv = String.fromEnvironment('AI_API_KEY_SECOND');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (isLocal) return '2xf7YtC^_7D7+e*V';
    return '_+AfxHY&D*53b44c';
  }
}
