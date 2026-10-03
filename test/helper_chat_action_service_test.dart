import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/helper_chat_action.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/helper_chat_action_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGoalService goals;
  late HelperChatActionService service;
  late DatabaseService db;
  late LocalDb localDb;
  late String dbPath;
  late _FakeHabitService habits;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    goals = _FakeGoalService();
    final created = await createTestDatabaseService();
    db = created.db;
    localDb = created.localDb;
    dbPath = created.path;
    habits = _FakeHabitService();
    service = HelperChatActionService(
      goalService: goals,
      habitService: habits,
      database: db,
      userService: UserService(forceLocalOnly: true),
    );
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('add goal treats archived name as already existing', () async {
    goals.items = [UserGoal(name: 'Fitness', isArchived: true)];

    final result = await service.apply(
      const HelperChatAction(type: HelperChatActionType.goal, title: 'Fitness'),
    );

    expect(result.kind, HelperChatActionApplyKind.alreadyExists);
    expect(goals.lastIsArchived, isNull);
    expect(goals.saved, isEmpty);
  });

  test('add habit resolves goal hint against archived goals', () async {
    goals.items = [
      UserGoal(id: 7, localId: 7, name: 'Fitness', isArchived: true),
    ];

    final result = await service.apply(
      const HelperChatAction(
        type: HelperChatActionType.habit,
        title: 'Run',
        goalName: 'Fitness',
      ),
    );

    expect(result.kind, HelperChatActionApplyKind.created);
    expect(goals.lastIsArchived, isNull);
    final stored = (await db.getAllHabits(isArchived: null)).single;
    expect(stored.targetGoal, 'Fitness');
    expect(stored.targetGoalId, 7);
  });

  test('add habit prefers active goal when name matches both', () async {
    goals.items = [
      UserGoal(id: 1, localId: 1, name: 'Fitness', isArchived: true),
      UserGoal(id: 2, localId: 2, name: 'Fitness', isArchived: false),
    ];

    final result = await service.apply(
      const HelperChatAction(
        type: HelperChatActionType.habit,
        title: 'Walk',
        goalName: 'Fitness',
      ),
    );

    expect(result.kind, HelperChatActionApplyKind.created);
    final stored = (await db.getAllHabits(isArchived: null)).single;
    expect(stored.targetGoalId, 2);
  });
}

class _FakeGoalService extends GoalService {
  _FakeGoalService() : super(AuthService(SecureStore()));

  List<UserGoal> items = [];
  final saved = <UserGoal>[];
  bool? lastIsArchived;

  @override
  Future<List<UserGoal>> getGoals({bool? isArchived = false}) async {
    lastIsArchived = isArchived;
    if (isArchived == null) return List.of(items);
    return items.where((g) => g.isArchived == isArchived).toList();
  }

  @override
  Future<UserGoal> saveGoal(UserGoal goal) async {
    saved.add(goal);
    items = [...items, goal];
    return goal;
  }
}

class _FakeHabitService extends HabitService {
  _FakeHabitService()
    : super(
        AuthService(_TokenStore(), dio: Dio()..httpClientAdapter = _Noop()),
      );

  @override
  Future<int?> pushHabit(
    Habit habit, {
    required bool isNew,
    bool enqueueOnFailure = true,
    bool awaitRemote = false,
  }) async {
    return habit.id ?? 99;
  }
}

class _TokenStore extends SecureStore {
  @override
  Future<String?> read(String key) async => 'token';
}

class _Noop implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
