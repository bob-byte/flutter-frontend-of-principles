import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

import 'task_theme_palette.dart';

/// Switches the home-screen / window icon to match orange vs blue UI themes.
///
/// Orange (light and dark) uses the primary launcher icon. Blue uses the
/// `AppIconBlue` / `icon_1` alternate on mobile, and a second Windows icon
/// resource while the app is running. No-ops on web/macOS and when the
/// current icon already matches.
class AppIconController {
  static const iosBlueIcon = 'AppIconBlue';
  static const androidBlueIcon = 'icon_1';
  static const _windowsChannel = MethodChannel('com.set.principles/app_icon');

  static Future<void> apply(TasksUiTheme theme) async {
    if (kIsWeb) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _windowsChannel.invokeMethod<void>(
          'setIcon',
          theme.isOrange ? 'orange' : 'blue',
        );
        return;
      }

      if (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android) {
        return;
      }

      if (!await FlutterDynamicIconPlus.supportsAlternateIcons) return;

      final desired = theme.isOrange ? null : _alternateName;
      final current = await FlutterDynamicIconPlus.alternateIconName;
      if (_sameIcon(current, desired)) return;

      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: desired,
        blacklistBrands: const ['Redmi'],
        blacklistManufactures: const ['Xiaomi'],
      );
    } catch (_) {
      // Icon switching is best-effort; theme still applies without it.
    }
  }

  static String get _alternateName =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? iosBlueIcon
      : androidBlueIcon;

  static bool _sameIcon(String? current, String? desired) {
    final normalizedCurrent = (current == null || current.isEmpty)
        ? null
        : current.replaceFirst(RegExp(r'^\.'), '');
    return normalizedCurrent == desired;
  }
}
