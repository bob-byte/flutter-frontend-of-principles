import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/sync_bootstrap_snapshot.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_handler.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_access_token': 'test-token',
    });
    AppConfig.debugUseLocalDataOverride = false;
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  test('empty queue does a single bootstrap GET', () async {
    final gets = <String>[];
    final sync = _buildSync(
      queue: SyncQueueService(memoryItems: []),
      handlers: const [],
      onBootstrap: () => gets.add('bootstrap'),
    );

    await sync.sync();

    expect(gets, ['bootstrap']);
  });

  test('resume with since prefers /sync/changes', () async {
    final gets = <String>[];
    final sync = _buildSync(
      queue: SyncQueueService(memoryItems: []),
      handlers: const [],
      onBootstrap: () => gets.add('bootstrap'),
      onChanges: () => gets.add('changes'),
    );

    final cursor = await sync.sync(since: DateTime.utc(2026, 9, 1));

    expect(gets, ['changes']);
    expect(cursor, isNotNull);
  });

  test('falls back to bootstrap when changes requiresFullBootstrap', () async {
    final gets = <String>[];
    final sync = _buildSync(
      queue: SyncQueueService(memoryItems: []),
      handlers: const [],
      onBootstrap: () => gets.add('bootstrap'),
      onChanges: () => gets.add('changes'),
      changesRequiresFull: true,
    );

    await sync.sync(since: DateTime.utc(2026, 9, 1));

    expect(gets, ['changes', 'bootstrap']);
  });

  test('re-pulls bootstrap only after pushing local queue items', () async {
    final gets = <String>[];
    final queue = SyncQueueService(memoryItems: []);
    await queue.addToQueue(
      handlerType: SyncHandlerType.userGoal,
      operation: 'Save',
      payload: {'id': 1},
      entityId: 1,
    );

    final sync = _buildSync(
      queue: queue,
      handlers: [_OkHandler()],
      onBootstrap: () => gets.add('bootstrap'),
    );

    await sync.sync();

    expect(gets, ['bootstrap', 'bootstrap']);
  });
}

SyncService _buildSync({
  required SyncQueueService queue,
  required List<SyncQueueHandler> handlers,
  required void Function() onBootstrap,
  void Function()? onChanges,
  bool changesRequiresFull = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains(ApiEndpoints.syncChanges)) {
          onChanges?.call();
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'serverTime': '2026-09-09T12:00:00Z',
                'requiresFullBootstrap': changesRequiresFull,
                if (!changesRequiresFull) ...{
                  'goals': <dynamic>[],
                  'activeHabits': <dynamic>[],
                  'tasks': <dynamic>[],
                  'conversations': <dynamic>[],
                },
              },
            ),
          );
          return;
        }
        if (options.path.contains(ApiEndpoints.syncBootstrap)) {
          onBootstrap();
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'serverTime': '2026-09-09T12:00:00Z',
              },
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            message: 'Unexpected ${options.path}',
          ),
        );
      },
    ),
  );

  final store = SecureStore();
  final apiClient = ApiClient(store, dio: dio);
  final db = DatabaseService();
  return SyncService(
    queue: queue,
    authService: AuthService(store),
    apiClient: apiClient,
    mergeService: _NoopMerge(
      queue: queue,
      databaseService: db,
      userService: UserService(forceLocalOnly: true),
      reminderService: ReminderService(forceLocalOnly: true),
      taskService: TaskService(apiClient: apiClient),
    ),
    databaseService: db,
    handlers: handlers,
  );
}

class _NoopMerge extends SyncSnapshotMergeService {
  _NoopMerge({
    required super.queue,
    required super.databaseService,
    required super.userService,
    required super.reminderService,
    required super.taskService,
  });

  @override
  Future<void> merge(SyncBootstrapSnapshot snapshot) async {}
}

class _OkHandler implements SyncQueueHandler {
  @override
  bool canHandle(String handlerType) => handlerType == SyncHandlerType.userGoal;

  @override
  Future<void> handle(SyncQueueItem item) async {}
}
