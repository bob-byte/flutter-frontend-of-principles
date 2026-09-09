import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'sync_authentication_exception.dart';
import 'sync_bootstrap_snapshot.dart';
import 'sync_handler_type.dart';
import 'sync_queue_handler.dart';
import 'sync_queue_item.dart';
import 'sync_queue_service.dart';
import 'sync_snapshot_merge_service.dart';

class SyncService {
  SyncService({
    required this.queue,
    required this.authService,
    required this.apiClient,
    required this.mergeService,
    required this.databaseService,
    required List<SyncQueueHandler> handlers,
  }) : _handlers = handlers;

  final SyncQueueService queue;
  final AuthService authService;
  final ApiClient apiClient;
  final SyncSnapshotMergeService mergeService;
  final DatabaseService databaseService;
  final List<SyncQueueHandler> _handlers;
  Future<DateTime?>? _inFlight;

  Future<void> runSync() async {
    await sync();
  }

  /// Runs bootstrap/changes sync, joining any already in-flight run instead of
  /// returning immediately with an empty local store.
  Future<void> runSyncSafely() async {
    try {
      await sync();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  /// Pulls remote state and drains the outbound queue.
  ///
  /// When [since] is set, prefers GET `/sync/changes` (falls back to full
  /// bootstrap if the server asks or the endpoint is missing). Returns the
  /// server cursor to store as the next `since` value.
  Future<DateTime?> sync({DateTime? since}) async {
    if (AppConfig.useLocalData) return null;
    final token = await authService.getToken();
    if (token == null || token.isEmpty) return null;

    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }

    final inFlight = _syncBody(since: since);
    _inFlight = inFlight;
    try {
      return await inFlight;
    } finally {
      if (identical(_inFlight, inFlight)) {
        _inFlight = null;
      }
    }
  }

  Future<DateTime?> _syncBody({DateTime? since}) async {
    await queue.removeProcessedItems();
    await queue.resetFailedItems();
    await queue.resetStuckItems();
    await queue.resetDeferredItems();
    await queue.compactQueue();

    final initial = await _fetchSnapshot(since: since);
    await _reconcileQueueAgainstSnapshot(initial);
    await mergeService.merge(initial);

    var processedAny = false;
    while (true) {
      final items = await queue.getPendingItems();
      if (items.isEmpty) break;
      var processed = 0;
      for (var i = 0; i < items.length; i++) {
        if (await _process(items[i])) processed++;
      }
      if (processed == 0) break;
      processedAny = true;
      await queue.compactQueue();
    }

    await queue.compactQueue();

    // First sync / empty queue: one pull is enough. A second pull is only
    // needed after we pushed local writes so server ids / peers can land.
    var cursor = initial.serverTime;
    if (!processedAny) {
      return cursor ?? DateTime.now().toUtc();
    }

    final finalSnapshot = await _fetchSnapshot(since: since);
    await mergeService.merge(finalSnapshot);
    cursor = finalSnapshot.serverTime ?? cursor;
    return cursor ?? DateTime.now().toUtc();
  }

  Future<SyncBootstrapSnapshot> _fetchSnapshot({DateTime? since}) async {
    if (since != null) {
      try {
        final changes = await _fetchChanges(since);
        if (!changes.requiresFullBootstrap) return changes;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          throw SyncAuthenticationException();
        }
        // Older servers: no /changes — fall through to full bootstrap.
        if (status != 404) rethrow;
      }
    }
    return _fetchBootstrap();
  }

  Future<SyncBootstrapSnapshot> _fetchBootstrap() async {
    try {
      final response = await apiClient.get(ApiEndpoints.syncBootstrap);
      return SyncBootstrapSnapshot.fromJson(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw SyncAuthenticationException();
      }
      rethrow;
    }
  }

  Future<SyncBootstrapSnapshot> _fetchChanges(DateTime since) async {
    final response = await apiClient.get(
      ApiEndpoints.syncChanges,
      queryParameters: {'since': since.toUtc().toIso8601String()},
    );
    return SyncBootstrapSnapshot.fromChangesJson(response.data);
  }

