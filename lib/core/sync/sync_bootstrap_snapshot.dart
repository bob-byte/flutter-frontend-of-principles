import '../../models/reminder.dart';
import '../../models/task_item_dto.dart';
import '../../models/user.dart';
import '../../models/user_goal.dart';
import '../../services/habit_service.dart';

class SyncBootstrapArchivedHabit {
  const SyncBootstrapArchivedHabit({
    required this.id,
    required this.name,
    this.lastModified,
  });

  final int id;
  final String name;
  final DateTime? lastModified;
}

class SyncBootstrapSnapshot {
  const SyncBootstrapSnapshot({
    this.user,
    this.goals = const [],
    this.activeHabits = const [],
    this.archivedHabits = const [],
    this.habitsReportReminder,
    this.tasks = const [],
  });

  final User? user;
  final List<UserGoal> goals;
  final List<Map<String, dynamic>> activeHabits;
  final List<SyncBootstrapArchivedHabit> archivedHabits;
  final Reminder? habitsReportReminder;
  final List<TaskItemDto> tasks;

  factory SyncBootstrapSnapshot.fromJson(dynamic data) {
    if (data is! Map) return const SyncBootstrapSnapshot();
    final map = Map<dynamic, dynamic>.from(data);

    return SyncBootstrapSnapshot(
      user: _map(map['user'] ?? map['User']) == null
          ? null
          : User.fromJson(_map(map['user'] ?? map['User'])!),
      goals: _list(map['goals'] ?? map['Goals'])
          .map((item) {
            final json = _map(item);
            if (json == null) return null;
            return UserGoal.fromJson(json);
          })
          .whereType<UserGoal>()
          .toList(),
      activeHabits: _list(
        map['activeHabits'] ?? map['ActiveHabits'],
      ).map(_map).whereType<Map<String, dynamic>>().toList(),
      archivedHabits: _list(map['archivedHabits'] ?? map['ArchivedHabits'])
          .map((item) {
            final json = _map(item);
            if (json == null) return null;
            final id = readJsonInt(json['id'] ?? json['Id']);
            if (id == null) return null;
            return SyncBootstrapArchivedHabit(
              id: id,
              name: '${json['name'] ?? json['Name'] ?? 'Habit'}',
              lastModified: _date(json['lastModified'] ?? json['LastModified']),
            );
          })
          .whereType<SyncBootstrapArchivedHabit>()
          .toList(),
      habitsReportReminder:
          _map(map['habitsReportReminder'] ?? map['HabitsReportReminder']) ==
              null
          ? null
          : Reminder.fromJson(
              _map(map['habitsReportReminder'] ?? map['HabitsReportReminder']),
            ),
      tasks: _list(map['tasks'] ?? map['Tasks'])
          .map((item) {
            try {
              final json = _map(item);
              if (json == null) return null;
              return TaskItemDto.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<TaskItemDto>()
          .toList(),
    );
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final parsed = DateTime.tryParse(value.toString())?.toUtc();
    if (parsed == null || parsed.year < 2000) return null;
    return parsed;
  }
}
