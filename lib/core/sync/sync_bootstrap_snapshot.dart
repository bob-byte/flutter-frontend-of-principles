import '../../models/reminder.dart';
import '../../models/task_item_dto.dart';
import '../../models/ai_conversation.dart';
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
    this.reminders = const AllRemindersResponse(),
    this.remindersProvided = false,
    this.tasks = const [],
    this.tasksProvided = false,
    this.tasksTrustedForPrune = false,
    this.conversations = const [],
    this.conversationsProvided = false,
    this.conversationsTrustedForPrune = false,
    this.isDelta = false,
    this.requiresFullBootstrap = false,
    this.serverTime,
    this.deletedGoalIds = const [],
    this.deletedHabitIds = const [],
    this.deletedTaskIds = const [],
    this.deletedConversationIds = const [],
  });

  final User? user;
  final List<UserGoal> goals;
  final List<Map<String, dynamic>> activeHabits;
  final List<SyncBootstrapArchivedHabit> archivedHabits;
  final Reminder? habitsReportReminder;

  /// Same lists as GET `/reminder/all` when the server includes them on bootstrap.
  final AllRemindersResponse reminders;

  /// True when the payload included `generalReminders` and/or `userHabitReminders`.
  final bool remindersProvided;
  final List<TaskItemDto> tasks;

  /// True when the payload included a `tasks`/`Tasks` key (even if empty).
  /// Missing key means an older server — do not prune local tasks.
  final bool tasksProvided;

  /// False when every task object failed to parse — do not wipe local rows.
  final bool tasksTrustedForPrune;
  final List<AiConversation> conversations;

  /// True when the payload included a `conversations` key (even if empty).
  final bool conversationsProvided;

  /// False when every conversation object failed to parse — do not wipe local rows.
  final bool conversationsTrustedForPrune;

  /// True for GET `/sync/changes` — upsert only; never prune by absence.
  final bool isDelta;

  /// Server asked the client to call full bootstrap instead.
  final bool requiresFullBootstrap;

  /// Cursor for the next `/sync/changes?since=` call.
  final DateTime? serverTime;

  final List<int> deletedGoalIds;
  final List<int> deletedHabitIds;
  final List<int> deletedTaskIds;
  final List<int> deletedConversationIds;

  factory SyncBootstrapSnapshot.fromJson(dynamic data) {
    return _parse(data, isDelta: false);
  }

  /// Payload of GET `/sync/changes`.
  factory SyncBootstrapSnapshot.fromChangesJson(dynamic data) {
    return _parse(data, isDelta: true);
  }

  static SyncBootstrapSnapshot _parse(dynamic data, {required bool isDelta}) {
    if (data is! Map) {
      return SyncBootstrapSnapshot(
        isDelta: isDelta,
        requiresFullBootstrap: isDelta,
      );
    }
    final map = Map<dynamic, dynamic>.from(data);
    final requiresFull =
        isDelta &&
        (map['requiresFullBootstrap'] == true ||
            map['RequiresFullBootstrap'] == true);
    if (requiresFull) {
      return SyncBootstrapSnapshot(
        isDelta: true,
        requiresFullBootstrap: true,
        serverTime: _date(map['serverTime'] ?? map['ServerTime']),
      );
    }

    final rawTasks = _list(map['tasks'] ?? map['Tasks']);
    final parsedTasks = rawTasks
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
        .toList();
    final hasTasksKey = map.containsKey('tasks') || map.containsKey('Tasks');
    final rawConversations = _list(
      map['conversations'] ?? map['Conversations'],
    );
    final parsedConversations = rawConversations
        .map((item) {
          try {
            final json = _map(item);
            if (json == null) return null;
            return AiConversation.fromDtoJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<AiConversation>()
        .toList();
    final hasConversationsKey =
        map.containsKey('conversations') || map.containsKey('Conversations');
    final hasRemindersKey =
        map.containsKey('generalReminders') ||
        map.containsKey('GeneralReminders') ||
        map.containsKey('userHabitReminders') ||
        map.containsKey('UserHabitReminders');

    // Delta lists are partial — never trust them for absence-pruning.
    final trustPrune = !isDelta;

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
      reminders: hasRemindersKey
          ? AllRemindersResponse.fromJson(map)
          : const AllRemindersResponse(),
      remindersProvided: hasRemindersKey,
      tasks: parsedTasks,
      tasksProvided: hasTasksKey,
      tasksTrustedForPrune:
          trustPrune && hasTasksKey && (rawTasks.isEmpty || parsedTasks.isNotEmpty),
      conversations: parsedConversations,
      conversationsProvided: hasConversationsKey,
      conversationsTrustedForPrune:
          trustPrune &&
          hasConversationsKey &&
          (rawConversations.isEmpty || parsedConversations.isNotEmpty),
      isDelta: isDelta,
      requiresFullBootstrap: false,
      serverTime: _date(map['serverTime'] ?? map['ServerTime']),
      deletedGoalIds: isDelta
          ? _idList(map['deletedGoalIds'] ?? map['DeletedGoalIds'])
          : const [],
      deletedHabitIds: isDelta
          ? _idList(map['deletedHabitIds'] ?? map['DeletedHabitIds'])
          : const [],
      deletedTaskIds: isDelta
          ? _idList(map['deletedTaskIds'] ?? map['DeletedTaskIds'])
          : const [],
      deletedConversationIds: isDelta
          ? _idList(
              map['deletedConversationIds'] ?? map['DeletedConversationIds'],
            )
          : const [],
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

  static List<int> _idList(dynamic value) {
    final out = <int>[];
    for (final item in _list(value)) {
      final id = readJsonInt(item);
      if (id != null && id != 0) out.add(id);
    }
    return out;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final parsed = DateTime.tryParse(value.toString())?.toUtc();
    if (parsed == null || parsed.year < 2000) return null;
    return parsed;
  }
}
