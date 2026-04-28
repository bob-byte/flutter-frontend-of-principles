import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'principles.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE SyncQueueItem (
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
            errorMessage TEXT NULL,
            isFailed INTEGER DEFAULT 0
          );
        ''');
      },
    );
    return _db!;
  }
}