  Future<void> _reconcileQueueAgainstSnapshot(
    SyncBootstrapSnapshot snapshot,
  ) async {
    final items = await queue.getBlockingItems();
    if (items.isEmpty) return;

    final goalsById = <int, DateTime?>{
      for (final goal in snapshot.goals)
        if (goal.id != null && goal.id != 0) goal.id!: goal.lastModified,
    };
    final habitsById = <int, DateTime?>{};
    for (final item in snapshot.activeHabits) {
      final id = readJsonIntFromDynamic(item['id'] ?? item['Id']);
      if (id == null) continue;
      habitsById[id] = _date(item['lastModified'] ?? item['LastModified']);
    }
    for (final archived in snapshot.archivedHabits) {
      habitsById[archived.id] = archived.lastModified;
    }

    for (final item in items) {
      final serverTs = await _serverTimestamp(
        item,
        snapshot,
        goalsById,
        habitsById,
      );
      if (serverTs == null) continue;
      var localTs = item.lastModified;
      final entityLocalId = item.entityLocalId;
      if (entityLocalId != null && entityLocalId != 0) {
        localTs = await _localTimestamp(item, entityLocalId) ?? localTs;
      }
      if (!serverTs.isBefore(localTs)) {
        await queue.markAsProcessed(item.localId!);
      }
    }
  }

  Future<DateTime?> _serverTimestamp(
    SyncQueueItem item,
    SyncBootstrapSnapshot snapshot,
    Map<int, DateTime?> goalsById,
    Map<int, DateTime?> habitsById,
  ) async {
    if (item.handlerType == SyncHandlerType.user) {
      return snapshot.user?.lastModified;
    }
    if (item.handlerType == SyncHandlerType.reminder) {
      final ts = snapshot.habitsReportReminder?.lastModified;
      if (ts == null || ts.year < 2000) return null;
      return ts;
    }
    if (item.handlerType == SyncHandlerType.task) {
      return null;
    }

    var entityId = item.entityId ?? 0;
    if (entityId == 0 &&
        item.entityLocalId != null &&
        item.entityLocalId != 0) {
      entityId = await _lookupServerId(item.handlerType, item.entityLocalId!);
    }
    if (entityId == 0) return null;

    if (item.handlerType == SyncHandlerType.userGoal) {
      return goalsById[entityId];
    }
    if (item.handlerType == SyncHandlerType.userHabit) {
      return habitsById[entityId];
    }
    return null;
  }

  Future<int> _lookupServerId(String handlerType, int localId) async {
    if (handlerType == SyncHandlerType.userGoal) {
      return await databaseService.goalServerId(localId) ?? 0;
    }
    if (handlerType == SyncHandlerType.userHabit) {
      return await databaseService.habitServerId(localId) ?? localId;
    }
    return 0;
  }

  Future<DateTime?> _localTimestamp(SyncQueueItem item, int localId) async {
    switch (item.handlerType) {
      case SyncHandlerType.user:
        return databaseService.userLastModified();
      case SyncHandlerType.userGoal:
        return databaseService.goalLastModified(localId);
      case SyncHandlerType.userHabit:
        return databaseService.habitLastModified(localId);
      case SyncHandlerType.reminder:
        return databaseService.reminderLastModified(localId);
      default:
        return item.lastModified;
    }
  }

  Future<bool> _process(SyncQueueItem item) async {
    final id = item.localId;
    if (id == null) return false;
    try {
      await queue.markAsProcessing(id);
      final handler = _handlers.cast<SyncQueueHandler?>().firstWhere(
        (h) => h!.canHandle(item.handlerType),
        orElse: () => null,
      );
      if (handler == null) {
        await queue.markAsFailed(
          id,
          'Handler for ${item.handlerType} not found',
        );
        return false;
      }
      // Reload so remaps from earlier items in this drain (e.g. local habit
      // id → server id) are visible in the payload.
      final fresh = await queue.getItem(id) ?? item;
      await handler.handle(fresh);
      await queue.markAsProcessed(id);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await queue.markAsProcessed(id);
        return true;
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw SyncAuthenticationException();
      }
      debugPrint('Sync item $id failed: $e');
      await queue.markAsFailed(id, e.message ?? e.toString());
      return false;
    } catch (e) {
      debugPrint('Sync item $id failed: $e');
      await queue.markAsFailed(id, e.toString());
      return false;
    }
  }
}

int? readJsonIntFromDynamic(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final parsed = DateTime.tryParse(value.toString())?.toUtc();
  if (parsed == null || parsed.year < 2000) return null;
  return parsed;
}
