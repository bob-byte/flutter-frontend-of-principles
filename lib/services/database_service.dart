import 'package:sqflite/sqflite.dart';
import '../core/storage/local_db.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/progress_value.dart';
import '../models/user_goal.dart';

/// One progress upsert for [applyHabitRecordWrites].
typedef HabitRecordWrite = ({
  int habitId,
  DateTime date,
  int value,
  int? existingId,
  DateTime? lastModified,
});

const _kSqliteBindLimit = 400;

List<List<int>> _idChunks(Iterable<int> ids) {
  final list = ids.toList();
  if (list.isEmpty) return const [];
  return [
    for (var i = 0; i < list.length; i += _kSqliteBindLimit)
      list.sublist(
        i,
        i + _kSqliteBindLimit > list.length
            ? list.length
            : i + _kSqliteBindLimit,
      ),
  ];
}

String _inPlaceholders(int count) => List.filled(count, '?').join(',');

String _habitDateKey(DateTime date) => date.toIso8601String().substring(0, 10);

class DatabaseService {
  DatabaseService._(this._localDb);

  /// Defaults to [LocalDb.instance]. Prefer injecting the Provider instance
  /// so tests and the app never open a second handle to the same file.
  static final DatabaseService _instance = DatabaseService._(LocalDb.instance);

  factory DatabaseService({LocalDb? localDb}) {
    if (localDb != null) return DatabaseService._(localDb);
    return _instance;
  }

  final LocalDb _localDb;

  Future<Database> get database async => _localDb.database;

  // --- HABITS (Звички) ---
  Future<int> insertHabit(Habit habit) async {
    final db = await database;
    final map = Map<String, dynamic>.from(habit.toMap())
      ..removeWhere((key, value) => value == null);
    // Never send a null PK; SQLite must generate the local id (MAUI LocalId).
    map.remove('id');
    return await db.insert('habits', map);
  }

  /// After the backend assigns an id, point the local row (and its records) at it.
  ///
  /// Returns the new local id if a *different* local-only habit occupied [toId]
  /// and had to be moved. Callers must repoint the sync queue in that case.
  Future<int?> reassignHabitId(int fromId, int toId) async {
    if (fromId == toId) return null;
    final db = await database;
    return db.transaction((txn) async {
      final vacated = await _vacateLocalOnlyHabitAt(txn, toId);
      final conflict = await txn.query(
        'habits',
        where: 'id = ?',
        whereArgs: [toId],
      );
      if (conflict.isNotEmpty) {
        await txn.delete(
          'habit_records',
          where: 'habitId = ?',
          whereArgs: [fromId],
        );
        await txn.delete('habits', where: 'id = ?', whereArgs: [fromId]);
        return vacated;
      }
      await txn.update(
        'habits',
        {'id': toId, 'serverId': toId},
        where: 'id = ?',
        whereArgs: [fromId],
      );
      await txn.update(
        'habit_records',
        {'habitId': toId},
        where: 'habitId = ?',
        whereArgs: [fromId],
      );
      return vacated;
    });
  }

  /// Moves a local-only row off [id] so a server-backed habit can use that PK.
  /// Returns the new local id, or null when nothing was moved.
  Future<int?> vacateLocalOnlyHabitOccupyingId(int id) async {
    final db = await database;
    return db.transaction((txn) => _vacateLocalOnlyHabitAt(txn, id));
  }

