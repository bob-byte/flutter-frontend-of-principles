import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(requestOptions: options, message: 'offline'),
          );
        },
      ),
    );
    service = TaskService(
      apiClient: ApiClient(SecureStore(), dio: dio),
      taskDb: null,
    );
  });

  test('saveTask persists locally even when remote fails', () async {
    await service.saveTask(
      Task(
        id: '0',
        title: 'Buy milk',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      isNew: true,
    );

    final tasks = await service.getTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Buy milk');
    expect(tasks.single.id, startsWith('L'));
  });

  test('updateTaskStatus flips local completion', () async {
    await service.saveTask(
      Task(
        id: 't1',
        title: 'Ship',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      isNew: false,
    );
    await service.updateTaskStatus('t1', true);
    expect((await service.getTask('t1'))?.isDone, isTrue);
  });
}
