import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_store.dart';

/// OpenAI key з продакшн-сервера `/account/apikey` (як MAUI).
class OpenAiApiKeyService {
  OpenAiApiKeyService({
    required SecureStore secureStore,
    Dio? dio,
  })  : _secureStore = secureStore,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.aiKeyApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: const {'Accept': 'application/json'},
              ),
            );

  static const _cacheKey = 'openai_api_key_from_server_v1';

  final SecureStore _secureStore;
  final Dio _dio;

  Future<String> resolveApiKey() async {
    // Явний override лише через --dart-define=OPENAI_API_KEY=...
    final fromEnv = AppConfig.openAiApiKey.trim();
    if (fromEnv.isNotEmpty) return fromEnv;

    final cached = await _secureStore.read(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    final plain = await _fetchAndDecryptFromServer();
    await _secureStore.write(_cacheKey, plain);
    return plain;
  }

  Future<String> _fetchAndDecryptFromServer() async {
    final token = await _bestAuthToken();
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.apiKey,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError(
          'Немає доступу до AI-ключа на сервері. '
          'Увійдіть під акаунтом (DATA_SOURCE=api, API_ENV=production) '
          'або переконайтесь, що /account/apikey доступний.',
        );
      }

      if (response.statusCode != 200) {
        throw StateError(
          'Сервер не віддав AI-ключ (HTTP ${response.statusCode}).',
        );
      }

      final value = (response.data as Map?)?['value'] ??
          (response.data as Map?)?['Value'];
      if (value is! String || value.trim().isEmpty) {
        throw StateError('Сервер повернув порожній AI-ключ.');
      }

      final plain = _decrypt(value.trim());
      if (plain.isEmpty) {
        throw StateError('Не вдалося розшифрувати AI-ключ із сервера.');
      }
      return plain;
    } on DioException catch (e) {
      debugPrint('AI key fetch failed: $e');
      throw StateError(
        'Не вдалося отримати AI-ключ із сервера. Перевірте інтернет.',
      );
    }
  }

  Future<String?> _bestAuthToken() async {
    const keys = [
      'auth_access_token',
      'local_access_token',
      'offline_access_token',
    ];
    for (final key in keys) {
      final token = await _secureStore.read(key);
      if (token == null || token.trim().isEmpty) continue;
      if (token == AppConfig.offlineToken) continue;
      return token.trim();
    }
    return null;
  }

  String _decrypt(String cipherText) {
    final pairs = <({String first, String second})>[
      (
        first: AppConfig.aiApiKeyEncryptionFirstKey,
        second: AppConfig.aiApiKeyEncryptionSecondKey,
      ),
      (
        first: AppConfig.aiApiKeyEncryptionFirstKeyDev,
        second: AppConfig.aiApiKeyEncryptionSecondKeyDev,
      ),
    ];

    Object? lastError;
    for (final pair in pairs) {
      try {
        final key = encrypt.Key.fromUtf8(pair.first);
        final iv = encrypt.IV.fromUtf8(pair.second);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plain = encrypter.decrypt64(cipherText, iv: iv).trim();
        if (plain.isNotEmpty) return plain;
      } catch (e) {
        lastError = e;
      }
    }

    debugPrint('OpenAI API key decrypt failed: $lastError');
    throw StateError('Не вдалося розшифрувати AI-ключ із сервера.');
  }
}