  Future<int?> _vacateLocalOnlyHabitAt(DatabaseExecutor txn, int id) async {
    final rows = await txn.query('habits', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final serverId = rows.first['serverId'] as int?;
    if (serverId != null && serverId != 0 && serverId == id) return null;

    final map = Map<String, dynamic>.from(rows.first)..remove('id');
    map['serverId'] = null;
    final newId = await txn.insert('habits', map);
    await txn.update(
      'habit_records',
      {'habitId': newId},
      where: 'habitId = ?',
      whereArgs: [id],
    );
    await txn.delete('habits', where: 'id = ?', whereArgs: [id]);
    return newId;
  }

  Future<void> insertOrUpdateHabitWithBackendId(
    Habit habit, {
    bool applyArchiveStatus = false,
    bool replaceReminders = false,
  }) async {
    final backendId = habit.serverId ?? habit.id;
    if (backendId == null) return;
    final db = await database;
    await db.transaction((txn) async {
      var existing = await txn.query(
        'habits',
        where: 'serverId = ?',
        whereArgs: [backendId],
        limit: 1,
      );
      if (existing.isEmpty) {
        existing = await txn.query(
          'habits',
          where: 'id = ?',
          whereArgs: [backendId],
          limit: 1,
        );
      }

      final map = Map<String, dynamic>.from(habit.toMap());
      map['id'] = existing.isNotEmpty ? existing.first['id'] : backendId;
      map['serverId'] = backendId;
      if (!applyArchiveStatus && existing.isNotEmpty) {
        map['isArchived'] = existing.first['isArchived'];
      }
      if (habit.targetGoalId == null && existing.isNotEmpty) {
        map['targetGoalId'] = existing.first['targetGoalId'];
      }
      if (habit.targetGoal.trim().isEmpty && existing.isNotEmpty) {
        map['targetGoal'] = existing.first['targetGoal'];
      }
      if (!replaceReminders &&
          habit.reminders.isEmpty &&
          existing.isNotEmpty &&
          existing.first['reminders'] != null) {
        map['reminders'] = existing.first['reminders'];
      }

      if (existing.isNotEmpty) {
        await txn.update(
          'habits',
          map,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert('habits', map);
      }
    });
  }

  Future<void> upsertArchivedHabit({
    required int id,
    required String name,
  }) async {
    final existing = await getHabitById(id);
    await upsertArchivedHabits(
      [(id: id, name: name)],
      existingLocalIds: {if (existing != null) id},
    );
  }

  /// Archives many habits in one transaction. Pass known sqlite ids in
  /// [existingLocalIds] so the batch can skip existence queries.
  Future<void> upsertArchivedHabits(
    List<({int id, String name})> items, {
    required Set<int> existingLocalIds,
  }) async {
    if (items.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        if (existingLocalIds.contains(item.id)) {
          batch.update(
            'habits',
            {'isArchived': 1},
            where: 'id = ?',
            whereArgs: [item.id],
          );
        } else {
          batch.insert(
            'habits',
            Habit(
              id: item.id,
              name: item.name,
              isArchived: true,
              serverId: item.id,
            ).toMap(),
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  /// Inserts or updates habits without a per-row existence query.
  Future<void> upsertHabits(
    List<Habit> habits, {
    required Set<int> existingLocalIds,
  }) async {
    if (habits.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final habit in habits) {
        final map = Map<String, dynamic>.from(habit.toMap());
        final id = habit.id;
        if (id != null && existingLocalIds.contains(id)) {
          batch.update('habits', map, where: 'id = ?', whereArgs: [id]);
        } else {
          batch.insert('habits', map);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Habit>> getAllHabits({bool? isArchived = false}) async {
    final db = await database;
    final maps = isArchived == null
        ? await db.query('habits')
        : await db.query(
            'habits',
            where: 'isArchived = ?',
            whereArgs: [isArchived ? 1 : 0],
          );
    return maps.map((e) => Habit.fromMap(e)).toList();
  }

  Future<List<UserGoal>> getAllGoals() async {
    final db = await database;
    final rows = await db.query('user_goals');
    return rows.map((row) => UserGoal.fromJson(row)).toList();
  }

  Future<void> deleteGoalByServerId(int serverId) async {
    await deleteGoalsByServerIds([serverId]);
  }

  Future<void> deleteGoalsByServerIds(Iterable<int> serverIds) async {
    final unique = serverIds.where((id) => id != 0).toSet().toList();
    if (unique.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final chunk in _idChunks(unique)) {
        final placeholders = _inPlaceholders(chunk.length);
        await txn.update(
          'habits',
          {'targetGoalId': null},
          where: 'targetGoalId IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'user_goals',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }

  Future<Habit?> getHabitById(int id) async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Habit.fromMap(maps.first);
  }

  Future<Habit?> getHabitByServerId(int serverId) async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'serverId = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Habit.fromMap(maps.first);
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    return await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(int id) async {
    return deleteHabitsByIds([id]);
  }

  Future<int> deleteHabitsByIds(Iterable<int> ids) async {
    final unique = ids.where((id) => id != 0).toSet().toList();
    if (unique.isEmpty) return 0;
    final db = await database;
    var deleted = 0;
    await db.transaction((txn) async {
      for (final chunk in _idChunks(unique)) {
        final placeholders = _inPlaceholders(chunk.length);
        await txn.delete(
          'habit_records',
          where: 'habitId IN ($placeholders)',
          whereArgs: chunk,
        );
        deleted += await txn.delete(
          'habits',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
    return deleted;
  }

  // --- HABIT RECORDS (Відмітки) ---

  Future<void> setHabitRecordStatus(
    int habitId,
    DateTime date,
    HabitStatus status, {
    bool skipSync = false,
  }) async {
    await setHabitRecordValue(habitId, date, progressValueFromStatus(status));
  }

  Future<void> setHabitRecordValue(
    int habitId,
    DateTime date,
    int value, {
    DateTime? lastModified,
  }) async {
    final db = await database;
    await _writeHabitRecordValue(
      db,
      habitId,
      date,
      value,
      lastModified: lastModified,
    );
  }

  /// Writes many progress rows for one habit in a single transaction.
  Future<void> setHabitRecordValuesBatch(
    int habitId,
    List<({DateTime date, int value})> entries, {
    DateTime? lastModified,
  }) async {
    if (entries.isEmpty) return;
    final existing = await getAllRecordsForHabit(habitId);
    final byDate = <String, HabitRecord>{
      for (final record in existing) _habitDateKey(record.date): record,
    };
    final writes = <HabitRecordWrite>[
      for (final entry in entries)
        if (byDate[_habitDateKey(entry.date)]?.value != entry.value)
          (
            habitId: habitId,
            date: entry.date,
            value: entry.value,
            existingId: byDate[_habitDateKey(entry.date)]?.id,
            lastModified: lastModified,
          ),
    ];
    await applyHabitRecordWrites(writes);
  }

  /// Applies progress writes without a SELECT per row.
  Future<void> applyHabitRecordWrites(List<HabitRecordWrite> writes) async {
    if (writes.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final write in writes) {
        _queueHabitRecordWrite(batch, write);
      }
      await batch.commit(noResult: true);
    });
  }

  void _queueHabitRecordWrite(Batch batch, HabitRecordWrite write) {
    final dateString = _habitDateKey(write.date);
    if (write.value == kProgressUnknown) {
      if (write.existingId != null) {
        batch.delete(
          'habit_records',
          where: 'id = ?',
          whereArgs: [write.existingId],
        );
      }
      return;
    }
    final row = {
      'habitId': write.habitId,
      'date': dateString,
      'status': habitStatusFromProgressValue(write.value).index,
      'value': write.value,
      'lastModified': (write.lastModified ?? DateTime.now().toUtc())
          .toIso8601String(),
    };
    if (write.existingId != null) {
      batch.update(
        'habit_records',
        row,
        where: 'id = ?',
        whereArgs: [write.existingId],
      );
    } else {
      batch.insert('habit_records', row);
    }
  }

  Future<void> _writeHabitRecordValue(
    DatabaseExecutor db,
    int habitId,
    DateTime date,
    int value, {
    DateTime? lastModified,
  }) async {
    final dateString = _habitDateKey(date);
    final status = habitStatusFromProgressValue(value);

    final existing = await db.query(
      'habit_records',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateString],
    );

    if (value == kProgressUnknown) {
      if (existing.isNotEmpty) {
        await db.delete(
          'habit_records',
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      return;
    }

    if (existing.isNotEmpty && existing.first['value'] == value) {
      return;
    }

    final row = {
      'habitId': habitId,
      'date': dateString,
      'status': status.index,
      'value': value,
      'lastModified': (lastModified ?? DateTime.now().toUtc())
          .toIso8601String(),
    };

    if (existing.isNotEmpty) {
      await db.update(
        'habit_records',
        row,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('habit_records', row);
    }
  }

  // Отримати всі відмітки за діапазон дат (наприклад, для відмальовки 7 днів на головному екрані)
  Future<List<HabitRecord>> getRecordsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final startString = start.toIso8601String().substring(0, 10);
    final endString = end.toIso8601String().substring(0, 10);

    final maps = await db.query(
      'habit_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startString, endString],
    );

    return maps.map((e) => HabitRecord.fromMap(e)).toList();
  }

  Future<List<HabitRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query('habit_records');
    return maps.map((e) => HabitRecord.fromMap(e)).toList();
  }

  Future<List<HabitRecord>> getAllRecordsForHabit(int habitId) async {
    return getRecordsForHabitIds([habitId]);
  }

  Future<List<HabitRecord>> getRecordsForHabitIds(
    Iterable<int> habitIds,
  ) async {
    final unique = habitIds.where((id) => id != 0).toSet();
    if (unique.isEmpty) return const [];
    final db = await database;
    final out = <HabitRecord>[];
    for (final chunk in _idChunks(unique)) {
      final rows = await db.query(
        'habit_records',
        where: 'habitId IN (${_inPlaceholders(chunk.length)})',
        whereArgs: chunk,
      );
      out.addAll(rows.map(HabitRecord.fromMap));
    }
    return out;
  }

  Future<HabitRecord?> findRecord(int habitId, DateTime date) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);
    final maps = await db.query(
      'habit_records',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateString],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HabitRecord.fromMap(maps.first);
  }

  Future<void> upsertGoal(UserGoal goal) async {
    await upsertGoals([goal]);
  }

  Future<void> upsertGoals(List<UserGoal> goals) async {
    if (goals.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final goal in goals) {
        final existing = goal.localId != null
            ? <Map<String, Object?>>[]
            : goal.id == null
            ? <Map<String, Object?>>[]
            : await txn.query(
                'user_goals',
                columns: ['localId'],
                where: 'id = ?',
                whereArgs: [goal.id],
                limit: 1,
              );
        final row = {
          'id': goal.id,
          'name': goal.name,
          'isCompleted': goal.isCompleted ? 1 : 0,
          'lastModified': goal.lastModified.toUtc().toIso8601String(),
        };
        final localId =
            goal.localId ??
            (existing.isEmpty ? null : existing.first['localId']);
        if (localId != null) {
          batch.update(
            'user_goals',
            row,
            where: 'localId = ?',
            whereArgs: [localId],
          );
        } else {
          batch.insert('user_goals', row);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int?> goalServerId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'user_goals',
      columns: ['id'],
      where: 'localId = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  /// Backend goal id only. Local SQLite [localId] values are not valid FKs.
  Future<int?> resolveGoalServerId(int? localOrServerId) async {
    if (localOrServerId == null || localOrServerId == 0) return null;
    final db = await database;
    final byServerId = await db.query(
      'user_goals',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [localOrServerId],
      limit: 1,
    );
    final serverId = byServerId.isEmpty ? null : byServerId.first['id'] as int?;
    if (serverId != null && serverId != 0) return serverId;

    final byLocalId = await db.query(
      'user_goals',
      columns: ['id'],
      where: 'localId = ?',
      whereArgs: [localOrServerId],
      limit: 1,
    );
    final fromLocal = byLocalId.isEmpty ? null : byLocalId.first['id'] as int?;
    if (fromLocal != null && fromLocal != 0) return fromLocal;
    return null;
  }

  Future<DateTime?> goalLastModified(int localId) async {
    return _readDate('user_goals', 'localId', localId);
  }

  Future<int?> habitServerId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'habits',
      columns: ['serverId', 'id'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['serverId'] as int?;
  }

  Future<DateTime?> habitLastModified(int localId) async {
    return _readDate('habits', 'id', localId);
  }

  Future<DateTime?> userLastModified() async {
    final db = await database;
    final rows = await db.query('users', columns: ['lastModified'], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse('${rows.first['lastModified']}')?.toUtc();
  }

  Future<DateTime?> reminderLastModified(int localId) async {
    return _readDate('reminders', 'localId', localId);
  }

  Future<DateTime?> _readDate(String table, String key, int id) async {
    final db = await database;
    final rows = await db.query(
      table,
      columns: ['lastModified'],
      where: '$key = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse('${rows.first['lastModified']}')?.toUtc();
  }
}
