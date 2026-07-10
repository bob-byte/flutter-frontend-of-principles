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
      version: 1,
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
    );
    return _db!;
  }
}
