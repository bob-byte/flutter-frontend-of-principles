import '../../models/habit.dart';
import '../../models/task.dart';
import '../deep_link/notification_payload.dart';

/// Notification ids stored on [task] that a pending alarm may still use.
Set<int> scheduledTaskNotificationIds(Task task) {
  final ids = <int>{
    for (final offset in task.reminders)
      if (offset.notificationRequestId case final int id when id > 0) id,
  };
  final constantId = task.constantNotificationRequestId;
  if (task.constantReminder && constantId != null && constantId > 0) {
    ids.add(constantId);
  }
  return ids;
}

/// Tasks and habits that may still own local notifications on this device.
class ReminderTargets {
  const ReminderTargets({
    this.taskIds = const {},
    this.habitIds = const {},
    this.taskNotificationIds = const {},
  });

  /// Open tasks, keyed by local id and server id.
  ///
  /// Habits are keyed by local id, server id, and reminder id: older restore
  /// jobs used the server reminder id in `habit:` payloads.
  factory ReminderTargets.from({
    required Iterable<Task> openTasks,
    required Iterable<Habit> activeHabits,
  }) {
    final notificationIds = <String, Set<int>>{};
    for (final task in openTasks) {
      final ids = scheduledTaskNotificationIds(task);
      notificationIds[task.id] = ids;
      final serverId = task.serverId;
      if (serverId != null) notificationIds['$serverId'] = ids;
    }
    return ReminderTargets(
      taskIds: {
        for (final task in openTasks) ...[
          task.id,
          if (task.serverId != null) '${task.serverId}',
        ],
      },
      habitIds: {
        for (final habit in activeHabits) ...[
          ?habit.id,
          ?habit.serverId,
          for (final reminder in habit.reminders) ?reminder.id,
        ],
      },
      taskNotificationIds: notificationIds,
    );
  }

  final Set<String> taskIds;
  final Set<int> habitIds;

  /// Stored notification ids for an open task, keyed by local id and server id.
  ///
  /// An empty set means the task has no stored ids yet, so pending alarms are
  /// left in place.
  final Map<String, Set<int>> taskNotificationIds;

  /// Whether [payload] points at a task/habit that is gone, done, or archived.
  ///
  /// Daily-report and unknown payloads are never orphans.
  bool isOrphanPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    final taskId =
        _suffix(payload, NotificationPayloads.taskConstant) ??
        _suffix(payload, NotificationPayloads.task);
    if (taskId != null) {
      return taskId.isNotEmpty && !taskIds.contains(taskId);
    }
    final habitRaw =
        _suffix(payload, NotificationPayloads.habitConstant) ??
        _suffix(payload, NotificationPayloads.habit);
    if (habitRaw != null) {
      final habitId = int.tryParse(habitRaw);
      return habitId != null && !habitIds.contains(habitId);
    }
    return false;
  }

  /// Whether [notificationId] should be cancelled.
  ///
  /// Gone tasks and habits are always cancelled. An open task that already has
  /// stored ids also drops alarms scheduled under an older id — that happens
  /// when a due date moves to another day and the previous alarm is left
  /// behind.
  bool shouldCancelNotification(String? payload, int notificationId) {
    if (isOrphanPayload(payload)) return true;
    final taskId = _taskPayloadId(payload);
    if (taskId == null) return false;
    final allowed = taskNotificationIds[taskId];
    if (allowed == null || allowed.isEmpty) return false;
    return !allowed.contains(notificationId);
  }

  static String? _taskPayloadId(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return _suffix(payload, NotificationPayloads.taskConstant) ??
        _suffix(payload, NotificationPayloads.task);
  }

  static String? _suffix(String payload, String prefix) =>
      payload.startsWith(prefix) ? payload.substring(prefix.length) : null;
}
