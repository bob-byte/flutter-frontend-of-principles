import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const notificationSettingsChannel = MethodChannel(
  'com.set.principles/app_settings',
);

/// Opens this app's notification settings on the device.
///
/// Uses the native method channel on iOS / Android / macOS / Windows when
/// available, then falls back to a platform settings URI via [launchUrl].
Future<bool> openNotificationSettings() async {
  if (kIsWeb) return false;
  try {
    final opened = await notificationSettingsChannel.invokeMethod<bool>(
      'openNotificationSettings',
    );
    if (opened ?? true) return true;
  } on MissingPluginException {
    // Tests / unsupported embeds — try URI fallback below.
  } on PlatformException {
    // Channel failed — try URI fallback below.
  }
  return _openNotificationSettingsFallback();
}

Future<bool> _openNotificationSettingsFallback() async {
  final uri = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => Uri.parse('app-settings:'),
    TargetPlatform.macOS => Uri.parse(
      'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
    ),
    TargetPlatform.windows => Uri.parse('ms-settings:notifications'),
    // Android needs an Intent; without the channel there is no reliable URI.
    TargetPlatform.android ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => null,
  };
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
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
