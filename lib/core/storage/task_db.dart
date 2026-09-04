import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskDb {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'principles_tasks.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
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
            completedAt TEXT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE task_themes (
            name TEXT PRIMARY KEY,
            colorArgb INTEGER NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          Future<void> add(String sql) async {
            try {
              await db.execute(sql);
            } catch (_) {}
          }

          await add("ALTER TABLE tasks ADD COLUMN endDate TEXT NULL");
          await add(
            "ALTER TABLE tasks ADD COLUMN allDay INTEGER NOT NULL DEFAULT 0",
          );
          await add(
            "ALTER TABLE tasks ADD COLUMN remindersJson TEXT NOT NULL DEFAULT '[]'",
          );
          await add(
            "ALTER TABLE tasks ADD COLUMN constantReminder INTEGER NOT NULL DEFAULT 0",
          );
          await add(
            "ALTER TABLE tasks ADD COLUMN repeatJson TEXT NOT NULL DEFAULT '{}'",
          );
          await add(
            "ALTER TABLE tasks ADD COLUMN constantNotificationRequestId INTEGER NULL",
          );
        }
      },
    );
    return _db!;
  }
}
