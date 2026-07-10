import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_store.dart';

class AuthService {
  AuthService(this._secureStore, this._apiClient);

  final SecureStore _secureStore;
  final ApiClient _apiClient;

  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;

    if (AppConfig.useLocalData) {
      await ensureGuestSession();
      return true;
    }

    try {
      final path = AppConfig.useSimpleAuth
          ? ApiEndpoints.simpleAuthorization
          : ApiEndpoints.authorization;

      final response = await _apiClient.post(
        path,
        data: {'email': email, 'password': password},
        authenticate: false,
      );

      final token = _extractToken(response.data);
      if (token == null || token.isEmpty) return false;

      await _secureStore.write(AppConfig.tokenStorageKey, token);
      return true;
    } on DioException {
      return false;
    }
  }

  String? _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      return (data['token'] ?? data['Token']) as String?;
    }
    return null;
  }

  Future<void> logout() =>
      _secureStore.delete(AppConfig.tokenStorageKey);

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
