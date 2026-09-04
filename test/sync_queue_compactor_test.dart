import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_compactor.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';

void main() {
  SyncQueueItem item({
    required int localId,
    required String handlerType,
    required String operation,
    int? entityId,
    int? entityLocalId,
    DateTime? lastModified,
  }) {
    return SyncQueueItem(
      localId: localId,
      handlerType: handlerType,
      operation: operation,
      entityId: entityId,
      entityLocalId: entityLocalId,
      lastModified: lastModified ?? DateTime.utc(2026, 1, 1),
    );
  }

  test('drops items whose local entity is missing', () {
    final items = [
      item(
        localId: 1,
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        entityLocalId: 10,
      ),
      item(
        localId: 2,
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        entityLocalId: 11,
      ),
    ];

    final removed = SyncQueueCompactor.idsToRemove(
      items,
      localEntityMissing: (i) => i.entityLocalId == 10,
    );

    expect(removed, [1]);
  });

  test('keeps only the latest user operation of each kind', () {
    final items = [
      item(
        localId: 1,
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveUserName,
        lastModified: DateTime.utc(2026, 1, 1),
      ),
      item(
        localId: 2,
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveUserName,
        lastModified: DateTime.utc(2026, 1, 2),
      ),
      item(
        localId: 3,
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveMission,
        lastModified: DateTime.utc(2026, 1, 3),
      ),
    ];

    expect(SyncQueueCompactor.idsToRemove(items), [1]);
  });

  test('supersedes older entity saves of the same operation', () {
    final items = [
      item(
        localId: 1,
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        entityLocalId: 5,
        lastModified: DateTime.utc(2026, 1, 1),
      ),
      item(
        localId: 2,
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        entityLocalId: 5,
        lastModified: DateTime.utc(2026, 1, 2),
      ),
    ];

    expect(SyncQueueCompactor.idsToRemove(items), [1]);
  });

  test('delete of local-only entity clears the whole group', () {
    final items = [
      item(
        localId: 1,
        handlerType: SyncHandlerType.task,
        operation: OperationKind.save,
        entityLocalId: 9,
        lastModified: DateTime.utc(2026, 1, 1),
      ),
      item(
        localId: 2,
        handlerType: SyncHandlerType.task,
        operation: OperationKind.delete,
        entityLocalId: 9,
        lastModified: DateTime.utc(2026, 1, 2),
      ),
    ];

    expect(SyncQueueCompactor.idsToRemove(items), unorderedEquals([1, 2]));
  });

  test('delete of remote entity keeps the delete and drops earlier ops', () {
    final items = [
      item(
        localId: 1,
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.save,
        entityId: 42,
        lastModified: DateTime.utc(2026, 1, 1),
      ),
      item(
        localId: 2,
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.delete,
        entityId: 42,
        lastModified: DateTime.utc(2026, 1, 2),
      ),
    ];

    expect(SyncQueueCompactor.idsToRemove(items), [1]);
  });
}
