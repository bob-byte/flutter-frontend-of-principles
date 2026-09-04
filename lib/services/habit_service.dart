import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/network/network_service.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../core/sync/sync_queue_service.dart';
import '../models/habit.dart';
import '../models/frequency_config.dart';
import '../models/habit_record.dart';
import '../models/habit_reminder.dart';
import '../models/progress_value.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// .NET [TypeOfHabit]: None=0, Principled=1, Flexible=2, Mind=3.
const int kTypeOfHabitPrincipled = 1;
const int kTypeOfHabitFlexible = 2;

/// .NET [StatusOfHabit]: InProgress=0, Frozen=1.
const int kStatusOfHabitInProgress = 0;

/// .NET [FrequencyType]: EveryDay=0, EverySeveralDays=1, SeveralTimesPerPeriod=2.
const int kFrequencyEveryDay = 0;
const int kFrequencyEverySeveralDays = 1;
const int kFrequencySeveralTimesPerPeriod = 2;

/// .NET [ProgressValue] used as DefaultProgressValue.
const int kDefaultProgressUnknown = -1;
const int kDefaultProgressSkip = 3;

/// Builds [EditUserHabitDto] JSON matching MAUI [HabitRemoteApi.BuildDtoAsync].
@visibleForTesting
Map<String, dynamic> buildEditUserHabitDto(
  Habit habit, {
  required bool isNew,
  int? goalId,
}) {
  var backendType = kFrequencyEveryDay;
  var repeats = 1;
  var intervalLengthInDays = 1;

  if (habit.frequency.type == FrequencyType.everyXDays) {
    backendType = kFrequencyEverySeveralDays;
    intervalLengthInDays = habit.frequency.interval ?? 1;
  } else if (habit.frequency.type == FrequencyType.timesPerPeriod) {
    backendType = kFrequencySeveralTimesPerPeriod;
    repeats = habit.frequency.interval ?? 1;
    intervalLengthInDays = habit.frequency.period == PeriodType.month ? 30 : 7;
  }

  if (backendType == kFrequencyEveryDay) {
    intervalLengthInDays = 1;
    repeats = 1;
  } else if (backendType == kFrequencyEverySeveralDays) {
    repeats = 1;
  }

  final lastModified = DateTime.now().toUtc().toIso8601String();
  final goalName = habit.targetGoal.trim();
  final resolvedGoalId = goalId ?? habit.targetGoalId ?? 0;

  return {
    'id': isNew ? 0 : (habit.id ?? 0),
    'name': habit.name.trim(),
    'type': habit.isFlexible ? kTypeOfHabitFlexible : kTypeOfHabitPrincipled,
    'areasOfLife': <Map<String, dynamic>>[],
    'description': habit.notes.trim().isEmpty ? null : habit.notes.trim(),
    'goal': goalName.isEmpty
        ? null
        : {
            'id': resolvedGoalId > 0 ? resolvedGoalId : 0,
            'name': goalName,
            'lastModified': lastModified,
          },
    'question': '',
    'status': kStatusOfHabitInProgress,
    'isArchived': habit.isArchived,
    'frequency': {
      'id': 0,
      'type': backendType,
      'repeats': repeats,
      'intervalLengthInDays': intervalLengthInDays,
      'lastModified': lastModified,
    },
    'priority': 0,
    'complexity': habit.difficulty,
    'colorName': '#1C1C1C',
    'reminders': _remindersToApi(habit.reminders, lastModified),
    'endDate': habit.endDate == null
        ? null
        : '${habit.endDate!.year.toString().padLeft(4, '0')}-${habit.endDate!.month.toString().padLeft(2, '0')}-${habit.endDate!.day.toString().padLeft(2, '0')}',
    'endTime': habit.endDate == null
        ? null
        : '${habit.endDate!.hour.toString().padLeft(2, '0')}:${habit.endDate!.minute.toString().padLeft(2, '0')}:00',
    'allDay': habit.allDay,
    'constantReminder': habit.constantReminder,
    'lastModified': lastModified,
    'prioritizedHabits': <Map<String, dynamic>>[],
    'defaultProgressValue': habit.isFlexible
        ? kDefaultProgressSkip
        : kDefaultProgressUnknown,
    'progressMarkVariaty': 0,
  };
}

