import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';

class ApiClient {
  ApiClient(this._secureStore)
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['authenticate'] != false) {
            final token = await _secureStore.read(AppConfig.tokenStorageKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final SecureStore _secureStore;
  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticate = true,
  }) =>
      _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {'authenticate': authenticate}),
      );

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    bool authenticate = true,
  }) =>
      _dio.post(
        path,
        data: data,
        options: Options(
          extra: {'authenticate': authenticate},
          headers: {'Content-Type': 'application/json'},
        ),
      );

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    bool authenticate = true,
  }) =>
      _dio.put(
        path,
        data: data,
        options: Options(
          extra: {'authenticate': authenticate},
          headers: {'Content-Type': 'application/json'},
        ),
      );

  Future<Response<dynamic>> delete(
    String path, {
    bool authenticate = true,
  }) =>
      _dio.delete(
        path,
        options: Options(extra: {'authenticate': authenticate}),
      );
}
