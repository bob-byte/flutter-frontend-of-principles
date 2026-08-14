import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/habit_reminder.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    // Assuming local timezone is standard for the device
    tz.setLocalLocation(tz.getLocation('Europe/Kiev')); // Fallback, could be dynamic

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> addNotificationToDeviceAsync(HabitReminder reminder, WeekDay weekDay) async {
    await init();

    if (reminder.isEnabled) {
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
           (reminder.time.hour == nowTime.hour && reminder.time.minute <= nowTime.minute)) {
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

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
              'habit_reminders_channel', 
              'Habit Reminders',
              channelDescription: 'Notifications for habit reminders',
              importance: Importance.max,
              priority: Priority.high,
          );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notificationsPlugin.zonedSchedule(
          id: weekDay.userNotificationRequestId,
          title: reminder.title,
          body: reminder.description.isNotEmpty ? reminder.description : null,
          scheduledDate: tzDate,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          notificationDetails: platformChannelSpecifics,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else {
      await cancelNotification(weekDay.userNotificationRequestId);
    }
  }

  Future<void> cancelNotification(int id) async {
    await init();
    await _notificationsPlugin.cancel(id: id);
  }

  Future<void> tryToRecoverAllUserReminders() async {
    // Placeholder for recovering reminders after login/app restart
  }
}
