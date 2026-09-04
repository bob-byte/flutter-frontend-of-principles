import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_bootstrap_snapshot.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/models/task_item_dto.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueueService queue;
  late UserService users;
  late _FakeTaskService tasks;
  late SyncSnapshotMergeService merge;
  late DatabaseService db;
  late LocalDb localDb;
  late String dbPath;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final created = await createTestDatabaseService();
    db = created.db;
    localDb = created.localDb;
    dbPath = created.path;
    queue = SyncQueueService(memoryItems: []);
    users = UserService(forceLocalOnly: true);
    final api = ApiClient(SecureStore(), dio: Dio());
    tasks = _FakeTaskService(api);
    merge = SyncSnapshotMergeService(
      queue: queue,
      databaseService: db,
      userService: users,
      reminderService: ReminderService(forceLocalOnly: true),
      taskService: tasks,
    );
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('applies remote user when local is empty', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        user: User(
          name: 'Ada',
          email: 'ada@example.com',
          lastModified: DateTime.utc(2026, 1, 2),
        ),
      ),
    );

    final local = await users.loadLocalUser();
    expect(local?.name, 'Ada');
    expect(local?.email, 'ada@example.com');
  });

  test('keeps newer local user over older remote', () async {
    await users.saveLocalUser(
      User(name: 'Local', lastModified: DateTime.utc(2026, 2, 1)),
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        user: User(name: 'Remote', lastModified: DateTime.utc(2026, 1, 1)),
      ),
    );

    expect((await users.loadLocalUser())?.name, 'Local');
  });

  test('skips user merge when user queue has blocking items', () async {
    await queue.addToQueue(
      handlerType: SyncHandlerType.user,
      operation: OperationKind.saveUserName,
      payload: {'UserName': 'Pending'},
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        user: User(name: 'Remote', lastModified: DateTime.utc(2026, 3, 1)),
      ),
    );

    expect(await users.loadLocalUser(), isNull);
  });

  test('merges remote goals when queue is clear', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        goals: [UserGoal(id: 11, name: 'Fitness')],
      ),
    );

    final rows = await localDb.database.then(
      (database) => database.query('user_goals'),
    );
    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Fitness');
    expect(rows.single['id'], 11);
  });

  test('skips remote goal with a blocking queue item', () async {
    await queue.addToQueue(
      handlerType: SyncHandlerType.userGoal,
      operation: OperationKind.save,
      entityId: 11,
      payload: {'id': 11, 'name': 'Pending'},
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        goals: [UserGoal(id: 11, name: 'Remote')],
      ),
    );

    final rows = await localDb.database.then(
      (database) => database.query('user_goals'),
    );
    expect(rows, isEmpty);
  });

  test('merges remote active habits when local is empty', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {
            'id': 42,
            'name': 'Walk',
            'complexity': 5,
            'type': 1,
            'goalName': 'Health',
            'goalId': 3,
          },
        ],
      ),
    );

    final habits = await db.getAllHabits();
    expect(habits, hasLength(1));
    expect(habits.single.name, 'Walk');
    expect(habits.single.serverId, 42);
    expect(habits.single.targetGoal, 'Health');
  });

  test('merges archived habits from bootstrap', () async {
    await merge.merge(
      const SyncBootstrapSnapshot(
        archivedHabits: [
          SyncBootstrapArchivedHabit(id: 9, name: 'Old habit'),
        ],
      ),
    );

    final archived = await db.getAllHabits(isArchived: true);
    expect(archived.map((h) => h.name), ['Old habit']);
    expect(archived.single.id, 9);
  });

  test('merges remote tasks when queue is clear', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        tasks: [
          const TaskItemDto(id: 7, name: 'Inbox task', isCompleted: false),
        ],
      ),
    );

    expect(tasks.mergedTitles, ['Inbox task']);
  });

  test('skips remote task that has a pending delete in the queue', () async {
    await queue.addToQueue(
      handlerType: SyncHandlerType.task,
      operation: OperationKind.delete,
      entityId: 7,
      payload: {'id': 7},
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        tasks: [
          const TaskItemDto(id: 7, name: 'Should skip', isCompleted: false),
        ],
      ),
    );

    expect(tasks.mergedTitles, isEmpty);
  });
}

class _FakeTaskService extends TaskService {
  _FakeTaskService(ApiClient apiClient) : super(apiClient: apiClient);

  final mergedTitles = <String>[];

  @override
  Future<void> mergeRemoteTask(TaskItemDto dto) async {
    mergedTitles.add(dto.name);
  }
}
