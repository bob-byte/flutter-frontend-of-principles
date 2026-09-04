import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/config/app_config.dart';
import '../core/helpers/password_changer.dart';
import '../core/storage/secure_store.dart';

class AuthService {
  static const _customLocalApiUrl = String.fromEnvironment('LOCAL_API_URL');

  // Account endpoints append `/api`, while AppConfig.apiBaseUrl already
  // includes it for the shared ApiClient.
  static String get baseUrl {
    if (_customLocalApiUrl.isNotEmpty) {
      return _withoutApiSuffix(_customLocalApiUrl);
    }
    return _withoutApiSuffix(AppConfig.apiBaseUrl);
  }

  static String _withoutApiSuffix(String value) {
    final trimmed = value.replaceFirst(RegExp(r'/+$'), '');
    return trimmed.endsWith('/api')
        ? trimmed.substring(0, trimmed.length - 4)
        : trimmed;
  }

  AuthService(this._secureStore, {Dio? dio}) : _dioOverride = dio;

  final SecureStore _secureStore;
  final Dio? _dioOverride;

  String get _tokenKey => AppConfig.tokenStorageKey;

  Dio createDio([BaseOptions? options]) {
    final override = _dioOverride;
    if (override != null) return override;

    final dio = Dio(options);
    if (AppConfig.allowBadCertificates && !kIsWeb) {
      final allowedHost = Uri.parse(baseUrl).host;
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) =>
              host == allowedHost;
          return client;
        },
      );
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await logout();
          }
          handler.next(error);
        },
      ),
    );
    return dio;
  }

  Future<void> _storeSessionToken(String token) async {
    await _secureStore.write(_tokenKey, token);
    if (!AppConfig.isLocal) {
      await _secureStore.write(AppConfig.productionAuthTokenKey, token);
    }
  }

  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;

    if (AppConfig.useLocalData) {
      await ensureGuestSession();
      return true;
    }

    try {
      final encryptedPassword = PasswordChanger.encryptNewPassword(password);
      final dio = createDio();
      final response = await dio.post(
        '${baseUrl}/api/account/authorization',
        data: {'email': email, 'password': encryptedPassword},
      );

      final appToken = response.data['token'] ?? response.data['Token'];
      if (appToken != null) {
        await _storeSessionToken(appToken.toString());
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Login Dio Error: ${e.response?.data}');
      if (e.response?.data is String) {
        throw Exception(e.response!.data);
      }
      return false;
    } catch (e) {
      debugPrint('Login Error: $e');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required int gender,
    String? mission,
    String? slogan,
  }) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) return false;

    try {
      final encryptedPassword = PasswordChanger.encryptNewPassword(password);
      final dio = createDio();
      final response = await dio.post(
        '${baseUrl}/api/account/authentication',
        data: {
          'name': name,
          'email': email,
          'password': encryptedPassword,
          'gender': gender,
          if (mission != null && mission.isNotEmpty) 'mission': mission,
          if (slogan != null && slogan.isNotEmpty) 'mainSlogan': slogan,
        },
      );

      // Backend returns 200 OK with an empty body on successful signup.
      // So we immediately call login() to get the token.
      if (response.statusCode == 200 || response.statusCode == 201) {
        return await login(email, password);
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Registration Dio Error: ${e.response?.data}');
      if (e.response?.data is String) {
        throw Exception(e.response!.data);
      }
      return false;
    } catch (e) {
      debugPrint('Registration Error: $e');
      return false;
    }
  }

  Future<int?> generateCode(String email) async {
    try {
      final dio = createDio();
      final response = await dio.get(
        '${baseUrl}/api/account/code',
        queryParameters: {'emailWhereSendCode': email},
      );
      if (response.statusCode == 200) {
        return response.data['code'] ?? response.data['Code'];
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Generate Code Dio Error: ${e.response?.data}');
      if (e.response?.data is String) {
        throw Exception(e.response!.data);
      }
      return null;
    } catch (e) {
      debugPrint('Generate Code Error: $e');
      return null;
    }
  }

  Future<bool> changePassword(String email, String newPassword) async {
    try {
      final encryptedPassword = PasswordChanger.encryptNewPassword(newPassword);
      final dio = createDio();
      final response = await dio.put(
        '${baseUrl}/api/account/password',
        data: {'email': email, 'newPassword': encryptedPassword},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Change Password Dio Error: ${e.response?.data}');
      if (e.response?.data is String) {
        throw Exception(e.response!.data);
      }
      return false;
    } catch (e) {
      debugPrint('Change Password Error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _secureStore.delete(_tokenKey);
    await _secureStore.delete(AppConfig.productionAuthTokenKey);
    await _secureStore.delete('openai_api_key_from_server_v1');
  }

  /// Guest session so the frontend can run without a backend.
  Future<void> ensureGuestSession() async {
    if (!AppConfig.useLocalData) return;
    final token = await getToken();
    if (token == null || token.isEmpty) {
      await _secureStore.write(
        AppConfig.tokenStorageKey,
        AppConfig.offlineToken,
      );
    }
  }

  Future<String?> getToken() => _secureStore.read(_tokenKey);

  /// Local token only — no network. Used so cold start can open the app
  /// without waiting on a 30s API timeout.
  Future<bool> hasLocalSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    if (AppConfig.useLocalData) {
      return token == AppConfig.offlineToken;
    }
    return _isActiveJwt(token);
  }

  Future<bool> hasValidSession() async {
    if (!await hasLocalSession()) {
      final token = await getToken();
      if (token != null && token.isNotEmpty && !AppConfig.useLocalData) {
        await logout();
      }
      return false;
    }

    if (AppConfig.useLocalData) return true;

    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response =
          await createDio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ).get(
            '$baseUrl/api/profile',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        await logout();
        return false;
      }

      // Keep a locally valid session during temporary network outages.
      debugPrint('Session validation unavailable: ${e.message}');
      return true;
    }
  }

  bool _isActiveJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return false;

      final expiresAt = _numericDate(payload['exp']);
      if (expiresAt == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final notBefore = _numericDate(payload['nbf']);
      return expiresAt > now && (notBefore == null || notBefore <= now);
    } catch (_) {
      return false;
    }
  }

  int? _numericDate(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Android / iOS OAuth client IDs must stay in sync with backend
  /// `Google:AndroidClientId` / `Google:iOSClientId` (ID-token audience).
  static const googleAndroidClientId =
      '40949920786-030cht7nm5a2q2hi4jgm7leldfcc6miu.apps.googleusercontent.com';
  static const googleIosClientId =
      '40949920786-ufvoeeof4s82011n4got9udapd6pm35e.apps.googleusercontent.com';

  /// Package-name scheme used by the Android installed-app OAuth flow.
  static const googleAndroidCallbackScheme = 'com.set.principles';

  /// Reversed iOS client ID — the only redirect Google accepts for iOS clients.
  static const googleIosCallbackScheme =
      'com.googleusercontent.apps.40949920786-ufvoeeof4s82011n4got9udapd6pm35e';

  static const googleOAuthScopes =
      'openid profile email https://www.googleapis.com/auth/user.gender.read';

  @visibleForTesting
  static bool get isAppleGoogleOAuthPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @visibleForTesting
  static String googleCallbackScheme({required bool isApplePlatform}) =>
      isApplePlatform ? googleIosCallbackScheme : googleAndroidCallbackScheme;

  @visibleForTesting
  static String googleRedirectUri({required bool isApplePlatform}) =>
      '${googleCallbackScheme(isApplePlatform: isApplePlatform)}:/oauth2redirect';

  /// Builds the Google authorization URL.
  ///
  /// `service`, `o2v`, `ddm`, and `flowName` match the MAUI client and force
  /// Google's classic HTML OAuth flow. Without them, Google serves the GIS
  /// account picker ("Sign in with Google" / "Choose an account to continue
  /// to Principles"), which crashes in ASWebAuthenticationSession on the iOS
  /// Simulator with "Something went wrong".
  @visibleForTesting
  static Uri googleAuthorizationUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    required String nonce,
  }) {
    return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': googleOAuthScopes,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'state': state,
      'nonce': nonce,
      'service': 'lso',
      'o2v': '2',
      'ddm': '0',
      'flowName': 'GeneralOAuthFlow',
    });
  }

  static bool isExternalAuthCanceled(Object error) {
    if (error is PlatformException && error.code.toUpperCase() == 'CANCELED') {
      return true;
    }
    if (error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled) {
      return true;
    }
    return false;
  }

  static String _randomUrlSafeBytes(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<bool> googleAuthorize() async {
    try {
      final isApplePlatform = isAppleGoogleOAuthPlatform;
      final clientId = isApplePlatform
          ? googleIosClientId
          : googleAndroidClientId;
      final callbackScheme = googleCallbackScheme(
        isApplePlatform: isApplePlatform,
      );
      final redirectUri = googleRedirectUri(isApplePlatform: isApplePlatform);

      final codeVerifier = _randomUrlSafeBytes(32);
      final codeChallenge = base64UrlEncode(
        sha256.convert(ascii.encode(codeVerifier)).bytes,
      ).replaceAll('=', '');
      final state = _randomUrlSafeBytes(16);
      final nonce = _randomUrlSafeBytes(16);

      final authUrl = googleAuthorizationUrl(
        clientId: clientId,
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
        state: state,
        nonce: nonce,
      );

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: callbackScheme,
        options: FlutterWebAuth2Options(
          // GIS/FedCM account listing crashes in the iOS Simulator when it
          // tries to reuse Safari cookies. An ephemeral session skips that
          // picker and shows the classic sign-in form instead.
          preferEphemeral: isApplePlatform,
        ),
      );

      final resultUri = Uri.parse(result);
      final code = resultUri.queryParameters['code'];
      final error = resultUri.queryParameters['error'];
      final returnedState = resultUri.queryParameters['state'];

      if (error == 'access_denied') return false;
      if (error != null || code == null) {
        throw Exception(
          'Code generated by Google to get tokens is null or error occurred: $error',
        );
      }
      if (returnedState != state) {
        throw Exception('Google OAuth state mismatch.');
      }

      final dio = createDio();
      final tokenResponse = await dio.post(
        'https://oauth2.googleapis.com/token',
        data: {
          'code': code,
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final accessToken = tokenResponse.data['access_token'];
      final idToken = tokenResponse.data['id_token'];

      if (accessToken == null || idToken == null) return false;

      final backendUrl = '${baseUrl}/api/account/googleauthorization';
      final backendResponse = await dio.post(
        backendUrl,
        data: {'AccessToken': accessToken, 'IdToken': idToken},
      );

      final appToken =
          backendResponse.data['token'] ?? backendResponse.data['Token'];
      if (appToken == null) return false;

      await _storeSessionToken(appToken.toString());
      return true;
    } on PlatformException catch (e) {
      if (isExternalAuthCanceled(e)) {
        debugPrint('Google Auth canceled by user.');
        return false;
      }
      debugPrint('Google Auth Error: $e');
      rethrow;
    } catch (e) {
      debugPrint('Google Auth Error: $e');
      rethrow;
    }
  }

  Future<bool> appleAuthorize() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('AppleAuthUnavailableOnDevice');
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple ID token is null or empty.');
      }

      // Send IdToken to our backend
      final backendUrl = '${baseUrl}/api/account/appleauthorization';
      final dio = createDio();
      final backendResponse = await dio.post(
        backendUrl,
        data: {'IdToken': idToken},
      );

      final appToken =
          backendResponse.data['token'] ?? backendResponse.data['Token'];
      if (appToken == null) return false;

      await _storeSessionToken(appToken.toString());
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('Apple Auth canceled by user (code 1001 equivalent).');
        return false;
      }
      debugPrint('Apple Auth Exception: $e');
      rethrow;
    } catch (e) {
      debugPrint('Apple Auth Error: $e');
      rethrow;
    }
  }
}
