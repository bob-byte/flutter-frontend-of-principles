import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = UserService(forceLocalOnly: true);
  });

  test('saveLocalUser and loadLocalUser round-trip', () async {
    await service.saveLocalUser(
      User(
        name: 'Ada',
        email: 'ada@example.com',
        mainSlogan: 'Keep going',
        mission: 'Build',
        lastModified: DateTime.utc(2026, 1, 2),
      ),
    );

    final loaded = await service.loadLocalUser();
    expect(loaded?.name, 'Ada');
    expect(loaded?.email, 'ada@example.com');
    expect(loaded?.mainSlogan, 'Keep going');
    expect(loaded?.mission, 'Build');
    expect(loaded?.lastModified, DateTime.utc(2026, 1, 2));
  });

  test('clearLocal removes cached profile', () async {
    await service.saveLocalUser(User(name: 'Ada'));
    await service.clearLocal();
    expect(await service.loadLocalUser(), isNull);
  });

  test('fillMissingFromRemote keeps local edits and fills blank email', () {
    final merged = UserService.fillMissingFromRemote(
      User(
        name: 'Local',
        hasSeenRoadGuide: true,
        lastModified: DateTime.utc(2026, 2, 1),
      ),
      User(
        id: 3,
        name: 'Remote',
        email: 'ada@example.com',
        gender: 1,
        lastModified: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(merged.name, 'Local');
    expect(merged.email, 'ada@example.com');
    expect(merged.id, 3);
    expect(merged.gender, 1);
    expect(merged.hasSeenRoadGuide, isTrue);
    expect(merged.lastModified, DateTime.utc(2026, 2, 1));
  });

  test('getCurrentUser fetches profile when local email is blank', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'test-token',
    });
    SharedPreferences.setMockInitialValues({
      UserService.prefsKey: jsonEncode(
        User(
          hasSeenRoadGuide: true,
          lastModified: DateTime.utc(2026, 3, 2),
        ).toJson(),
      ),
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.profile) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 9,
                  'name': 'Ada',
                  'email': 'ada@example.com',
                  'gender': 1,
                  'hasSeenRoadGuide': false,
                },
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Unexpected path ${options.path}',
            ),
          );
        },
      ),
    );

    final remoteService = UserService(
      apiClient: ApiClient(SecureStore(), dio: dio),
    );
    final user = await remoteService.getCurrentUser();

    expect(user.email, 'ada@example.com');
    expect(user.name, 'Ada');
    expect(user.id, 9);
    expect(user.hasSeenRoadGuide, isTrue);
    expect((await remoteService.loadLocalUser())?.email, 'ada@example.com');
  });
}
