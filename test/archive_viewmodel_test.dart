import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/viewmodels/archive_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeHabitService habits;
  late ArchiveViewModel vm;
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
    vm = ArchiveViewModel(db, habits);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await disposeTestDatabase(localDb: localDb, path: dbPath);
  });

  test('showBanner and hideBanner update prefs', () async {
    vm.showBanner();
    expect(vm.showInfoBanner, isTrue);

    await vm.hideBanner();
    expect(vm.showInfoBanner, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenArchiveInfo'), isTrue);
  });

  test('loadHabits prefers HabitService archived list', () async {
    habits.archived = [Habit(id: 3, name: 'Old', isArchived: true)];
    await vm.loadHabits();
    expect(vm.isLoading, isFalse);
    expect(vm.archivedHabits.map((h) => h.name), ['Old']);
  });

  test('unarchiveHabit updates local row and removes from list', () async {
    final id = await db.insertHabit(
      Habit(name: 'Archived walk', isArchived: true),
    );
    habits.archived = [Habit(id: id, name: 'Archived walk', isArchived: true)];
    await vm.loadHabits();

    await vm.unarchiveHabit(vm.archivedHabits.single);

    expect(vm.archivedHabits, isEmpty);
    expect(habits.archiveCalls, hasLength(1));
    expect(habits.archiveCalls.single.isArchived, isFalse);
    expect((await db.getHabitById(id))?.isArchived, isFalse);
  });

  test('deleteHabit removes remote then local when delete succeeds', () async {
    final id = await db.insertHabit(
      Habit(name: 'Drop me', isArchived: true),
    );
    habits.archived = [Habit(id: id, name: 'Drop me', isArchived: true)];
    await vm.loadHabits();

    expect(await vm.deleteHabit(vm.archivedHabits.single), isTrue);
    expect(vm.archivedHabits, isEmpty);
    expect(habits.deletedIds, [id]);
    expect(await db.getHabitById(id), isNull);
  });

  test('deleteHabit keeps local row when remote delete fails', () async {
    final id = await db.insertHabit(
      Habit(name: 'Keep me', isArchived: true),
    );
    habits
      ..archived = [Habit(id: id, name: 'Keep me', isArchived: true)]
      ..deleteOk = false;
    await vm.loadHabits();

    expect(await vm.deleteHabit(vm.archivedHabits.single), isFalse);
    expect(vm.archivedHabits, hasLength(1));
    expect(await db.getHabitById(id), isNotNull);
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

  List<Habit> archived = [];
  final archiveCalls = <Habit>[];
  final deletedIds = <int>[];
  bool deleteOk = true;

  @override
  Future<List<Habit>> getArchivedHabits() async => List.of(archived);

  @override
  Future<bool> setArchiveStatus(Habit habit) async {
    archiveCalls.add(habit);
    return true;
  }

  @override
  Future<bool> deleteHabit(int habitId, {int? serverId}) async {
    deletedIds.add(habitId);
    return deleteOk;
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
