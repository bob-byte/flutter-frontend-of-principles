import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HabitProgressViewModel vm;
  late _FakeHabitService habits;
  late DatabaseService db;
  late LocalDb localDb;
  late String dbPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final created = await createTestDatabaseService();
    db = created.db;
    localDb = created.localDb;
    dbPath = created.path;
    habits = _FakeHabitService();
    vm = HabitProgressViewModel(habits, dbService: db);
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('selectDate normalizes to calendar day', () {
    vm.selectDate(DateTime(2026, 9, 4, 15, 30));
    expect(vm.selectedDate, DateTime(2026, 9, 4));
  });

  test('toggleGoalGroup expands and collapses', () {
    expect(vm.isGoalGroupExpanded('undefined'), isTrue);
    vm.toggleGoalGroup('undefined');
    expect(vm.isGoalGroupExpanded('undefined'), isFalse);
    vm.toggleGoalGroup('undefined');
    expect(vm.isGoalGroupExpanded('undefined'), isTrue);
  });

  test('clear resets habits and records', () {
    vm.habits = [Habit(id: 1, name: 'Walk')];
    vm.clear();
    expect(vm.habits, isEmpty);
    expect(vm.records, isEmpty);
    expect(vm.isLoading, isFalse);
  });

  test('groupedHabits puts undefined goals first via groupHabitsByGoal', () {
    final groups = groupHabitsByGoal([
      Habit(id: 1, name: 'B', targetGoal: 'Career', targetGoalId: 2),
      Habit(id: 2, name: 'A'),
    ]);
    expect(groups.first.isUndefined, isTrue);
    expect(groups.first.habits.single.name, 'A');
  });

  test('load with syncRemote false reads only active local habits', () async {
    await db.insertHabit(Habit(name: 'Active'));
    await db.insertHabit(Habit(name: 'Archived', isArchived: true));

    await vm.load(syncRemote: false);

    expect(vm.isLoading, isFalse);
    expect(vm.habits.map((h) => h.name), ['Active']);
    expect(habits.syncCalls, 0);
  });

  test('load with syncRemote true refreshes after backend sync', () async {
    await db.insertHabit(Habit(name: 'Before sync'));
    habits.onSync = () async {
      await db.insertHabit(Habit(name: 'After sync'));
    };

    await vm.load(syncRemote: true);

    expect(habits.syncCalls, 1);
    expect(
      vm.habits.map((h) => h.name),
      unorderedEquals(['After sync', 'Before sync']),
    );
  });

  test('archiveHabit removes habit from active list and syncs', () async {
    final id = await db.insertHabit(Habit(name: 'Walk'));
    await vm.load(syncRemote: false);
    final habit = vm.habits.single;

    await vm.archiveHabit(habit);

    expect(vm.habits, isEmpty);
    expect(habits.archiveCalls.single.id, id);
    expect(habits.archiveCalls.single.isArchived, isTrue);
    expect((await db.getHabitById(id))?.isArchived, isTrue);
  });

  test('deleteHabit removes local row when remote delete succeeds', () async {
    final id = await db.insertHabit(Habit(name: 'Drop'));
    await vm.load(syncRemote: false);

    expect(await vm.deleteHabit(vm.habits.single), isTrue);
    expect(vm.habits, isEmpty);
    expect(await db.getHabitById(id), isNull);
  });
}

class _FakeHabitService extends HabitService {
  _FakeHabitService()
    : super(
        AuthService(
          _TokenStore(),
          dio: Dio()..httpClientAdapter = _Noop(),
        ),
      );

  int syncCalls = 0;
  Future<void> Function()? onSync;
  final archiveCalls = <Habit>[];

  @override
  Future<void> syncFromBackend() async {
    syncCalls++;
    await onSync?.call();
  }

  @override
  Future<bool> setArchiveStatus(Habit habit) async {
    archiveCalls.add(habit);
    return true;
  }

  @override
  Future<bool> deleteHabit(int habitId) async => true;
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
