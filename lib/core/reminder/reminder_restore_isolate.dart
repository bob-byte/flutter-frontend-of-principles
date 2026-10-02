import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/app_notification_sound.dart';
import '../../models/habit_reminder.dart';
import '../../models/reminder.dart';
import '../../models/schedule_reminder_offset.dart';
import '../../models/task.dart';
import '../deep_link/notification_payload.dart';
import 'constant_reminder_alarm.dart';
import 'notification_sound_details.dart';

/// Timezone used by [ReminderService.init] when scheduling.
const kReminderRestoreTimezone = 'Europe/Kiev';

const _kConstantTaskIdsKey = 'constant_task_reminder_ids_v1';
const _kConstantHabitIdsKey = 'constant_habit_reminder_ids_v1';

/// OS notification id for one weekday × offset slot of a habit reminder.
int habitSlotNotificationId(WeekDay day, ScheduleReminderOffset offset) {
  final offsetId = offset.notificationRequestId;
  final id = offsetId == null
      ? day.userNotificationRequestId
      : offsetId + day.type;
  return id.abs() % 2000000000;
}

/// Every OS id a habit reminder may occupy on this device.
Set<int> habitReminderNotificationIds(HabitReminder reminder) {
  final offsets = reminder.offsets.isEmpty
      ? const [ScheduleReminderOffset(offsetMinutes: 0)]
      : reminder.offsets;
  return {
    for (final day in reminder.daysOfWeek) ...[
      day.userNotificationRequestId,
      for (final offset in offsets) habitSlotNotificationId(day, offset),
    ],
  };
}

