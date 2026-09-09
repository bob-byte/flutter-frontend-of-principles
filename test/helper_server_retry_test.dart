import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/ai_chat_service.dart';
import 'package:principles_app/services/ai_conversation_service.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int chatCalls;
  late HelperViewModel vm;
  late int prompts;
  late bool retryNext;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = true;
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'test-token',
    });
    chatCalls = 0;
    prompts = 0;
    retryNext = false;

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.aiChat) {
            chatCalls += 1;
            if (chatCalls == 1) {
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
                data: ResponseBody.fromString(
                  'data: {"content":"Recovered"}\n\n'
                  'data: [DONE]\n\n',
                  200,
                  headers: {
                    Headers.contentTypeHeader: ['text/event-stream'],
                  },
                ),
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

    vm = HelperViewModel(
      AiChatService(apiClient),
      AiConversationService(apiClient: apiClient),
      serverRetry: ServerRequiredRetry(
        prompt: () async {
          prompts += 1;
          return retryNext;
        },
      ),
    );
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  Future<void> waitUntilIdle() async {
    for (var i = 0; i < 40; i++) {
      if (!vm.isBusy) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('404 shows retry; cancel leaves the generic chat error', () async {
    retryNext = false;
    await vm.ask('Hello', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();

    expect(prompts, 1);
    expect(chatCalls, 1);
    expect(vm.messages, hasLength(2));
    expect(vm.messages.last.isUser, isFalse);
    expect(vm.messages.last.text, 'error');
    expect(vm.messages.last.isComplete, isTrue);
    expect(vm.isBusy, isFalse);
  });

  test('404 retry repeats the server call and streams the answer', () async {
    retryNext = true;
    await vm.ask('Hello', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();

    expect(prompts, 1);
    expect(chatCalls, 2);
    expect(vm.messages.last.text, 'Recovered');
    expect(vm.messages.last.isComplete, isTrue);
    expect(vm.isBusy, isFalse);
  });
}
