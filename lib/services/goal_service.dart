import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/local_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../core/sync/sync_queue_service.dart';
import '../models/user_goal.dart';
import 'auth_service.dart';

class GoalService {
  GoalService(
    this._authService, {
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
    SyncQueueService? queue,
  }) : _localDb = localDb,
       _executor = executor,
       _queue = queue,
       _dio = _authService.createDio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 3),
           receiveTimeout: const Duration(seconds: 3),
         ),
       );

  final AuthService _authService;
  final LocalDb? _localDb;
  final LocalRemoteExecutor? _executor;
  final SyncQueueService? _queue;
  final Dio _dio;

  List<UserGoal> _goals = [];
  bool _initialized = false;
  static const prefsKey = 'user_goals_cache';

  bool get _useSqlite => !kIsWeb && _localDb != null;

  Future<void> _init() async {
    if (_initialized) return;
    if (_useSqlite) {
      _goals = await _loadFromSqlite();
    } else {
      _goals = await _loadFromPrefs();
    }
    _initialized = true;
  }

  Future<List<UserGoal>> _loadFromSqlite({bool? isArchived = false}) async {
    final db = await _localDb!.database;
    final rows = isArchived == null
        ? await db.query('user_goals', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'user_goals',
            where: 'isArchived = ?',
            whereArgs: [isArchived ? 1 : 0],
            orderBy: 'name COLLATE NOCASE',
          );
    return rows.map((row) => UserGoal.fromJson(row)).toList();
  }

  Future<List<UserGoal>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getStringList(prefsKey);
    if (goalsJson == null) return [];
    return goalsJson.map((json) {
      final map = jsonDecode(json);
      return UserGoal.fromJson(Map<String, dynamic>.from(map as Map));
    }).toList();
  }

  Future<void> _saveToStorage() async {
    if (_useSqlite) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = _goals.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(prefsKey, goalsJson);
  }

  /// Active goals by default (`false`); pass `true` for archived, `null` for all.
  Future<List<UserGoal>> getGoals({bool? isArchived = false}) async {
    await _init();
    if (_useSqlite) {
      final loaded = await _loadFromSqlite(isArchived: isArchived);
      // Keep `_goals` as the active working set.
      if (isArchived == false) {
        _goals = loaded;
      } else if (isArchived == null) {
        // Refresh active cache from the full read so it does not drift from DB.
        _goals = [
          for (final g in loaded)
            if (!g.isArchived) g,
        ];
      }
      return List.unmodifiable(loaded);
    }

    // Prefs/web: re-read durable storage (same freshness model as SQLite).
    // `_goals` is the full set here (active + archived).
    final loaded = await _loadFromPrefs();
    _goals = loaded;
    if (isArchived == null) {
      return List.unmodifiable(loaded);
    }
    return List.unmodifiable(loaded.where((g) => g.isArchived == isArchived));
  }

  Future<void> clearLocal() async {
    _goals = [];
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        await db.delete('user_goals');
      } catch (e) {
        debugPrint('Clear sqlite goals failed: $e');
      }
    }
  }

  Future<UserGoal?> getGoalByLocalId(int localId) async {
    await _init();
    for (final goal in _goals) {
      if (goal.localId == localId) return goal;
    }
    if (_useSqlite) {
      final db = await _localDb!.database;
      final rows = await db.query(
        'user_goals',
        where: 'localId = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return UserGoal.fromJson(rows.first);
    }
    return null;
  }

  Future<void> assignServerId(UserGoal goal, int serverId) async {
    await _init();
    if (_useSqlite && goal.localId != null) {
      final db = await _localDb!.database;
      await db.update(
        'user_goals',
        {'id': serverId},
        where: 'localId = ?',
        whereArgs: [goal.localId],
      );
    }
    final index = _goals.indexWhere(
      (item) =>
          item.localId == goal.localId ||
          (item.id == goal.id && item.name == goal.name),
    );
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(id: serverId);
      await _saveToStorage();
    }
  }

  Future<UserGoal> saveGoal(UserGoal goal) async {
    await _init();
    final stamped = goal.copyWith(lastModified: DateTime.now().toUtc());
    var stored = stamped;

    if (_useSqlite) {
      final db = await _localDb!.database;
      final localId = await db.insert('user_goals', {
        'id': stamped.id,
        'name': stamped.name,
        'notes': _notesForStorage(stamped.notes),
        'isCompleted': stamped.isCompleted ? 1 : 0,
        'isArchived': stamped.isArchived ? 1 : 0,
        'lastModified': stamped.lastModified.toUtc().toIso8601String(),
      });
      stored = stamped.copyWith(localId: localId);
      _goals.add(stored);
    } else {
      _goals.add(stamped);
      await _saveToStorage();
    }

    await _pushGoal(stored, isNew: stored.id == null || stored.id == 0);
    return stored;
  }

  Future<UserGoal> updateGoal(UserGoal oldGoal, UserGoal newGoal) async {
    await _init();
    final stamped = newGoal.copyWith(
      localId: oldGoal.localId,
      id: newGoal.id ?? oldGoal.id,
      lastModified: DateTime.now().toUtc(),
    );
    final index = _goals.indexWhere(
      (g) =>
          g.localId == oldGoal.localId ||
          (g.id == oldGoal.id && g.name == oldGoal.name),
    );
    if (index == -1) return stamped;

    if (_useSqlite && stamped.localId != null) {
      final db = await _localDb!.database;
      await db.update(
        'user_goals',
        {
          'id': stamped.id,
          'name': stamped.name,
          'notes': _notesForStorage(stamped.notes),
          'isCompleted': stamped.isCompleted ? 1 : 0,
          'isArchived': stamped.isArchived ? 1 : 0,
          'lastModified': stamped.lastModified.toUtc().toIso8601String(),
        },
        where: 'localId = ?',
        whereArgs: [stamped.localId],
      );
    }
    _goals[index] = stamped;
    await _saveToStorage();
    await _pushGoal(stamped, isNew: false);
    return stamped;
  }

  /// Updates archive flag locally without pushing a full goal save.
  Future<UserGoal> applyLocalArchiveStatus(UserGoal goal) async {
    await _init();
    final stamped = goal.copyWith(lastModified: DateTime.now().toUtc());
    final index = _goals.indexWhere((g) => _isSameGoal(g, stamped));

    if (_useSqlite && stamped.localId != null) {
      final db = await _localDb!.database;
      await db.update(
        'user_goals',
        {
          'isArchived': stamped.isArchived ? 1 : 0,
          'lastModified': stamped.lastModified.toUtc().toIso8601String(),
        },
        where: 'localId = ?',
        whereArgs: [stamped.localId],
      );
    } else if (_useSqlite && stamped.id != null) {
      final db = await _localDb!.database;
      await db.update(
        'user_goals',
        {
          'isArchived': stamped.isArchived ? 1 : 0,
          'lastModified': stamped.lastModified.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [stamped.id],
      );
    }

    if (index != -1) {
      // SQLite keeps archived rows in the DB; `_goals` is the active cache only.
      // Prefs/web storage *is* `_goals`, so archived rows must stay in the list.
      if (stamped.isArchived && _useSqlite) {
        _goals.removeAt(index);
      } else {
        _goals[index] = stamped;
      }
    } else if (!stamped.isArchived || !_useSqlite) {
      _goals.add(stamped);
    }
    await _saveToStorage();
    return stamped;
  }

  /// Prefer local/server ids. Treat `id` null/0 as unsynced so a row that
  /// later receives a server id still matches its prefs copy by name.
  bool _isSameGoal(UserGoal a, UserGoal b) {
    if (a.localId != null && a.localId == b.localId) return true;
    final aId = _effectiveServerId(a.id);
    final bId = _effectiveServerId(b.id);
    if (aId != null && aId == bId) return true;
    if (a.name != b.name) return false;
    // Same name: match when at least one side is still unsynced.
    return aId == null || bId == null;
  }

  int? _effectiveServerId(int? id) => (id == null || id == 0) ? null : id;

  String? _notesForStorage(String notes) {
    final trimmed = notes.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pushGoal(UserGoal goal, {required bool isNew}) async {
    if (AppConfig.useLocalData) return;
    final payload = goal.toJson();
    Future<void> remote() async {
      final token = await _authService.getToken();
      if (token == null) {
        throw StateError('Missing auth token');
      }
      final serverId = isNew ? 0 : (goal.id ?? 0);
      final response = await _dio.post(
        '${AuthService.baseUrl}/api${ApiEndpoints.goals}/$serverId',
        data: {
          'id': serverId,
          'name': goal.name,
          'notes': _notesForStorage(goal.notes),
          'isCompleted': goal.isCompleted,
          'isArchived': goal.isArchived,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw StateError('Push goal failed: ${response.statusCode}');
      }
      final data = response.data;
      final newId = data is Map ? data['id'] as int? : null;
      if (newId != null && newId != goal.id) {
        await assignServerId(goal, newId);
      }
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.save,
        payload: payload,
        entityId: goal.id,
        entityLocalId: goal.localId,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (e) {
        debugPrint('Push Goal Error: $e');
        await _queue?.addToQueue(
          handlerType: SyncHandlerType.userGoal,
          operation: OperationKind.save,
          payload: payload,
          entityId: goal.id,
          entityLocalId: goal.localId,
        );
      }
    }());
  }

  Future<bool> setArchiveStatus(UserGoal goal) async {
    final serverId = goal.id;
    if (serverId == null || serverId == 0) {
      // Local row already updated; a pending Save will load isArchived from SQLite.
      return true;
    }
    if (AppConfig.useLocalData) return true;

    final payload = {
      'goalId': serverId,
      'isArchived': goal.isArchived,
      'lastModified': DateTime.now().toUtc().toIso8601String(),
    };

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: () =>
            pushArchiveStatus(goalId: serverId, isArchived: goal.isArchived),
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.setArchiveStatus,
        payload: payload,
        entityId: serverId,
        entityLocalId: goal.localId,
      );
      return true;
    }

    try {
      unawaited(
        pushArchiveStatus(
          goalId: serverId,
          isArchived: goal.isArchived,
        ).catchError((Object e) async {
          debugPrint('Set goal archive status error: $e');
          await _queue?.addToQueue(
            handlerType: SyncHandlerType.userGoal,
            operation: OperationKind.setArchiveStatus,
            payload: payload,
            entityId: serverId,
            entityLocalId: goal.localId,
          );
        }),
      );
      return true;
    } catch (e) {
      debugPrint('Set goal archive status error: $e');
      await _queue?.addToQueue(
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.setArchiveStatus,
        payload: payload,
        entityId: serverId,
        entityLocalId: goal.localId,
      );
      return true;
    }
  }

  Future<void> pushArchiveStatus({
    required int goalId,
    required bool isArchived,
    String? lastModified,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw StateError('Missing auth token');
    }
    final response = await _dio.post(
      '${AuthService.baseUrl}/api${ApiEndpoints.goalArchiveStatus}',
      data: {
        'goalId': goalId,
        'isArchived': isArchived,
        'lastModified':
            lastModified ?? DateTime.now().toUtc().toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('Push goal archive status failed: $statusCode');
    }
  }

  Future<List<UserGoal>> getArchivedGoals() async {
    await _init();
    if (_useSqlite) {
      final local = await _loadFromSqlite(isArchived: true);
      if (AppConfig.useLocalData) return local;
      try {
        await syncArchivedFromBackend();
        return await _loadFromSqlite(isArchived: true);
      } catch (e) {
        debugPrint('Failed to sync archived goals: $e');
        return local;
      }
    }
    return _goals.where((g) => g.isArchived).toList();
  }

  Future<void> syncArchivedFromBackend() async {
    if (AppConfig.useLocalData || !_useSqlite) return;
    final token = await _authService.getToken();
    if (token == null) return;
    final response = await _dio.get(
      '${AuthService.baseUrl}/api${ApiEndpoints.goalsArchive}',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data is! List) return;
    final db = await _localDb!.database;
    for (final item in data) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id'] ?? map['Id'];
      final name = '${map['name'] ?? map['Name'] ?? ''}';
      if (id == null || name.isEmpty) continue;
      final existing = await db.query(
        'user_goals',
        columns: ['localId'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final row = <String, Object?>{
        'id': id,
        'name': name,
        'isCompleted':
            map['isCompleted'] == true ||
                map['IsCompleted'] == true ||
                map['isCompleted'] == 1
            ? 1
            : 0,
        'isArchived': 1,
        'lastModified':
            map['lastModified']?.toString() ??
            map['LastModified']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      };
      // Preserve local notes when an older archive API omits the field.
      if (map.containsKey('notes') || map.containsKey('Notes')) {
        row['notes'] = _notesForStorage(
          '${map['notes'] ?? map['Notes'] ?? ''}',
        );
      }
      if (existing.isEmpty) {
        await db.insert('user_goals', row);
      } else {
        await db.update(
          'user_goals',
          row,
          where: 'localId = ?',
          whereArgs: [existing.first['localId']],
        );
      }
    }
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _init();
    _goals.removeWhere(
      (g) =>
          g.localId == goal.localId || (g.id == goal.id && g.name == goal.name),
    );
    if (_useSqlite && goal.localId != null) {
      final db = await _localDb!.database;
      await db.delete(
        'user_goals',
        where: 'localId = ?',
        whereArgs: [goal.localId],
      );
    } else if (_useSqlite && goal.id != null) {
      final db = await _localDb!.database;
      await db.delete('user_goals', where: 'id = ?', whereArgs: [goal.id]);
    }
    await _saveToStorage();

    if (AppConfig.useLocalData) return;
    final id = goal.id;
    if (id == null || id == 0) return;

    Future<void> remote() async {
      final token = await _authService.getToken();
      if (token == null) return;
      await _dio.delete(
        '${AuthService.baseUrl}/api${ApiEndpoints.goals}/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.delete,
        payload: goal.toJson(),
        entityId: id,
        entityLocalId: goal.localId,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (e) {
        debugPrint('Delete Goal Error: $e');
        await _queue?.addToQueue(
          handlerType: SyncHandlerType.userGoal,
          operation: OperationKind.delete,
          payload: goal.toJson(),
          entityId: id,
          entityLocalId: goal.localId,
        );
      }
    }());
  }
}
