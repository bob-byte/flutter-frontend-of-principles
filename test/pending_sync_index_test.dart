import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/pending_sync_index.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';

void main() {
  test('indexes archive payload habit ids as pending habits', () {
    final pending = PendingSyncIndex([
      SyncQueueItem(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.setArchiveStatus,
        payloadJson: '{"habitId":42,"isArchived":true}',
      ),
    ]);

    expect(pending.pendingHabit(serverId: 42), isTrue);
    expect(pending.pendingHabit(serverId: 7), isFalse);
  });

  test('indexes progress by habit id and date', () {
    final pending = PendingSyncIndex([
      SyncQueueItem(
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        entityId: 9,
        payloadJson: '{"habitId":42,"date":"2026-09-03","value":2}',
      ),
    ]);

    expect(pending.habitHasPendingProgress(42, null), isTrue);
    expect(
      pending.pendingProgress(habitId: 42, dateKey: '2026-09-03', recordId: 9),
      isTrue,
    );
    expect(
      pending.pendingProgress(habitId: 42, dateKey: '2026-09-04'),
      isFalse,
    );
  });

  test('indexes task deletes separately from saves', () {
    final pending = PendingSyncIndex([
      SyncQueueItem(
        handlerType: SyncHandlerType.task,
        operation: OperationKind.delete,
        entityId: 7,
      ),
      SyncQueueItem(
        handlerType: SyncHandlerType.task,
        operation: OperationKind.save,
        entityId: 8,
      ),
    ]);

    expect(pending.pendingTaskDeletes, {7});
    expect(pending.pendingTaskSaves, {8});
    expect(pending.pendingTask(7), isTrue);
    expect(pending.pendingTask(8), isTrue);
    expect(pending.pendingTask(9), isFalse);
  });
}
