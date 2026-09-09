import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/sync_reachability_service.dart';
import 'package:principles_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.debugUseLocalDataOverride = false;
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'token',
    });
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  test('ping 404 throws ServerTechnicalWorkException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, ApiEndpoints.syncPing);
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final reachability = SyncReachabilityService(
      apiClient: ApiClient(SecureStore(), dio: dio),
      authService: AuthService(SecureStore()),
    );

    expect(
      reachability.canReachBackend,
      throwsA(
        isA<ServerTechnicalWorkException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });
}
