import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../reminder/constant_reminder_alarm.dart';
import 'reminder_target_index.dart';

/// Cancels pending/delivered reminders and constant alarms for tasks/habits
/// another device deleted, identified by server id.
///
/// Reads only SharedPreferences + the notification plugin, so it is safe in
/// the FCM background isolate while the app is not running.
Future<void> cancelRemoteDeletedReminders({
  required FlutterLocalNotificationsPlugin plugin,
  Iterable<int> taskIds = const [],
  Iterable<int> habitIds = const [],
}) async {
  if (taskIds.isEmpty && habitIds.isEmpty) return;
  try {
    final index = await ReminderTargetIndex.load();
    final payloads = index.payloadsForDeleted(
      taskIds: taskIds,
      habitIds: habitIds,
    );
    if (payloads.isEmpty) return;

    for (final alarm in (await loadConstantAlarms()).values) {
      if (!payloads.contains(alarm.payload)) continue;
      await cancelConstantAlarm(
        plugin: plugin,
        payload: alarm.payload,
        notificationId: alarm.notificationId,
      );
    }
    for (final request in await plugin.pendingNotificationRequests()) {
      if (payloads.contains(request.payload)) {
        await plugin.cancel(id: request.id);
      }
    }
    try {
      for (final notification in await plugin.getActiveNotifications()) {
        final id = notification.id;
        if (id != null && payloads.contains(notification.payload)) {
          await plugin.cancel(id: id);
        }
      }
    } catch (_) {
      // Some desktops do not expose delivered notifications.
    }
  } catch (e) {
    debugPrint('Cancel remote-deleted reminders failed: $e');
  }
}
