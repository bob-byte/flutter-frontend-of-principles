import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/models/recommended_habit.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RecommendedHabit.fromJson maps name and reason', () {
    final habit = RecommendedHabit.fromJson({
      'Name': 'Meditate when I wake up',
      'ReasonToFollow': 'Starts the day calmly',
    });

    expect(habit.name, 'Meditate when I wake up');
    expect(habit.reasonToFollow, 'Starts the day calmly');
  });

  test('recommendHabits posts context to /ai/recommend-habits', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'test-token',
    });

    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == ApiEndpoints.aiRecommendHabits) {
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

    final service = AiRecommendationService(apiClient);
    final habits = await service.recommendHabits(
      culture: 'uk',
      currentHabits: ['Journal'],
      goals: ['Be healthy'],
      mission: 'Grow',
      slogan: 'Stay honest',
      goal: 'Be healthy',
      gender: 0,
    );

    expect(habits, hasLength(1));
    expect(habits.single.name, 'Walk after lunch');
    expect(habits.single.reasonToFollow, 'Keeps energy stable');
    expect(requests, hasLength(1));
    expect(requests.single.path, ApiEndpoints.aiRecommendHabits);
    expect(requests.single.method, 'POST');
    expect(requests.single.data, {
      'culture': 'uk',
      'goal': 'Be healthy',
      'goals': ['Be healthy'],
      'currentHabits': ['Journal'],
      'mission': 'Grow',
      'mainSlogan': 'Stay honest',
      'gender': 0,
    });
  });

  test('recommendHabits throws ServerTechnicalWorkException on 404', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'test-token',
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
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
        },
      ),
    );

    final service = AiRecommendationService(apiClient);
    expect(
      () => service.recommendHabits(
        culture: 'en',
        currentHabits: const [],
        goals: const [],
      ),
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
