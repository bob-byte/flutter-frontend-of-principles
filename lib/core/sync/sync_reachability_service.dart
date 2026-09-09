import 'package:dio/dio.dart';

import '../../services/auth_service.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/server_required_retry.dart';
import 'sync_authentication_exception.dart';

class SyncReachabilityService {
  SyncReachabilityService({
    required ApiClient apiClient,
    required AuthService authService,
  }) : _apiClient = apiClient,
       _authService = authService;

  final ApiClient _apiClient;
  final AuthService _authService;

  Future<bool> canReachBackend() async {
    if (AppConfig.useLocalData) return false;
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _apiClient
          .get(ApiEndpoints.syncPing)
          .timeout(const Duration(seconds: 5));
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw SyncAuthenticationException();
      }
      return status >= 200 && status < 300;
    } on SyncAuthenticationException {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw SyncAuthenticationException();
      }
      if (isServerTechnicalWorkStatus(status)) {
        throw ServerTechnicalWorkException(statusCode: status);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
