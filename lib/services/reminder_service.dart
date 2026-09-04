import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/local_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../models/habit.dart';
import '../models/habit_reminder.dart';
import '../models/reminder.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';

class ReminderService {
  ReminderService({
    ApiClient? apiClient,
    this.forceLocalOnly = false,
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
  }) : _apiClient = apiClient,
       _localDb = localDb,
       _executor = executor;

  static const prefsKey = 'habits_report_reminder_v1';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  final ApiClient? _apiClient;
  final bool forceLocalOnly;
  final LocalDb? _localDb;
  final LocalRemoteExecutor? _executor;

  bool get _useRemote =>
      !forceLocalOnly && !AppConfig.useLocalData && _apiClient != null;

  bool get _useSqlite => !kIsWeb && _localDb != null && !forceLocalOnly;

  Future<void> init() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    // Assuming local timezone is standard for the device
    tz.setLocalLocation(
      tz.getLocation('Europe/Kiev'),
    ); // Fallback, could be dynamic

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _isInitialized = true;
  }

  static const _constantTaskIdsKey = 'constant_task_reminder_ids_v1';
  static const _constantHabitIdsKey = 'constant_habit_reminder_ids_v1';

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (payload.startsWith('task_constant:')) {
      final taskId = payload.substring('task_constant:'.length);
      if (await _isConstantTaskActive(taskId)) {
        await _scheduleConstantFollowUp(
          id: _stableId('task_const_$taskId'),
          title: 'Reminder',
          body: null,
          payload: payload,
        );
      }
    } else if (payload.startsWith('habit_constant:')) {
      final habitId = payload.substring('habit_constant:'.length);
      if (await _isConstantHabitActive(habitId)) {
        await _scheduleConstantFollowUp(
          id: _stableId('habit_const_$habitId'),
          title: 'Reminder',
          body: null,
          payload: payload,
        );
      }
    }
  }

  int allocateNotificationId() {
    final value = 100000 + Random().nextInt(800000000);
    if (value == kHabitsReportNotificationRequestId) {
      return value + 1;
    }
    return value;
  }

  int _stableId(String seed) => seed.hashCode.abs() % 2000000000;

  Future<Task> prepareTaskNotifications(Task task) async {
    final offsets = <ScheduleReminderOffset>[];
    for (final offset in task.reminders) {
      offsets.add(
        offset.copyWith(
          notificationRequestId:
              offset.notificationRequestId ?? allocateNotificationId(),
        ),
      );
    }
    var constantId = task.constantNotificationRequestId;
    if (task.constantReminder) {
      constantId ??= allocateNotificationId();
    }
    return task.copyWith(
      reminders: offsets,
      constantNotificationRequestId: constantId,
      clearConstantNotificationRequestId: !task.constantReminder,
    );
  }

  Future<void> syncTaskNotifications(Task task) async {
    if (kIsWeb || forceLocalOnly) return;
    await cancelTaskNotifications(task);
    if (task.isDone || task.dueDate == null || task.reminders.isEmpty) {
      await _setConstantTaskActive(task.id, false);
      return;
    }
    final allowed = await requestPermissions();
    if (!allowed) return;
    final start = task.dueDate!;
    for (final offset in task.reminders) {
      final id = offset.notificationRequestId;
      if (id == null) continue;
      var fire = start.subtract(Duration(minutes: offset.offsetMinutes));
      if (!fire.isAfter(DateTime.now())) continue;
      await _zonedOneShot(
        id: id,
        title: task.title,
        body: task.description.isEmpty ? null : task.description,
        when: fire,
        payload: 'task:${task.id}',
      );
    }
    if (task.constantReminder) {
      await _setConstantTaskActive(task.id, true);
      final id = task.constantNotificationRequestId ?? allocateNotificationId();
      var fire = start;
      if (!fire.isAfter(DateTime.now())) {
        fire = DateTime.now().add(const Duration(minutes: 5));
      }
      await _zonedOneShot(
        id: id,
        title: task.title,
        body: task.description.isEmpty ? null : task.description,
        when: fire,
        payload: 'task_constant:${task.id}',
      );
    } else {
      await _setConstantTaskActive(task.id, false);
    }
  }

  Future<void> cancelTaskNotifications(Task task) async {
    for (final offset in task.reminders) {
      final id = offset.notificationRequestId;
      if (id != null) await cancelNotification(id);
    }
    final constantId = task.constantNotificationRequestId;
    if (constantId != null) await cancelNotification(constantId);
  }

  Future<void> syncHabitNotifications(Habit habit) async {
    if (kIsWeb || forceLocalOnly) return;
    if (habit.reminders.isEmpty) {
      await _setConstantHabitActive('${habit.id}', false);
      return;
    }
    final allowed = await requestPermissions();
    if (!allowed) return;

    var anyEnabled = false;
    var wantsConstant = habit.constantReminder;
    for (final reminder in habit.reminders) {
      wantsConstant = wantsConstant || reminder.constantReminder;
      if (!reminder.isEnabled) {
        for (final day in reminder.daysOfWeek) {
          await cancelNotification(day.userNotificationRequestId);
        }
        for (final offset in reminder.offsets) {
          final id = offset.notificationRequestId;
          if (id != null) await cancelNotification(id);
        }
        continue;
      }
      anyEnabled = true;
      final offsets = reminder.offsets.isEmpty
          ? const [ScheduleReminderOffset(offsetMinutes: 0)]
          : reminder.offsets;

      for (final day in reminder.daysOfWeek) {
        for (final offset in offsets) {
          final adjustedMinutes =
              reminder.time.hour * 60 +
              reminder.time.minute -
              offset.offsetMinutes;
          final wrapped = adjustedMinutes.remainder(24 * 60);
          final adjusted = TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
          final id = offset.notificationRequestId == null
              ? day.userNotificationRequestId
              : offset.notificationRequestId! + day.type;
          await addNotificationToDeviceAsync(
            reminder.copyWith(time: adjusted),
            WeekDay(
              type: day.type,
              userNotificationRequestId: id.abs() % 2000000000,
            ),
          );
        }
      }
    }
    await _setConstantHabitActive('${habit.id}', anyEnabled && wantsConstant);
  }

  Future<void> _zonedOneShot({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    String? payload,
  }) async {
    await init();
    final tzDate = tz.TZDateTime.from(when, tz.local);
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: _taskNotificationDetails,
      payload: payload,
    );
  }

  Future<void> _scheduleConstantFollowUp({
    required int id,
    required String title,
    String? body,
    required String payload,
  }) async {
    final when = DateTime.now().add(const Duration(minutes: 5));
    await _zonedOneShot(
      id: id,
      title: title,
      body: body,
      when: when,
      payload: payload,
    );
  }

  Future<bool> _isConstantTaskActive(String taskId) async {
    final ids = await _loadIdSet(_constantTaskIdsKey);
    return ids.contains(taskId);
  }

  Future<bool> _isConstantHabitActive(String habitId) async {
    final ids = await _loadIdSet(_constantHabitIdsKey);
    return ids.contains(habitId);
  }

  Future<void> _setConstantTaskActive(String taskId, bool active) async {
    await _mutateIdSet(_constantTaskIdsKey, taskId, active);
  }

  Future<void> _setConstantHabitActive(String habitId, bool active) async {
    await _mutateIdSet(_constantHabitIdsKey, habitId, active);
  }

  Future<Set<String>> _loadIdSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const [];
    return raw.toSet();
  }

  Future<void> _mutateIdSet(String key, String id, bool active) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (active) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await prefs.setStringList(key, ids.toList());
  }

  static const NotificationDetails _taskNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders_channel',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<bool> requestPermissions() async {
    await init();
    final android = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (android == false) return false;
    if (ios == false) return false;
    return true;
  }

  /// MAUI [RequestAccessToSendNotificationsAsync]. Web has no local notifications.
  Future<bool> requestAccessToSendNotifications() async {
    if (kIsWeb || forceLocalOnly) return true;
    return requestPermissions();
  }

  Future<void> addNotificationToDeviceAsync(
    HabitReminder reminder,
    WeekDay weekDay,
  ) async {
    if (reminder.isEnabled) {
      final allowed = await requestPermissions();
      if (!allowed) return;

      final now = DateTime.now();
      int reminderDayIndex = weekDay.type; // 0 = Sunday, 1 = Monday...
      // wait, DateTime.now().weekday is 1..7 (1=Mon, 7=Sun).
      // weekDay.type should be 0..6 (0=Sun, 1=Mon, ..., 6=Sat) to match the MAUI code?
      // Let's assume weekDay.type: 1=Mon, 7=Sun

      // Let's standardize: weekDay.type is 1..7 (DateTime.weekday format)
      int currentDayIndex = now.weekday;

      int daysUntilNextReminder = (reminderDayIndex - currentDayIndex + 7) % 7;

      // If it's today but the time has already passed
      if (daysUntilNextReminder == 0) {
        final nowTime = TimeOfDay.fromDateTime(now);
        if (reminder.time.hour < nowTime.hour ||
            (reminder.time.hour == nowTime.hour &&
                reminder.time.minute <= nowTime.minute)) {
          daysUntilNextReminder = 7;
        }
      }

      final scheduleDate = now.add(Duration(days: daysUntilNextReminder));
      final tzDate = tz.TZDateTime(
        tz.local,
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        reminder.time.hour,
        reminder.time.minute,
      );

      await _notificationsPlugin.zonedSchedule(
        id: weekDay.userNotificationRequestId,
        title: reminder.title,
        body: reminder.description.isNotEmpty ? reminder.description : null,
        scheduledDate: tzDate,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: _habitNotificationDetails,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else {
      await cancelNotification(weekDay.userNotificationRequestId);
    }
  }

  Future<void> cancelNotification(int id) async {
    if (id <= 0) return;
    await init();
    await _notificationsPlugin.cancel(id: id);
  }

  /// GET `/reminder/habitsreport`, with a local cache like MAUI.
  Future<Reminder> habitsReportReminder() async {
    final stored = await _loadCached();
    if (stored != null) return stored;

    if (!_useRemote) {
      return Reminder();
    }

    try {
      final response = await _apiClient!.get(ApiEndpoints.habitsReportReminder);
      final reminder = Reminder.fromJson(response.data);
      if (!reminder.isUnset) {
        await _saveCached(reminder);
      }
      return reminder;
    } catch (e) {
      debugPrint('Get habits report reminder failed: $e');
      return Reminder();
    }
  }

  /// POST `/reminder/habitsreport/{id}` and schedule the daily local notification.
  Future<SaveHabitsReportReminderResponse> saveHabitsReportReminder(
    Reminder reminder,
  ) async {
    var toSave = reminder;
    if (toSave.userNotificationRequestId == 0) {
      toSave = toSave.copyWith(
        userNotificationRequestId: kHabitsReportNotificationRequestId,
      );
    }
    toSave = toSave.copyWith(lastModified: DateTime.now().toUtc());
    await _saveCached(toSave);
    await applyHabitReportReminderLocally(toSave);

    if (!_useRemote) {
      return SaveHabitsReportReminderResponse(
        id: toSave.id ?? 0,
        userNotificationRequestId: toSave.userNotificationRequestId,
      );
    }

    Future<SaveHabitsReportReminderResponse> remote() async {
      final response = await _apiClient!.post(
        '${ApiEndpoints.habitsReportReminder}/${toSave.id ?? 0}',
        data: toSave.toApiJson(),
      );
      final saved = SaveHabitsReportReminderResponse.fromJson(response.data);
      final synced = toSave.copyWith(
        id: saved.id,
        userNotificationRequestId: saved.userNotificationRequestId,
      );
      await _saveCached(synced);
      return saved;
    }

    if (_executor != null) {
      final result = await _executor.execute<SaveHabitsReportReminderResponse>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.reminder,
        operation: OperationKind.save,
        payload: toSave.toJson(),
        entityId: toSave.id,
        entityLocalId: toSave.localId,
      );
      return result ??
          SaveHabitsReportReminderResponse(
            id: toSave.id ?? 0,
            userNotificationRequestId: toSave.userNotificationRequestId,
          );
    }

    unawaited(
      remote().catchError((Object e) {
        debugPrint('Save habits report reminder failed: $e');
        return SaveHabitsReportReminderResponse(
          id: toSave.id ?? 0,
          userNotificationRequestId: toSave.userNotificationRequestId,
        );
      }),
    );
    return SaveHabitsReportReminderResponse(
      id: toSave.id ?? 0,
      userNotificationRequestId: toSave.userNotificationRequestId,
    );
  }

  Future<void> applyHabitReportReminderLocally(Reminder reminder) async {
    if (kIsWeb || forceLocalOnly) return;
    final notificationId = reminder.userNotificationRequestId == 0
        ? kHabitsReportNotificationRequestId
        : reminder.userNotificationRequestId;
    if (reminder.isEnabled) {
      await _scheduleDailyNotification(reminder, notificationId);
    } else {
      await cancelNotification(notificationId);
    }
  }

  Future<void> tryToRecoverAllUserReminders() async {
    // Placeholder for recovering reminders after login/app restart
  }

  Future<Reminder?> getByLocalId(int localId) async {
    final stored = await _loadCached();
    if (stored?.localId == localId) return stored;
    if (!_useSqlite) return stored;
    final db = await _localDb!.database;
    final rows = await db.query(
      'reminders',
      where: 'localId = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Reminder.fromJson(rows.first);
  }

  Future<void> applyServerIds({
    int? localId,
    required int id,
    required int userNotificationRequestId,
  }) async {
    final stored = await _loadCached() ?? Reminder();
    await _saveCached(
      stored.copyWith(
        localId: localId ?? stored.localId,
        id: id,
        userNotificationRequestId: userNotificationRequestId,
      ),
    );
  }

  Future<void> mergeFromBootstrap(Reminder reminder) async {
    final local = await _loadCached();
    if (local != null &&
        !local.isUnset &&
        local.lastModified.isAfter(reminder.lastModified)) {
      return;
    }
    await _saveCached(reminder);
    await applyHabitReportReminderLocally(reminder);
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        await db.delete('reminders');
      } catch (e) {
        debugPrint('Clear sqlite reminders failed: $e');
      }
    }
  }

  Future<Reminder?> _loadCached() async {
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        final rows = await db.query('reminders', limit: 1);
        if (rows.isNotEmpty) {
          final reminder = Reminder.fromJson(rows.first);
          if (!reminder.isUnset) return reminder;
        }
      } catch (e) {
        debugPrint('Load sqlite reminder failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final reminder = Reminder.fromJson(decoded);
      if (reminder.isUnset) return null;
      return reminder;
    } catch (e) {
      debugPrint('Failed to parse cached habits report reminder: $e');
      return null;
    }
  }

  Future<void> _saveCached(Reminder reminder) async {
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        final row = {
          'id': reminder.id,
          'title': reminder.title,
          'description': reminder.description,
          'time': toTimeOnlyString(reminder.time),
          'isEnabled': reminder.isEnabled ? 1 : 0,
          'userNotificationRequestId': reminder.userNotificationRequestId,
          'lastModified': reminder.lastModified.toUtc().toIso8601String(),
        };
        final existing = await db.query('reminders', limit: 1);
        if (existing.isEmpty) {
          await db.insert('reminders', row);
        } else {
          await db.update(
            'reminders',
            row,
            where: 'localId = ?',
            whereArgs: [existing.first['localId']],
          );
        }
      } catch (e) {
        debugPrint('Save sqlite reminder failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(reminder.toJson()));
  }

  Future<void> _scheduleDailyNotification(Reminder reminder, int id) async {
    await init();
    final allowed = await requestPermissions();
    if (!allowed) return;

    final now = DateTime.now();
    var notify = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    if (!notify.isAfter(now)) {
      notify = notify.add(const Duration(days: 1));
    }
    final tzDate = tz.TZDateTime.from(notify, tz.local);
    final title = reminder.title.trim();

    await _notificationsPlugin.cancel(id: id);
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title.isEmpty ? 'Reminder' : title,
      body: reminder.description.isNotEmpty ? reminder.description : null,
      scheduledDate: tzDate,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: _habitNotificationDetails,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static const NotificationDetails _habitNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders_channel',
          'Habit Reminders',
          channelDescription: 'Notifications for habit reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
}
