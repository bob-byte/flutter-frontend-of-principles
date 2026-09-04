import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';

class ApiClient {
  ApiClient(this._secureStore, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    if (dio == null && AppConfig.allowBadCertificates) {
      final allowedHost = Uri.parse(AppConfig.apiBaseUrl).host;
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) =>
              host == allowedHost;
          return client;
        },
      );
    }

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
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['authenticate'] != false) {
            await _secureStore.delete(AppConfig.tokenStorageKey);
            await _secureStore.delete(AppConfig.productionAuthTokenKey);
          }
          handler.next(error);
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
  }) => _dio.get(
    path,
    queryParameters: queryParameters,
    options: Options(extra: {'authenticate': authenticate}),
  );

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    bool authenticate = true,
    Duration? receiveTimeout,
  }) => _dio.post(
    path,
    data: data,
    options: Options(
      extra: {'authenticate': authenticate},
      headers: {'Content-Type': 'application/json'},
      receiveTimeout: receiveTimeout,
    ),
  );

  Future<Response<ResponseBody>> postStream(
    String path, {
    Object? data,
    bool authenticate = true,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) => _dio.post<ResponseBody>(
    path,
    data: data,
    cancelToken: cancelToken,
    options: Options(
      extra: {'authenticate': authenticate},
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      responseType: ResponseType.stream,
      receiveTimeout: receiveTimeout,
    ),
  );

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    bool authenticate = true,
  }) => _dio.put(
    path,
    data: data,
    options: Options(
      extra: {'authenticate': authenticate},
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<Response<dynamic>> delete(String path, {bool authenticate = true}) =>
      _dio.delete(
        path,
        options: Options(extra: {'authenticate': authenticate}),
      );
}