/// Builds a sendable job for [runReminderRestoreIsolate].
///
/// Pure Dart — safe to call from the UI isolate before spawning.
///
/// Server habit reminders carry their own row id, not the habit id.
/// [habitIdByReminderId] maps them back so payloads and constant alarms use
/// the same habit id as in-app scheduling (and cancel on delete).
Map<String, Object?> buildReminderRestoreJob({
  required List<Reminder> generalReminders,
  required List<HabitReminder> habitReminders,
  required List<Task> tasks,
  DateTime? now,
  Set<int> satisfiedHabitIds = const {},
  Map<int, int> habitIdByReminderId = const {},
  String timezoneLocation = kReminderRestoreTimezone,
}) {
  final clock = now ?? DateTime.now();
  final ops = <Map<String, Object?>>[];

  for (final reminder in generalReminders) {
    final id = reminder.userNotificationRequestId == 0
        ? kHabitsReportNotificationRequestId
        : reminder.userNotificationRequestId;
    ops.add({'type': 'cancel', 'id': id});
    ops.add({
      'type': 'daily',
      'id': id,
      'title': reminder.title.trim().isEmpty
          ? 'Reminder'
          : reminder.title.trim(),
      'body': reminder.description.isNotEmpty ? reminder.description : null,
      'hour': reminder.time.hour,
      'minute': reminder.time.minute,
      'payload': NotificationPayloads.habitsReport,
    });
  }

  for (final habitReminder in habitReminders) {
    final reminderId = habitReminder.id;
    final habitId = reminderId == null
        ? null
        : habitIdByReminderId[reminderId] ?? reminderId;
    final payload = habitId == null
        ? null
        : '${NotificationPayloads.habit}$habitId';
    final title = habitReminder.title.isEmpty
        ? 'Reminder'
        : habitReminder.title;
    final body = habitReminder.description.isNotEmpty
        ? habitReminder.description
        : null;
    final offsets = habitReminder.offsets.isEmpty
        ? const [ScheduleReminderOffset(offsetMinutes: 0)]
        : habitReminder.offsets;

    var anyEnabled = false;
    var wantsConstant = habitReminder.constantReminder;

    if (!habitReminder.isEnabled) {
      for (final id in habitReminderNotificationIds(habitReminder)) {
        ops.add({'type': 'cancel', 'id': id});
      }
    } else {
      anyEnabled = true;
      wantsConstant = wantsConstant || habitReminder.constantReminder;
      for (final day in habitReminder.daysOfWeek) {
        for (final offset in offsets) {
          if (wantsConstant && offset.offsetMinutes == 0) continue;
          final adjustedMinutes =
              habitReminder.time.hour * 60 +
              habitReminder.time.minute -
              offset.offsetMinutes;
          final wrapped = adjustedMinutes.remainder(24 * 60);
          final hour = wrapped ~/ 60;
          final minute = wrapped % 60;
          ops.add({
            'type': 'weekly',
            'id': habitSlotNotificationId(day, offset),
            'title': title,
            'body': body,
            'hour': hour,
            'minute': minute,
            'weekday': day.type,
            'payload': payload,
            'nowMs': clock.millisecondsSinceEpoch,
          });
        }
      }
    }

    if (habitId != null) {
      final constantId = habitConstantNotificationId(
        habitId,
        stored: habitReminder.constantNotificationRequestId,
      );
      final active = anyEnabled && wantsConstant;
      if (!active) {
        ops.add({
          'type': 'constantAlarm',
          'id': constantId,
          'payload': habitConstantPayload(habitId),
          'active': false,
        });
      } else {
        final fire = nextConstantHabitFire(
          reminders: [habitReminder],
          now: clock,
          satisfiedToday: satisfiedHabitIds.contains(habitId),
        );
        if (fire != null) {
          ops.add({
            'type': 'constantAlarm',
            'id': constantId,
            'title': title,
            'body': body,
            'whenMs': fire.millisecondsSinceEpoch,
            'payload': habitConstantPayload(habitId),
            'active': true,
          });
        }
      }
      ops.add({
        'type': 'constantHabit',
        'habitId': '$habitId',
        'active': active,
      });
    }
  }

  for (final task in tasks) {
    for (final offset in task.reminders) {
      final id = offset.notificationRequestId;
      if (id != null) ops.add({'type': 'cancel', 'id': id});
    }
    final constantId = task.constantNotificationRequestId;
    if (constantId != null) ops.add({'type': 'cancel', 'id': constantId});

    if (task.isDone || task.dueDate == null || task.reminders.isEmpty) {
      ops.add({'type': 'constantTask', 'taskId': task.id, 'active': false});
      if (constantId != null) {
        ops.add({
          'type': 'constantAlarm',
          'id': constantId,
          'payload': taskConstantPayload(task.id),
          'active': false,
        });
      }
      continue;
    }

    final start = task.dueDate!;
    final title = task.title;
    final body = task.description.isEmpty ? null : task.description;

    for (final offset in task.reminders) {
      final id = offset.notificationRequestId;
      if (id == null) continue;
      if (task.constantReminder && offset.offsetMinutes == 0) continue;
      var fire = start.subtract(Duration(minutes: offset.offsetMinutes));
      if (!fire.isAfter(clock)) continue;
      ops.add({
        'type': 'oneShot',
        'id': id,
        'title': title,
        'body': body,
        'whenMs': fire.millisecondsSinceEpoch,
        'payload': '${NotificationPayloads.task}${task.id}',
      });
    }

    if (task.constantReminder) {
      final id =
          task.constantNotificationRequestId ??
          (100000 + (task.id.hashCode.abs() % 800000000));
      final fire = constantAlarmFireTime(scheduled: start, now: clock);
      ops.add({
        'type': 'constantAlarm',
        'id': id,
        'title': title,
        'body': body,
        'whenMs': fire.millisecondsSinceEpoch,
        'payload': taskConstantPayload(task.id),
        'active': true,
      });
      ops.add({'type': 'constantTask', 'taskId': task.id, 'active': true});
    } else {
      ops.add({'type': 'constantTask', 'taskId': task.id, 'active': false});
      if (constantId != null) {
        ops.add({
          'type': 'constantAlarm',
          'id': constantId,
          'payload': taskConstantPayload(task.id),
          'active': false,
        });
      }
    }
  }

  return {'timezone': timezoneLocation, 'ops': ops};
}

/// Applies a [buildReminderRestoreJob] on the UI isolate.
///
/// Prefer [initializePlugin] = false with the app's already-initialized
/// [FlutterLocalNotificationsPlugin] — a second `initialize` /
/// `setMethodCallHandler` after Allow can hang iOS.
Future<void> runReminderRestoreIsolate(Map<String, Object?> job) {
  return executeReminderRestoreJob(job);
}

