import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_store.dart';

/// OpenAI key: локальний `kAiApiKey` → кеш → бекенд `/account/apikey`.
class OpenAiApiKeyService {
  OpenAiApiKeyService({
    required ApiClient apiClient,
    required SecureStore secureStore,
  })  : _apiClient = apiClient,
        _secureStore = secureStore;

  static const _cacheKey = 'openai_api_key';

  final ApiClient _apiClient;
  final SecureStore _secureStore;

  Future<String> resolveApiKey() async {
    final fromConfig = AppConfig.openAiApiKey.trim();
    if (fromConfig.isNotEmpty) return fromConfig;

    final cached = await _secureStore.read(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    // У чисто локальному режимі бекенду немає — ключ має бути в ai_api_key.dart.
    if (AppConfig.useLocalData) {
      throw StateError(
        'OpenAI API key is missing. '
        'Put it into lib/core/config/ai_api_key.dart (kAiApiKey) '
        'or run with DATA_SOURCE=api and backend AiApiKey.',
      );
    }

    final response = await _apiClient.get(ApiEndpoints.apiKey);
    final value = (response.data as Map?)?['value'] ??
        (response.data as Map?)?['Value'];
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Backend returned empty OpenAI API key.');
    }

    final plain = _decrypt(value.trim());
    if (plain.isEmpty) {
      throw StateError('Failed to decrypt OpenAI API key.');
    }

    await _secureStore.write(_cacheKey, plain);
    return plain;
  }

  String _decrypt(String cipherText) {
    final first = AppConfig.aiApiKeyEncryptionFirstKey;
    final second = AppConfig.aiApiKeyEncryptionSecondKey;
    if (first.isEmpty || second.isEmpty) {
      throw StateError('AI API encryption keys are missing.');
    }

    try {
      final key = Key.fromUtf8(first);
      final iv = IV.fromUtf8(second);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      return encrypter.decrypt64(cipherText, iv: iv).trim();
    } catch (e) {
      debugPrint('OpenAI API key decrypt failed: $e');
      rethrow;
    }
  }
}
