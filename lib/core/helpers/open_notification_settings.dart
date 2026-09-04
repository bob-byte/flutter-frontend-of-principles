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
