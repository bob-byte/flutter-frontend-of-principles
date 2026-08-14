import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/frequency_config.dart';
import '../models/habit_record.dart';
import 'auth_service.dart';
import 'database_service.dart';

class HabitService {
  final AuthService _authService;
  final DatabaseService _dbService = DatabaseService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  HabitService(this._authService);

  // Fetch from backend and populate local DB
  Future<void> syncFromBackend() async {
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
          final backendId = item['id'] ?? item['Id'];
          if (backendId == null) continue;

          // We check if this habit already exists in our local DB
          // Since our local DB uses its own auto-increment ID, we should ideally store backendId.
          // Let's add a backend_id column to Habit, or just use the local ID if we reset DB.
          // For now, let's keep it simple: we clear the local DB and insert everything from backend.
          // (In a real production app, we would do a smart merge, but this is a solid start)
          
          final habitName = item['name'] ?? item['Name'] ?? 'Невідома звичка';
          final description = item['description'] ?? item['Description'];
          final complexity = item['complexity'] ?? item['Complexity'] ?? 5;
          
          // Parse progresses
          final progresses = item['progresses'] ?? item['Progresses'] ?? [];

          // Create local Habit object
          final localHabit = Habit(
            // We temporarily map the backend ID to our local ID so they match
            id: backendId,
            name: habitName,
            notes: description ?? '',
            difficulty: complexity,
            isFlexible: true, // Default
            frequency: const FrequencyConfig(type: FrequencyType.daily), // Default
          );

          // Note: To prevent duplicating, we can just insert with conflict resolution, 
          // or we can just fetch and update.
          // We will rely on _dbService for the actual insert/update.
          await _dbService.insertOrUpdateHabitWithBackendId(localHabit);

          // Now parse records
          for (var prog in progresses) {
            final pDateStr = prog['date'] ?? prog['Date'];
            final pVal = prog['value'] ?? prog['Value'];
            if (pDateStr != null && pVal != null) {
              final parsedDate = DateTime.tryParse(pDateStr);
              if (parsedDate != null) {
                final status = (pVal == 1) ? HabitStatus.completed : HabitStatus.skipped;
                await _dbService.setHabitRecordStatus(backendId, parsedDate, status, skipSync: true);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sync From Backend Error: $e');
    }
  }

  // Push local changes to backend
  Future<bool> pushHabit(Habit habit) async {
    // Map our Flutter FrequencyConfig to .NET Backend Frequency model
    int backendType = 0; // EveryDay (C# Enums usually start at 0)
    int repeats = 1;
    int intervalLengthInDays = 1;

    if (habit.frequency.type == FrequencyType.everyXDays) {
      backendType = 1; // EverySeveralDays
      intervalLengthInDays = habit.frequency.interval ?? 1;
    } else if (habit.frequency.type == FrequencyType.timesPerPeriod) {
      backendType = 2; // SeveralTimesPerPeriod
      repeats = habit.frequency.interval ?? 1;
      intervalLengthInDays = habit.frequency.period == PeriodType.month ? 30 : 7;
    }

    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      // Map to EditUserHabitDto
      final payload = {
        'id': habit.id ?? 0,
        'name': habit.name,
        'type': 0, // Default TypeOfHabit
        'areasOfLife': [],
        'description': habit.notes,
        'complexity': habit.difficulty,
        'question': '',
        'goalId': habit.targetGoalId,
        'isArchived': habit.isArchived,
        'status': 1, // InProgress
        'frequency': {
          'id': 0,
          'type': backendType,
          'repeats': repeats,
          'intervalLengthInDays': intervalLengthInDays
        },
        'priority': 0,
        'colorName': 'blue',
        'reminders': [],
        'progresses': []
      };

      // Create or Update
      final response = await _dio.post(
        '${AuthService.baseUrl}/api/habits/${habit.id ?? 0}',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Push Habit Error: $e');
      return false;
    }
  }

  Future<bool> pushProgress(int habitId, DateTime date, HabitStatus status) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final val = status == HabitStatus.completed ? 1 : (status == HabitStatus.skipped ? 0 : -1);
      if (val == -1) return true; // We don't send "none" as a progress update (or we delete it, but backend uses POST {progressId})

      final dateStr = date.toIso8601String().substring(0, 10);

      // We send 0 as progressId to create a new progress record. Backend handles addOrUpdate.
      final payload = {
        'id': 0,
        'date': dateStr,
        'value': val,
        'habitId': habitId
      };

      final response = await _dio.post(
        '${AuthService.baseUrl}/api/progressesofhabit/0',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Push Progress Error: $e');
      return false;
    }
  }
}
