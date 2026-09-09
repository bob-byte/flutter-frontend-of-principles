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
import 'package:principles_app/models/habit.dart';
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

  test(
    'keeps newer local user over older remote but fills blank email',
    () async {
      await users.saveLocalUser(
        User(
          name: 'Local',
          hasSeenRoadGuide: true,
          lastModified: DateTime.utc(2026, 2, 1),
        ),
      );

      await merge.merge(
        SyncBootstrapSnapshot(
          user: User(
            id: 5,
            name: 'Remote',
            email: 'ada@example.com',
            gender: 1,
            lastModified: DateTime.utc(2026, 1, 1),
          ),
        ),
      );

      final local = await users.loadLocalUser();
      expect(local?.name, 'Local');
      expect(local?.email, 'ada@example.com');
      expect(local?.id, 5);
      expect(local?.gender, 1);
      expect(local?.hasSeenRoadGuide, isTrue);
    },
  );

  test(
    'fills blank email from remote even when user queue is blocking',
    () async {
      await users.saveLocalUser(
        User(hasSeenRoadGuide: true, lastModified: DateTime.utc(2026, 3, 2)),
      );
      await queue.addToQueue(
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveHasSeenRoadGuide,
        payload: {'HasSeenRoadGuide': true},
      );

      await merge.merge(
        SyncBootstrapSnapshot(
          user: User(
            id: 9,
            name: 'Ada',
            email: 'ada@example.com',
            lastModified: DateTime.utc(2026, 3, 1),
          ),
        ),
      );

      final local = await users.loadLocalUser();
      expect(local?.email, 'ada@example.com');
      expect(local?.id, 9);
      expect(local?.name, 'Ada');
      expect(local?.hasSeenRoadGuide, isTrue);
    },
  );

  test(
    'skips creating a user when queue is blocking and local is empty',
    () async {
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
    },
  );

  test('preserves local hasSeenRoadGuide when applying remote user', () async {
    await users.saveLocalUser(User(hasSeenRoadGuide: true));

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
    expect(local?.hasSeenRoadGuide, isTrue);
  });

  test('merges remote goals when queue is clear', () async {
    await merge.merge(
      SyncBootstrapSnapshot(goals: [UserGoal(id: 11, name: 'Fitness')]),
    );

    final rows = await localDb.database.then(
      (database) => database.query('user_goals'),
    );
    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Fitness');
    expect(rows.single['id'], 11);
  });

  test('keeps newer local goal over older remote', () async {
    await db.upsertGoal(
      UserGoal(id: 11, name: 'Local', lastModified: DateTime.utc(2026, 3, 1)),
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        goals: [
          UserGoal(
            id: 11,
            name: 'Remote',
            lastModified: DateTime.utc(2026, 1, 1),
          ),
        ],
      ),
    );

    final rows = await localDb.database.then(
      (database) => database.query('user_goals'),
    );
    expect(rows.single['name'], 'Local');
  });

  test('prunes server-backed goals missing from the snapshot', () async {
    await db.upsertGoal(UserGoal(id: 11, name: 'Keep'));
    await db.upsertGoal(UserGoal(id: 12, name: 'Drop'));

    await merge.merge(
      SyncBootstrapSnapshot(goals: [UserGoal(id: 11, name: 'Keep')]),
    );

    final names = (await db.getAllGoals()).map((g) => g.name).toSet();
    expect(names, {'Keep'});
  });

  test('skips remote goal with a blocking queue item', () async {
    await queue.addToQueue(
      handlerType: SyncHandlerType.userGoal,
      operation: OperationKind.save,
      entityId: 11,
      payload: {'id': 11, 'name': 'Pending'},
    );

    await merge.merge(
      SyncBootstrapSnapshot(goals: [UserGoal(id: 11, name: 'Remote')]),
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

  test('does not overwrite pending habit progress', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {
            'id': 42,
            'name': 'Walk',
            'complexity': 5,
            'type': 1,
            'progresses': [
              {'date': '2026-09-03', 'value': 3},
            ],
          },
        ],
      ),
    );
    await db.setHabitRecordValue(42, DateTime(2026, 9, 3), 2);
    await queue.addToQueue(
      handlerType: SyncHandlerType.progressOfHabit,
      operation: OperationKind.save,
      payload: {'habitId': 42, 'date': '2026-09-03', 'value': 2},
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {
            'id': 42,
            'name': 'Walk',
            'complexity': 5,
            'type': 1,
            'progresses': [
              {'date': '2026-09-03', 'value': 3},
            ],
          },
        ],
      ),
    );

    final record = await db.findRecord(42, DateTime(2026, 9, 3));
    expect(record?.value, 2);
  });

  test('does not rewrite matching habit progress', () async {
    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {
            'id': 42,
            'name': 'Walk',
            'complexity': 5,
            'type': 1,
            'progresses': [
              {
                'date': '2026-09-03',
                'value': 3,
                'lastModified': '2026-01-01T00:00:00.000Z',
              },
            ],
          },
        ],
      ),
    );
    final first = await db.findRecord(42, DateTime(2026, 9, 3));
    expect(first?.value, 3);
    expect(first?.lastModified, DateTime.utc(2026, 1, 1));

    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {
            'id': 42,
            'name': 'Walk',
            'complexity': 5,
            'type': 1,
            'progresses': [
              {
                'date': '2026-09-03',
                'value': 3,
                'lastModified': '2026-01-01T00:00:00.000Z',
              },
            ],
          },
        ],
      ),
    );

    final second = await db.findRecord(42, DateTime(2026, 9, 3));
    expect(second?.id, first?.id);
    expect(second?.lastModified, DateTime.utc(2026, 1, 1));
  });

  test('prunes server-backed habits missing from the snapshot', () async {
    await db.insertOrUpdateHabitWithBackendId(
      Habit(id: 42, serverId: 42, name: 'Keep'),
    );
    await db.insertOrUpdateHabitWithBackendId(
      Habit(id: 43, serverId: 43, name: 'Drop'),
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {'id': 42, 'name': 'Keep', 'complexity': 5, 'type': 1},
        ],
      ),
    );

    final names = (await db.getAllHabits(isArchived: null)).map((h) => h.name);
    expect(names, ['Keep']);
  });

  test('skips remote habit with an archive payload in the queue', () async {
    await db.insertOrUpdateHabitWithBackendId(
      Habit(id: 42, serverId: 42, name: 'Local'),
    );
    await queue.addToQueue(
      handlerType: SyncHandlerType.userHabit,
      operation: OperationKind.setArchiveStatus,
      payload: {'habitId': 42, 'isArchived': true},
    );

    await merge.merge(
      SyncBootstrapSnapshot(
        activeHabits: [
          {'id': 42, 'name': 'Remote', 'complexity': 5, 'type': 1},
        ],
      ),
    );

    final habits = await db.getAllHabits(isArchived: null);
    expect(habits.single.name, 'Local');
  });

  test('merges archived habits from bootstrap', () async {
    await merge.merge(
      const SyncBootstrapSnapshot(
        archivedHabits: [SyncBootstrapArchivedHabit(id: 9, name: 'Old habit')],
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

  test('prunes local tasks missing from a tasks-provided snapshot', () async {
    await merge.merge(
      const SyncBootstrapSnapshot(
        tasks: [TaskItemDto(id: 7, name: 'Keep', isCompleted: false)],
        tasksProvided: true,
        tasksTrustedForPrune: true,
      ),
    );

    expect(tasks.mergedTitles, ['Keep']);
    expect(tasks.discardedRemoteIds, {7});
    expect(tasks.retainedServerIds, isEmpty);
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
  Set<int> discardedRemoteIds = {};
  Set<int> retainedServerIds = {};

  @override
  Future<void> mergeRemoteTask(TaskItemDto dto) async {
    mergedTitles.add(dto.name);
  }

  @override
  Future<void> discardLocalTasksAbsentFromRemote(
    Set<int> remoteServerIds, {
    Set<int> retainServerIds = const {},
  }) async {
    discardedRemoteIds = remoteServerIds;
    retainedServerIds = retainServerIds;
  }
}
