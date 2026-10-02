import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/reminder/notification_sound_details.dart';
import 'package:principles_app/models/app_notification_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to Principles sound', () {
    expect(AppNotificationSound.fromId(null), AppNotificationSound.principles);
    expect(
      AppNotificationSound.fromId('missing'),
      AppNotificationSound.principles,
    );
  });

  test('persists and reloads the selected sound', () async {
    expect(await AppNotificationSound.load(), AppNotificationSound.principles);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppNotificationSound.prefsKey, 'chime');

    expect(await AppNotificationSound.load(), AppNotificationSound.chime);
  });

  test('custom sounds use platform resource names', () {
    expect(
      AppNotificationSound.principles.androidRawName,
      'principles_reminder',
    );
    expect(
      AppNotificationSound.principles.darwinFileName,
      'principles_reminder.wav',
    );
    expect(AppNotificationSound.system.androidRawName, isNull);
    expect(AppNotificationSound.system.darwinFileName, isNull);
  });

  test('channel ids include the sound suffix', () {
    final principles = reminderNotificationDetails(
      channel: ReminderNotificationChannel.task,
      sound: AppNotificationSound.principles,
    );
    final system = reminderNotificationDetails(
      channel: ReminderNotificationChannel.task,
      sound: AppNotificationSound.system,
    );

    expect(principles.android?.channelId, 'task_reminders_channel_principles_v3');
    expect(system.android?.channelId, 'task_reminders_channel_system_v3');
    expect(principles.iOS?.sound, 'principles_reminder.wav');
    expect(system.iOS?.sound, isNull);
  });
}
