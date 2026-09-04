import 'operation_kind.dart';
import 'sync_handler_type.dart';
import 'sync_queue_item.dart';

class SyncQueueCompactor {
  SyncQueueCompactor._();

  static List<int> idsToRemove(
    List<SyncQueueItem> items, {
    bool Function(SyncQueueItem item)? localEntityMissing,
  }) {
    if (items.isEmpty) return const [];

    final idsToRemove = <int>{};
    for (final item in items) {
      final id = item.localId;
      if (id == null) continue;
      if (localEntityMissing?.call(item) == true) {
        idsToRemove.add(id);
      }
    }

    final active = items
        .where((item) => item.localId != null && !idsToRemove.contains(item.localId))
        .toList()
      ..sort(_byTimeThenId);

    for (final group in _groupBy(
      active.where((item) => item.handlerType == SyncHandlerType.user),
      (item) => OperationKind.normalize(item.operation),
    ).values) {
      final ordered = [...group]..sort(_byTimeThenId);
      for (final extra in ordered.reversed.skip(1)) {
        final id = extra.localId;
        if (id != null) idsToRemove.add(id);
      }
    }

    for (final group in _groupBy(
      active.where(
        (item) =>
            item.handlerType != SyncHandlerType.user && hasEntityKey(item),
      ),
      entityKey,
    ).values) {
      idsToRemove.addAll(supersededEntityItemIds(group));
    }

    return idsToRemove.toList();
  }

  static bool hasEntityKey(SyncQueueItem item) {
    return (item.entityLocalId != null && item.entityLocalId != 0) ||
        (item.entityId != null && item.entityId != 0);
  }

  static String entityKey(SyncQueueItem item) {
    if (item.entityLocalId != null && item.entityLocalId != 0) {
      return '${item.handlerType}:local:${item.entityLocalId}';
    }
    return '${item.handlerType}:server:${item.entityId}';
  }

  static Iterable<int> supersededEntityItemIds(List<SyncQueueItem> items) {
    if (items.length <= 1) return const [];

    final ordered = [...items]..sort(_byTimeThenId);
    final latest = ordered.last;
    final latestId = latest.localId;
    if (latestId == null) return const [];

    if (OperationKind.isDelete(latest.operation) &&
        (latest.entityId == null || latest.entityId == 0)) {
      return ordered.map((item) => item.localId).whereType<int>();
    }

    if (OperationKind.isDelete(latest.operation)) {
      return ordered
          .where((item) => item.localId != latestId)
          .map((item) => item.localId)
          .whereType<int>();
    }

    final latestByOperation = <String, int>{};
    for (final item in ordered) {
      final id = item.localId;
      if (id == null) continue;
      latestByOperation[OperationKind.normalize(item.operation)] = id;
    }

    return ordered
        .where((item) {
          final id = item.localId;
          if (id == null) return false;
          return latestByOperation[OperationKind.normalize(item.operation)] !=
              id;
        })
        .map((item) => item.localId)
        .whereType<int>();
  }

  static int _byTimeThenId(SyncQueueItem a, SyncQueueItem b) {
    final time = a.lastModified.compareTo(b.lastModified);
    if (time != 0) return time;
    return (a.localId ?? 0).compareTo(b.localId ?? 0);
  }

  static Map<String, List<SyncQueueItem>> _groupBy(
    Iterable<SyncQueueItem> items,
    String Function(SyncQueueItem item) keyOf,
  ) {
    final groups = <String, List<SyncQueueItem>>{};
    for (final item in items) {
      groups.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return groups;
  }
}