/// Plugin work for restored reminders (must run on the UI isolate).
Future<void> executeReminderRestoreJob(
  Map<String, Object?> job, {
  FlutterLocalNotificationsPlugin? plugin,
  bool initializePlugin = true,
}) async {
  final timezone = job['timezone'] as String? ?? kReminderRestoreTimezone;
  final ops = (job['ops'] as List?)?.cast<Map>() ?? const <Map>[];

  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(timezone));

  final notifications = plugin ?? FlutterLocalNotificationsPlugin();
  if (initializePlugin) {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = kReminderDarwinInitializationSettings;
    await notifications.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
  }

  final sound = await AppNotificationSound.load();
  final habitDetails = reminderNotificationDetails(
    channel: ReminderNotificationChannel.habit,
    sound: sound,
  );
  final taskDetails = reminderNotificationDetails(
    channel: ReminderNotificationChannel.task,
    sound: sound,
  );

  for (final raw in ops) {
    // Let frames paint between native schedule calls (post-Allow freeze).
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final op = Map<String, Object?>.from(raw);
    switch (op['type'] as String?) {
      case 'cancel':
        final id = op['id'] as int?;
        if (id != null && id > 0) {
          await notifications.cancel(id: id);
        }
      case 'daily':
        await _scheduleDaily(notifications, habitDetails, op);
      case 'weekly':
        await _scheduleWeekly(notifications, habitDetails, op);
      case 'oneShot':
        await _scheduleOneShot(notifications, taskDetails, op);
      case 'constantAlarm':
        final payload = op['payload'] as String? ?? '';
        final id = op['id'] as int?;
        if (op['active'] == false) {
          await cancelConstantAlarm(
            plugin: notifications,
            payload: payload,
            notificationId: id,
          );
        } else if (id != null && id > 0) {
          final whenMs = op['whenMs'] as int?;
          if (whenMs != null) {
            await scheduleConstantAlarm(
              plugin: notifications,
              entry: ConstantAlarmEntry(
                notificationId: id,
                title: op['title'] as String? ?? 'Reminder',
                body: op['body'] as String?,
                payload: payload,
              ),
              when: DateTime.fromMillisecondsSinceEpoch(whenMs),
              sound: sound,
            );
          }
        }
      case 'constantHabit':
        await _mutateIdSet(
          _kConstantHabitIdsKey,
          op['habitId'] as String? ?? '',
          op['active'] == true,
        );
      case 'constantTask':
        await _mutateIdSet(
          _kConstantTaskIdsKey,
          op['taskId'] as String? ?? '',
          op['active'] == true,
        );
    }
  }
}

Future<void> _mutateIdSet(String key, String id, bool active) async {
  if (id.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final ids = (prefs.getStringList(key) ?? const <String>[]).toSet();
  if (active) {
    ids.add(id);
  } else {
    ids.remove(id);
  }
  await prefs.setStringList(key, ids.toList());
}

Future<void> _scheduleDaily(
  FlutterLocalNotificationsPlugin plugin,
  NotificationDetails details,
  Map<String, Object?> op,
) async {
  final id = op['id'] as int?;
  if (id == null || id <= 0) return;
  final hour = op['hour'] as int? ?? 0;
  final minute = op['minute'] as int? ?? 0;
  final now = DateTime.now();
  var notify = DateTime(now.year, now.month, now.day, hour, minute);
  if (!notify.isAfter(now)) {
    notify = notify.add(const Duration(days: 1));
  }
  await plugin.cancel(id: id);
  await plugin.zonedSchedule(
    id: id,
    title: op['title'] as String? ?? 'Reminder',
    body: op['body'] as String?,
    scheduledDate: tz.TZDateTime.from(notify, tz.local),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: details,
    matchDateTimeComponents: DateTimeComponents.time,
    payload: op['payload'] as String?,
  );
}

Future<void> _scheduleWeekly(
  FlutterLocalNotificationsPlugin plugin,
  NotificationDetails details,
  Map<String, Object?> op,
) async {
  final id = op['id'] as int?;
  if (id == null || id <= 0) return;
  final hour = op['hour'] as int? ?? 0;
  final minute = op['minute'] as int? ?? 0;
  final weekday = op['weekday'] as int? ?? DateTime.monday;
  final nowMs = op['nowMs'] as int?;
  final now = nowMs == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(nowMs);

  var daysUntil = (weekday - now.weekday + 7) % 7;
  if (daysUntil == 0) {
    final nowTimeMinutes = now.hour * 60 + now.minute;
    final reminderMinutes = hour * 60 + minute;
    if (reminderMinutes <= nowTimeMinutes) {
      daysUntil = 7;
    }
  }
  final scheduleDate = now.add(Duration(days: daysUntil));
  final tzDate = tz.TZDateTime(
    tz.local,
    scheduleDate.year,
    scheduleDate.month,
    scheduleDate.day,
    hour,
    minute,
  );

  await plugin.zonedSchedule(
    id: id,
    title: op['title'] as String? ?? 'Reminder',
    body: op['body'] as String?,
    scheduledDate: tzDate,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: details,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    payload: op['payload'] as String?,
  );
}

Future<void> _scheduleOneShot(
  FlutterLocalNotificationsPlugin plugin,
  NotificationDetails details,
  Map<String, Object?> op,
) async {
  final id = op['id'] as int?;
  final whenMs = op['whenMs'] as int?;
  if (id == null || id <= 0 || whenMs == null) return;
  final when = DateTime.fromMillisecondsSinceEpoch(whenMs);
  await plugin.zonedSchedule(
    id: id,
    title: op['title'] as String? ?? 'Reminder',
    body: op['body'] as String?,
    scheduledDate: tz.TZDateTime.from(when, tz.local),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: details,
    payload: op['payload'] as String?,
  );
}
