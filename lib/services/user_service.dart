import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/local_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../models/user.dart';

class UserService {
  UserService({
    ApiClient? apiClient,
    this.forceLocalOnly = false,
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
  }) : _apiClient = apiClient,
       _localDb = localDb,
       _executor = executor;

  static const prefsKey = 'current_user_profile_v1';

  final ApiClient? _apiClient;
  final bool forceLocalOnly;
  final LocalDb? _localDb;
  final LocalRemoteExecutor? _executor;

  bool get _useRemote =>
      !forceLocalOnly && !AppConfig.useLocalData && _apiClient != null;

  bool get _useSqlite => !kIsWeb && _localDb != null && !forceLocalOnly;

  Future<User> getCurrentUser() async {
    final local = await loadLocalUser();
    if (local != null) return local;
    if (!_useRemote) return User();

    try {
      final response = await _apiClient!.get(ApiEndpoints.profile);
      final remote = _userFromResponse(response.data);
      if (remote == null) return User();
      await saveLocalUser(remote);
      return remote;
    } catch (e) {
      debugPrint('Get current user failed: $e');
      return User();
    }
  }

  Future<User?> loadLocalUser() async {
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        final rows = await db.query('users', limit: 1);
        if (rows.isNotEmpty) {
          return User(
            localId: rows.first['localId'] as int?,
            id: rows.first['id'] as int?,
            name: rows.first['name'] as String?,
            mainSlogan: rows.first['mainSlogan'] as String?,
            mission: rows.first['mission'] as String?,
            email: rows.first['email'] as String?,
            gender: rows.first['gender'] as int?,
            hasSeenRoadGuide: (rows.first['hasSeenRoadGuide'] as int? ?? 0) == 1,
            lastModified: rows.first['lastModified'] != null
                ? DateTime.tryParse(rows.first['lastModified'] as String)
                : null,
          );
        }
      } catch (e) {
        debugPrint('Load sqlite user failed: $e');
      }
    }
    return _loadPrefs();
  }

  Future<void> saveLocalUser(User user) async {
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        final rows = await db.query('users', limit: 1);
        final row = {
          'id': user.id,
          'name': user.name,
          'mainSlogan': user.mainSlogan,
          'mission': user.mission,
          'email': user.email,
          'gender': user.gender,
          'hasSeenRoadGuide': user.hasSeenRoadGuide ? 1 : 0,
          'lastModified': user.lastModified?.toUtc().toIso8601String(),
        };
        if (rows.isEmpty) {
          await db.insert('users', row);
        } else {
          await db.update(
            'users',
            row,
            where: 'localId = ?',
            whereArgs: [rows.first['localId']],
          );
        }
      } catch (e) {
        debugPrint('Save sqlite user failed: $e');
      }
    }
    await _savePrefs(user);
  }

  Future<void> saveUserName(String userName) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(name: userName, lastModified: lastModified),
      path: ApiEndpoints.profileName,
      operation: OperationKind.saveUserName,
      queuePayload: (lastModified) => {
        'UserName': userName,
        'LastModified': lastModified.toIso8601String(),
      },
      remoteBody: () => userName,
    );
  }

  Future<void> saveMainSlogan(String mainSlogan) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(mainSlogan: mainSlogan, lastModified: lastModified),
      path: ApiEndpoints.profileMainSlogan,
      operation: OperationKind.saveMainSlogan,
      queuePayload: (lastModified) => {
        'MainSlogan': mainSlogan,
        'LastModified': lastModified.toIso8601String(),
      },
      remoteBody: () => mainSlogan,
    );
  }

  Future<void> saveMission(String mission) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(mission: mission, lastModified: lastModified),
      path: ApiEndpoints.profileMission,
      operation: OperationKind.saveMission,
      queuePayload: (lastModified) => {
        'Mission': mission,
        'LastModified': lastModified.toIso8601String(),
      },
      remoteBody: () => mission,
    );
  }

  Future<void> saveGender(int gender) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(gender: gender, lastModified: lastModified),
      path: ApiEndpoints.profileGender,
      operation: OperationKind.saveGender,
      queuePayload: (lastModified) => {
        'Gender': gender,
        'LastModified': lastModified.toIso8601String(),
      },
      remoteBody: () => gender,
    );
  }

  Future<void> saveHasSeenRoadGuide(bool hasSeenRoadGuide) {
    return _saveField(
      update: (user, lastModified) => user.copyWith(
        hasSeenRoadGuide: hasSeenRoadGuide,
        lastModified: lastModified,
      ),
      path: ApiEndpoints.profileRoadGuide,
      operation: OperationKind.saveHasSeenRoadGuide,
      queuePayload: (lastModified) => {
        'HasSeenRoadGuide': hasSeenRoadGuide,
        'LastModified': lastModified.toIso8601String(),
      },
      remoteBody: () => hasSeenRoadGuide,
    );
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        await db.delete('users');
      } catch (e) {
        debugPrint('Clear sqlite user failed: $e');
      }
    }
  }

  Future<void> deleteAccount() async {
    if (_useRemote) {
      await _apiClient!.delete(ApiEndpoints.account);
    }
    await clearLocal();
  }

  Future<void> _saveField({
    required User Function(User user, DateTime lastModified) update,
    required String path,
    required String operation,
    required Map<String, dynamic> Function(DateTime lastModified) queuePayload,
    required Object? Function() remoteBody,
  }) async {
    final lastModified = DateTime.now().toUtc();
    final current = await loadLocalUser() ?? User();
    final updated = update(current, lastModified);
    final payload = queuePayload(lastModified);

    Future<void> remote() async {
      await _apiClient!.put(path, data: jsonEncode(remoteBody()));
    }

    if (_executor != null && _useRemote) {
      await _executor.execute<void>(
        localCall: () => saveLocalUser(updated),
        remoteCall: remote,
        handlerType: SyncHandlerType.user,
        operation: operation,
        payload: payload,
        entityId: updated.id,
        entityLocalId: updated.localId,
      );
      return;
    }

    await saveLocalUser(updated);
    if (!_useRemote) return;
    unawaited(() async {
      try {
        await remote();
      } catch (e) {
        debugPrint('Remote profile save failed: $e');
      }
    }());
  }

  Future<User?> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return User.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('Failed to parse cached user: $e');
      return null;
    }
  }

  Future<void> _savePrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(user.toJson()));
  }

  User? _userFromResponse(dynamic data) {
    if (data is! Map) return null;
    return User.fromJson(Map<String, dynamic>.from(data));
  }
}
