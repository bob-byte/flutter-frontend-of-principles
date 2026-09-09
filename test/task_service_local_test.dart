import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/models/task_item_dto.dart';
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
      Task(id: '0', title: 'Buy milk', createdAt: DateTime.utc(2026, 1, 1)),
      isNew: true,
    );

    final tasks = await service.getTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Buy milk');
    expect(tasks.single.id, startsWith('L'));
  });

  test('assignServerId keeps local id and sets serverId', () async {
    await service.saveTask(
      Task(
        id: '0',
        title: 'Keep id',
        description: 'long notes ok',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      isNew: true,
    );
    final local = (await service.getTasks()).single;
    expect(local.id, startsWith('L'));

    await service.assignServerId(local, 42);

    final updated = await service.getTask(local.id);
    expect(updated, isNotNull);
    expect(updated!.id, local.id);
    expect(updated.serverId, 42);
    expect(await service.getTask('42'), isNotNull);
    expect((await service.getTask('42'))!.title, 'Keep id');
  });

  test('discardLocalTasksAbsentFromRemote keeps unsynced rows', () async {
    await service.saveTask(
      Task(id: 'L1', title: 'Local only', createdAt: DateTime.utc(2026, 1, 1)),
      isNew: false,
    );
    await service.saveTask(
      Task(
        id: '10',
        title: 'Keep',
        createdAt: DateTime.utc(2026, 1, 1),
        serverId: 10,
      ),
      isNew: false,
    );
    await service.saveTask(
      Task(
        id: '11',
        title: 'Drop',
        createdAt: DateTime.utc(2026, 1, 1),
        serverId: 11,
      ),
      isNew: false,
    );

    await service.discardLocalTasksAbsentFromRemote({10});

    final titles = (await service.getTasks()).map((t) => t.title).toSet();
    expect(titles, {'Local only', 'Keep'});
  });

  test('mergeRemoteTask collapses local and server-id duplicate rows', () async {
    await service.saveTask(
      Task(
        id: 'Lkeep',
        title: 'Local copy',
        createdAt: DateTime.utc(2026, 1, 1),
        serverId: 2,
      ),
      isNew: false,
    );
    await service.saveTask(
      Task(
        id: '2',
        title: 'Bootstrap copy',
        createdAt: DateTime.utc(2026, 1, 1),
        serverId: 2,
      ),
      isNew: false,
    );

    await service.mergeRemoteTask(
      const TaskItemDto(id: 2, name: 'Merged'),
    );

    final tasks = await service.getTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.id, '2');
    expect(tasks.single.title, 'Merged');
    expect(tasks.single.serverId, 2);
  });

  test('updateTaskStatus flips local completion', () async {
    await service.saveTask(
      Task(id: 't1', title: 'Ship', createdAt: DateTime.utc(2026, 1, 1)),
      isNew: false,
    );
    await service.updateTaskStatus('t1', true);
    expect((await service.getTask('t1'))?.isDone, isTrue);
  });
}
