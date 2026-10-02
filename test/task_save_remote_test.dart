import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/models/task_subtask.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late Completer<void> releaseCreate;
  late TaskService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_access_token': 't'});
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = false;
    requests = [];
    releaseCreate = Completer<void>();
    var nextId = 100;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    final apiClient = ApiClient(SecureStore(), dio: dio);
    // Register after ApiClient so this runs first on the way out / last on the
    // way in depending on Dio version — resolve here to avoid real HTTP.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (options.method == 'POST' &&
              options.path.endsWith(ApiEndpoints.tasks)) {
            await releaseCreate.future;
            final id = nextId++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'id': id, 'name': 'Task', 'isCompleted': false},
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'id': 100, 'name': 'Task', 'isCompleted': false},
            ),
          );
        },
      ),
    );
    service = TaskService(apiClient: apiClient, taskDb: null);
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  test(
    'edit save waits for create and PUTs instead of posting a duplicate',
    () async {
      AppConfig.debugUseLocalDataOverride = true;
      final created = await service.saveTask(
        Task(id: '0', title: 'Parent', createdAt: DateTime.utc(2026, 1, 1)),
        isNew: true,
      );
      AppConfig.debugUseLocalDataOverride = false;

      final createFuture = service.pushSaveToRemote(created, allowCreate: true);
      final editFuture = service.pushSaveToRemote(
        created.copyWith(
          subtasks: [TaskSubtask(id: 'S1', title: 'Milk', sortOrder: 0)],
        ),
        allowCreate: false,
      );

      releaseCreate.complete();
      await Future.wait([createFuture, editFuture]);

      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(
        requests.where(
          (r) =>
              r.method == 'PUT' && r.path.endsWith('${ApiEndpoints.tasks}/100'),
        ),
        hasLength(1),
      );
      expect((await service.getTask(created.id))?.serverId, 100);
    },
  );

  test(
    'edit without server id throws so the queue can retry after create',
    () async {
      AppConfig.debugUseLocalDataOverride = true;
      final local = await service.saveTask(
        Task(
          id: 'Lorphan',
          title: 'No server yet',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        isNew: false,
      );
      AppConfig.debugUseLocalDataOverride = false;

      await expectLater(
        service.pushSaveToRemote(local, allowCreate: false),
        throwsA(isA<StateError>()),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
}
