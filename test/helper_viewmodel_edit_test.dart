import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/ai_chat_message.dart';
import 'package:principles_app/models/ai_conversation.dart';
import 'package:principles_app/services/ai_chat_service.dart';
import 'package:principles_app/services/ai_conversation_service.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late AiConversationService conversationService;
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

    conversationService = AiConversationService(apiClient: apiClient);
    vm = HelperViewModel(AiChatService(apiClient), conversationService);
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  Future<void> waitUntilIdle() async {
    while (vm.isBusy) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> seedConversation() async {
    final now = DateTime.utc(2026, 9, 23, 12);
    await conversationService.saveConversation(
      AiConversation(
        id: 'c-prev',
        title: 'Previous chat',
        createdAt: now,
        updatedAt: now,
        messages: [
          AiChatMessageModel(
            id: 'm1',
            conversationId: 'c-prev',
            role: 'user',
            content: 'Old question',
            sortOrder: 0,
            createdAt: now,
          ),
        ],
      ),
    );
  }

  test(
    'prepareEditUserMessage returns text and truncates later turns',
    () async {
      await vm.ask('First', fallbackAnswer: 'fallback', errorMessage: 'error');
      await waitUntilIdle();
      await vm.ask('Second', fallbackAnswer: 'fallback', errorMessage: 'error');
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
    },
  );

  test('editing a prompt keeps the old thread as a version', () async {
    await vm.ask('First', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();
    await vm.ask('Second', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();

    await vm.prepareEditUserMessage(0);
    await vm.ask('First v2', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();

    expect(vm.messages.map((m) => m.text), ['First v2', 'Answer']);
    expect(vm.versionOf(vm.messages[0]), (index: 2, count: 2));

    await vm.switchVersion(vm.messages[0], -1);
    expect(vm.messages.map((m) => m.text), [
      'First',
      'Answer',
      'Second',
      'Answer',
    ]);
    expect(vm.versionOf(vm.messages[0]), (index: 1, count: 2));
  });

  test('cancelEdit restores the hidden turns', () async {
    await vm.ask('First', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();

    await vm.prepareEditUserMessage(0);
    expect(vm.isEditing, isTrue);
    expect(vm.messages, isEmpty);

    vm.cancelEdit();
    expect(vm.isEditing, isFalse);
    expect(vm.messages.map((m) => m.text), ['First', 'Answer']);
  });

  test('retry adds a reply version and keeps the previous one', () async {
    await vm.ask('Hello', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();
    final first = vm.messages[1];

    await vm.retryAnswer(first, fallbackAnswer: 'fallback', errorMessage: 'e');
    await waitUntilIdle();

    expect(vm.messages, hasLength(2));
    expect(identical(vm.messages[1], first), isFalse);
    expect(vm.versionOf(vm.messages[1]), (index: 2, count: 2));

    final body = requests.last.data as Map;
    expect((body['messages'] as List).cast<Map>(), [
      {'role': 'user', 'content': 'Hello'},
    ]);

    await vm.switchVersion(vm.messages[1], -1);
    expect(identical(vm.messages[1], first), isTrue);
  });

  test('versions survive reopening the chat', () async {
    await vm.ask('First', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();
    await vm.prepareEditUserMessage(0);
    await vm.ask('First v2', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();
    final id = vm.activeConversationId!;

    vm.startNewChat();
    await vm.openConversation(id);

    expect(vm.messages.first.text, 'First v2');
    expect(vm.versionOf(vm.messages.first), (index: 2, count: 2));

    final synced = await conversationService.getConversation(id);
    expect(synced!.messages.map((m) => m.content), ['First v2', 'Answer']);
  });

  test('prepareEditUserMessage rejects non-user indices', () async {
    await vm.ask('Hello', fallbackAnswer: 'fallback', errorMessage: 'error');
    await waitUntilIdle();
    expect(await vm.prepareEditUserMessage(1), isNull);
    expect(vm.messages, hasLength(2));
  });

  test('refreshIfLoaded is a no-op before first Chat open', () async {
    expect(vm.isLoaded, isFalse);
    await vm.refreshIfLoaded();
    expect(vm.conversations, isEmpty);
    expect(vm.isLoaded, isFalse);
  });

  test('load keeps a new chat instead of opening the latest', () async {
    await seedConversation();

    await vm.load();

    expect(vm.isLoaded, isTrue);
    expect(vm.conversations.any((c) => c.id == 'c-prev'), isTrue);
    expect(vm.activeConversationId, isNull);
    expect(vm.messages, isEmpty);
  });

  test('load keeps an already opened chat across reloads', () async {
    await seedConversation();
    await vm.openConversation('c-prev');
    expect(vm.activeConversationId, 'c-prev');
    expect(vm.messages, isNotEmpty);

    await vm.load();

    expect(vm.activeConversationId, 'c-prev');
    expect(vm.messages, isNotEmpty);
    expect(vm.messages.first.text, 'Old question');
  });
}
