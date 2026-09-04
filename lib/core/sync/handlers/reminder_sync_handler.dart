import 'dart:convert';

import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class ReminderSyncHandler implements SyncQueueHandler {
  ReminderSyncHandler(this._apiClient, {this.reminderService});

  final ApiClient _apiClient;
  final ReminderService? reminderService;

  @override
  bool canHandle(String handlerType) => handlerType == SyncHandlerType.reminder;

  @override
  Future<void> handle(SyncQueueItem item) async {
    if (OperationKind.normalize(item.operation) != OperationKind.save) {
      throw UnsupportedError(
        'Unsupported reminder operation: ${item.operation}',
      );
    }

    final reminder = await _load(item);
    final response = await _apiClient.post(
      '${ApiEndpoints.habitsReportReminder}/${reminder.id ?? 0}',
      data: reminder.toApiJson(),
    );
    final saved = SaveHabitsReportReminderResponse.fromJson(response.data);
    await reminderService?.applyServerIds(
      localId: reminder.localId ?? item.entityLocalId,
      id: saved.id,
      userNotificationRequestId: saved.userNotificationRequestId,
    );
  }

  Future<Reminder> _load(SyncQueueItem item) async {
    if (item.entityLocalId != null && item.entityLocalId != 0) {
      final local = await reminderService?.getByLocalId(item.entityLocalId!);
      if (local != null) return local;
    }
    if (item.payloadJson == null) {
      throw StateError('PayloadJson is null for queued reminder.');
    }
    return Reminder.fromJson(jsonDecode(item.payloadJson!));
  }
}
