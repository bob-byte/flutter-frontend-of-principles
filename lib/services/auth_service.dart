import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/security/password_encryptor.dart';
import '../core/storage/secure_store.dart';

class AuthService {
  AuthService(this._secureStore, this._apiClient);

  final SecureStore _secureStore;
  final ApiClient _apiClient;

  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;

    // Завжди пробуємо взяти прод-токен — він потрібен для AI-ключа з сервера.
    await _tryStoreProductionToken(email, password);

    if (AppConfig.useLocalData) {
      await ensureGuestSession();
      return true;
    }

    try {
      final path = AppConfig.useSimpleAuth
          ? ApiEndpoints.simpleAuthorization
          : ApiEndpoints.authorization;

      final payloadPassword = AppConfig.useSimpleAuth
          ? password
          : PasswordEncryptor.encryptPassword(
              password,
              AppConfig.passwordEncryptionFirstKey,
              AppConfig.passwordEncryptionSecondKey,
            );

      final response = await _apiClient.post(
        path,
        data: {'email': email, 'password': payloadPassword},
        authenticate: false,
      );

      final token = _extractToken(response.data);
      if (token == null || token.isEmpty) return false;

      await _secureStore.write(AppConfig.tokenStorageKey, token);
      if (!AppConfig.isLocal) {
        await _secureStore.write(AppConfig.productionAuthTokenKey, token);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  /// Логін на прод для `/account/apikey` (навіть якщо завдання локальні).
  Future<void> _tryStoreProductionToken(String email, String password) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.productionApiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      final encrypted = PasswordEncryptor.encryptPassword(
        password,
        AppConfig.passwordEncryptionFirstKey,
        AppConfig.passwordEncryptionSecondKey,
      );
      final response = await dio.post<dynamic>(
        ApiEndpoints.authorization,
        data: {'email': email, 'password': encrypted},
      );
      final token = _extractToken(response.data);
      if (token != null && token.isNotEmpty) {
        await _secureStore.write(AppConfig.productionAuthTokenKey, token);
        // Скидаємо кеш AI-ключа, щоб підтягнути свіжий із сервера.
        await _secureStore.delete('openai_api_key_from_server_v1');
      }
    } catch (e) {
      debugPrint('Production auth for AI key skipped: $e');
    }
  }

  String? _extractToken(dynamic data) {
    if (data is Map) {
      return (data['token'] ?? data['Token'])?.toString();
    }
    return null;
  }

  Future<void> logout() async {
    await _secureStore.delete(AppConfig.tokenStorageKey);
    await _secureStore.delete(AppConfig.productionAuthTokenKey);
    await _secureStore.delete('openai_api_key_from_server_v1');
  }

  /// Гостьова сесія для запуску лише фронту без бекенду.
  Future<void> ensureGuestSession() async {
    if (!AppConfig.useLocalData) return;
    final token = await getToken();
    if (token == null || token.isEmpty) {
      await _secureStore.write(AppConfig.tokenStorageKey, AppConfig.offlineToken);
    }
  }

  Future<String?> getToken() =>
      _secureStore.read(AppConfig.tokenStorageKey);
}
