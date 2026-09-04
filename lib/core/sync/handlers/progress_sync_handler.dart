import 'dart:convert';

import '../../../models/habit_record.dart';
import '../../../models/progress_value.dart';
import '../../../services/habit_service.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class ProgressSyncHandler implements SyncQueueHandler {
  ProgressSyncHandler(this._habitService);

  final HabitService _habitService;

  @override
  bool canHandle(String handlerType) =>
      handlerType == SyncHandlerType.progressOfHabit;

  @override
  Future<void> handle(SyncQueueItem item) async {
    if (OperationKind.normalize(item.operation) != OperationKind.save) {
      throw UnsupportedError(
        'Unsupported progress operation: ${item.operation}',
      );
    }

    final payload = _decode(item.payloadJson);
    final habitId = readJsonInt(payload['habitId']) ?? 0;
    if (habitId == 0) {
      return;
    }

    final date = progressDateFromApi(payload['date']);
    if (date == null) {
      return;
    }

    final status = habitStatusFromProgressValue(
      readJsonInt(payload['value']) ?? kProgressUnknown,
    );
    if (status == HabitStatus.none) {
      return;
    }

    try {
      final ok = await _habitService.pushProgress(
        habitId,
        date,
        status,
        enqueueOnFailure: false,
      );
      if (!ok) {
        throw StateError('Failed to push queued habit progress.');
      }
    } on ProgressSyncDroppedException {
      return;
    }
  }

  Map<String, dynamic> _decode(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      throw StateError('PayloadJson is null for queued progress.');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw StateError('Cannot deserialize progress payload.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
