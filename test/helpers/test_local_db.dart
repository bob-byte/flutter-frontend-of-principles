import 'dart:io';

import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiReady = false;

void ensureSqliteFfi() {
  if (_ffiReady) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiReady = true;
}

Future<({DatabaseService db, LocalDb localDb, String path})>
createTestDatabaseService() async {
  ensureSqliteFfi();
  final path =
      '${Directory.systemTemp.path}/principles_test_${DateTime.now().microsecondsSinceEpoch}.db';
  final localDb = LocalDb(pathOverride: path);
  final db = DatabaseService(localDb: localDb);
  // Force open so schema exists before first use.
  await localDb.database;
  return (db: db, localDb: localDb, path: path);
}

Future<void> disposeTestDatabase({
  required LocalDb localDb,
  required String path,
}) async {
  await localDb.close();
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
