import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_goal.dart';
import 'auth_service.dart';

class GoalService {
  final AuthService _authService;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  ));
  
  GoalService(this._authService);

  List<UserGoal> _goals = [];
  bool _initialized = false;
  static const _goalsKey = 'user_goals_cache';

  Future<void> _init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getStringList(_goalsKey);
    if (goalsJson != null) {
      _goals = goalsJson.map((json) {
        final map = jsonDecode(json);
        return UserGoal(
          id: map['id'],
          name: map['name'] as String,
          lastModified: map['lastModified'] != null ? DateTime.parse(map['lastModified']) : null,
        );
      }).toList();
    }
    _initialized = true;
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = _goals.map((g) => jsonEncode({
      'id': g.id,
      'name': g.name,
      'lastModified': g.lastModified.toIso8601String(),
    })).toList();
    await prefs.setStringList(_goalsKey, goalsJson);
  }

  Future<List<UserGoal>> getGoals() async {
    await _init();
    
    // Try to sync with backend in the background
    _syncGoalsFromBackend();
    
    return List.unmodifiable(_goals);
  }
  
  Future<void> _syncGoalsFromBackend() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final response = await _dio.get(
        '${AuthService.baseUrl}/api/goals',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        
        _goals = data.map((json) => UserGoal(
          id: json['id'],
          name: json['name'],
        )).toList();
        
        await _saveToStorage();
      }
    } catch (e) {
      debugPrint('Sync Goals From Backend Error: $e');
    }
  }

  Future<void> saveGoal(UserGoal goal) async {
    await _init();
    
    // Add locally immediately so UI updates
    _goals.add(goal);
    await _saveToStorage();
    
    // Try to push to backend in background
    _pushGoalToBackend(goal).catchError((e) => debugPrint('Push Goal Error: $e'));
  }

  Future<void> _pushGoalToBackend(UserGoal goal) async {
    try {
      final token = await _authService.getToken();
      if (token != null) {
        final response = await _dio.post(
          '${AuthService.baseUrl}/api/goals/0',
          data: {'id': 0, 'name': goal.name},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          // Update the local goal with backend ID
          final index = _goals.indexWhere((g) => g.name == goal.name);
          if (index != -1) {
            _goals[index] = UserGoal(id: data['id'], name: data['name'], localId: _goals[index].localId);
            await _saveToStorage();
          }
        }
      }
    } catch (e) {
      debugPrint('Push Goal Error: $e');
    }
  }

  Future<void> updateGoal(UserGoal oldGoal, UserGoal newGoal) async {
    await _init();
    final index = _goals.indexWhere((g) => g.name == oldGoal.name);
    if (index != -1) {
      _goals[index] = newGoal;
      await _saveToStorage();

      // Try to push to backend in background
      _updateGoalToBackend(oldGoal, newGoal).catchError((e) => debugPrint('Update Goal Error: $e'));
    }
  }

  Future<void> _updateGoalToBackend(UserGoal oldGoal, UserGoal newGoal) async {
    try {
      final token = await _authService.getToken();
      if (token != null && oldGoal.id != null) {
        await _dio.post(
          '${AuthService.baseUrl}/api/goals/${oldGoal.id}',
          data: {'id': oldGoal.id, 'name': newGoal.name},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (e) {
      debugPrint('Update Goal Error: $e');
    }
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _init();
    
    _goals.removeWhere((g) => g.name == goal.name);
    await _saveToStorage();

    // Try to delete from backend in background
    _deleteGoalFromBackend(goal).catchError((e) => debugPrint('Delete Goal Error: $e'));
  }

  Future<void> _deleteGoalFromBackend(UserGoal goal) async {
    try {
      final token = await _authService.getToken();
      if (token != null && goal.id != null) {
        await _dio.delete(
          '${AuthService.baseUrl}/api/goals/${goal.id}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (e) {
      debugPrint('Delete Goal Error: $e');
    }
  }
}

