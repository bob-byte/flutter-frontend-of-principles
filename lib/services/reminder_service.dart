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
import '../core/deep_link/notification_payload.dart';
import '../core/helpers/open_notification_settings.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/reminder/reminder_restore_isolate.dart';
import '../core/storage/local_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../models/habit.dart';
import '../models/habit_reminder.dart';
import '../models/reminder.dart';
import '../models/schedule_reminder_offset.dart';
import '../models/task.dart';
import 'dialog_service.dart';
import 'task_service.dart';

class ReminderService {
  ReminderService({
    ApiClient? apiClient,
    this.forceLocalOnly = false,
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
    DialogService? dialogService,
    TaskService? taskService,
  }) : _apiClient = apiClient,
       _localDb = localDb,
       _executor = executor,
       _dialogService = dialogService,
       _taskService = taskService;

  static const prefsKey = 'habits_report_reminder_v1';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Set by [DeepLinkBinder]; may fire with no [BuildContext].
  static void Function(String? payload)? onNotificationOpened;

  final ApiClient? _apiClient;
  final bool forceLocalOnly;
  final LocalDb? _localDb;
  final LocalRemoteExecutor? _executor;
  final DialogService? _dialogService;
  final TaskService? _taskService;

  /// Last bootstrap `generalReminders` / `userHabitReminders` (SyncGate restore).
  AllRemindersResponse? _bootstrapReminders;

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
          macOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _isInitialized = true;
  }

  static const _constantTaskIdsKey = 'constant_task_reminder_ids_v1';
  static const _constantHabitIdsKey = 'constant_habit_reminder_ids_v1';

  static void _onNotificationResponse(NotificationResponse response) {
    onNotificationOpened?.call(response.payload);
  }

  /// Cold-start payload when the OS launched the app from a notification tap.
  static Future<String?> consumeAppLaunchNotificationPayload() async {
    if (kIsWeb) return null;
    try {
      final details = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return details.notificationResponse?.payload;
    } catch (e) {
      debugPrint('Read notification launch details failed: $e');
      return null;
    }
  }

  int allocateNotificationId() {
    final value = 100000 + Random().nextInt(800000000);
    if (value == kHabitsReportNotificationRequestId) {
      return value + 1;
    }
    return value;
  }

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

  Future<void> syncTaskNotifications(
    Task task, {
    bool ensurePermission = true,
  }) async {
    if (kIsWeb || forceLocalOnly) return;
    await cancelTaskNotifications(task);
    if (task.isDone || task.dueDate == null || task.reminders.isEmpty) {
      await _setConstantTaskActive(task.id, false);
      return;
    }
    if (ensurePermission) {
      final allowed = await requestPermissions();
      if (!allowed) return;
    }
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
        payload: '${NotificationPayloads.task}${task.id}',
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
        payload: '${NotificationPayloads.taskConstant}${task.id}',
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

  Future<void> syncHabitNotifications(
    Habit habit, {
    bool ensurePermission = true,
  }) async {
    if (kIsWeb || forceLocalOnly) return;
    if (habit.reminders.isEmpty) {
      await _setConstantHabitActive('${habit.id}', false);
      return;
    }
    if (ensurePermission) {
      final allowed = await requestPermissions();
      if (!allowed) return;
    }

    final habitPayload = habit.id == null
        ? null
        : '${NotificationPayloads.habit}${habit.id}';
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
            payload: habitPayload,
            ensurePermission: false,
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

  Future<void> _setConstantTaskActive(String taskId, bool active) async {
    await _mutateIdSet(_constantTaskIdsKey, taskId, active);
  }

  Future<void> _setConstantHabitActive(String habitId, bool active) async {
    await _mutateIdSet(_constantHabitIdsKey, habitId, active);
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
        macOS: DarwinNotificationDetails(),
      );

  final NotificationPermissionGate _permissionGate =
      NotificationPermissionGate();

  /// One native permission sheet per session. A second iOS/macOS
  /// `requestPermissions` after Allow can hang the Flutter isolate.
  Future<bool> requestPermissions() async {
    if (kIsWeb || forceLocalOnly) return true;
    return _permissionGate.run(_requestPermissionsNative);
  }

  Future<bool> _requestPermissionsNative() async {
    await init();
    if (await areNotificationsEnabled()) return true;
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
    final macOS = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (android == false) return false;
    if (ios == false) return false;
    if (macOS == false) return false;
    return true;
  }

  /// Check without prompting (MAUI [AreNotificationsEnabledAsync]).
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || forceLocalOnly) return false;
    await init();
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final status = await ios.checkPermissions();
      return status?.isEnabled ?? false;
    }
    final macOS = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macOS != null) {
      final status = await macOS.checkPermissions();
      return status?.isEnabled ?? false;
    }
    return false;
  }

  /// MAUI [RequestAccessToSendNotificationsAsync]. Web has no local notifications.
  Future<bool> requestAccessToSendNotifications() async {
    if (kIsWeb || forceLocalOnly) return true;
    return requestPermissions();
  }

  /// Whether this build can schedule OS local notifications (Flutter-only gate).
  ///
  /// Does not change the shared API — MAUI keeps its own support check.
  bool get isLocalNotificationSupported =>
      localNotificationSupportedOverride ?? !kIsWeb;

  /// Test hook for [isLocalNotificationSupported].
  @visibleForTesting
  bool? localNotificationSupportedOverride;

  /// Local cache only (no network). Used for Tasks chrome; safe if unset.
  Future<Reminder?> cachedHabitsReportReminder() => _loadCached();

  Future<void> addNotificationToDeviceAsync(
    HabitReminder reminder,
    WeekDay weekDay, {
    String? payload,
    bool ensurePermission = true,
  }) async {
    if (reminder.isEnabled) {
      if (ensurePermission) {
        final allowed = await requestPermissions();
        if (!allowed) return;
      }

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
        payload: payload,
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

  /// Stash bootstrap reminder lists for SyncGate restore (avoids `/reminder/all`).
  void rememberBootstrapReminders(AllRemindersResponse reminders) {
    _bootstrapReminders = reminders;
  }

  /// Drop the bootstrap stash after SyncGate restore so it is not kept in RAM.
  void clearBootstrapReminders() {
    _bootstrapReminders = null;
  }

  @visibleForTesting
  AllRemindersResponse? get bootstrapRemindersForTest => _bootstrapReminders;

  /// Loads account reminders, shows MAUI why-copy, requests permission once.
  ///
  /// Prefers bootstrap lists (same shape as GET `/reminder/all`), then falls
  /// back to that endpoint for older servers. Always returns a schedule job
  /// when reminders exist — even if the user denies permission — so entries
  /// are registered on-device for when access is granted later.
  Future<Map<String, Object?>?> prepareReminderRestore({
    List<Task>? knownTasks,
    List<Habit>? knownHabits,
    Future<void> Function()? onExplainRestore,
    AllRemindersResponse? knownReminders,
  }) async {
    if (kIsWeb || forceLocalOnly) return null;

    try {
      await init();

      final all = await _resolveRemindersForRestore(knownReminders);

      var enabledGeneral = all.generalReminders
          .where((r) => r.isEnabled && !r.isUnset)
          .toList();
      var enabledHabits = all.userHabitReminders
          .where((r) => r.isEnabled && r.daysOfWeek.isNotEmpty)
          .toList();

      // Bootstrap already hydrated SQLite — use it when remote lists are empty
      // so MAUI RestoreReminders copy still appears before the OS sheet.
      if (enabledGeneral.isEmpty) {
        final cached = await _loadCached();
        if (cached != null && cached.isEnabled && !cached.isUnset) {
          enabledGeneral = [cached];
        }
      }
      enabledHabits = _mergeHabitRemindersFromLocal(
        enabledHabits,
        knownHabits ?? const <Habit>[],
      );

      final tasks =
          knownTasks ?? await _taskService?.getTasks() ?? const <Task>[];
      final tasksWithReminders = tasks
          .where(
            (t) => !t.isDone && (t.reminders.isNotEmpty || t.constantReminder),
          )
          .toList();

      // MAUI gates the restore alert on general + habit reminders.
      final hasAccountReminders =
          enabledGeneral.isNotEmpty || enabledHabits.isNotEmpty;
      if (!hasAccountReminders && tasksWithReminders.isEmpty) {
        return null;
      }

      var notificationsOn = await areNotificationsEnabled();
      if (!notificationsOn) {
        // Always explain why before the system permission sheet (MAUI
        // AfterLoginWhenUserAccountHaveReminders / RestoreReminders).
        if (onExplainRestore != null) {
          await onExplainRestore();
        } else {
          await _promptRestoreReminders();
        }
        // One native sheet only. A second iOS requestPermissions after Allow
        // hangs the isolate and freezes SyncGate.
        notificationsOn = await requestAccessToSendNotifications();
        // The system sheet backgrounds the app. Wait until Flutter is
        // resumed before touching SQLite / continuing the gate.
        await _waitUntilResumed();
      }
      if (notificationsOn) {
        // Mark the gate so later schedule helpers never re-enter the
        // native permission channel.
        _permissionGate.allowed = true;
      }

      for (final reminder in enabledGeneral) {
        await _saveCached(reminder);
      }

      // Schedule/register anyway — OS may no-op until permission is granted.
      return buildReminderRestoreJob(
        generalReminders: enabledGeneral,
        habitReminders: enabledHabits,
        tasks: tasksWithReminders,
      );
    } catch (e) {
      debugPrint('Prepare reminder restore failed: $e');
      return null;
    }
  }

  Future<AllRemindersResponse> _resolveRemindersForRestore(
    AllRemindersResponse? knownReminders,
  ) async {
    if (knownReminders != null) return knownReminders;
    final fromBootstrap = _bootstrapReminders;
    if (fromBootstrap != null) return fromBootstrap;
    // Older servers: do not block SyncGate forever if /reminder/all is slow.
    return _loadAllReminders().timeout(
      const Duration(seconds: 20),
      onTimeout: () => const AllRemindersResponse(),
    );
  }

  /// Applies [prepareReminderRestore]'s job using the already-initialized plugin.
  Future<void> applyReminderRestoreJob(Map<String, Object?> job) async {
    if (kIsWeb || forceLocalOnly) return;
    try {
      await init();
      await executeReminderRestoreJob(
        job,
        plugin: _notificationsPlugin,
        initializePlugin: false,
      );
    } catch (e) {
      debugPrint('Apply reminder restore failed: $e');
    }
  }

  Future<void> tryToRecoverAllUserReminders({
    List<Task>? knownTasks,
    List<Habit>? knownHabits,
    Future<void> Function()? onExplainRestore,
  }) async {
    final job = await prepareReminderRestore(
      knownTasks: knownTasks,
      knownHabits: knownHabits,
      onExplainRestore: onExplainRestore,
    );
    if (job == null) return;
    await applyReminderRestoreJob(job);
  }

  /// Prefer API habit reminders; fill gaps from habits already in memory.
  @visibleForTesting
  static List<HabitReminder> mergeHabitRemindersFromLocalForTest(
    List<HabitReminder> fromApi,
    List<Habit> localHabits,
  ) => _mergeHabitRemindersFromLocal(fromApi, localHabits);

  static List<HabitReminder> _mergeHabitRemindersFromLocal(
    List<HabitReminder> fromApi,
    List<Habit> localHabits,
  ) {
    if (localHabits.isEmpty) return fromApi;
    final byId = <int, HabitReminder>{
      for (final reminder in fromApi)
        if (reminder.id != null) reminder.id!: reminder,
    };
    final merged = List<HabitReminder>.from(fromApi);
    for (final habit in localHabits) {
      for (final reminder in habit.reminders) {
        if (!reminder.isEnabled || reminder.daysOfWeek.isEmpty) continue;
        final id = reminder.id ?? habit.id;
        if (id != null && byId.containsKey(id)) continue;
        final withMeta = HabitReminder(
          id: id,
          title: reminder.title.isNotEmpty
              ? reminder.title
              : (habit.name.isEmpty ? 'Reminder' : habit.name),
          description: reminder.description,
          time: reminder.time,
          isEnabled: reminder.isEnabled,
          daysOfWeek: reminder.daysOfWeek,
          offsets: reminder.offsets,
          constantReminder: reminder.constantReminder || habit.constantReminder,
          constantNotificationRequestId: reminder.constantNotificationRequestId,
          endTime: reminder.endTime,
          allDay: reminder.allDay,
        );
        if (id != null) byId[id] = withMeta;
        merged.add(withMeta);
      }
    }
    return merged;
  }

  Future<AllRemindersResponse> _loadAllReminders() async {
    if (!_useRemote || _apiClient == null) {
      return const AllRemindersResponse();
    }
    final response = await _apiClient.get(ApiEndpoints.allReminders);
    return AllRemindersResponse.fromJson(response.data);
  }

  Future<void> _promptRestoreReminders() async {
    final dialogs = _dialogService;
    if (dialogs == null) return;
    try {
      final l10n = dialogs.l10n;
      await dialogs.showAlertAsync(
        msg: l10n.afterLoginWhenUserAccountHaveReminders,
        title: l10n.restoreReminders,
        buttonLabel: l10n.okButton,
      );
    } catch (e) {
      debugPrint('Restore-reminders prompt failed: $e');
    }
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

  /// Server has no daily-report reminder — drop the local copy.
  Future<void> clearFromRemote() async {
    final local = await _loadCached();
    if (local == null || local.isUnset) return;
    if (local.userNotificationRequestId > 0) {
      await cancelNotification(local.userNotificationRequestId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        await db.delete('reminders');
      } catch (e) {
        debugPrint('Clear remote reminder failed: $e');
      }
    }
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
    await cancelAllLocally();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await prefs.remove(_constantTaskIdsKey);
    await prefs.remove(_constantHabitIdsKey);
    if (_useSqlite) {
      try {
        final db = await _localDb!.database;
        await db.delete('reminders');
      } catch (e) {
        debugPrint('Clear sqlite reminders failed: $e');
      }
    }
  }

  /// MAUI [CancelAllLocallyAsync] — drops every pending local notification.
  Future<void> cancelAllLocally() async {
    if (kIsWeb || forceLocalOnly) return;
    try {
      await init();
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Cancel all local notifications failed: $e');
    }
  }

  /// MAUI [ClearDeliveredLocallyAsync] / [LocalNotificationCenter.ClearAll].
  ///
  /// Removes notifications already shown in the system tray/center without
  /// canceling pending schedules (habit weekly / daily report, etc.).
  Future<void> clearDeliveredLocally() async {
    if (kIsWeb || forceLocalOnly) return;
    try {
      await clearDeliveredNotifications();
    } catch (e) {
      debugPrint('Clear delivered local notifications failed: $e');
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

  Future<void> _scheduleDailyNotification(
    Reminder reminder,
    int id, {
    bool ensurePermission = true,
  }) async {
    await init();
    if (ensurePermission) {
      final allowed = await requestPermissions();
      if (!allowed) return;
    }

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
      payload: NotificationPayloads.habitsReport,
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
        macOS: DarwinNotificationDetails(),
      );

  Future<void> _waitUntilResumed() async {
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      await binding.endOfFrame;
      return;
    }

    final done = Completer<void>();
    late final WidgetsBindingObserver observer;
    observer = _ResumeObserver(() {
      if (!done.isCompleted) done.complete();
    });
    binding.addObserver(observer);
    try {
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } finally {
      binding.removeObserver(observer);
    }
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResumed);

  final VoidCallback _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}

/// Dedupes the OS notification permission sheet.
///
/// Calling `requestPermissions` again after the user taps Allow can hang
/// the Flutter isolate on iOS/macOS (the method channel never completes).
class NotificationPermissionGate {
  bool allowed = false;
  Future<bool>? _inFlight;

  Future<bool> run(Future<bool> Function() request) async {
    if (allowed) return true;
    final existing = _inFlight;
    if (existing != null) return existing;
    final run = request();
    _inFlight = run;
    try {
      final result = await run;
      if (result) allowed = true;
      return result;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    }
  }
}