List<Map<String, dynamic>> _remindersToApi(
  List<HabitReminder> reminders,
  String lastModified,
) {
  final result = <Map<String, dynamic>>[];
  for (final reminder in reminders) {
    final title = reminder.title.trim();
    final days = reminder.daysOfWeek
        .map(
          (day) => {
            'id': 0,
            'type': toDotNetDayOfWeek(day.type),
            'userNotificationRequestId': day.userNotificationRequestId,
            'lastModified': lastModified,
          },
        )
        .toList();
    if (title.isEmpty || days.isEmpty) continue;
    result.add({
      'id': reminder.id ?? 0,
      'title': title,
      // DB column UserHabitReminders.Description is NOT NULL.
      'description': reminder.description.trim(),
      'time': toTimeOnlyString(reminder.time),
      'isEnabled': reminder.isEnabled,
      'lastModified': lastModified,
      'daysOfWeek': days,
      'offsets': reminder.offsets.map((e) => e.toJson()).toList(),
      'constantReminder': reminder.constantReminder,
      'constantNotificationRequestId': reminder.constantNotificationRequestId,
      'endTime': reminder.endTime == null
          ? null
          : toTimeOnlyString(reminder.endTime!),
      'allDay': reminder.allDay,
    });
  }
  return result;
}

int? readJsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

dynamic readMapValue(dynamic value, String camelKey, String pascalKey) {
  if (value is! Map) return null;
  final map = Map<dynamic, dynamic>.from(value);
  return map[camelKey] ?? map[pascalKey];
}

/// Maps backend [FrequencyDto] to local [FrequencyConfig].
FrequencyConfig? frequencyFromApi(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<dynamic, dynamic>.from(raw);
  final type = readJsonInt(map['type'] ?? map['Type']) ?? kFrequencyEveryDay;
  final repeats = readJsonInt(map['repeats'] ?? map['Repeats']) ?? 1;
  final intervalLengthInDays =
      readJsonInt(map['intervalLengthInDays'] ?? map['IntervalLengthInDays']) ??
      1;

  if (type == kFrequencyEverySeveralDays) {
    return FrequencyConfig(
      type: FrequencyType.everyXDays,
      interval: intervalLengthInDays < 1 ? 1 : intervalLengthInDays,
    );
  }
  if (type == kFrequencySeveralTimesPerPeriod) {
    return FrequencyConfig(
      type: FrequencyType.timesPerPeriod,
      interval: repeats < 1 ? 1 : repeats,
      period: intervalLengthInDays >= 30 ? PeriodType.month : PeriodType.week,
    );
  }
  return const FrequencyConfig(type: FrequencyType.daily);
}

/// Confirmed backend habit id, or null when the row is still local-only.
@visibleForTesting
int? confirmedServerHabitId(Habit habit) {
  final serverId = habit.serverId;
  if (serverId != null && serverId != 0) return serverId;
  return null;
}

