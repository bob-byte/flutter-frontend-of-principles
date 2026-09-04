import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/edit_habit_viewmodel.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditHabitViewModel vm;
  late _FakeHabitService habits;
  late DatabaseService db;
  late LocalDb localDb;
  late String dbPath;

  setUp(() async {
    final created = await createTestDatabaseService();
    db = created.db;
    localDb = created.localDb;
    dbPath = created.path;
    final auth = AuthService(
      _TokenStore(),
      dio: Dio()..httpClientAdapter = _Noop(),
    );
    final api = ApiClient(
      _TokenStore(),
      dio: Dio()..httpClientAdapter = _Noop(),
    );
    habits = _FakeHabitService(auth);
    vm = EditHabitViewModel(
      habits,
      ReminderService(forceLocalOnly: true),
      GoalService(auth),
      AiRecommendationService(api),
      UserService(forceLocalOnly: true),
      dbService: db,
    );
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('init copies fields from an existing habit', () {
    vm.init(
      Habit(
        id: 9,
        name: 'Walk',
        targetGoal: 'Health',
        targetGoalId: 2,
        isFlexible: false,
        notes: 'Morning',
        difficulty: 7,
        frequency: const FrequencyConfig(
          type: FrequencyType.everyXDays,
          interval: 2,
        ),
      ),
    );

    expect(vm.isNewHabit, isFalse);
    expect(vm.editingHabitId, 9);
    expect(vm.habitName, 'Walk');
    expect(vm.targetGoal, 'Health');
    expect(vm.targetGoalId, 2);
    expect(vm.isFlexible, isFalse);
    expect(vm.notes, 'Morning');
    expect(vm.difficulty, 7);
    expect(vm.frequency.type, FrequencyType.everyXDays);
  });

  test('init without habit resets to create defaults', () {
    vm.init(Habit(id: 1, name: 'Old', difficulty: 8));
    vm.init(null);

    expect(vm.isNewHabit, isTrue);
    expect(vm.habitName, isEmpty);
    expect(vm.difficulty, 5);
    expect(vm.frequency.type, FrequencyType.daily);
  });

  test('saveHabit returns false when name is blank', () async {
    vm.init(null);
    vm.habitName = '   ';
    expect(await vm.saveHabit(), isFalse);
  });

  test('saveHabit inserts a new habit and pushes remotely', () async {
    vm.init(null);
    vm.habitName = 'Morning walk';
    vm.notes = 'Park';
    vm.difficulty = 6;

    expect(await vm.saveHabit(), isTrue);
    expect(habits.pushed, hasLength(1));
    expect(habits.pushed.single.isNew, isTrue);
    expect(habits.pushed.single.habit.name, 'Morning walk');

    final stored = await db.getAllHabits();
    expect(stored, hasLength(1));
    expect(stored.single.name, 'Morning walk');
    expect(stored.single.notes, 'Park');
    expect(stored.single.difficulty, 6);
  });

  test('saveHabit updates an existing habit', () async {
    final id = await db.insertHabit(Habit(name: 'Old name', difficulty: 3));
    vm.init(Habit(id: id, name: 'Old name', difficulty: 3));
    vm.habitName = 'Renamed';
    vm.difficulty = 8;

    expect(await vm.saveHabit(), isTrue);
    expect(habits.pushed.single.isNew, isFalse);

    final stored = await db.getHabitById(id);
    expect(stored?.name, 'Renamed');
    expect(stored?.difficulty, 8);
  });
}

class _PushCall {
  _PushCall(this.habit, this.isNew);
  final Habit habit;
  final bool isNew;
}

class _FakeHabitService extends HabitService {
  _FakeHabitService(AuthService auth) : super(auth);

  final pushed = <_PushCall>[];

  @override
  Future<int?> pushHabit(
    Habit habit, {
    required bool isNew,
    bool enqueueOnFailure = true,
    bool awaitRemote = false,
  }) async {
    pushed.add(_PushCall(habit, isNew));
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
