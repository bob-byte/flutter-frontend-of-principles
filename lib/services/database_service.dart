import 'package:sqflite/sqflite.dart';
import '../core/storage/local_db.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/progress_value.dart';
import '../models/user_goal.dart';

class DatabaseService {
  DatabaseService._(this._localDb);

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
  Future<void> reassignHabitId(int fromId, int toId) async {
    if (fromId == toId) return;
    final db = await database;
    await db.transaction((txn) async {
      final conflict = await txn.query(
        'habits',
        where: 'id = ?',
        whereArgs: [toId],
      );
      if (conflict.isNotEmpty) {
        await txn.delete('habits', where: 'id = ?', whereArgs: [fromId]);
        return;
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
    });
  }

  Future<void> insertOrUpdateHabitWithBackendId(Habit habit) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'habits',
        where: 'id = ?',
        whereArgs: [habit.id],
      );
      if (existing.isNotEmpty) {
        final map = Map<String, dynamic>.from(habit.toMap());
        map['serverId'] = habit.serverId ?? habit.id;
        // In-progress sync does not include archive status; keep the local flag.
        map['isArchived'] = existing.first['isArchived'];
        if (habit.targetGoalId == null) {
          map['targetGoalId'] = existing.first['targetGoalId'];
        }
        if (habit.targetGoal.trim().isEmpty) {
          map['targetGoal'] = existing.first['targetGoal'];
        }
        if (habit.reminders.isEmpty && existing.first['reminders'] != null) {
          map['reminders'] = existing.first['reminders'];
        }
        await txn.update('habits', map, where: 'id = ?', whereArgs: [habit.id]);
      } else {
        final map = Map<String, dynamic>.from(habit.toMap());
        map['serverId'] = habit.serverId ?? habit.id;
        await txn.insert('habits', map);
      }
    });
  }

  Future<void> upsertArchivedHabit({
    required int id,
    required String name,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'habits',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty) {
        await txn.update(
          'habits',
          {'isArchived': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.insert(
          'habits',
          Habit(id: id, name: name, isArchived: true, serverId: id).toMap(),
        );
      }
    });
  }

  Future<List<Habit>> getAllHabits({bool isArchived = false}) async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'isArchived = ?',
      whereArgs: [isArchived ? 1 : 0],
    );
    return maps.map((e) => Habit.fromMap(e)).toList();
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
    final db = await database;
    return db.transaction((txn) async {
      // Do this explicitly instead of relying on SQLite foreign-key cascading,
      // which is disabled by default unless PRAGMA foreign_keys is enabled.
      await txn.delete('habit_records', where: 'habitId = ?', whereArgs: [id]);
      return txn.delete('habits', where: 'id = ?', whereArgs: [id]);
    });
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
    int value,
  ) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);
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

    final row = {
      'habitId': habitId,
      'date': dateString,
      'status': status.index,
      'value': value,
      'lastModified': DateTime.now().toUtc().toIso8601String(),
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
    final db = await database;
    final maps = await db.query(
      'habit_records',
      where: 'habitId = ?',
      whereArgs: [habitId],
    );
    return maps.map((e) => HabitRecord.fromMap(e)).toList();
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
    final db = await database;
    final existing = goal.id == null
        ? <Map<String, Object?>>[]
        : await db.query(
            'user_goals',
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
    if (existing.isNotEmpty) {
      await db.update(
        'user_goals',
        row,
        where: 'localId = ?',
        whereArgs: [existing.first['localId']],
      );
    } else if (goal.localId != null) {
      await db.update(
        'user_goals',
        row,
        where: 'localId = ?',
        whereArgs: [goal.localId],
      );
    } else {
      await db.insert('user_goals', row);
    }
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
