import 'dart:convert';

import '../../../models/habit.dart';
import '../../../services/habit_service.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class HabitSyncHandler implements SyncQueueHandler {
  HabitSyncHandler(this._habitService);

  final HabitService _habitService;

  @override
  bool canHandle(String handlerType) =>
      handlerType == SyncHandlerType.userHabit;

  @override
  Future<void> handle(SyncQueueItem item) async {
    final operation = OperationKind.normalize(item.operation);

    if (operation == OperationKind.setArchiveStatus) {
      final payload = _decode(item.payloadJson);
      final habitId = payload['habitId'] as int? ?? item.entityId ?? 0;
      final isArchived = payload['isArchived'] == true;
      await _habitService.pushArchiveStatus(
        habitId: habitId,
        isArchived: isArchived,
        lastModified: payload['lastModified']?.toString(),
      );
      return;
    }

    if (operation == OperationKind.save) {
      final habit = await _loadHabit(item);
      final isNew =
          confirmedServerHabitId(habit) == null &&
          (item.entityId == null || item.entityId == 0);
      final remoteId = await _habitService.pushHabit(
        habit,
        isNew: isNew,
        enqueueOnFailure: false,
      );
      if (remoteId == null || remoteId == 0) {
        throw StateError('Failed to push queued habit.');
      }
      return;
    }

    if (operation == OperationKind.delete) {
      final id = item.entityId ?? 0;
      if (id != 0) {
        await _habitService.deleteHabitRemote(id);
      }
      return;
    }

    throw UnsupportedError('Unsupported habit operation: $operation');
  }

  Future<Habit> _loadHabit(SyncQueueItem item) async {
    final localId = item.entityLocalId ?? item.entityId;
    if (localId != null && localId != 0) {
      final local = await _habitService.getHabitById(localId);
      if (local != null) return local;
    }
    final payload = _decode(item.payloadJson);
    return Habit.fromMap(payload);
  }

  Map<String, dynamic> _decode(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      throw StateError('PayloadJson is null for queued habit item.');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw StateError('Cannot deserialize habit payload.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
