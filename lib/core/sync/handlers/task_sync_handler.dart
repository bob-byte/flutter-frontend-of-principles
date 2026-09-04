import 'dart:convert';

import '../../../models/task.dart';
import '../../../models/task_item_dto.dart';
import '../../../services/task_service.dart';
import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class TaskSyncHandler implements SyncQueueHandler {
  TaskSyncHandler(this._apiClient, {this.taskService});

  final ApiClient _apiClient;
  final TaskService? taskService;

  @override
  bool canHandle(String handlerType) => handlerType == SyncHandlerType.task;

  @override
  Future<void> handle(SyncQueueItem item) async {
    final operation = OperationKind.normalize(item.operation);
    if (operation == OperationKind.delete) {
      final id = item.entityId ?? 0;
      if (id != 0) {
        await _apiClient.delete('${ApiEndpoints.tasks}/$id');
      }
      return;
    }

    if (operation == OperationKind.updateStatus) {
      final payload = _decode(item.payloadJson);
      final id = payload['id'] as int? ?? item.entityId ?? 0;
      if (id == 0) return;
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$id/status',
        data: {'isCompleted': payload['isCompleted'] == true},
      );
      return;
    }

    if (operation == OperationKind.save) {
      final task = await _loadTask(item);
      final dto = TaskItemDto.fromTask(task);
      final serverId = int.tryParse(task.id) ?? item.entityId ?? 0;
      if (serverId == 0) {
        final response = await _apiClient.post(
          ApiEndpoints.tasks,
          data: dto.toJson()..remove('id'),
        );
        if (response.data is Map) {
          final created = TaskItemDto.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
          await taskService?.assignServerId(task, created.id);
        }
      } else {
        await _apiClient.put(
          '${ApiEndpoints.tasks}/$serverId',
          data: dto.toJson(),
        );
      }
      return;
    }

    throw UnsupportedError('Unsupported task operation: $operation');
  }

  Future<Task> _loadTask(SyncQueueItem item) async {
    if (item.entityLocalId != null && item.entityLocalId != 0) {
      final local = await taskService?.getTaskByLocalId(item.entityLocalId!);
      if (local != null) return local;
    }
    final payload = _decode(item.payloadJson);
    if (payload.containsKey('title')) {
      return Task.fromMap(payload.cast<String, Object?>());
    }
    return TaskItemDto.fromJson(payload).toTask();
  }

  Map<String, dynamic> _decode(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      throw StateError('PayloadJson is null for queued task.');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw StateError('Cannot deserialize task payload.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
