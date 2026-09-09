import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/day_change_notifier.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/utils/date_helpers.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/completion_feedback.dart';
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
    vm.dispose();
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('selectDate normalizes to calendar day', () {
    vm.selectDate(DateTime(2026, 9, 4, 15, 30));
    expect(vm.selectedDate, DateTime(2026, 9, 4));
  });

  test('refreshForNewDay advances tip selection to the new today', () {
    final yesterday = dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    vm.dates = habitProgressDates(now: yesterday);
    vm.selectedDate = yesterday;

    final today = dateOnly(DateTime.now());
    vm.refreshForNewDay(now: today);

    expect(vm.dates.last, today);
    expect(vm.selectedDate, today);
    expect(vm.dates.length, kHabitProgressDateCount);
  });

  test('refreshForNewDay keeps an older explicit selection', () {
    final today = dateOnly(DateTime.now());
    final older = today.subtract(const Duration(days: 5));
    vm.dates = habitProgressDates(now: today.subtract(const Duration(days: 1)));
    vm.selectedDate = older;

    vm.refreshForNewDay(now: today);

    expect(vm.dates.last, today);
    expect(vm.selectedDate, older);
  });

  test('day change notifier listener advances tip day', () {
    var now = DateTime(2026, 9, 8, 10);
    final dayChange = DayChangeNotifier(
      clock: () => now,
      observeLifecycle: false,
      scheduleTimer: false,
    );
    addTearDown(dayChange.dispose);

    final linked = HabitProgressViewModel(
      habits,
      dbService: db,
      dayChange: dayChange,
    );
    addTearDown(linked.dispose);

    linked.refreshForNewDay(now: DateTime(2026, 9, 8));
    expect(linked.selectedDate, DateTime(2026, 9, 8));

    now = DateTime(2026, 9, 9, 0, 5);
    expect(dayChange.checkForDayChange(), isTrue);
    expect(linked.selectedDate, DateTime(2026, 9, 9));
    expect(linked.dates.last, DateTime(2026, 9, 9));
  });

  test('clear resets habits and records', () {
    vm.habits = [Habit(id: 1, name: 'Walk')];
    vm.clear();
    expect(vm.habits, isEmpty);
    expect(vm.records, isEmpty);
    expect(vm.isLoading, isFalse);
  });

  test('goalFilterOptions lists unique goals with undefined first', () {
    final options = habitGoalFilterOptions([
      Habit(id: 1, name: 'B', targetGoal: 'Career', targetGoalId: 2),
      Habit(id: 2, name: 'A'),
    ]);
    expect(options.first.isUndefined, isTrue);
    expect(options, hasLength(2));
  });

  test('load with syncRemote false reads only active local habits', () async {
    await db.insertHabit(Habit(name: 'Active'));
    await db.insertHabit(Habit(name: 'Archived', isArchived: true));

    await vm.load(syncRemote: false);

    expect(vm.isLoading, isFalse);
    expect(vm.habits.map((h) => h.name), ['Active']);
    expect(habits.syncCalls, 0);
  });

  test('load defaults to local-only', () async {
    await db.insertHabit(Habit(name: 'Walk'));

    await vm.load();

    expect(habits.syncCalls, 0);
    expect(vm.habits.map((h) => h.name), ['Walk']);
  });

  test('concurrent load joins a single in-flight read', () async {
    await db.insertHabit(Habit(name: 'Walk'));
    habits.onSync = () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    };

    await Future.wait([
      vm.load(syncRemote: true),
      vm.load(syncRemote: true),
      vm.load(syncRemote: true),
    ]);

    expect(habits.syncCalls, 1);
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

  test('toggleHabitStatus completes, clears, and completes again', () async {
    final id = await db.insertHabit(Habit(name: 'Walk'));
    await vm.load(syncRemote: false);
    final day = dateOnly(DateTime.now());

    expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.none);

    await vm.toggleHabitStatus(id, day);
    expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.completed);

    await vm.toggleHabitStatus(id, day);
    expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.none);

    await vm.toggleHabitStatus(id, day);
    expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.completed);
  });

  test('toggleHabitStatus does not park on skipped after uncomplete', () async {
    final id = await db.insertHabit(Habit(name: 'Run'));
    await vm.load(syncRemote: false);
    final day = dateOnly(DateTime.now());

    await vm.toggleHabitStatus(id, day);
    await vm.toggleHabitStatus(id, day);

    expect(vm.getStatusForHabitAndDate(id, day), isNot(HabitStatus.skipped));
    expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.none);
  });

  test('default not-done filter hides completed and skipped habits', () {
    final day = dateOnly(DateTime.now());
    vm.selectedDate = day;
    vm.habits = [
      Habit(id: 1, name: 'Open'),
      Habit(id: 2, name: 'Done'),
      Habit(id: 3, name: 'Skip'),
    ];
    vm.records = [
      HabitRecord(habitId: 2, date: day, status: HabitStatus.completed),
      HabitRecord(habitId: 3, date: day, status: HabitStatus.skipped),
    ];

    expect(vm.filteredHabits.map((h) => h.name), ['Open']);
    expect(vm.hasActiveFilters, isFalse);

    vm.setDayStatusFilter(HabitDayStatusFilter.all);
    expect(vm.filteredHabits.map((h) => h.name), ['Done', 'Open', 'Skip']);
    expect(vm.hasActiveFilters, isTrue);
  });

  test('goal filter uses grouping keys and clear restores defaults', () {
    vm.habits = [
      Habit(id: 1, name: 'Read', targetGoal: 'Career', targetGoalId: 4),
      Habit(id: 2, name: 'Walk'),
    ];

    vm.setGoalFilter('id:4');
    expect(vm.filteredHabits.map((h) => h.name), ['Read']);
    expect(vm.goalFilterOptions, hasLength(2));

    vm.setGoalFilter(kUndefinedHabitGoalKey);
    expect(vm.filteredHabits.map((h) => h.name), ['Walk']);

    vm.setDayStatusFilter(HabitDayStatusFilter.all);
    vm.setDueFilter(HabitDueFilter.notDue);
    vm.clearFilters();
    expect(vm.dayStatusFilter, HabitDayStatusFilter.notDone);
    expect(vm.dueFilter, HabitDueFilter.due);
    expect(vm.selectedGoalFilter, isNull);
    expect(vm.hasActiveFilters, isFalse);
    expect(vm.filteredHabits.map((h) => h.name), ['Read', 'Walk']);
  });

  test(
    'completing a habit stays visible until the celebration hold ends',
    () async {
      final id = await db.insertHabit(Habit(name: 'Walk'));
      await vm.load(syncRemote: false);
      final day = dateOnly(DateTime.now());

      await vm.toggleHabitStatus(id, day);

      expect(vm.getStatusForHabitAndDate(id, day), HabitStatus.completed);
      expect(vm.isHeldCompletedHabit(id), isTrue);
      expect(vm.filteredHabits.map((h) => h.name), ['Walk']);

      await Future<void>.delayed(
        kCompletionCelebrationDuration + const Duration(milliseconds: 40),
      );

      expect(vm.isHeldCompletedHabit(id), isFalse);
      expect(vm.filteredHabits, isEmpty);
    },
  );
}

class _FakeHabitService extends HabitService {
  _FakeHabitService()
    : super(
        AuthService(_TokenStore(), dio: Dio()..httpClientAdapter = _Noop()),
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
  Future<bool> deleteHabit(int habitId, {int? serverId}) async => true;
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
