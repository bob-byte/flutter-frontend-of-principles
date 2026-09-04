import '../../models/frequency_config.dart';
import '../../models/habit.dart';
import '../../models/progress_value.dart';
import '../../services/database_service.dart';
import '../../services/habit_service.dart';
import '../../services/reminder_service.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';
import 'sync_bootstrap_snapshot.dart';
import 'sync_handler_type.dart';
import 'sync_queue_service.dart';

class SyncSnapshotMergeService {
  SyncSnapshotMergeService({
    required this.queue,
    required this.databaseService,
    required this.userService,
    required this.reminderService,
    required this.taskService,
  });

  final SyncQueueService queue;
  final DatabaseService databaseService;
  final UserService userService;
  final ReminderService reminderService;
  final TaskService taskService;

  Future<void> merge(SyncBootstrapSnapshot snapshot) async {
    await _mergeUser(snapshot);
    await _mergeGoals(snapshot);
    await _mergeHabits(snapshot);
    await _mergeReminder(snapshot);
    await _mergeTasks(snapshot);
  }

  Future<void> _mergeUser(SyncBootstrapSnapshot snapshot) async {
    final remote = snapshot.user;
    if (remote == null) return;
    if (await queue.hasBlocking(handlerType: SyncHandlerType.user)) return;

    final local = await userService.loadLocalUser();
    if (local?.lastModified != null &&
        remote.lastModified != null &&
        local!.lastModified!.isAfter(remote.lastModified!)) {
      return;
    }
    await userService.saveLocalUser(remote);
  }

  Future<void> _mergeGoals(SyncBootstrapSnapshot snapshot) async {
    for (final goal in snapshot.goals) {
      final id = goal.id;
      if (id == null || id == 0) continue;
      if (await queue.hasBlocking(
        handlerType: SyncHandlerType.userGoal,
        entityId: id,
      )) {
        continue;
      }
      await databaseService.upsertGoal(goal);
    }
  }

  Future<void> _mergeHabits(SyncBootstrapSnapshot snapshot) async {
    for (final item in snapshot.activeHabits) {
      final backendId = readJsonInt(item['id'] ?? item['Id']);
      if (backendId == null) continue;
      if (await queue.hasBlocking(
        handlerType: SyncHandlerType.userHabit,
        entityId: backendId,
        entityLocalId: backendId,
      )) {
        continue;
      }

      final habitName = item['name'] ?? item['Name'] ?? 'Habit';
      final description = item['description'] ?? item['Description'];
      final complexity = readJsonInt(item['complexity'] ?? item['Complexity']) ?? 5;
      final habitType = readJsonInt(item['type'] ?? item['Type']);
      final goalId = readJsonInt(
        item['goalId'] ??
            item['GoalId'] ??
            readMapValue(item['goal'] ?? item['Goal'], 'id', 'Id'),
      );
      final goalNameRaw =
          item['goalName'] ??
          item['GoalName'] ??
          readMapValue(item['goal'] ?? item['Goal'], 'name', 'Name');
      final lastModified = _date(item['lastModified'] ?? item['LastModified']);
      final frequency =
          frequencyFromApi(item['frequency'] ?? item['Frequency']) ??
          const FrequencyConfig(type: FrequencyType.daily);

      await databaseService.insertOrUpdateHabitWithBackendId(
        Habit(
          id: backendId,
          serverId: backendId,
          name: '$habitName',
          notes: description?.toString() ?? '',
          difficulty: complexity,
          targetGoal: goalNameRaw == null ? '' : '$goalNameRaw',
          targetGoalId: goalId,
          isFlexible: habitType != kTypeOfHabitPrincipled,
          frequency: frequency,
          lastModified: lastModified,
        ),
      );

      final progresses = item['progresses'] ?? item['Progresses'] ?? [];
      if (progresses is! List) continue;
      for (final prog in progresses) {
        if (prog is! Map) continue;
        final progMap = Map<dynamic, dynamic>.from(prog);
        if (await queue.hasBlocking(
          handlerType: SyncHandlerType.progressOfHabit,
          entityId: readJsonInt(progMap['id'] ?? progMap['Id']),
        )) {
          continue;
        }
        final parsedDate = progressDateFromApi(progMap['date'] ?? progMap['Date']);
        final pVal = readJsonInt(progMap['value'] ?? progMap['Value']);
        if (parsedDate != null && pVal != null && pVal != kProgressUnknown) {
          await databaseService.setHabitRecordValue(backendId, parsedDate, pVal);
        }
      }
    }

    for (final archived in snapshot.archivedHabits) {
      if (await queue.hasBlocking(
        handlerType: SyncHandlerType.userHabit,
        entityId: archived.id,
        entityLocalId: archived.id,
      )) {
        continue;
      }
      await databaseService.upsertArchivedHabit(
        id: archived.id,
        name: archived.name,
      );
    }
  }

  Future<void> _mergeReminder(SyncBootstrapSnapshot snapshot) async {
    final reminder = snapshot.habitsReportReminder;
    if (reminder == null || reminder.isUnset) return;
    if (await queue.hasBlocking(handlerType: SyncHandlerType.reminder)) return;
    await reminderService.mergeFromBootstrap(reminder);
  }

  Future<void> _mergeTasks(SyncBootstrapSnapshot snapshot) async {
    final pendingDeletes = <int>{};
    final pendingSaves = <int>{};
    for (final item in await queue.getBlockingItems(
      handlerType: SyncHandlerType.task,
    )) {
      final id = item.entityId;
      if (id == null || id == 0) continue;
      if (item.operation.toLowerCase() == 'delete') {
        pendingDeletes.add(id);
      } else {
        pendingSaves.add(id);
      }
    }

    for (final dto in snapshot.tasks) {
      if (pendingDeletes.contains(dto.id) || pendingSaves.contains(dto.id)) {
        continue;
      }
      await taskService.mergeRemoteTask(dto);
    }
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
