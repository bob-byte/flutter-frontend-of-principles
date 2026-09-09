import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/task_priority.dart';
import 'package:principles_app/services/ai_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late AiChatService service;

  setUp(() {
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
                  'data: {"content":"Hello"}\n\n'
                  'data: {"content":" from backend"}\n\n'
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
          if (options.path == ApiEndpoints.aiParseTask) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'title': 'Buy groceries',
                  'description': 'Milk and bread',
                  'priority': 'high',
                  'theme': 'Health',
                  'dueDate': '2026-09-04',
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

    service = AiChatService(apiClient);
  });

  test(
    'streamAnswer posts conversation to /ai/chat and yields SSE chunks',
    () async {
      final chunks = await service
          .streamAnswer(
            messages: const [
              {'role': 'user', 'content': 'Hi'},
            ],
            fallbackResponse: 'fallback',
            errorMessage: 'error',
          )
          .toList();

      expect(chunks, ['Hello', ' from backend']);
      expect(requests, hasLength(1));
      expect(requests.single.path, ApiEndpoints.aiChat);
      expect(requests.single.method, 'POST');
      expect(requests.single.responseType, ResponseType.stream);
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      expect(requests.single.headers['Accept'], 'text/event-stream');

      final body = requests.single.data as Map;
      final messages = (body['messages'] as List).cast<Map>();
      expect(messages, [
        {'role': 'user', 'content': 'Hi'},
      ]);
    },
  );

  test('chunksFromResponse parses SSE token events', () async {
    final chunks = await chunksFromResponse(
      ResponseBody.fromString(
        'data: {"content":"Hel"}\n\n'
        'data: {"content":"lo"}\n\n'
        'data: [DONE]\n\n',
        200,
      ),
    ).toList();

    expect(chunks, ['Hel', 'lo']);
  });

  test('chunksFromResponse accepts a full JSON body as one chunk', () async {
    final chunks = await chunksFromResponse(
      '{"content":"Hello from backend"}',
    ).toList();

    expect(chunks, ['Hello from backend']);
  });

  test('parseTaskDraft posts prompt to /ai/parse-task', () async {
    final draft = await service.parseTaskDraft('buy milk tomorrow');

    expect(draft.title, 'Buy groceries');
    expect(draft.description, 'Milk and bread');
    expect(draft.priority, TaskPriority.high);
    expect(draft.theme, 'Health');
    expect(draft.dueDate, DateTime(2026, 9, 4));

    expect(requests, hasLength(1));
    expect(requests.single.path, ApiEndpoints.aiParseTask);
    expect(requests.single.method, 'POST');
    expect(requests.single.data, {'prompt': 'buy milk tomorrow'});
  });
}
