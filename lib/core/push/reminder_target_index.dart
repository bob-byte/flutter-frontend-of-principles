import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/habit.dart';
import '../../models/task.dart';
import '../deep_link/notification_payload.dart';

/// Server id → notification payload ids, saved after each sync merge.
///
/// A silent push can arrive while the app is not running; the FCM background
/// isolate must not open SQLite (a second connection locks the merge), so it
/// resolves remote-deleted server ids through this SharedPreferences copy.
class ReminderTargetIndex {
  const ReminderTargetIndex({this.tasks = const {}, this.habits = const {}});

  static const prefsKey = 'reminder_target_index_v1';

  /// Task server id → local task ids used in `task:` payloads.
  final Map<int, Set<String>> tasks;

  /// Habit server id → ids used in `habit:` payloads (local id plus legacy
  /// reminder ids that no other habit uses as its local id).
  final Map<int, Set<int>> habits;

  factory ReminderTargetIndex.build({
    required Iterable<Task> openTasks,
    required Iterable<Habit> activeHabits,
  }) {
    final tasks = <int, Set<String>>{};
    for (final task in openTasks) {
      final serverId = task.serverId ?? int.tryParse(task.id);
      if (serverId == null || serverId <= 0) continue;
      (tasks[serverId] ??= {}).addAll({task.id, '$serverId'});
    }
    final localHabitIds = {for (final habit in activeHabits) ?habit.id};
    final habits = <int, Set<int>>{};
    for (final habit in activeHabits) {
      final localId = habit.id;
      final serverId = habit.serverId;
      if (localId == null || serverId == null || serverId <= 0) continue;
      habits[serverId] = {
        localId,
        ...habit.reminders
            .map((reminder) => reminder.id)
            .whereType<int>()
            .where((id) => !localHabitIds.contains(id)),
      };
    }
    return ReminderTargetIndex(tasks: tasks, habits: habits);
  }

  static Future<void> save({
    required Iterable<Task> openTasks,
    required Iterable<Habit> activeHabits,
  }) async {
    try {
      final index = ReminderTargetIndex.build(
        openTasks: openTasks,
        activeHabits: activeHabits,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(index.toJson()));
    } catch (e) {
      debugPrint('Save reminder target index failed: $e');
    }
  }

  static Future<ReminderTargetIndex> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return const ReminderTargetIndex();
      return ReminderTargetIndex.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('Load reminder target index failed: $e');
      return const ReminderTargetIndex();
    }
  }

  /// Payloads (`task:`, `task_constant:`, `habit:`, `habit_constant:`) that
  /// belong to the given remote-deleted server ids.
  Set<String> payloadsForDeleted({
    Iterable<int> taskIds = const [],
    Iterable<int> habitIds = const [],
  }) {
    final localHabitIds = {for (final ids in habits.values) ...ids};
    return {
      for (final serverId in taskIds)
        for (final id in tasks[serverId] ?? {'$serverId'}) ...[
          '${NotificationPayloads.task}$id',
          '${NotificationPayloads.taskConstant}$id',
        ],
      for (final serverId in habitIds)
        for (final id
            in habits[serverId] ??
                // Unknown here: only trust the server id when no other
                // habit on this device uses it as its local id.
                (localHabitIds.contains(serverId)
                    ? const <int>{}
                    : {serverId})) ...[
          '${NotificationPayloads.habit}$id',
          '${NotificationPayloads.habitConstant}$id',
        ],
    };
  }

  Map<String, Object?> toJson() => {
    'tasks': {
      for (final entry in tasks.entries) '${entry.key}': entry.value.toList(),
    },
    'habits': {
      for (final entry in habits.entries) '${entry.key}': entry.value.toList(),
    },
  };

  factory ReminderTargetIndex.fromJson(Object? json) {
    if (json is! Map) return const ReminderTargetIndex();
    Map<int, Set<T>> read<T>(Object? raw, T? Function(Object?) parse) {
      if (raw is! Map) return {};
      return {
        for (final entry in raw.entries)
          ?int.tryParse('${entry.key}'): {
            if (entry.value is List)
              for (final value in entry.value as List) ?parse(value),
          },
      };
    }

    return ReminderTargetIndex(
      tasks: read<String>(json['tasks'], (v) => v == null ? null : '$v'),
      habits: read<int>(json['habits'], (v) => v is int ? v : null),
    );
  }
}
