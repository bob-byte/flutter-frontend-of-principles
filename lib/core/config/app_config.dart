import 'package:flutter/foundation.dart';

/// Конфігурація API (аналог `LOCALDEBUG` у MAUI).
///
/// **Без бекенду (за замовчуванням):**
/// `flutter run` — локальна БД, будь-який логін/пароль.
/// AI-ключ завжди з продакшн-сервера `/account/apikey`.
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

  static bool get useLocalData => dataSource == 'local';

  static bool get isLocal =>
      apiEnv == 'local' || (apiEnv.isEmpty && kDebugMode);

  static String get apiBaseUrl {
    if (isLocal) {
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://localhost:6001/api',
      );
    }
    return productionApiBaseUrl;
  }

  /// Прод-сервер — джерело OpenAI-ключа (як у MAUI).
  static const productionApiBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: 'https://principles-server.ckwavh.easypanel.host/api',
  );

  static String get aiKeyApiBaseUrl {
    const fromEnv = String.fromEnvironment('AI_KEY_API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Debug (зокрема Web): локальний AI-проксі з серверним ключем у AiApiKey.
    if (kDebugMode) return 'https://localhost:6001/api';
    return productionApiBaseUrl;
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
    defaultValue: 'gpt-5-mini',
  );

  /// Лише явний override. Інакше ключ з продакшн `/account/apikey`.
  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

  /// MAUI production `ApiKeyEncryptionSettings` — для ключа з прод-сервера.
  static const aiApiKeyEncryptionFirstKey = String.fromEnvironment(
    'AI_API_KEY_FIRST',
    defaultValue: '6)e8Ar%8;5dd38E+BDYYUU%2;yaa5-z_',
  );

  static const aiApiKeyEncryptionSecondKey = String.fromEnvironment(
    'AI_API_KEY_SECOND',
    defaultValue: '_+AfxHY&D*53b44c',
  );

  /// Fallback decrypt keys (local/dev backend).
  static const aiApiKeyEncryptionFirstKeyDev =
      '9&KG6L#~UCea+Z4T&Jx4d8n5gr&)+b29';
  static const aiApiKeyEncryptionSecondKeyDev = '2xf7YtC^_7D7+e*V';

  /// MAUI production `EncryptionSettings` — шифрування пароля для `/authorization`.
  static const passwordEncryptionFirstKey =
      'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  static const passwordEncryptionSecondKey = 'M%m5Vy9R(_k74t^M';

  static const productionAuthTokenKey = 'auth_access_token';
}
