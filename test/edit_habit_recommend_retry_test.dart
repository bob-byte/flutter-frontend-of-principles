import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/edit_habit_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditHabitViewModel vm;
  late DatabaseService db;
  late LocalDb localDb;
  late String dbPath;
  late int recommendCalls;
  late int prompts;
  late bool retryNext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final created = await createTestDatabaseService();
    db = created.db;
    localDb = created.localDb;
    dbPath = created.path;
    recommendCalls = 0;
    prompts = 0;
    retryNext = false;

    final auth = AuthService(
      _TokenStore(),
      dio: Dio()..httpClientAdapter = _Noop(),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path != ApiEndpoints.aiRecommendHabits) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Unexpected ${options.path}',
              ),
            );
            return;
          }
          recommendCalls += 1;
          if (recommendCalls == 1) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: 'Not Found',
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'habits': [
                  {
                    'name': 'Walk after lunch',
                    'reasonToFollow': 'Keeps energy stable',
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    vm = EditHabitViewModel(
      HabitService(auth),
      ReminderService(forceLocalOnly: true),
      GoalService(auth),
      AiRecommendationService(ApiClient(_TokenStore(), dio: dio)),
      UserService(forceLocalOnly: true),
      dbService: db,
      serverRetry: ServerRequiredRetry(
        prompt: () async {
          prompts += 1;
          return retryNext;
        },
      ),
    )..init(null);
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('recommendation 404 cancel sets the technical-work error', () async {
    retryNext = false;
    await vm.loadRecommendedHabits(culture: 'en');

    expect(prompts, 1);
    expect(recommendCalls, 1);
    expect(vm.recommendedHabits, isEmpty);
    expect(
      vm.recommendedHabitsError,
      'Technical work on our server is in progress. Please try again later.',
    );
    expect(vm.isRecommendedHabitsLoading, isFalse);
  });

  test('recommendation 404 retry loads habits', () async {
    retryNext = true;
    await vm.loadRecommendedHabits(culture: 'en');

    expect(prompts, 1);
    expect(recommendCalls, 2);
    expect(vm.recommendedHabits, hasLength(1));
    expect(vm.recommendedHabits.single.name, 'Walk after lunch');
    expect(vm.recommendedHabitsError, isNull);
  });
}

class _TokenStore extends SecureStore {
  @override
  Future<String?> read(String key) async => 'token';
}

class _Noop implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
