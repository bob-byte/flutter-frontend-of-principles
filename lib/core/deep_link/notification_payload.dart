import 'deep_link_action.dart';

/// Local-notification payload prefixes used by [ReminderService].
abstract final class NotificationPayloads {
  static const task = 'task:';
  static const taskConstant = 'task_constant:';
  static const habit = 'habit:';
  static const habitConstant = 'habit_constant:';
  static const habitsReport = 'habits_report';
}

DeepLinkAction? parseNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;

  if (payload == NotificationPayloads.habitsReport) {
    return const DeepLinkAction.openTasksTab();
  }

  if (payload.startsWith(NotificationPayloads.taskConstant)) {
    final id = payload.substring(NotificationPayloads.taskConstant.length);
    if (id.isEmpty) return null;
    return DeepLinkAction.openTask(id);
  }

  if (payload.startsWith(NotificationPayloads.task)) {
    final id = payload.substring(NotificationPayloads.task.length);
    if (id.isEmpty) return null;
    return DeepLinkAction.openTask(id);
  }

  if (payload.startsWith(NotificationPayloads.habitConstant)) {
    final raw = payload.substring(NotificationPayloads.habitConstant.length);
    final id = int.tryParse(raw);
    if (id == null) return null;
    return DeepLinkAction.openHabitDetail(id);
  }

  if (payload.startsWith(NotificationPayloads.habit)) {
    final raw = payload.substring(NotificationPayloads.habit.length);
    final id = int.tryParse(raw);
    if (id == null) return null;
    return DeepLinkAction.openHabitDetail(id);
  }

  return null;
}
