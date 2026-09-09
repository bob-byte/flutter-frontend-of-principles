import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/local_db.dart';
import 'operation_kind.dart';
import 'sync_handler_type.dart';
import 'sync_queue_compactor.dart';
import 'sync_queue_item.dart';
import 'sync_retry_config.dart';

class SyncQueueService {
  SyncQueueService({
    LocalDb? localDb,
    SyncRetryConfig retryConfig = const SyncRetryConfig(),
    List<SyncQueueItem>? memoryItems,
  }) : _localDb = localDb,
       _retryConfig = retryConfig,
       _memory = memoryItems ?? <SyncQueueItem>[],
       _useMemory = memoryItems != null || localDb == null || kIsWeb;

  static const _prefsKey = 'sync_queue_v1';

  final LocalDb? _localDb;
  final SyncRetryConfig _retryConfig;
  final List<SyncQueueItem> _memory;
  final bool _useMemory;
  int _nextMemoryId = 1;

  Future<int> addToQueue({
    required String handlerType,
    required String operation,
    Object? payload,
    int? entityId,
    int? entityLocalId,
    DateTime? lastModified,
  }) async {
    final item = SyncQueueItem(
      entityId: entityId,
      entityLocalId: entityLocalId,
      handlerType: handlerType,
      operation: OperationKind.normalize(operation),
      payloadJson: payload == null
          ? null
          : payload is String
          ? payload
          : jsonEncode(payload),
      lastModified: lastModified ?? DateTime.now().toUtc(),
      nextRetryAt: DateTime.now().toUtc(),
    );
    if (_useMemory) {
      await _ensureMemoryLoaded();
      final stored = item.copyWith(localId: _nextMemoryId++);
      _memory.add(stored);
      await _persistMemory();
      return stored.localId!;
    }

    final db = await _localDb!.database;
    return db.insert('SyncQueueItem', item.toMap()..remove('localId'));
  }

  Future<List<SyncQueueItem>> getPendingItems({DateTime? now}) async {
    final cutoff = now ?? DateTime.now().toUtc();
    final items = (await getBlockingItems())
        .where(
          (item) =>
              !item.isProcessing &&
              !item.isFailed &&
              (item.nextRetryAt == null || !item.nextRetryAt!.isAfter(cutoff)),
        )
        .toList();
    return items;
  }

  Future<List<SyncQueueItem>> getBlockingItems({String? handlerType}) async {
    final items = await _loadUnprocessed();
    final filtered = handlerType == null
        ? items
        : items.where((item) => item.handlerType == handlerType);
    return filtered.toList()..sort((a, b) {
      final order = SyncHandlerType.orderOf(
        a.handlerType,
      ).compareTo(SyncHandlerType.orderOf(b.handlerType));
      if (order != 0) return order;
      final time = a.lastModified.compareTo(b.lastModified);
      if (time != 0) return time;
      return (a.localId ?? 0).compareTo(b.localId ?? 0);
    });
  }

  Future<List<SyncQueueItem>> getFailedItems() async {
    return (await _loadAll()).where((item) => item.isFailed).toList();
  }

