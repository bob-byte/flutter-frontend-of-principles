import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb({this.pathOverride});

  /// Shared app connection. Do not `LocalDb()` another handle to [fileName].
  static final LocalDb instance = LocalDb();

  static const fileName = 'principles.db';
  static const schemaVersion = 10;
  static const _legacyMigratedKey = 'local_db_legacy_migrated_v2';

  final String? pathOverride;
  Database? _db;
  Future<Database>? _opening;
  bool _migratingLegacy = false;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite LocalDb is not available on web.');
    }
    if (_db != null) return _db!;
    final opening = _opening;
    if (opening != null) return opening;
    final run = _openAndMigrate();
    _opening = run;
    try {
      return await run;
    } finally {
      if (identical(_opening, run)) {
        _opening = null;
      }
    }
  }

  Future<Database> _openAndMigrate() async {
    final opened = await _open();
    _db = opened;
    await _migrateLegacyStores();
    return opened;
  }

  Future<Database?> get databaseOrNull async {
    if (kIsWeb) return null;
    return database;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final dbPath = pathOverride ?? join(await getDatabasesPath(), fileName);
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await _createQueueTable(db);
        await _createDomainTables(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _upgradeQueueTable(db);
          await _createDomainTables(db);
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            'user_goals',
            'isCompleted',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await _upgradeScheduleColumns(db);
        }
        if (oldVersion < 5) {
          await _addColumnIfMissing(
            db,
            'users',
            'hasSeenRoadGuide',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 7) {
          await _createTaskSubtasksTable(db);
        }
        if (oldVersion < 8) {
          await _createAiConversationTables(db);
        }
        if (oldVersion < 9) {
          await _createPerfIndexes(db);
        }
        if (oldVersion < 10) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_habits_serverId ON habits (serverId)',
          );
        }
      },
    );
  }

  Future<void> _createPerfIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_records_habitId_date '
      'ON habit_records (habitId, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_isDone ON tasks (isDone)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_serverId ON tasks (serverId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks (dueDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_unprocessed '
      'ON SyncQueueItem (isProcessed, handlerType)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habits_serverId ON habits (serverId)',
    );
  }

  Future<void> _upgradeScheduleColumns(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'tasks', 'endDate', 'TEXT NULL');
    await _addColumnIfMissing(
      db,
      'tasks',
      'allDay',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'tasks',
      'remindersJson',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await _addColumnIfMissing(
      db,
      'tasks',
      'constantReminder',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'tasks',
      'repeatJson',
      "TEXT NOT NULL DEFAULT '{}'",
    );
    await _addColumnIfMissing(
      db,
      'tasks',
      'constantNotificationRequestId',
      'INTEGER NULL',
    );
    await _addColumnIfMissing(db, 'habits', 'endDate', 'TEXT NULL');
    await _addColumnIfMissing(
      db,
      'habits',
      'allDay',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'habits',
      'constantReminder',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _createQueueTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS SyncQueueItem (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        entityId INTEGER NULL,
        entityLocalId INTEGER NULL,
        handlerType TEXT NOT NULL,
        operation TEXT NOT NULL,
        payloadJson TEXT NULL,
        lastModified TEXT NULL,
        isProcessing INTEGER DEFAULT 0,
        isProcessed INTEGER DEFAULT 0,
        retryCount INTEGER DEFAULT 0,
        nextRetryAt TEXT NULL,
        lastRetryAt TEXT NULL,
        processedAt TEXT NULL,
        errorMessage TEXT NULL,
        isFailed INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_unprocessed '
      'ON SyncQueueItem (isProcessed, handlerType)',
    );
  }

  Future<void> _upgradeQueueTable(DatabaseExecutor db) async {
    await _createQueueTable(db);
    await _addColumnIfMissing(db, 'SyncQueueItem', 'lastRetryAt', 'TEXT');
    await _addColumnIfMissing(db, 'SyncQueueItem', 'processedAt', 'TEXT');
  }

  Future<void> _createDomainTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        id INTEGER,
        name TEXT,
        mainSlogan TEXT,
        mission TEXT,
        email TEXT,
        gender INTEGER,
        hasSeenRoadGuide INTEGER NOT NULL DEFAULT 0,
        lastModified TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_goals (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        id INTEGER,
        name TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        lastModified TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetGoal TEXT,
        targetGoalId INTEGER,
        isFlexible INTEGER DEFAULT 1,
        frequency TEXT,
        reminderTime TEXT,
        difficulty INTEGER DEFAULT 5,
        notes TEXT,
        isArchived INTEGER DEFAULT 0,
        reminders TEXT,
        lastModified TEXT,
        serverId INTEGER,
        endDate TEXT NULL,
        allDay INTEGER NOT NULL DEFAULT 0,
        constantReminder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habits_serverId ON habits (serverId)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        value INTEGER DEFAULT -1,
        lastModified TEXT,
        serverId INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_records_date ON habit_records (date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_records_habitId_date '
      'ON habit_records (habitId, date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        id INTEGER,
        title TEXT,
        description TEXT,
        time TEXT,
        isEnabled INTEGER DEFAULT 0,
        userNotificationRequestId INTEGER DEFAULT 1,
        lastModified TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT NOT NULL UNIQUE,
        serverId INTEGER,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        isDone INTEGER NOT NULL DEFAULT 0,
        theme TEXT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        createdAt TEXT NOT NULL,
        dueDate TEXT NULL,
        endDate TEXT NULL,
        allDay INTEGER NOT NULL DEFAULT 0,
        remindersJson TEXT NOT NULL DEFAULT '[]',
        constantReminder INTEGER NOT NULL DEFAULT 0,
        repeatJson TEXT NOT NULL DEFAULT '{}',
        constantNotificationRequestId INTEGER NULL,
        completedAt TEXT NULL,
        lastModified TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_isDone ON tasks (isDone)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_serverId ON tasks (serverId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks (dueDate)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_themes (
        name TEXT PRIMARY KEY,
        colorArgb INTEGER NOT NULL
      )
    ''');
    await _createTaskSubtasksTable(db);
    await _createAiConversationTables(db);
  }

  Future<void> _createTaskSubtasksTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_subtasks (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        isDone INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_subtasks_taskId ON task_subtasks (taskId)',
    );
  }

  Future<void> _createAiConversationTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_conversations (
        id TEXT PRIMARY KEY,
        serverId INTEGER,
        title TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        hasAiTitle INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_conversations_updatedAt '
      'ON ai_conversations (updatedAt)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_messages_conversationId '
      'ON ai_messages (conversationId)',
    );
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _migrateLegacyStores() async {
    if (_migratingLegacy || _db == null) return;
    _migratingLegacy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_legacyMigratedKey) == true) return;

      await _migrateHabitsDatabase();
      await _migrateTasksDatabase();
      await _migratePrefs(prefs);
      await prefs.setBool(_legacyMigratedKey, true);
    } catch (e) {
      debugPrint('Legacy LocalDb migration failed: $e');
    } finally {
      _migratingLegacy = false;
    }
  }

  Future<void> _migrateHabitsDatabase() async {
    final db = _db!;
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM habits'),
    );
    if ((existing ?? 0) > 0) return;

    final oldPath = join(await getDatabasesPath(), 'principles_habits.db');
    if (!await databaseExists(oldPath)) return;

    final old = await openDatabase(oldPath, readOnly: true);
    try {
      final habits = await old.query('habits');
      for (final row in habits) {
        final map = Map<String, Object?>.from(row);
        map.putIfAbsent(
          'lastModified',
          () => DateTime.now().toUtc().toIso8601String(),
        );
        await db.insert(
          'habits',
          map,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      try {
        final records = await old.query('habit_records');
        for (final row in records) {
          await db.insert(
            'habit_records',
            row,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (e) {
        debugPrint('Legacy habit_records copy skipped: $e');
      }
    } finally {
      await old.close();
    }
  }

  Future<void> _migrateTasksDatabase() async {
    final db = _db!;
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tasks'),
    );
    if ((existing ?? 0) > 0) return;

    final oldPath = join(await getDatabasesPath(), 'principles_tasks.db');
    if (!await databaseExists(oldPath)) return;

    final old = await openDatabase(oldPath, readOnly: true);
    try {
      final tasks = await old.query('tasks');
      for (final row in tasks) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await db.insert('tasks', {
          ...row,
          'serverId': int.tryParse(id),
          'lastModified': DateTime.now().toUtc().toIso8601String(),
          'isDeleted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      try {
        final themes = await old.query('task_themes');
        for (final row in themes) {
          await db.insert(
            'task_themes',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint('Legacy task_themes copy skipped: $e');
      }
    } finally {
      await old.close();
    }
  }

  Future<void> _migratePrefs(SharedPreferences prefs) async {
    final db = _db!;

    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    if ((userCount ?? 0) == 0) {
      final raw = prefs.getString('current_user_profile_v1');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            await db.insert('users', {
              'id': map['id'],
              'name': map['name'],
              'mainSlogan': map['mainSlogan'],
              'mission': map['mission'],
              'email': map['email'],
              'gender': map['gender'],
              'lastModified': map['lastModified'],
            });
          }
        } catch (e) {
          debugPrint('User prefs migration failed: $e');
        }
      }
    }

    final goalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM user_goals'),
    );
    if ((goalCount ?? 0) == 0) {
      final goalsJson = prefs.getStringList('user_goals_cache');
      if (goalsJson != null) {
        for (final json in goalsJson) {
          try {
            final map = jsonDecode(json);
            if (map is Map) {
              await db.insert('user_goals', {
                'id': map['id'],
                'name': map['name'],
                'isCompleted':
                    map['isCompleted'] == true || map['isCompleted'] == 1
                    ? 1
                    : 0,
                'lastModified': map['lastModified'],
              });
            }
          } catch (e) {
            debugPrint('Goal prefs migration skipped: $e');
          }
        }
      }
    }

    final reminderCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reminders'),
    );
    if ((reminderCount ?? 0) == 0) {
      final raw = prefs.getString('habits_report_reminder_v1');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            await db.insert('reminders', {
              'id': map['id'],
              'title': map['title'],
              'description': map['description'],
              'time': map['time'],
              'isEnabled': map['isEnabled'] == true || map['isEnabled'] == 1
                  ? 1
                  : 0,
              'userNotificationRequestId': map['userNotificationRequestId'],
              'lastModified': map['lastModified'],
            });
          }
        } catch (e) {
          debugPrint('Reminder prefs migration failed: $e');
        }
      }
    }
  }

  Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      'current_user_profile_v1',
      'user_goals_cache',
      'habits_report_reminder_v1',
      'tasks_module_tasks_v1',
      'tasks_module_themes_v1',
      'tasks_module_ui_theme_v1',
      'tasks_module_meta_v1',
      'ai_conversations_v1',
      'sync_queue_v1',
      'LastOpenDate',
      'LastMissedDate',
      'last_successful_sync_at',
      'last_failed_sync_at',
      _legacyMigratedKey,
    ]) {
      await prefs.remove(key);
    }

    if (kIsWeb) return;

    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final table in const [
          'habit_records',
          'habits',
          'user_goals',
          'reminders',
          'tasks',
          'task_subtasks',
          'ai_messages',
          'ai_conversations',
          'users',
          'SyncQueueItem',
        ]) {
          await txn.delete(table);
        }
      });
    } catch (e) {
      debugPrint('Clear sqlite user data failed: $e');
    }
  }
}