/// Calendar date as DateOnly JSON (`yyyy-MM-dd`), ignoring time-zone shifts.
@visibleForTesting
String progressDateToApi(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Calendar date from DateOnly JSON (`yyyy-MM-dd`), ignoring time-zone shifts.
DateTime? progressDateFromApi(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) {
    return DateTime(raw.year, raw.month, raw.day);
  }
  if (raw is int) {
    final text = raw.toString();
    if (text.length == 8) {
      final year = int.tryParse(text.substring(0, 4));
      final month = int.tryParse(text.substring(4, 6));
      final day = int.tryParse(text.substring(6, 8));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
  }
  if (raw is String) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  if (raw is Map) {
    final map = Map<dynamic, dynamic>.from(raw);
    final year = readJsonInt(map['year'] ?? map['Year']);
    final month = readJsonInt(map['month'] ?? map['Month']);
    final day = readJsonInt(map['day'] ?? map['Day']);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}

int progressValueToApi(HabitStatus status) {
  switch (status) {
    case HabitStatus.completed:
      return kProgressYesManual;
    case HabitStatus.skipped:
      return kProgressSkip;
    case HabitStatus.none:
      return kProgressUnknown;
  }
}

/// Queued progress that the server will never accept (unknown habit, bad date).
class ProgressSyncDroppedException implements Exception {
  ProgressSyncDroppedException(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

class ServerHabitIdResolution {
  const ServerHabitIdResolution.ready(this.serverId) : drop = false;

  const ServerHabitIdResolution.drop() : serverId = null, drop = true;

  const ServerHabitIdResolution.retry() : serverId = null, drop = false;

  final int? serverId;
  final bool drop;
}

class HabitService {
  HabitService(
    this._authService, {
    DatabaseService? dbService,
    NetworkService? network,
    SyncQueueService? queue,
    LocalRemoteExecutor? executor,
  }) : _dbService = dbService ?? DatabaseService(),
       _network = network,
       _queue = queue,
       _executor = executor,
       _dio = _authService.createDio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
         ),
       );

  final AuthService _authService;
  final DatabaseService _dbService;
  final NetworkService? _network;
  final SyncQueueService? _queue;
  final LocalRemoteExecutor? _executor;
  final Dio _dio;
  Future<void>? _syncFromBackendFuture;

  bool get _online => _network?.isConnected ?? true;

  Future<Habit?> getHabitById(int id) => _dbService.getHabitById(id);

  Future<Habit?> getHabitByServerId(int serverId) =>
      _dbService.getHabitByServerId(serverId);

  /// Backend id only. Never falls back to a local-only SQLite id.
  Future<int?> serverIdForHabit(int localOrServerId) async {
    final habit =
        await _dbService.getHabitById(localOrServerId) ??
        await _dbService.getHabitByServerId(localOrServerId);
    if (habit == null) return null;
    return confirmedServerHabitId(habit);
  }

  /// Resolves a backend habit id, creating the habit first when it is local-only.
  Future<ServerHabitIdResolution> ensureServerHabitId(int localOrServerId) async {
    final habit =
        await _dbService.getHabitById(localOrServerId) ??
        await _dbService.getHabitByServerId(localOrServerId);
    if (habit == null) {
      return const ServerHabitIdResolution.drop();
    }

    final existing = confirmedServerHabitId(habit);
    if (existing != null) {
      return ServerHabitIdResolution.ready(existing);
    }

    if (_queue != null &&
        habit.id != null &&
        await _queue.hasBlocking(
          handlerType: SyncHandlerType.userHabit,
          entityLocalId: habit.id,
        )) {
      return const ServerHabitIdResolution.retry();
    }

    final created = await pushHabit(
      habit,
      isNew: true,
      enqueueOnFailure: true,
      awaitRemote: true,
    );
    if (created != null && created != 0) {
      return ServerHabitIdResolution.ready(created);
    }
    return const ServerHabitIdResolution.retry();
  }

  Future<void> syncFromBackend() {
    final inProgress = _syncFromBackendFuture;
    if (inProgress != null) return inProgress;

    late final Future<void> sync;
    sync = _performBackendSync().whenComplete(() {
      if (identical(_syncFromBackendFuture, sync)) {
        _syncFromBackendFuture = null;
      }
    });
    _syncFromBackendFuture = sync;
    return sync;
  }

  Future<void> _performBackendSync() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final response = await _dio.get(
        '${AuthService.baseUrl}/api/habits/inprogress',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        for (var item in data) {
          // Parse UserHabitInProgressShortDto
          final backendId = _readInt(item['id'] ?? item['Id']);
          if (backendId == null) continue;
          if (_queue != null &&
              await _queue.hasBlocking(
                handlerType: SyncHandlerType.userHabit,
                entityId: backendId,
                entityLocalId: backendId,
              )) {
            continue;
          }

          final habitName = item['name'] ?? item['Name'] ?? 'Невідома звичка';
          final description = item['description'] ?? item['Description'];
          final complexity =
              _readInt(item['complexity'] ?? item['Complexity']) ?? 5;
          final habitType = _readInt(item['type'] ?? item['Type']);
          final goalId = _readInt(
            item['goalId'] ??
                item['GoalId'] ??
                _mapValue(item['goal'] ?? item['Goal'], 'id', 'Id'),
          );
          final goalNameRaw =
              item['goalName'] ??
              item['GoalName'] ??
              _mapValue(item['goal'] ?? item['Goal'], 'name', 'Name');
          final goalName = goalNameRaw == null ? '' : '$goalNameRaw';
          final frequency =
              frequencyFromApi(item['frequency'] ?? item['Frequency']) ??
              const FrequencyConfig(type: FrequencyType.daily);

          // Parse progresses
          final progresses = item['progresses'] ?? item['Progresses'] ?? [];

          // Create local Habit object
          final localHabit = Habit(
            // We temporarily map the backend ID to our local ID so they match
            id: backendId,
            serverId: backendId,
            name: habitName,
            notes: description ?? '',
            difficulty: complexity,
            targetGoal: goalName,
            targetGoalId: goalId,
            isFlexible: habitType != kTypeOfHabitPrincipled,
            frequency: frequency,
          );

          // Note: To prevent duplicating, we can just insert with conflict resolution,
          // or we can just fetch and update.
          // We will rely on _dbService for the actual insert/update.
          await _dbService.insertOrUpdateHabitWithBackendId(localHabit);

          // Now parse records
          for (var prog in progresses) {
            if (prog is! Map) continue;
            final progMap = Map<dynamic, dynamic>.from(prog);
            final parsedDate = progressDateFromApi(
              progMap['date'] ?? progMap['Date'],
            );
            final pVal = _readInt(progMap['value'] ?? progMap['Value']);
            if (parsedDate != null &&
                pVal != null &&
                pVal != kProgressUnknown) {
              await _dbService.setHabitRecordValue(backendId, parsedDate, pVal);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sync From Backend Error: $e');
    }
  }

  Future<List<Habit>> getArchivedHabits() async {
    try {
      await syncArchivedFromBackend();
    } catch (e) {
      debugPrint('Archived habits sync error: $e');
    }
    return _dbService.getAllHabits(isArchived: true);
  }

  Future<void> syncArchivedFromBackend() async {
    final token = await _authService.getToken();
    if (token == null) return;

    final response = await _dio.get(
      '${AuthService.baseUrl}/api/habits/archive',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode != 200 || response.data is! List) return;

    for (final item in response.data as List<dynamic>) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = _readInt(map['id'] ?? map['Id']);
      if (id == null) continue;
      final rawName = map['name'] ?? map['Name'];
      final name = rawName == null || '$rawName'.trim().isEmpty
          ? 'Habit'
          : '$rawName';
      await _dbService.upsertArchivedHabit(id: id, name: name);
    }
  }

  Future<bool> setArchiveStatus(Habit habit) async {
    if (habit.id == null) return false;
    if (AppConfig.useLocalData) return true;

    final payload = {
      'habitId': habit.id,
      'isArchived': habit.isArchived,
      'lastModified': DateTime.now().toUtc().toIso8601String(),
    };

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: () =>
            pushArchiveStatus(habitId: habit.id!, isArchived: habit.isArchived),
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.setArchiveStatus,
        payload: payload,
        entityId: habit.serverId ?? habit.id,
        entityLocalId: habit.id,
      );
      return true;
    }

    try {
      unawaited(
        pushArchiveStatus(
          habitId: habit.id!,
          isArchived: habit.isArchived,
        ).catchError((Object e) async {
          debugPrint('Set archive status error: $e');
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.userHabit,
            operation: OperationKind.setArchiveStatus,
            payload: payload,
            entityId: habit.serverId ?? habit.id,
            entityLocalId: habit.id,
          );
        }),
      );
      return true;
    } catch (e) {
      debugPrint('Set archive status error: $e');
      await _queue?.addToQueue(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.setArchiveStatus,
        payload: payload,
        entityId: habit.serverId ?? habit.id,
        entityLocalId: habit.id,
      );
      return true;
    }
  }

  Future<void> pushArchiveStatus({
    required int habitId,
    required bool isArchived,
    String? lastModified,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw StateError('Missing auth token');
    }
    final response = await _dio.post(
      '${AuthService.baseUrl}/api/habits/archivestatus',
      data: {
        'habitId': habitId,
        'isArchived': isArchived,
        'lastModified':
            lastModified ?? DateTime.now().toUtc().toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('Archive status failed: $statusCode');
    }
  }

  Future<bool> deleteHabit(int habitId) async {
    if (habitId <= 0) return false;
    if (AppConfig.useLocalData) return true;

    if (_online) {
      unawaited(() async {
        try {
          await deleteHabitRemote(habitId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) return;
          debugPrint('Delete Habit Error: $e');
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.userHabit,
            operation: OperationKind.delete,
            payload: {'id': habitId},
            entityId: habitId,
            entityLocalId: habitId,
          );
        } catch (e) {
          debugPrint('Delete Habit Error: $e');
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.userHabit,
            operation: OperationKind.delete,
            payload: {'id': habitId},
            entityId: habitId,
            entityLocalId: habitId,
          );
        }
      }());
      return true;
    }

    await _queue?.addToQueue(
      handlerType: SyncHandlerType.userHabit,
      operation: OperationKind.delete,
      payload: {'id': habitId},
      entityId: habitId,
      entityLocalId: habitId,
    );
    return true;
  }

  Future<void> deleteHabitRemote(int habitId) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw StateError('Missing auth token');
    }
    final response = await _dio.delete(
      '${AuthService.baseUrl}/api/habits/$habitId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final statusCode = response.statusCode;
    if (statusCode == 404) return;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw StateError('Delete habit failed: $statusCode');
    }
  }

  int? _readInt(dynamic value) => readJsonInt(value);

  dynamic _mapValue(dynamic value, String camelKey, String pascalKey) =>
      readMapValue(value, camelKey, pascalKey);

  /// Saves the habit on the backend. Returns the backend id on success.
  ///
  /// New habits must be posted to `/api/habits/0` (MAUI uses [UserHabit.Id] == 0
  /// until [SaveHabitResponse] comes back).
  Future<int?> pushHabit(
    Habit habit, {
    required bool isNew,
    bool enqueueOnFailure = true,
    bool awaitRemote = false,
  }) async {
    Future<int?> remote() async {
      final token = await _authService.getToken();
      if (token == null) return null;

      final backendId = isNew ? 0 : (habit.serverId ?? habit.id ?? 0);
      final resolvedGoalId = await _dbService.resolveGoalServerId(
        habit.targetGoalId,
      );
      final payload = buildEditUserHabitDto(
        habit,
        isNew: isNew,
        goalId: resolvedGoalId ?? 0,
      );

      final response = await _dio.post(
        '${AuthService.baseUrl}/api/habits/$backendId',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final remoteId =
          _readSaveHabitResponseId(response.data) ?? (isNew ? null : habit.id);
      if (remoteId != null && habit.id != null && remoteId != habit.id) {
        await _dbService.reassignHabitId(habit.id!, remoteId);
        await _queue?.repointEntity(
          handlerType: SyncHandlerType.userHabit,
          fromLocalId: habit.id!,
          toLocalId: remoteId,
          toEntityId: remoteId,
        );
        await _queue?.rewriteProgressHabitId(
          fromHabitId: habit.id!,
          toHabitId: remoteId,
        );
      }
      return remoteId;
    }

    if (!enqueueOnFailure || _executor == null) {
      try {
        return await remote();
      } catch (e) {
        if (e is DioException) {
          debugPrint(
            'Push Habit Error: HTTP ${e.response?.statusCode} ${e.response?.data}',
          );
        } else {
          debugPrint('Push Habit Error: $e');
        }
        if (enqueueOnFailure) {
          await _enqueueHabitSave(habit, isNew: isNew);
        }
        return null;
      }
    }

    return _executor.execute<int?>(
      localCall: () async {},
      remoteCall: remote,
      handlerType: SyncHandlerType.userHabit,
      operation: OperationKind.save,
      payload: habit.toMap(),
      entityId: habit.serverId ?? (isNew ? null : habit.id),
      entityLocalId: habit.id,
      awaitRemote: awaitRemote,
    );
  }

  Future<void> _enqueueHabitSave(Habit habit, {required bool isNew}) {
    return _queue?.addToQueue(
          handlerType: SyncHandlerType.userHabit,
          operation: OperationKind.save,
          payload: habit.toMap(),
          entityId: habit.serverId ?? (isNew ? null : habit.id),
          entityLocalId: habit.id,
        ) ??
        Future.value();
  }

  int? _readSaveHabitResponseId(dynamic data) {
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data);
    if (data is! Map) return null;
    final map = Map<dynamic, dynamic>.from(data);
    return _readInt(map['id'] ?? map['Id']);
  }

  Future<bool> pushProgress(
    int habitId,
    DateTime date,
    HabitStatus status, {
    bool enqueueOnFailure = true,
  }) async {
    final resolved = await ensureServerHabitId(habitId);
    if (resolved.drop) {
      if (enqueueOnFailure) return false;
      throw ProgressSyncDroppedException(
        'Habit $habitId is not on this device; dropping queued progress.',
      );
    }

    final serverHabitId = resolved.serverId;
    final record = await _dbService.findRecord(habitId, date) ??
        (serverHabitId == null
            ? null
            : await _dbService.findRecord(serverHabitId, date));
    final payload = {
      'id': record?.id ?? 0,
      'date': progressDateToApi(date),
      'value': progressValueToApi(status),
      'habitId': serverHabitId ?? habitId,
    };

    if (serverHabitId == null || serverHabitId == 0) {
      if (enqueueOnFailure) {
        await _queue?.addToQueue(
          handlerType: SyncHandlerType.progressOfHabit,
          operation: OperationKind.save,
          payload: payload,
          entityId: record?.id,
          entityLocalId: record?.id,
        );
      }
      return false;
    }

    Future<bool> remote() async {
      final token = await _authService.getToken();
      if (token == null) return false;

      final val = progressValueToApi(status);
      if (val == kProgressUnknown) {
        return true;
      }

      final remotePayload = {
        'id': 0,
        'date': progressDateToApi(date),
        'value': val,
        'habitId': serverHabitId,
      };

      final response = await _dio.post(
        '${AuthService.baseUrl}/api/progressesofhabit/0',
        data: remotePayload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (statusCode) =>
              statusCode != null && (statusCode < 300 || statusCode == 400),
        ),
      );

      if (response.statusCode == 400) {
        debugPrint(
          'Push Progress rejected for habit $serverHabitId: ${response.data}',
        );
        if (!enqueueOnFailure) {
          throw ProgressSyncDroppedException(
            'Progress rejected for habit $serverHabitId: ${response.data}',
          );
        }
        return false;
      }

      return response.statusCode == 200 || response.statusCode == 201;
    }

    if (!enqueueOnFailure || _executor == null) {
      try {
        final ok = await remote();
        if (!ok && enqueueOnFailure) {
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.progressOfHabit,
            operation: OperationKind.save,
            payload: payload,
            entityId: record?.id,
            entityLocalId: record?.id,
          );
        }
        return ok;
      } on ProgressSyncDroppedException {
        if (enqueueOnFailure) return false;
        rethrow;
      } catch (e) {
        debugPrint('Push Progress Error: $e');
        if (enqueueOnFailure) {
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.progressOfHabit,
            operation: OperationKind.save,
            payload: payload,
            entityId: record?.id,
            entityLocalId: record?.id,
          );
        }
        return false;
      }
    }

    try {
      final result = await _executor.execute<bool>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        payload: payload,
        entityId: record?.id,
        entityLocalId: record?.id,
      );
      return result ?? true;
    } on ProgressSyncDroppedException {
      return false;
    }
  }
}
