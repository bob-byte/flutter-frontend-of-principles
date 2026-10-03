import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('prefs', () {
    late GoalService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      service = GoalService(AuthService(SecureStore()));
    });

    test('saveGoal and getGoals round-trip via prefs', () async {
      await service.saveGoal(UserGoal(name: 'Read'));
      final goals = await service.getGoals();
      expect(goals.map((g) => g.name), ['Read']);
    });

    test('updateGoal renames existing goal', () async {
      await service.saveGoal(UserGoal(name: 'Draft'));
      final original = (await service.getGoals()).single;
      await service.updateGoal(original, original.copyWith(name: 'Final'));
      expect((await service.getGoals()).single.name, 'Final');
    });

    test('clearLocal removes cached goals', () async {
      await service.saveGoal(UserGoal(name: 'Temp'));
      await service.clearLocal();
      expect(await service.getGoals(), isEmpty);
    });

    test('getGoals(isArchived: null) includes archived on prefs', () async {
      final active = await service.saveGoal(UserGoal(name: 'Active'));
      final parked = await service.saveGoal(UserGoal(name: 'Parked'));
      await service.applyLocalArchiveStatus(parked.copyWith(isArchived: true));

      expect((await service.getGoals()).map((g) => g.name), ['Active']);
      expect(
        (await service.getGoals(isArchived: null)).map((g) => g.name).toSet(),
        {'Active', 'Parked'},
      );
      expect((await service.getGoals(isArchived: true)).map((g) => g.name), [
        'Parked',
      ]);

      // Active cache must still be updatable after archived/all fetches.
      await service.updateGoal(active, active.copyWith(name: 'Renamed'));
      expect((await service.getGoals()).map((g) => g.name), ['Renamed']);
      expect(
        (await service.getGoals(isArchived: null)).map((g) => g.name).toSet(),
        {'Renamed', 'Parked'},
      );
    });

    test('getGoals reloads prefs so all/active stay consistent', () async {
      await service.saveGoal(UserGoal(name: 'Local'));
      // Another writer updates durable prefs (same process, shared store).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(GoalService.prefsKey, [
        jsonEncode(UserGoal(name: 'FromPrefs', isArchived: false).toJson()),
        jsonEncode(UserGoal(name: 'ArchivedPrefs', isArchived: true).toJson()),
      ]);

      expect(
        (await service.getGoals(isArchived: null)).map((g) => g.name).toSet(),
        {'FromPrefs', 'ArchivedPrefs'},
      );
      expect((await service.getGoals()).map((g) => g.name), ['FromPrefs']);
      expect((await service.getGoals(isArchived: true)).map((g) => g.name), [
        'ArchivedPrefs',
      ]);
    });

    test(
      'applyLocalArchiveStatus matches unsynced row after server id',
      () async {
        await service.saveGoal(UserGoal(name: 'Parked'));
        // Simulate a push that assigned a server id onto a copy used for archive.
        await service.applyLocalArchiveStatus(
          UserGoal(name: 'Parked', id: 42, isArchived: true),
        );

        expect((await service.getGoals()).map((g) => g.name), isEmpty);
        final all = await service.getGoals(isArchived: null);
        expect(all, hasLength(1));
        expect(all.single.name, 'Parked');
        expect(all.single.isArchived, isTrue);
        expect(all.single.id, 42);
      },
    );
  });

  group('sqlite', () {
    late GoalService service;
    late LocalDb localDb;
    late String dbPath;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final created = await createTestDatabaseService();
      localDb = created.localDb;
      dbPath = created.path;
      service = GoalService(AuthService(SecureStore()), localDb: localDb);
    });

    tearDown(() async {
      await disposeTestDatabase(localDb: localDb, path: dbPath);
    });

    test(
      'getGoals defaults to active; null/archived do not stomp cache',
      () async {
        final active = await service.saveGoal(UserGoal(name: 'Active'));
        final archived = await service.saveGoal(
          UserGoal(name: 'Parked', isArchived: true),
        );
        await service.applyLocalArchiveStatus(archived);

        expect((await service.getGoals()).map((g) => g.name), ['Active']);
        expect(
          (await service.getGoals(isArchived: null)).map((g) => g.name).toSet(),
          {'Active', 'Parked'},
        );
        expect((await service.getGoals(isArchived: true)).map((g) => g.name), [
          'Parked',
        ]);

        // Cached active row must still be updatable after archived/all fetches.
        await service.updateGoal(active, active.copyWith(name: 'Renamed'));
        expect((await service.getGoals()).map((g) => g.name), ['Renamed']);
      },
    );

    test('getGoals(isArchived: null) refreshes active cache from DB', () async {
      final active = await service.saveGoal(UserGoal(name: 'Active'));
      final db = await localDb.database;
      await db.delete(
        'user_goals',
        where: 'localId = ?',
        whereArgs: [active.localId],
      );
      final newLocalId = await db.insert('user_goals', {
        'name': 'Replacement',
        'isCompleted': 0,
        'isArchived': 0,
        'lastModified': DateTime.now().toUtc().toIso8601String(),
      });

      expect((await service.getGoals(isArchived: null)).map((g) => g.name), [
        'Replacement',
      ]);
      expect(await service.getGoalByLocalId(newLocalId), isNotNull);
      // Stale active cache would still return the deleted row by localId.
      expect(await service.getGoalByLocalId(active.localId!), isNull);
    });
  });
}
