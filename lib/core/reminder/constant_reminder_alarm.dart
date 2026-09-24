import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/habit_reminder.dart';
import '../deep_link/notification_payload.dart';

/// How soon a missed constant reminder rings after it is already due.
const kConstantReminderSoon = Duration(seconds: 5);

/// Delay after dismiss/tap before the alarm rings again if still not done.
const kConstantReminderRepeat = Duration(minutes: 5);

const kConstantAlarmsPrefsKey = 'constant_reminder_alarms_v1';
const kConstantAlarmChannelId = 'constant_alarm_channel';
const kConstantDarwinCategoryId = 'constant_reminder';
const kConstantAlarmTimezone = 'Europe/Kiev';

/// Stable id range above [ReminderService.allocateNotificationId].
int habitConstantNotificationId(int habitId, {int? stored}) {
  if (stored != null && stored > 0) return stored;
  return 900000000 + (habitId.abs() % 99999999);
}

String taskConstantPayload(String taskId) =>
    '${NotificationPayloads.taskConstant}$taskId';

String habitConstantPayload(int habitId) =>
    '${NotificationPayloads.habitConstant}$habitId';

const kReminderDarwinInitializationSettings = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
  notificationCategories: [
    DarwinNotificationCategory(
      kConstantDarwinCategoryId,
      options: {DarwinNotificationCategoryOption.customDismissAction},
    ),
  ],
);

/// First fire at [scheduled], or almost immediately when that time has passed.
DateTime constantAlarmFireTime({
  required DateTime scheduled,
  required DateTime now,
}) {
  if (scheduled.isAfter(now)) return scheduled;
  return now.add(kConstantReminderSoon);
}

/// Next weekday+time the habit constant alarm should ring.
///
/// Uses reminder clock time (not offsets). If today's slot has passed and the
/// habit is not satisfied, rings immediately; if it is satisfied, skips to the
/// next selected weekday.
DateTime? nextConstantHabitFire({
  required Iterable<HabitReminder> reminders,
  required DateTime now,
  required bool satisfiedToday,
}) {
  DateTime? soonest;
  for (final reminder in reminders) {
    if (!reminder.isEnabled || reminder.daysOfWeek.isEmpty) continue;
    for (final day in reminder.daysOfWeek) {
      var daysUntil = (day.type - now.weekday + 7) % 7;
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      candidate = candidate.add(Duration(days: daysUntil));
      if (!candidate.isAfter(now)) {
        candidate = satisfiedToday
            ? candidate.add(const Duration(days: 7))
            : now.add(kConstantReminderSoon);
      }
      if (soonest == null || candidate.isBefore(soonest)) {
        soonest = candidate;
      }
    }
  }
  return soonest;
}

class ConstantAlarmEntry {
  const ConstantAlarmEntry({
    required this.notificationId,
    required this.title,
    required this.payload,
    this.body,
  });

  final int notificationId;
  final String title;
  final String? body;
  final String payload;

  Map<String, Object?> toJson() => {
    'notificationId': notificationId,
    'title': title,
    'body': body,
    'payload': payload,
  };

  factory ConstantAlarmEntry.fromJson(Map<dynamic, dynamic> json) {
    return ConstantAlarmEntry(
      notificationId: json['notificationId'] as int? ?? 0,
      title: json['title'] as String? ?? 'Reminder',
      body: json['body'] as String?,
      payload: json['payload'] as String? ?? '',
    );
  }
}

NotificationDetails constantAlarmNotificationDetails() {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      kConstantAlarmChannelId,
      'Alarms',
      channelDescription:
          'Constant reminders that ring until you mark them done',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      channelBypassDnd: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      ongoing: false,
      additionalFlags: Int32List.fromList(const <int>[4]), // FLAG_INSISTENT
      dismissIsolate: NotificationDismissedIsolate.background,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: kConstantDarwinCategoryId,
      dismissIsolate: NotificationDismissedIsolate.background,
    ),
    macOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: kConstantDarwinCategoryId,
      dismissIsolate: NotificationDismissedIsolate.main,
    ),
  );
}

