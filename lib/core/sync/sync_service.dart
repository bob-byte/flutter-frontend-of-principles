import 'package:sqflite/sqflite.dart';

import '../storage/local_db.dart';
import '../../services/auth_service.dart';

class SyncService {
  SyncService({
    required LocalDb db,
    required AuthService authService,
  })  : _db = db,
        _authService = authService;

  final LocalDb _db;
  final AuthService _authService;
  bool _isSyncing = false;

  Future<void> enqueue({
    required String handlerType,
    required String operation,
    String? payloadJson,
    int? entityId,
    int? entityLocalId,
  }) async {
    final db = await _db.database;
    await db.insert(
      'SyncQueueItem',
      {
        'entityId': entityId,
        'entityLocalId': entityLocalId,
        'handlerType': handlerType,
        'operation': operation,
        'payloadJson': payloadJson,
        'lastModified': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> runSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final db = await _db.database;
      final rows = await db.query(
        'SyncQueueItem',
        where: 'isProcessed = 0 AND isFailed = 0',
      );

      for (final row in rows) {
        await db.update(
          'SyncQueueItem',
          {'isProcessed': 1, 'isProcessing': 0},
          where: 'localId = ?',
          whereArgs: [row['localId']],
        );
      }
    } finally {
      _isSyncing = false;
    }
  }
}
