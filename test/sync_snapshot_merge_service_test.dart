import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/push/reminder_target_index.dart';
import 'package:principles_app/core/reminder/reminder_targets.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_bootstrap_snapshot.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/schedule_reminder_offset.dart';
import 'package:principles_app/models/task.dart';
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

  group('reminders of rows removed by another device', () {
    late _RecordingReminderService reminders;

    setUp(() {
      reminders = _RecordingReminderService();
      merge = SyncSnapshotMergeService(
        queue: queue,
        databaseService: db,
        userService: users,
        reminderService: reminders,
        taskService: tasks,
      );
    });

    test('cancels a habit deleted via /changes tombstone', () async {
      await db.insertOrUpdateHabitWithBackendId(
        Habit(id: 43, serverId: 43, name: 'Drop'),
      );

      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, deletedHabitIds: [43]),
      );

      expect(reminders.cancelledHabitIds, [43]);
      expect(reminders.sweeps, 1);
    });

    test('cancels a habit pruned from full bootstrap', () async {
      await db.insertOrUpdateHabitWithBackendId(
        Habit(id: 43, serverId: 43, name: 'Drop'),
      );

      await merge.merge(const SyncBootstrapSnapshot());

      expect(reminders.cancelledHabitIds, [43]);
    });

    test('cancels a habit archived on another device', () async {
      await db.insertOrUpdateHabitWithBackendId(
        Habit(id: 9, serverId: 9, name: 'Read'),
      );

      await merge.merge(
        const SyncBootstrapSnapshot(
          isDelta: true,
          archivedHabits: [SyncBootstrapArchivedHabit(id: 9, name: 'Read')],
        ),
      );

      expect(reminders.cancelledHabitIds, [9]);
    });

    test('cancels tasks removed by a /changes tombstone', () async {
      tasks.remoteDeleted = [
        Task(id: '7', title: 'Call', createdAt: DateTime(2026, 9, 1)),
      ];

      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, deletedTaskIds: [7]),
      );

      expect(reminders.cancelledTaskIds, ['7']);
    });

    test('keeps a habit with a pending local save', () async {
      await db.insertOrUpdateHabitWithBackendId(
        Habit(id: 43, serverId: 43, name: 'Edited'),
      );
      await queue.addToQueue(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        payload: {'id': 43},
        entityId: 43,
        entityLocalId: 43,
      );

      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, deletedHabitIds: [43]),
      );

      expect(reminders.cancelledHabitIds, isEmpty);
    });

    test('saves the push target index after a merge', () async {
      await db.insertOrUpdateHabitWithBackendId(
        Habit(id: 42, serverId: 42, name: 'Walk'),
      );

      await merge.merge(
        SyncBootstrapSnapshot(
          isDelta: true,
          activeHabits: [
            {'id': 42, 'name': 'Walk', 'complexity': 5, 'type': 1},
          ],
        ),
      );

      final index = await ReminderTargetIndex.load();
      expect(index.habits, {
        42: {42},
      });
    });

    test('skips the orphan sweep for an empty delta', () async {
      await merge.merge(const SyncBootstrapSnapshot(isDelta: true));

      expect(reminders.sweeps, 0);
    });
  });

  group('reminders of rows rescheduled by another device', () {
    late _RecordingReminderService reminders;

    const remindedDto = TaskItemDto(
      id: 7,
      name: 'Call',
      date: '2026-10-02',
      time: '10:00:00',
      reminders: [
        ScheduleReminderOffset(offsetMinutes: 15, notificationRequestId: 71),
      ],
    );

    Task localCopy({required DateTime due}) => Task(
      id: 'L7',
      serverId: 7,
      title: 'Call',
      createdAt: DateTime(2026, 9, 1),
      dueDate: due,
      reminders: const [
        ScheduleReminderOffset(offsetMinutes: 15, notificationRequestId: 71),
      ],
    );

    Map<String, dynamic> habitJson({required String time}) => {
      'id': 42,
      'name': 'Walk',
      'complexity': 5,
      'type': 1,
      'lastModified': '2026-09-30T10:00:00.000Z',
      'reminders': [
        {
          'id': 300,
          'title': 'Walk',
          'time': time,
          'isEnabled': true,
          'daysOfWeek': [
            {'type': 1, 'userNotificationRequestId': 501},
          ],
        },
      ],
    };

    setUp(() {
      reminders = _RecordingReminderService();
      merge = SyncSnapshotMergeService(
        queue: queue,
        databaseService: db,
        userService: users,
        reminderService: reminders,
        taskService: tasks,
      );
    });

    test('reschedules a task whose time changed elsewhere', () async {
      tasks.localByServerId[7] = localCopy(due: DateTime(2026, 10, 2, 9));

      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, tasks: [remindedDto]),
      );

      expect(reminders.cancelledTaskIds, ['L7']);
      expect(reminders.syncedTasks.single.id, 'L7');
      expect(reminders.syncedTasks.single.dueDate, DateTime(2026, 10, 2, 10));
    });

    test('leaves an unchanged task alone', () async {
      tasks.localByServerId[7] = localCopy(due: DateTime(2026, 10, 2, 10));

      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, tasks: [remindedDto]),
      );

      expect(reminders.cancelledTaskIds, isEmpty);
      expect(reminders.syncedTasks, isEmpty);
    });

    test('schedules a new task from /changes', () async {
      await merge.merge(
        const SyncBootstrapSnapshot(isDelta: true, tasks: [remindedDto]),
      );

      expect(reminders.syncedTasks.single.id, '7');
    });

    test('leaves new full-bootstrap tasks to the restore job', () async {
      await merge.merge(const SyncBootstrapSnapshot(tasks: [remindedDto]));

      expect(reminders.syncedTasks, isEmpty);
    });

    test('reschedules a habit whose reminder time changed elsewhere', () async {
      await merge.merge(
        SyncBootstrapSnapshot(
          activeHabits: [
            {
              ...habitJson(time: '08:00:00'),
              'lastModified': '2026-09-29T00:00:00.000Z',
            },
          ],
        ),
      );
      expect(reminders.syncedHabits, isEmpty);

      await merge.merge(
        SyncBootstrapSnapshot(
          isDelta: true,
          activeHabits: [habitJson(time: '09:30:00')],
        ),
      );

      expect(reminders.cancelledHabitIds, [42]);
      final synced = reminders.syncedHabits.single;
      expect(synced.id, 42);
      expect(
        synced.reminders.single.time,
        const TimeOfDay(hour: 9, minute: 30),
      );
    });

    test('does not reschedule a habit when only progress changed', () async {
      await merge.merge(
        SyncBootstrapSnapshot(
          activeHabits: [
            {
              ...habitJson(time: '08:00:00'),
              'lastModified': '2026-09-29T00:00:00.000Z',
            },
          ],
        ),
      );

      await merge.merge(
        SyncBootstrapSnapshot(
          isDelta: true,
          activeHabits: [
            {
              ...habitJson(time: '08:00:00'),
              'progresses': [
                {'date': '2026-09-30', 'value': 3},
              ],
            },
          ],
        ),
      );

      expect(reminders.syncedHabits, isEmpty);
      expect(reminders.cancelledHabitIds, isEmpty);
    });
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

