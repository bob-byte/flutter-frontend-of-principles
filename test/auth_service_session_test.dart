import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

String _jwtWithExpiration(DateTime expiration) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({'exp': expiration.millisecondsSinceEpoch ~/ 1000}),
    'signature',
  ].join('.');
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int statusCode) {
  final dio = Dio();
  dio.httpClientAdapter = _StatusAdapter(statusCode);
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts a non-expired stored session', () async {
    final token = _jwtWithExpiration(
      DateTime.now().add(const Duration(hours: 1)),
    );
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: token,
    });
    final authService = AuthService(SecureStore(), dio: _dioReturning(200));

    expect(await authService.hasValidSession(), isTrue);
    expect(await authService.getToken(), token);
  });

  test('rejects and clears a session rejected by the backend', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: _jwtWithExpiration(
        DateTime.now().add(const Duration(hours: 1)),
      ),
    });
    final authService = AuthService(SecureStore(), dio: _dioReturning(401));

    expect(await authService.hasValidSession(), isFalse);
    expect(await authService.getToken(), isNull);
  });

  test('rejects and clears an expired stored session', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: _jwtWithExpiration(
        DateTime.now().subtract(const Duration(hours: 1)),
      ),
    });
    final authService = AuthService(SecureStore());

    expect(await authService.hasValidSession(), isFalse);
    expect(await authService.getToken(), isNull);
  });

  test('rejects and clears a malformed stored session', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'not-a-jwt',
    });
    final authService = AuthService(SecureStore());

    expect(await authService.hasValidSession(), isFalse);
    expect(await authService.getToken(), isNull);
  });

  test('uses ephemeral Google auth only on the iOS Simulator', () {
    expect(
      AuthService.preferEphemeralGoogleAuth(
        isApplePlatform: true,
        environment: const {'SIMULATOR_DEVICE_NAME': 'iPhone 16'},
      ),
      isTrue,
    );
    expect(
      AuthService.preferEphemeralGoogleAuth(
        isApplePlatform: true,
        environment: const {},
      ),
      isFalse,
    );
    expect(
      AuthService.preferEphemeralGoogleAuth(
        isApplePlatform: false,
        environment: const {'SIMULATOR_DEVICE_NAME': 'iPhone 16'},
      ),
      isFalse,
    );
  });

  test('uses the Android package-scheme redirect for Google OAuth', () {
    expect(
      AuthService.googleCallbackScheme(isApplePlatform: false),
      AuthService.googleAndroidCallbackScheme,
    );
    expect(
      AuthService.googleRedirectUri(isApplePlatform: false),
      'com.set.principles:/oauth2redirect',
    );
  });

  test('uses the reversed iOS client ID redirect for Google OAuth', () {
    expect(
      AuthService.googleCallbackScheme(isApplePlatform: true),
      AuthService.googleIosCallbackScheme,
    );
    expect(
      AuthService.googleRedirectUri(isApplePlatform: true),
      '${AuthService.googleIosCallbackScheme}:/oauth2redirect',
    );
  });

  test('Google authorization URL forces the classic OAuth HTML flow', () {
    final url = AuthService.googleAuthorizationUrl(
      clientId: AuthService.googleIosClientId,
      redirectUri: AuthService.googleRedirectUri(isApplePlatform: true),
      codeChallenge: 'challenge',
      state: 'state-token',
      nonce: 'nonce-token',
    );

    expect(url.scheme, 'https');
    expect(url.host, 'accounts.google.com');
    expect(url.path, '/o/oauth2/v2/auth');
    expect(url.queryParameters['client_id'], AuthService.googleIosClientId);
    expect(
      url.queryParameters['redirect_uri'],
      AuthService.googleRedirectUri(isApplePlatform: true),
    );
    expect(url.queryParameters['response_type'], 'code');
    expect(url.queryParameters['scope'], AuthService.googleOAuthScopes);
    expect(url.queryParameters['code_challenge'], 'challenge');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(url.queryParameters['access_type'], 'offline');
    expect(url.queryParameters['state'], 'state-token');
    expect(url.queryParameters['nonce'], 'nonce-token');
    expect(url.queryParameters['service'], 'lso');
    expect(url.queryParameters['o2v'], '2');
    expect(url.queryParameters['ddm'], '0');
    expect(url.queryParameters['flowName'], 'GeneralOAuthFlow');
  });

  test('treats Google and Apple user cancels as non-errors', () {
    expect(
      AuthService.isExternalAuthCanceled(PlatformException(code: 'CANCELED')),
      isTrue,
    );
    expect(
      AuthService.isExternalAuthCanceled(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        ),
      ),
      isTrue,
    );
    expect(
      AuthService.isExternalAuthCanceled(Exception('token exchange failed')),
      isFalse,
    );
  });
}
