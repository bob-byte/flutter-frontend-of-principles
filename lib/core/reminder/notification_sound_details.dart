import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/app_notification_sound.dart';
import 'constant_reminder_alarm.dart';

enum ReminderNotificationChannel { task, habit, constantAlarm }

NotificationDetails reminderNotificationDetails({
  required ReminderNotificationChannel channel,
  required AppNotificationSound sound,
}) {
  return switch (channel) {
    ReminderNotificationChannel.task => NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders_channel${sound.androidChannelSuffix}',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: _androidSound(sound),
      ),
      iOS: DarwinNotificationDetails(sound: sound.darwinFileName),
      macOS: DarwinNotificationDetails(sound: sound.darwinFileName),
    ),
    ReminderNotificationChannel.habit => NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminders_channel${sound.androidChannelSuffix}',
        'Habit Reminders',
        channelDescription: 'Notifications for habit reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: _androidSound(sound),
      ),
      iOS: DarwinNotificationDetails(sound: sound.darwinFileName),
      macOS: DarwinNotificationDetails(sound: sound.darwinFileName),
    ),
    ReminderNotificationChannel.constantAlarm =>
      constantAlarmNotificationDetails(sound: sound),
  };
}

RawResourceAndroidNotificationSound? _androidSound(AppNotificationSound sound) {
  final name = sound.androidRawName;
  if (name == null) return null;
  return RawResourceAndroidNotificationSound(name);
}
