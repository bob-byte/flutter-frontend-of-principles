import '../../models/frequency_config.dart';
import '../../models/habit.dart';
import '../../models/habit_record.dart';
import '../../models/habit_reminder.dart';
import '../../models/progress_value.dart';
import '../../models/user.dart';
import '../../models/user_goal.dart';
import '../../services/ai_conversation_service.dart';
import '../../services/database_service.dart';
import '../../services/habit_service.dart';
import '../../services/reminder_service.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';
import 'pending_sync_index.dart';
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
    this.conversationService,
  });

  final SyncQueueService queue;
  final DatabaseService databaseService;
  final UserService userService;
  final ReminderService reminderService;
  final TaskService taskService;
  final AiConversationService? conversationService;

  Future<void> merge(SyncBootstrapSnapshot snapshot) async {
    if (snapshot.requiresFullBootstrap) return;
    final pending = PendingSyncIndex(await queue.getBlockingItems());
    await _mergeUser(snapshot, pending);
    await _mergeGoals(snapshot, pending);
    await _mergeHabits(snapshot, pending);
    await _mergeReminder(snapshot, pending);
    await _mergeTasks(snapshot, pending);
    await _mergeConversations(snapshot, pending);
    if (snapshot.isDelta) {
      await _applyDeletedIds(snapshot, pending);
    }
  }

  Future<void> _mergeUser(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    final remote = snapshot.user;
    if (remote == null) return;

    final local = await userService.loadLocalUser();
    final localIsNewer =
        local?.lastModified != null &&
        remote.lastModified != null &&
        local!.lastModified!.isAfter(remote.lastModified!);

    // Pending local profile writes (or a newer local stamp) must not wipe
    // server-owned fields like email. Always fill blanks from remote.
    if (pending.hasUser || localIsNewer) {
      if (local != null) {
        await userService.saveLocalUser(
          UserService.fillMissingFromRemote(local, remote),
        );
      }
      return;
    }

    await userService.saveLocalUser(
      User(
        localId: local?.localId,
        id: remote.id,
        name: remote.name,
        mainSlogan: remote.mainSlogan,
        mission: remote.mission,
        email: remote.email,
        gender: remote.gender,
        // Bootstrap DTO may omit HasSeenRoadGuide — keep a local true flag.
        hasSeenRoadGuide:
            (local?.hasSeenRoadGuide ?? false) || remote.hasSeenRoadGuide,
        lastModified: remote.lastModified,
      ),
    );
  }

  Future<void> _mergeGoals(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    final localGoals = await databaseService.getAllGoals();
    final localByServerId = <int, UserGoal>{
      for (final goal in localGoals)
        if (goal.id != null && goal.id != 0) goal.id!: goal,
    };

    final toUpsert = <UserGoal>[];
    for (var i = 0; i < snapshot.goals.length; i++) {
      final goal = snapshot.goals[i];
      final id = goal.id;
      if (id == null || id == 0) continue;
      final local = localByServerId[id];
      if (pending.pendingGoal(serverId: id, localId: local?.localId)) continue;
      if (local != null && local.lastModified.isAfter(goal.lastModified)) {
        continue;
      }
      if (local != null &&
          local.name == goal.name &&
          local.isCompleted == goal.isCompleted &&
          !local.lastModified.isBefore(goal.lastModified) &&
          !goal.lastModified.isBefore(local.lastModified)) {
        continue;
      }
      toUpsert.add(goal.copyWith(localId: local?.localId));
    }
    await databaseService.upsertGoals(toUpsert);

    if (snapshot.isDelta) return;
    final remoteIds = {
      for (final goal in snapshot.goals)
        if (goal.id != null && goal.id != 0) goal.id!,
    };
    final toDelete = <int>[];
    for (final local in localGoals) {
      final id = local.id;
      if (id == null || id == 0) continue;
      if (remoteIds.contains(id)) continue;
      if (pending.pendingGoal(serverId: id, localId: local.localId)) continue;
      toDelete.add(id);
    }
    await databaseService.deleteGoalsByServerIds(toDelete);
  }

  Future<void> _mergeHabits(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    final remoteServerIds = <int>{};
    for (final item in snapshot.activeHabits) {
      final backendId = readJsonInt(item['id'] ?? item['Id']);
      if (backendId != null) remoteServerIds.add(backendId);
    }
    for (final archived in snapshot.archivedHabits) {
      remoteServerIds.add(archived.id);
    }

    var localHabits = await databaseService.getAllHabits(isArchived: null);
    if (await _vacateCollisions(remoteServerIds, localHabits)) {
      localHabits = await databaseService.getAllHabits(isArchived: null);
    }
    final maps = _HabitMaps(localHabits);

    final recordHabitIds = <int>{
      for (final id in remoteServerIds) id,
      for (final id in remoteServerIds)
        if (maps.lookup(id)?.id != null) maps.lookup(id)!.id!,
    };
    final recordsByHabit = <int, Map<String, HabitRecord>>{};
    for (final record in await databaseService.getRecordsForHabitIds(
      recordHabitIds,
    )) {
      (recordsByHabit[record.habitId] ??= {})[_habitDateKey(record.date)] =
          record;
    }

    final habitsToUpsert = <Habit>[];
    final existingHabitIds = <int>{};
    final progressWrites = <HabitRecordWrite>[];
    final archivedToUpsert = <({int id, String name})>[];
    final archivedExistingIds = <int>{};

    for (var i = 0; i < snapshot.activeHabits.length; i++) {
      final item = snapshot.activeHabits[i];
      final backendId = readJsonInt(item['id'] ?? item['Id']);
      if (backendId == null) continue;

      final local = maps.lookup(backendId);
      final lastModified = _date(item['lastModified'] ?? item['LastModified']);
      final isPending = pending.pendingHabit(
        serverId: backendId,
        localId: local?.id,
      );
      final localNewer =
          local?.lastModified != null &&
          lastModified != null &&
          local!.lastModified!.isAfter(lastModified);
      final unchanged =
          local != null &&
          lastModified != null &&
          local.lastModified != null &&
          !local.lastModified!.isAfter(lastModified) &&
          !lastModified.isAfter(local.lastModified!);

      if (!isPending && !localNewer && !unchanged) {
        final remoteHabit = _habitFromBootstrap(
          item,
          backendId,
          lastModified,
          isArchived: false,
        );
        final localId = local?.id ?? backendId;
        habitsToUpsert.add(
          remoteHabit.copyWith(id: localId, serverId: backendId),
        );
        if (local?.id != null) existingHabitIds.add(local!.id!);
      }

      progressWrites.addAll(
        _progressWritesFor(
          backendId,
          item['progresses'] ?? item['Progresses'],
          recordsByHabit[local?.id ?? backendId] ??
              recordsByHabit[backendId] ??
              const {},
          pending,
        ),
      );
    }

    for (final archived in snapshot.archivedHabits) {
      final local = maps.lookup(archived.id);
      if (pending.pendingHabit(serverId: archived.id, localId: local?.id)) {
        continue;
      }
      if (local?.lastModified != null &&
          archived.lastModified != null &&
          local!.lastModified!.isAfter(archived.lastModified!)) {
        continue;
      }
      if (local != null && local.isArchived) continue;
      final targetId = local?.id ?? archived.id;
      archivedToUpsert.add((id: targetId, name: archived.name));
      if (local?.id != null) archivedExistingIds.add(local!.id!);
    }

    await databaseService.upsertHabits(
      habitsToUpsert,
      existingLocalIds: existingHabitIds,
    );
    await databaseService.upsertArchivedHabits(
      archivedToUpsert,
      existingLocalIds: archivedExistingIds,
    );
    await databaseService.applyHabitRecordWrites(progressWrites);

    if (snapshot.isDelta) return;
    final toDelete = <int>[];
    for (final local in localHabits) {
      final serverId = confirmedServerHabitId(local);
      if (serverId == null) continue;
      if (remoteServerIds.contains(serverId)) continue;
      if (pending.pendingHabit(serverId: serverId, localId: local.id)) {
        continue;
      }
      if (pending.habitHasPendingProgress(serverId, local.id)) continue;
      toDelete.add(local.id ?? serverId);
    }
    await databaseService.deleteHabitsByIds(toDelete);
  }

  Future<bool> _vacateCollisions(
    Set<int> remoteServerIds,
    List<Habit> localHabits,
  ) async {
    var vacatedAny = false;
    for (final local in localHabits) {
      final id = local.id;
      if (id == null || !remoteServerIds.contains(id)) continue;
      if (confirmedServerHabitId(local) != null) continue;
      await _vacateIfNeeded(id);
      vacatedAny = true;
    }
    return vacatedAny;
  }

  Future<void> _vacateIfNeeded(int backendId) async {
    final vacated = await databaseService.vacateLocalOnlyHabitOccupyingId(
      backendId,
    );
    if (vacated == null) return;
    await queue.repointEntity(
      handlerType: SyncHandlerType.userHabit,
      fromLocalId: backendId,
      toLocalId: vacated,
    );
    await queue.rewriteProgressHabitId(
      fromHabitId: backendId,
      toHabitId: vacated,
    );
  }

  Habit _habitFromBootstrap(
    Map<String, dynamic> item,
    int backendId,
    DateTime? lastModified, {
    required bool isArchived,
  }) {
    final habitName = item['name'] ?? item['Name'] ?? 'Habit';
    final description = item['description'] ?? item['Description'];
    final complexity =
        readJsonInt(item['complexity'] ?? item['Complexity']) ?? 5;
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
    final frequency =
        frequencyFromApi(item['frequency'] ?? item['Frequency']) ??
        const FrequencyConfig(type: FrequencyType.daily);
    return Habit(
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
      isArchived: isArchived,
      reminders: _remindersFromBootstrap(item),
    );
  }

  List<HabitReminder> _remindersFromBootstrap(Map<String, dynamic> item) {
    final raw = item['reminders'] ?? item['Reminders'];
    if (raw is! List) return const [];
    final reminders = <HabitReminder>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      reminders.add(
        HabitReminder.fromApiJson(Map<String, dynamic>.from(entry)),
      );
    }
    return reminders;
  }

  List<HabitRecordWrite> _progressWritesFor(
    int habitId,
    dynamic progresses,
    Map<String, HabitRecord> localByDate,
    PendingSyncIndex pending,
  ) {
    if (progresses is! List) return const [];
    final writes = <HabitRecordWrite>[];
    for (var i = 0; i < progresses.length; i++) {
      final prog = progresses[i];
      if (prog is! Map) continue;
      final progMap = Map<dynamic, dynamic>.from(prog);
      final parsedDate = progressDateFromApi(
        progMap['date'] ?? progMap['Date'],
      );
      final pVal = readJsonInt(progMap['value'] ?? progMap['Value']);
      if (parsedDate == null || pVal == null || pVal == kProgressUnknown) {
        continue;
      }
      final dateKey = _habitDateKey(parsedDate);
      final local = localByDate[dateKey];
      if (pending.pendingProgress(
        habitId: habitId,
        dateKey: dateKey,
        recordId: local?.id,
      )) {
        continue;
      }
      final remoteLastModified = _date(
        progMap['lastModified'] ?? progMap['LastModified'],
      );
      final localTs = local?.lastModified;
      if (localTs != null &&
          remoteLastModified != null &&
          localTs.isAfter(remoteLastModified)) {
        continue;
      }
      if (local != null && local.value == pVal) continue;
      writes.add((
        habitId: habitId,
        date: parsedDate,
        value: pVal,
        existingId: local?.id,
        lastModified: remoteLastModified,
      ));
    }
    return writes;
  }

  Future<void> _mergeReminder(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    if (snapshot.remindersProvided) {
      reminderService.rememberBootstrapReminders(snapshot.reminders);
    }
    final reminder = snapshot.habitsReportReminder;
    if (pending.hasReminder) {
      return;
    }
    // Delta may omit an unchanged report reminder — do not clear local.
    if (reminder == null || reminder.isUnset) {
      if (!snapshot.isDelta) {
        await reminderService.clearFromRemote();
      }
      return;
    }
    await reminderService.mergeFromBootstrap(reminder);
  }

  Future<void> _applyDeletedIds(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    final goalDeletes = [
      for (final id in snapshot.deletedGoalIds)
        if (!pending.pendingGoal(serverId: id)) id,
    ];
    await databaseService.deleteGoalsByServerIds(goalDeletes);

    if (snapshot.deletedHabitIds.isNotEmpty) {
      final localHabits = await databaseService.getAllHabits(isArchived: null);
      final maps = _HabitMaps(localHabits);
      final habitDeletes = <int>[];
      for (final id in snapshot.deletedHabitIds) {
        final local = maps.lookup(id);
        if (pending.pendingHabit(serverId: id, localId: local?.id)) continue;
        habitDeletes.add(local?.id ?? id);
      }
      await databaseService.deleteHabitsByIds(habitDeletes);
    }

    for (final id in snapshot.deletedTaskIds) {
      if (pending.pendingTask(id)) continue;
      await taskService.discardRemoteDeletedTask(id);
    }
    final conversations = conversationService;
    if (conversations == null) return;
    for (final id in snapshot.deletedConversationIds) {
      if (pending.pendingConversation(serverId: id)) continue;
      await conversations.discardRemoteDeletedConversation(id);
    }
  }

  Future<void> _mergeTasks(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    for (var i = 0; i < snapshot.tasks.length; i++) {
      final dto = snapshot.tasks[i];
      if (pending.pendingTaskDeletes.contains(dto.id) ||
          pending.pendingTaskSaves.contains(dto.id)) {
        continue;
      }
      await taskService.mergeRemoteTask(dto);
    }

    if (!snapshot.tasksTrustedForPrune) return;
    await taskService.discardLocalTasksAbsentFromRemote(
      {for (final dto in snapshot.tasks) dto.id},
      retainServerIds: {
        ...pending.pendingTaskDeletes,
        ...pending.pendingTaskSaves,
      },
    );
  }

  Future<void> _mergeConversations(
    SyncBootstrapSnapshot snapshot,
    PendingSyncIndex pending,
  ) async {
    final service = conversationService;
    if (service == null) return;

    for (var i = 0; i < snapshot.conversations.length; i++) {
      final remote = snapshot.conversations[i];
      final serverId = remote.serverId ?? 0;
      if (pending.pendingConversation(
        serverId: serverId == 0 ? null : serverId,
        clientId: remote.id,
      )) {
        continue;
      }
      await service.mergeRemoteConversation(remote);
    }

    if (!snapshot.conversationsTrustedForPrune) return;
    await service.discardLocalConversationsAbsentFromRemote(
      remoteClientIds: {for (final remote in snapshot.conversations) remote.id},
      remoteServerIds: {
        for (final remote in snapshot.conversations)
          if (remote.serverId != null && remote.serverId != 0) remote.serverId!,
      },
      retainClientIds: pending.pendingConversationClientIds,
      retainServerIds: {
        ...pending.pendingConversationDeletes,
        ...pending.pendingConversationSaves,
      },
    );
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}

String _habitDateKey(DateTime date) => date.toIso8601String().substring(0, 10);

class _HabitMaps {
  _HabitMaps(List<Habit> habits) {
    for (final habit in habits) {
      final id = habit.id;
      if (id != null) byId[id] = habit;
      final serverId = confirmedServerHabitId(habit);
      if (serverId != null) byServerId[serverId] = habit;
    }
  }

  final byId = <int, Habit>{};
  final byServerId = <int, Habit>{};

  Habit? lookup(int backendId) => byServerId[backendId] ?? byId[backendId];
}
