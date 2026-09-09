import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/ai_chat_service.dart';
import 'package:principles_app/services/ai_conversation_service.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late HelperViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = true;
    FlutterSecureStorage.setMockInitialValues({
      AppConfig.tokenStorageKey: 'test-token',
    });
    requests = [];

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == ApiEndpoints.aiChat) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody.fromString(
                  'data: {"content":"Answer"}\n\n'
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
    );
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  Future<void> waitUntilIdle() async {
    while (vm.isBusy) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('prepareEditUserMessage returns text and truncates later turns', () async {
    await vm.ask(
      'First',
      fallbackAnswer: 'fallback',
      errorMessage: 'error',
    );
    await waitUntilIdle();
    await vm.ask(
      'Second',
      fallbackAnswer: 'fallback',
      errorMessage: 'error',
    );
    await waitUntilIdle();

    expect(vm.messages, hasLength(4));
    expect(vm.messages[0].text, 'First');
    expect(vm.messages[2].text, 'Second');

    final edited = await vm.prepareEditUserMessage(2);
    expect(edited, 'Second');
    expect(vm.messages, hasLength(2));
    expect(vm.messages[0].text, 'First');
    expect(vm.messages[1].isUser, isFalse);

    await vm.ask(
      'Second revised',
      fallbackAnswer: 'fallback',
      errorMessage: 'error',
    );
    await waitUntilIdle();

    final body = requests.last.data as Map;
    final messages = (body['messages'] as List).cast<Map>();
    expect(messages, [
      {'role': 'user', 'content': 'First'},
      {'role': 'assistant', 'content': 'Answer'},
      {'role': 'user', 'content': 'Second revised'},
    ]);
  });

  test('prepareEditUserMessage rejects non-user indices', () async {
    await vm.ask(
      'Hello',
      fallbackAnswer: 'fallback',
      errorMessage: 'error',
    );
    await waitUntilIdle();
    expect(await vm.prepareEditUserMessage(1), isNull);
    expect(vm.messages, hasLength(2));
  });
}
