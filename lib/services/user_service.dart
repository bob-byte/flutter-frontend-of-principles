import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/user.dart';

class UserService {
  UserService({ApiClient? apiClient, this.forceLocalOnly = false})
    : _apiClient = apiClient;

  static const prefsKey = 'current_user_profile_v1';

  final ApiClient? _apiClient;
  final bool forceLocalOnly;

  bool get _useRemote =>
      !forceLocalOnly && !AppConfig.useLocalData && _apiClient != null;

  Future<User> getCurrentUser() async {
    final local = await _loadLocal();
    if (!_useRemote) {
      return local ?? User();
    }

    try {
      final response = await _apiClient!.get(ApiEndpoints.profile);
      final remote = _userFromResponse(response.data);
      if (remote == null) {
        return local ?? User();
      }
      if (local?.lastModified != null &&
          remote.lastModified != null &&
          local!.lastModified!.isAfter(remote.lastModified!)) {
        return local;
      }
      await _saveLocal(remote);
      return remote;
    } catch (e) {
      debugPrint('Get current user failed: $e');
      return local ?? User();
    }
  }

  Future<void> saveUserName(String userName) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(name: userName, lastModified: lastModified),
      path: ApiEndpoints.profileName,
      body: (lastModified) => {
        'UserName': userName,
        'LastModified': lastModified.toIso8601String(),
      },
    );
  }

  Future<void> saveMainSlogan(String mainSlogan) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(mainSlogan: mainSlogan, lastModified: lastModified),
      path: ApiEndpoints.profileMainSlogan,
      body: (lastModified) => {
        'MainSlogan': mainSlogan,
        'LastModified': lastModified.toIso8601String(),
      },
    );
  }

  Future<void> saveMission(String mission) {
    return _saveField(
      update: (user, lastModified) =>
          user.copyWith(mission: mission, lastModified: lastModified),
      path: ApiEndpoints.profileMission,
      body: (lastModified) => {
        'Mission': mission,
        'LastModified': lastModified.toIso8601String(),
      },
    );
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
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
    required Map<String, dynamic> Function(DateTime lastModified) body,
  }) async {
    final lastModified = DateTime.now().toUtc();
    final current = await _loadLocal() ?? User();
    await _saveLocal(update(current, lastModified));

    if (!_useRemote) return;

    try {
      await _apiClient!.put(path, data: body(lastModified));
    } catch (e) {
      debugPrint('Remote profile save failed: $e');
    }
  }

  Future<User?> _loadLocal() async {
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

  Future<void> _saveLocal(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(user.toJson()));
  }

  User? _userFromResponse(dynamic data) {
    if (data is! Map) return null;
    return User.fromJson(Map<String, dynamic>.from(data));
  }
}
