import 'dart:async';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/local_db.dart';
import '../core/storage/task_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/task.dart';
import '../models/task_item_dto.dart';
import 'local_task_storage.dart';

class TaskService {
  TaskService({
    required ApiClient apiClient,
    TaskDb? taskDb,
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
  }) : _apiClient = apiClient,
       _local = LocalTaskStorage(taskDb, localDb: localDb),
       _executor = executor;

  final ApiClient _apiClient;
  final LocalTaskStorage _local;
  final LocalRemoteExecutor? _executor;

  bool get _useRemote => !AppConfig.useLocalData;

  Future<List<Task>> getTasks() => _local.getTasks();

  Future<Task?> getTask(String id) => _local.getTask(id);

  Future<Task?> getTaskByLocalId(int localId) => _local.getTaskByLocalId(localId);

  Future<void> saveTask(Task task, {required bool isNew}) async {
    var stored = task;
    if (isNew && (task.id == '0' || task.id.isEmpty)) {
      stored = task.copyWith(
        id: 'L${DateTime.now().millisecondsSinceEpoch}',
        lastModified: DateTime.now().toUtc(),
      );
    } else {
      stored = task.copyWith(lastModified: DateTime.now().toUtc());
    }

    await _local.saveTask(stored, isNew: isNew);
    if (!_useRemote) return;

    final persisted = await _local.getTask(stored.id) ?? stored;
    Future<Task> remote() async {
      final dto = TaskItemDto.fromTask(persisted);
      final serverId = persisted.serverId ?? int.tryParse(persisted.id) ?? 0;
      if (isNew || serverId == 0) {
        final response = await _apiClient.post(
          ApiEndpoints.tasks,
          data: dto.toJson()..remove('id'),
        );
        final created = TaskItemDto.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final mapped = persisted.copyWith(
          id: created.id.toString(),
          serverId: created.id,
        );
        await _local.replaceTaskId(persisted.id, mapped);
        return mapped;
      }
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$serverId',
        data: dto.toJson(),
      );
      return persisted;
    }

    if (_executor != null) {
      await _executor.execute<Task>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: 'Task',
        operation: OperationKind.save,
        payload: persisted.toMap(),
        entityId: persisted.serverId ?? int.tryParse(persisted.id),
        entityLocalId: persisted.localId,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {
        // Local copy remains the source of truth.
      }
    }());
  }

  Future<void> updateTaskStatus(String id, bool isDone) async {
    await _local.updateTaskStatus(id, isDone);
    if (!_useRemote) return;
    final task = await _local.getTask(id);
    final serverId = task?.serverId ?? int.tryParse(id) ?? 0;
    if (serverId == 0) return;

    Future<void> remote() async {
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$serverId/status',
        data: {'isCompleted': isDone},
      );
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: 'Task',
        operation: OperationKind.updateStatus,
        payload: {'id': serverId, 'isCompleted': isDone},
        entityId: serverId,
        entityLocalId: task?.localId,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {}
    }());
  }

  Future<void> deleteTask(String id) async {
    final existing = await _local.getTask(id);
    await _local.deleteTask(id);
    if (!_useRemote) return;
    final serverId = existing?.serverId ?? int.tryParse(id) ?? 0;
    if (serverId == 0) return;

    Future<void> remote() async {
      await _apiClient.delete('${ApiEndpoints.tasks}/$serverId');
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: 'Task',
        operation: OperationKind.delete,
        payload: {'id': serverId},
        entityId: serverId,
        entityLocalId: existing?.localId,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {}
    }());
  }

  Future<void> assignServerId(Task task, int serverId) {
    return _local.replaceTaskId(
      task.id,
      task.copyWith(id: serverId.toString(), serverId: serverId),
    );
  }

  Future<void> mergeRemoteTask(TaskItemDto dto) async {
    final existing = await _local.getTask(dto.id.toString());
    final merged = dto.toTask(
      priority: existing?.priority,
      theme: existing?.theme,
      completedAt: existing?.completedAt,
    ).copyWith(
      localId: existing?.localId,
      serverId: dto.id,
      lastModified: DateTime.now().toUtc(),
    );
    await _local.saveTask(merged, isNew: existing == null);
  }

  Future<Map<String, int>> getThemeColors() => _local.getThemeColors();

  Future<void> saveThemeColor(String name, int colorArgb) =>
      _local.saveThemeColor(name, colorArgb);

  Future<void> registerTheme(String? theme, int? colorArgb) =>
      _local.registerTheme(theme, colorArgb);

  Future<TasksUiTheme> getUiTheme() => _local.getUiTheme();

  Future<void> setUiTheme(TasksUiTheme theme) => _local.setUiTheme(theme);
}
