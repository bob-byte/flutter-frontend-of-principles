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

  Future<List<Task>> getTasks({bool? isDone}) => _local.getTasks(isDone: isDone);

  Future<List<Task>> getSessionTasks({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime today,
  }) => _local.getSessionTasks(
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    today: today,
  );

  Future<List<Task>> getCompletedTasks() => _local.getTasks(isDone: true);

  Future<Task?> getTask(String id) => _local.getTask(id);

  Future<Task?> getTaskByLocalId(int localId) =>
      _local.getTaskByLocalId(localId);

  Future<Task> saveTask(Task task, {required bool isNew}) async {
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
    final persisted = await _local.getTask(stored.id) ?? stored;
    if (!_useRemote) return persisted;

    Future<Task> remote() async {
      final latest = await _local.getTask(persisted.id) ?? persisted;
      final dto = TaskItemDto.fromTask(latest);
      final serverId = latest.serverId ?? int.tryParse(latest.id) ?? 0;
      if (isNew || serverId == 0) {
        final response = await _apiClient.post(
          ApiEndpoints.tasks,
          data: dto.toJson()..remove('id'),
        );
        final created = TaskItemDto.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        // Keep the stable local id so in-memory list rows stay editable
        // while background sync assigns serverId.
        final mapped = latest.copyWith(serverId: created.id);
        await _local.saveTask(mapped, isNew: false);
        return mapped;
      }
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$serverId',
        data: dto.toJson(),
      );
      return latest;
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
      return persisted;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {
        // Local copy remains the source of truth.
      }
    }());
    return persisted;
  }

  Future<void> updateTaskStatus(String id, bool isDone) async {
    await _local.updateTaskStatus(id, isDone);
    if (!_useRemote) return;
    final task = await _local.getTask(id);
    if (task == null) return;
    final serverId = task.serverId ?? int.tryParse(task.id) ?? 0;

    Future<void> remote() async {
      final latest = await _local.getTask(id) ?? task;
      final sid = latest.serverId ?? int.tryParse(latest.id) ?? 0;
      if (sid == 0) {
        throw StateError('Task has no server id yet');
      }
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$sid/status',
        data: {'isCompleted': isDone},
      );
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: 'Task',
        operation: OperationKind.updateStatus,
        payload: {
          'id': serverId == 0 ? null : serverId,
          'isCompleted': isDone,
          'clientId': task.id,
        },
        entityId: serverId == 0 ? null : serverId,
        entityLocalId: task.localId,
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

    Future<void> remote() async {
      if (serverId == 0) return;
      await _apiClient.delete('${ApiEndpoints.tasks}/$serverId');
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: 'Task',
        operation: OperationKind.delete,
        payload: {'id': serverId, 'clientId': existing?.id ?? id},
        entityId: serverId == 0 ? null : serverId,
        entityLocalId: existing?.localId,
      );
      return;
    }

    if (serverId == 0) return;
    unawaited(() async {
      try {
        await remote();
      } catch (_) {}
    }());
  }

  Future<void> assignServerId(Task task, int serverId) {
    return _local.saveTask(task.copyWith(serverId: serverId), isNew: false);
  }

  Future<void> mergeRemoteTask(TaskItemDto dto) async {
    final existing = await _local.getTask(dto.id.toString());
    final merged = dto
        .toTask(
          priority: existing?.priority,
          theme: existing?.theme,
          completedAt: existing?.completedAt,
          subtasks: dto.subtasks ?? existing?.subtasks,
        )
        .copyWith(
          // Preserve local id so open edit sheets / list rows keep resolving.
          id: existing?.id ?? dto.id.toString(),
          localId: existing?.localId,
          serverId: dto.id,
          lastModified: DateTime.now().toUtc(),
        );
    await _local.saveTask(merged, isNew: existing == null);

    // Collapse L… + "2" pairs left by older create/bootstrap races.
    await _local.deleteTasksByServerId(dto.id, exceptId: merged.id);
  }

  /// Drops local copies of server tasks that another device deleted.
  ///
  /// Rows with no [Task.serverId] (still uploading) are kept. [retainServerIds]
  /// covers in-flight local edits/deletes so bootstrap cannot clobber them.
  Future<void> discardLocalTasksAbsentFromRemote(
    Set<int> remoteServerIds, {
    Set<int> retainServerIds = const {},
  }) async {
    for (final task in await _local.getTasks()) {
      final serverId = task.serverId ?? int.tryParse(task.id) ?? 0;
      if (serverId == 0) continue;
      if (remoteServerIds.contains(serverId)) continue;
      if (retainServerIds.contains(serverId)) continue;
      await _local.deleteTask(task.id);
    }
  }

  /// Applies a single remote delete from GET `/sync/changes` tombstones.
  Future<void> discardRemoteDeletedTask(int serverId) async {
    if (serverId == 0) return;
    await _local.deleteTasksByServerId(serverId);
  }

  Future<Map<String, int>> getThemeColors() => _local.getThemeColors();

  Future<void> saveThemeColor(String name, int colorArgb) =>
      _local.saveThemeColor(name, colorArgb);

  Future<void> registerTheme(String? theme, int? colorArgb) =>
      _local.registerTheme(theme, colorArgb);

  Future<TasksUiTheme> getUiTheme() => _local.getUiTheme();

  Future<void> setUiTheme(TasksUiTheme theme) => _local.setUiTheme(theme);
}
