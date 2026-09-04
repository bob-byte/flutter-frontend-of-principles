import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/task_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late ApiClient apiClient;
  late _FakeTaskService tasks;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_access_token': 't'});
    requests = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'id': 55, 'title': 'New', 'isCompleted': false},
            ),
          );
        },
      ),
    );
    tasks = _FakeTaskService(apiClient);
  });

  test('deletes remote task by entity id', () async {
    await TaskSyncHandler(apiClient, taskService: tasks).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.task,
        operation: OperationKind.delete,
        entityId: 9,
      ),
    );
    expect(requests.single.method, 'DELETE');
    expect(requests.single.path, '${ApiEndpoints.tasks}/9');
  });

  test('updates task status', () async {
    await TaskSyncHandler(apiClient, taskService: tasks).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.task,
        operation: OperationKind.updateStatus,
        entityId: 3,
        payloadJson: jsonEncode({'id': 3, 'isCompleted': true}),
      ),
    );
    expect(requests.single.method, 'PUT');
    expect(requests.single.path, '${ApiEndpoints.tasks}/3/status');
    expect(requests.single.data['isCompleted'], isTrue);
  });

  test('posts new task when server id is missing', () async {
    await TaskSyncHandler(apiClient, taskService: tasks).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.task,
        operation: OperationKind.save,
        entityId: 0,
        payloadJson: jsonEncode({
          'id': 'local-1',
          'title': 'Buy milk',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ),
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.path, ApiEndpoints.tasks);
    expect(tasks.assignedServerIds, [55]);
  });
}

class _FakeTaskService extends TaskService {
  _FakeTaskService(ApiClient apiClient) : super(apiClient: apiClient);

  final assignedServerIds = <int>[];

  @override
  Future<Task?> getTaskByLocalId(int localId) async => null;

  @override
  Future<void> assignServerId(Task task, int serverId) async {
    assignedServerIds.add(serverId);
  }
}