class _RecordingReminderService extends ReminderService {
  _RecordingReminderService() : super(forceLocalOnly: true);

  final cancelledHabitIds = <int?>[];
  final cancelledTaskIds = <String>[];
  final syncedTasks = <Task>[];
  final syncedHabits = <Habit>[];
  var sweeps = 0;

  @override
  Future<void> syncTaskNotifications(
    Task task, {
    bool ensurePermission = true,
  }) async {
    expect(ensurePermission, isFalse);
    syncedTasks.add(task);
  }

  @override
  Future<void> syncHabitNotifications(
    Habit habit, {
    bool ensurePermission = true,
    bool? satisfiedToday,
  }) async {
    expect(ensurePermission, isFalse);
    syncedHabits.add(habit);
  }

  @override
  Future<void> cancelHabitNotifications(Habit habit) async {
    cancelledHabitIds.add(habit.id);
  }

  @override
  Future<void> cancelTaskNotifications(Task task) async {
    cancelledTaskIds.add(task.id);
  }

  @override
  Future<void> cancelOrphanedNotifications(
    Future<ReminderTargets> Function() loadTargets,
  ) async {
    sweeps++;
    await loadTargets();
  }
}

class _FakeTaskService extends TaskService {
  _FakeTaskService(ApiClient apiClient) : super(apiClient: apiClient);

  final mergedTitles = <String>[];
  Set<int> discardedRemoteIds = {};
  Set<int> retainedServerIds = {};
  List<Task> remoteDeleted = const [];

  @override
  Future<List<Task>> discardRemoteDeletedTask(int serverId) async =>
      remoteDeleted;

  /// Local rows keyed by server id, returned as `previous` on merge.
  final localByServerId = <int, Task>{};

  @override
  Future<({Task? previous, Task merged})> mergeRemoteTask(
    TaskItemDto dto,
  ) async {
    mergedTitles.add(dto.name);
    final previous = localByServerId[dto.id];
    final merged = dto.toTask().copyWith(
      id: previous?.id ?? '${dto.id}',
      serverId: dto.id,
    );
    return (previous: previous, merged: merged);
  }

  @override
  Future<List<Task>> discardLocalTasksAbsentFromRemote(
    Set<int> remoteServerIds, {
    Set<int> retainServerIds = const {},
  }) async {
    discardedRemoteIds = remoteServerIds;
    retainedServerIds = retainServerIds;
    return const [];
  }

  @override
  Future<List<Task>> getTasks({bool? isDone}) async => const [];
}
