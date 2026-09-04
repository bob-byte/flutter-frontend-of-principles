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
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getStringList(prefsKey);
      if (goalsJson != null) {
        _goals = goalsJson.map((json) {
          final map = jsonDecode(json);
          return UserGoal.fromJson(Map<String, dynamic>.from(map as Map));
        }).toList();
      }
    }
    _initialized = true;
  }

  Future<List<UserGoal>> _loadFromSqlite() async {
    final db = await _localDb!.database;
    final rows = await db.query('user_goals', orderBy: 'name COLLATE NOCASE');
    return rows.map((row) => UserGoal.fromJson(row)).toList();
  }

  Future<void> _saveToStorage() async {
    if (_useSqlite) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = _goals.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(prefsKey, goalsJson);
  }

  Future<List<UserGoal>> getGoals() async {
    await _init();
    if (_useSqlite) {
      _goals = await _loadFromSqlite();
    }
    return List.unmodifiable(_goals);
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

  Future<void> saveGoal(UserGoal goal) async {
    await _init();
    final stamped = goal.copyWith(lastModified: DateTime.now().toUtc());
    var stored = stamped;

    if (_useSqlite) {
      final db = await _localDb!.database;
      final localId = await db.insert('user_goals', {
        'id': stamped.id,
        'name': stamped.name,
        'isCompleted': stamped.isCompleted ? 1 : 0,
        'lastModified': stamped.lastModified.toUtc().toIso8601String(),
      });
      stored = stamped.copyWith(localId: localId);
      _goals.add(stored);
    } else {
      _goals.add(stamped);
      await _saveToStorage();
    }

    await _pushGoal(stored, isNew: stored.id == null || stored.id == 0);
  }

  Future<void> updateGoal(UserGoal oldGoal, UserGoal newGoal) async {
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
    if (index == -1) return;

    if (_useSqlite && stamped.localId != null) {
      final db = await _localDb!.database;
      await db.update(
        'user_goals',
        {
          'id': stamped.id,
          'name': stamped.name,
          'isCompleted': stamped.isCompleted ? 1 : 0,
          'lastModified': stamped.lastModified.toUtc().toIso8601String(),
        },
        where: 'localId = ?',
        whereArgs: [stamped.localId],
      );
    }
    _goals[index] = stamped;
    await _saveToStorage();
    await _pushGoal(stamped, isNew: false);
  }

  Future<void> _pushGoal(UserGoal goal, {required bool isNew}) async {
    if (AppConfig.useLocalData) return;
    final payload = goal.toJson();
    Future<void> remote() async {
      final token = await _authService.getToken();
      if (token == null) return;
      final serverId = isNew ? 0 : (goal.id ?? 0);
      final response = await _dio.post(
        '${AuthService.baseUrl}${ApiEndpoints.goals}/$serverId',
        data: {
          'id': serverId,
          'name': goal.name,
          'isCompleted': goal.isCompleted,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final newId = data is Map ? data['id'] as int? : null;
        if (newId != null && newId != goal.id) {
          await assignServerId(goal, newId);
        }
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
        '${AuthService.baseUrl}${ApiEndpoints.goals}/$id',
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