  Future<SyncQueueItem?> getItem(int localId) async {
    if (_useMemory) {
      await _ensureMemoryLoaded();
      for (final item in _memory) {
        if (item.localId == localId) return item;
      }
      return null;
    }
    final db = await _localDb!.database;
    final rows = await db.query(
      'SyncQueueItem',
      where: 'localId = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncQueueItem.fromMap(rows.first);
  }

  Future<List<SyncQueueItem>> getStuckItems({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(
      const Duration(minutes: 30),
    );
    return (await _loadAll())
        .where(
          (item) =>
              item.isProcessing &&
              item.lastRetryAt != null &&
              item.lastRetryAt!.isBefore(cutoff),
        )
        .toList();
  }

  Future<bool> hasBlocking({
    required String handlerType,
    int? entityId,
    int? entityLocalId,
  }) async {
    final filterByLocal = entityLocalId != null && entityLocalId != 0;
    final filterByEntity = entityId != null && entityId != 0;

    if (!_useMemory) {
      final db = await _localDb!.database;
      final where = <String>['isProcessed = 0', 'handlerType = ?'];
      final args = <Object?>[handlerType];
      if (filterByLocal && filterByEntity) {
        where.add('(entityLocalId = ? OR entityId = ?)');
        args
          ..add(entityLocalId)
          ..add(entityId);
      } else if (filterByLocal) {
        where.add('entityLocalId = ?');
        args.add(entityLocalId);
      } else if (filterByEntity) {
        where.add('entityId = ?');
        args.add(entityId);
      }
      final rows = await db.query(
        'SyncQueueItem',
        columns: ['localId'],
        where: where.join(' AND '),
        whereArgs: args,
        limit: 1,
      );
      return rows.isNotEmpty;
    }

    final items = await getBlockingItems(handlerType: handlerType);
    if (!filterByLocal && !filterByEntity) {
      return items.isNotEmpty;
    }
    return items.any((item) {
      if (filterByLocal && item.entityLocalId == entityLocalId) {
        return true;
      }
      if (filterByEntity && item.entityId == entityId) {
        return true;
      }
      return false;
    });
  }

  Future<void> markAsProcessing(int id, {DateTime? now}) async {
    await _update(
      id,
      (item) => item.copyWith(
        isProcessing: true,
        lastRetryAt: now ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> markAsFailed(
    int id,
    String errorMessage, {
    DateTime? now,
    double? jitterFraction,
  }) async {
    await _update(id, (item) {
      final retryCount = item.retryCount + 1;
      if (retryCount >= _retryConfig.maxRetryAttempts) {
        return item.copyWith(
          isProcessing: false,
          isFailed: true,
          retryCount: retryCount,
          errorMessage: errorMessage,
        );
      }
      return item.copyWith(
        isProcessing: false,
        isFailed: false,
        retryCount: retryCount,
        errorMessage: errorMessage,
        nextRetryAt: _retryConfig.nextRetryAt(
          retryCount,
          now: now,
          jitterFraction: jitterFraction,
        ),
      );
    });
  }

  Future<void> markAsProcessed(int id, {DateTime? now}) async {
    await remove(id);
  }

  /// Leaves the item pending after a live remote attempt so sync can retry.
  Future<void> releaseProcessing(int id, {DateTime? now}) async {
    await _update(
      id,
      (item) => item.copyWith(
        isProcessing: false,
        isFailed: false,
        nextRetryAt: now ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> remove(int id) async {
    await removeMany([id]);
  }

  Future<void> removeMany(Iterable<int> ids) async {
    final unique = ids.where((id) => id != 0).toSet().toList();
    if (unique.isEmpty) return;
    if (_useMemory) {
      await _ensureMemoryLoaded();
      _memory.removeWhere((item) => unique.contains(item.localId));
      await _persistMemory();
      return;
    }
    final db = await _localDb!.database;
    for (var i = 0; i < unique.length; i += 400) {
      final chunk = unique.sublist(
        i,
        i + 400 > unique.length ? unique.length : i + 400,
      );
      await db.delete(
        'SyncQueueItem',
        where: 'localId IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }
  }

  Future<void> removeProcessedItems() async {
    if (_useMemory) {
      await _ensureMemoryLoaded();
      _memory.removeWhere((item) => item.isProcessed);
      await _persistMemory();
      return;
    }
    final db = await _localDb!.database;
    await db.delete('SyncQueueItem', where: 'isProcessed = 1');
  }

  Future<void> resetStuckItems() async {
    if (_useMemory) {
      final items = await _loadAll();
      for (final item in items.where((item) => item.isProcessing)) {
        await _update(
          item.localId!,
          (current) => current.copyWith(
            isProcessing: false,
            nextRetryAt: DateTime.now().toUtc(),
          ),
        );
      }
      return;
    }
    final db = await _localDb!.database;
    await db.update('SyncQueueItem', {
      'isProcessing': 0,
      'nextRetryAt': DateTime.now().toUtc().toIso8601String(),
    }, where: 'isProcessing = 1');
  }

  Future<void> resetFailedItems() async {
    if (_useMemory) {
      for (final item in await getFailedItems()) {
        await _update(
          item.localId!,
          (current) => current.copyWith(
            isFailed: false,
            isProcessed: false,
            isProcessing: false,
            nextRetryAt: DateTime.now().toUtc(),
          ),
        );
      }
      return;
    }
    final db = await _localDb!.database;
    await db.update('SyncQueueItem', {
      'isFailed': 0,
      'isProcessed': 0,
      'isProcessing': 0,
      'nextRetryAt': DateTime.now().toUtc().toIso8601String(),
    }, where: 'isFailed = 1');
  }

  Future<void> resetDeferredItems() async {
    if (_useMemory) {
      final items = await _loadUnprocessed();
      for (final item in items.where(
        (item) => !item.isFailed && !item.isProcessing,
      )) {
        await _update(
          item.localId!,
          (current) => current.copyWith(nextRetryAt: DateTime.now().toUtc()),
        );
      }
      return;
    }
    final db = await _localDb!.database;
    await db.update(
      'SyncQueueItem',
      {'nextRetryAt': DateTime.now().toUtc().toIso8601String()},
      where: 'isProcessed = 0 AND isFailed = 0 AND isProcessing = 0',
    );
  }

  Future<void> compactQueue() async {
    final items = await getBlockingItems();
    final ids = SyncQueueCompactor.idsToRemove(
      items,
      localEntityMissing: (item) => false,
    );
    await removeMany(ids);
  }

  Future<void> compactQueueCheckingLocal(
    Future<bool> Function(SyncQueueItem item) localMissing,
  ) async {
    final items = await getBlockingItems();
    final missing = <int, bool>{};
    for (final item in items) {
      missing[item.localId ?? -1] = await localMissing(item);
    }
    final ids = SyncQueueCompactor.idsToRemove(
      items,
      localEntityMissing: (item) => missing[item.localId] == true,
    );
    await removeMany(ids);
  }

  Future<void> rewriteProgressHabitId({
    required int fromHabitId,
    required int toHabitId,
  }) async {
    if (fromHabitId == toHabitId) return;
    final items = await _loadUnprocessed();
    for (final item in items) {
      if (item.handlerType != SyncHandlerType.progressOfHabit) continue;
      if (item.localId == null || item.payloadJson == null) continue;
      try {
        final decoded = jsonDecode(item.payloadJson!);
        if (decoded is! Map) continue;
        final payload = Map<String, dynamic>.from(decoded);
        if (payload['habitId'] != fromHabitId) continue;
        payload['habitId'] = toHabitId;
        await _update(
          item.localId!,
          (current) => current.copyWith(payloadJson: jsonEncode(payload)),
        );
      } catch (_) {}
    }
  }

  Future<void> repointEntity({
    required String handlerType,
    required int fromLocalId,
    required int toLocalId,
    int? toEntityId,
  }) async {
    if (!_useMemory) {
      final db = await _localDb!.database;
      await db.update(
        'SyncQueueItem',
        {
          'entityLocalId': toLocalId,
          if (toEntityId != null) 'entityId': toEntityId,
        },
        where: 'handlerType = ? AND entityLocalId = ?',
        whereArgs: [handlerType, fromLocalId],
      );
      return;
    }
    final items = await _loadAll();
    for (final item in items) {
      if (item.handlerType != handlerType ||
          item.entityLocalId != fromLocalId) {
        continue;
      }
      await _update(
        item.localId!,
        (current) => current.copyWith(
          entityLocalId: toLocalId,
          entityId: toEntityId ?? current.entityId,
        ),
      );
    }
  }

  Future<void> cleanupOldProcessedItems(Duration ageThreshold) async {
    if (ageThreshold.isNegative) return;
    await removeProcessedItems();
  }

  Future<List<SyncQueueItem>> _loadUnprocessed() async {
    if (_useMemory) {
      return (await _loadAll()).where((item) => !item.isProcessed).toList();
    }
    final db = await _localDb!.database;
    final rows = await db.query('SyncQueueItem', where: 'isProcessed = 0');
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  Future<List<SyncQueueItem>> _loadAll() async {
    if (_useMemory) {
      await _ensureMemoryLoaded();
      return List<SyncQueueItem>.from(_memory);
    }
    final db = await _localDb!.database;
    final rows = await db.query('SyncQueueItem');
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  Future<void> _update(
    int id,
    SyncQueueItem Function(SyncQueueItem item) update,
  ) async {
    if (_useMemory) {
      await _ensureMemoryLoaded();
      final index = _memory.indexWhere((item) => item.localId == id);
      if (index < 0) return;
      _memory[index] = update(_memory[index]);
      await _persistMemory();
      return;
    }
    final db = await _localDb!.database;
    final rows = await db.query(
      'SyncQueueItem',
      where: 'localId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final updated = update(SyncQueueItem.fromMap(rows.first));
    await db.update(
      'SyncQueueItem',
      updated.toMap()..remove('localId'),
      where: 'localId = ?',
      whereArgs: [id],
    );
  }

  Future<void> _ensureMemoryLoaded() async {
    if (!kIsWeb || _memory.isNotEmpty || _nextMemoryId > 1) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        final item = SyncQueueItem.fromMap(
          Map<String, Object?>.from(entry as Map),
        );
        _memory.add(item);
        final id = item.localId ?? 0;
        if (id >= _nextMemoryId) _nextMemoryId = id + 1;
      }
    } catch (e) {
      debugPrint('Failed to load in-memory sync queue: $e');
    }
  }

  Future<void> _persistMemory() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_memory.map((item) => item.toMap()).toList()),
    );
  }
}
