import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const notificationSettingsChannel = MethodChannel(
  'com.set.principles/app_settings',
);

/// Opens this app's notification settings on the device.
Future<bool> openNotificationSettings() async {
  if (kIsWeb) return false;
  try {
    final opened = await notificationSettingsChannel.invokeMethod<bool>(
      'openNotificationSettings',
    );
    return opened ?? true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Dismisses notifications already shown in the system tray/center.
///
/// Does **not** cancel pending schedules (unlike
/// [FlutterLocalNotificationsPlugin.cancelAll]). Matches MAUI
/// `LocalNotificationCenter.Current.ClearAll()`.
Future<void> clearDeliveredNotifications() async {
  if (kIsWeb) return;
  try {
    await notificationSettingsChannel.invokeMethod<void>(
      'clearDeliveredNotifications',
    );
  } on MissingPluginException {
    // Tests / unsupported embeds.
  } on PlatformException {
    // Best-effort; opening the app should not fail if clear fails.
  }
}
