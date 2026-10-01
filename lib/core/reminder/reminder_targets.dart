import '../../models/habit.dart';
import '../../models/task.dart';
import '../deep_link/notification_payload.dart';

/// Tasks and habits that may still own local notifications on this device.
class ReminderTargets {
  const ReminderTargets({this.taskIds = const {}, this.habitIds = const {}});

  /// Open tasks, keyed by local id and server id.
  ///
  /// Habits are keyed by local id, server id, and reminder id: older restore
  /// jobs used the server reminder id in `habit:` payloads.
  factory ReminderTargets.from({
    required Iterable<Task> openTasks,
    required Iterable<Habit> activeHabits,
  }) {
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
    );
  }

  final Set<String> taskIds;
  final Set<int> habitIds;

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

  static String? _suffix(String payload, String prefix) =>
      payload.startsWith(prefix) ? payload.substring(prefix.length) : null;
}
