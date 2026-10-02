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
      // Prefer the queued server id: the local row is already gone when the
      // queue drains, so payload/local lookup is a fallback only.
      final id = item.entityId ?? 0;
      final resolved = id != 0 ? id : await _resolveServerId(item);
      if (resolved != 0) {
        await _apiClient.delete('${ApiEndpoints.tasks}/$resolved');
      }
      return;
    }

    if (operation == OperationKind.updateStatus) {
      final payload = _decode(item.payloadJson);
      var id = _asInt(payload['id']) ?? item.entityId ?? 0;
      if (id == 0) {
        id = await _resolveServerId(item);
      }
      if (id == 0) {
        throw StateError('Queued task status has no server id yet.');
      }
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$id/status',
        data: {'isCompleted': payload['isCompleted'] == true},
      );
      return;
    }

    if (operation == OperationKind.save) {
      final task = await _loadTask(item);
      final service = taskService;
      if (service != null) {
        // allowCreate: queue may be the only upload after compacting create+edit.
        // Shared lock + re-read prevents a second POST while create is in flight.
        await service.pushSaveToRemote(task, allowCreate: true);
        return;
      }
      final dto = TaskItemDto.fromTask(task);
      final serverId =
          task.serverId ?? int.tryParse(task.id) ?? item.entityId ?? 0;
      if (serverId == 0) {
        await _apiClient.post(
          ApiEndpoints.tasks,
          data: dto.toJson()..remove('id'),
        );
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

  Future<int> _resolveServerId(SyncQueueItem item) async {
    try {
      final task = await _loadTask(item);
      return task.serverId ?? int.tryParse(task.id) ?? 0;
    } catch (_) {
      return item.entityId ?? 0;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