Future<Map<String, ConstantAlarmEntry>> loadConstantAlarms() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kConstantAlarmsPrefsKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, ConstantAlarmEntry>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final alarm = ConstantAlarmEntry.fromJson(value);
      if (alarm.payload.isEmpty || alarm.notificationId <= 0) continue;
      out['${entry.key}'] = alarm;
    }
    return out;
  } catch (e) {
    debugPrint('Parse constant alarms failed: $e');
    return {};
  }
}

Future<void> saveConstantAlarms(Map<String, ConstantAlarmEntry> alarms) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kConstantAlarmsPrefsKey,
    jsonEncode({
      for (final entry in alarms.entries) entry.key: entry.value.toJson(),
    }),
  );
}

Future<void> upsertConstantAlarm(ConstantAlarmEntry entry) async {
  if (entry.payload.isEmpty || entry.notificationId <= 0) return;
  final alarms = await loadConstantAlarms();
  alarms[entry.payload] = entry;
  await saveConstantAlarms(alarms);
}

Future<ConstantAlarmEntry?> removeConstantAlarm(String payload) async {
  if (payload.isEmpty) return null;
  final alarms = await loadConstantAlarms();
  final removed = alarms.remove(payload);
  await saveConstantAlarms(alarms);
  return removed;
}

void ensureConstantAlarmTimeZone() {
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation(kConstantAlarmTimezone));
  } catch (e) {
    debugPrint('Constant alarm timezone failed: $e');
  }
}

Future<void> scheduleConstantAlarm({
  required FlutterLocalNotificationsPlugin plugin,
  required ConstantAlarmEntry entry,
  required DateTime when,
}) async {
  if (entry.notificationId <= 0) return;
  ensureConstantAlarmTimeZone();
  await upsertConstantAlarm(entry);
  var scheduled = tz.TZDateTime.from(when, tz.local);
  final now = tz.TZDateTime.now(tz.local);
  if (!scheduled.isAfter(now)) {
    scheduled = now.add(kConstantReminderSoon);
  }
  await plugin.cancel(id: entry.notificationId);
  try {
    await plugin.zonedSchedule(
      id: entry.notificationId,
      title: entry.title,
      body: entry.body,
      scheduledDate: scheduled,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      notificationDetails: constantAlarmNotificationDetails(),
      payload: entry.payload,
    );
  } catch (e) {
    debugPrint('AlarmClock schedule failed, falling back: $e');
    await plugin.zonedSchedule(
      id: entry.notificationId,
      title: entry.title,
      body: entry.body,
      scheduledDate: scheduled,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: constantAlarmNotificationDetails(),
      payload: entry.payload,
    );
  }
}

Future<void> cancelConstantAlarm({
  required FlutterLocalNotificationsPlugin plugin,
  required String payload,
  int? notificationId,
}) async {
  final removed = await removeConstantAlarm(payload);
  final id = notificationId ?? removed?.notificationId;
  if (id != null && id > 0) {
    await plugin.cancel(id: id);
  }
}

Future<void> snoozeConstantAlarm(String? payload) async {
  if (!isConstantReminderPayload(payload)) return;
  final alarms = await loadConstantAlarms();
  final entry = alarms[payload];
  if (entry == null) return;
  await scheduleConstantAlarm(
    plugin: FlutterLocalNotificationsPlugin(),
    entry: entry,
    when: DateTime.now().add(kConstantReminderRepeat),
  );
}

/// Dismiss or tap of a constant reminder — ring again until marked done.
Future<void> snoozeConstantAlarmIfActive(NotificationResponse response) {
  return snoozeConstantAlarm(response.payload);
}

/// Background isolate entry point for dismiss / non-UI actions.
@pragma('vm:entry-point')
void onConstantReminderBackgroundResponse(NotificationResponse response) {
  unawaited(snoozeConstantAlarmIfActive(response));
}
