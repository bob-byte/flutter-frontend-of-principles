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

  /// Serializes create/update HTTP for the same local task so a live-save edit
  /// cannot POST a duplicate while the initial create is still in flight.
  final Map<String, Future<void>> _remoteSaveChains = {};

  bool get _useRemote => !AppConfig.useLocalData;

  Future<List<Task>> getTasks({bool? isDone}) =>
      _local.getTasks(isDone: isDone);

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

  static int resolvedServerId(Task task) =>
      task.serverId ?? int.tryParse(task.id) ?? 0;

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

    Future<Task> remote() => pushSaveToRemote(persisted, allowCreate: isNew);

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

  /// Pushes the latest local row for [task] to the server.
  ///
  /// When [allowCreate] is false and the row still has no server id (create still
  /// in flight), throws so the queue retries after create assigns [Task.serverId].
  /// Queued sync should pass [allowCreate] true so a compacted first upload can
  /// POST once.
  Future<Task> pushSaveToRemote(Task task, {required bool allowCreate}) {
    return _enqueueRemoteSave(task.id, () async {
      final latest = await _local.getTask(task.id) ?? task;
      final dto = TaskItemDto.fromTask(latest);
      final serverId = resolvedServerId(latest);
      if (serverId != 0) {
        await _apiClient.put(
          '${ApiEndpoints.tasks}/$serverId',
          data: dto.toJson(),
        );
        return latest;
      }
      if (!allowCreate) {
        throw StateError('Task has no server id yet');
      }
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
    });
  }

  Future<T> _enqueueRemoteSave<T>(String taskId, Future<T> Function() action) {
    final previous = _remoteSaveChains[taskId] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => action());
    _remoteSaveChains[taskId] = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<void> updateTaskStatus(String id, bool isDone) async {
    await _local.updateTaskStatus(id, isDone);
    if (!_useRemote) return;
    final task = await _local.getTask(id);
    if (task == null) return;
    final serverId = task.serverId ?? int.tryParse(task.id) ?? 0;

    Future<void> remote() async {
      final latest = await _local.getTask(id) ?? task;
      final sid = resolvedServerId(latest);
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

  /// Upserts a server task. Returns the local row before the merge (null when
  /// new here) and the stored result so callers can rebuild notifications.
  Future<({Task? previous, Task merged})> mergeRemoteTask(
    TaskItemDto dto,
  ) async {
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
    return (previous: existing, merged: merged);
  }

  /// Drops local copies of server tasks that another device deleted.
  ///
  /// Rows with no [Task.serverId] (still uploading) are kept. [retainServerIds]
  /// covers in-flight local edits/deletes so bootstrap cannot clobber them.
  /// Returns the removed rows so their notifications can be cancelled.
  Future<List<Task>> discardLocalTasksAbsentFromRemote(
    Set<int> remoteServerIds, {
    Set<int> retainServerIds = const {},
  }) async {
    final removed = <Task>[];
    for (final task in await _local.getTasks()) {
      final serverId = task.serverId ?? int.tryParse(task.id) ?? 0;
      if (serverId == 0) continue;
      if (remoteServerIds.contains(serverId)) continue;
      if (retainServerIds.contains(serverId)) continue;
      await _local.deleteTask(task.id);
      removed.add(task);
    }
    return removed;
  }

  /// Applies a single remote delete from GET `/sync/changes` tombstones.
  /// Returns the removed rows so their notifications can be cancelled.
  Future<List<Task>> discardRemoteDeletedTask(int serverId) async {
    if (serverId == 0) return const [];
    final removed = [
      for (final task in await _local.getTasks())
        if ((task.serverId ?? int.tryParse(task.id) ?? 0) == serverId) task,
    ];
    await _local.deleteTasksByServerId(serverId);
    return removed;
  }

  Future<Map<String, int>> getThemeColors() => _local.getThemeColors();

  Future<void> saveThemeColor(String name, int colorArgb) =>
      _local.saveThemeColor(name, colorArgb);

  Future<void> registerTheme(String? theme, int? colorArgb) =>
      _local.registerTheme(theme, colorArgb);

  Future<TasksUiTheme> getUiTheme() => _local.getUiTheme();

  Future<void> setUiTheme(TasksUiTheme theme) => _local.setUiTheme(theme);
}
