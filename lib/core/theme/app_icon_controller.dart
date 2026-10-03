import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

import 'task_theme_palette.dart';

/// Switches the home-screen / window icon to match orange vs blue UI themes.
///
/// Orange (light and dark) uses the primary launcher icon. Blue uses the
/// `AppIconBlue` alternate on iOS, and a second desktop icon while the app is
/// running (Windows taskbar / macOS Dock).
///
/// Android does **not** swap launcher activity-aliases when the theme changes:
/// disabling the active alias removes the home-screen shortcut on many OEMs
/// (Samsung One UI especially). In-app colors still follow the selected theme.
class AppIconController {
  static const iosBlueIcon = 'AppIconBlue';
  static const _iconChannel = MethodChannel('com.set.principles/app_icon');

  static Future<void> apply(TasksUiTheme theme) async {
    if (kIsWeb) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Keep the existing launcher alias; see class doc.
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await _iconChannel.invokeMethod<void>(
          'setIcon',
          theme.isOrange ? 'orange' : 'blue',
        );
        return;
      }

      if (defaultTargetPlatform != TargetPlatform.iOS) return;

      if (!await FlutterDynamicIconPlus.supportsAlternateIcons) return;

      final desired = theme.isOrange ? null : iosBlueIcon;
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

  static bool _sameIcon(String? current, String? desired) {
    final normalizedCurrent = (current == null || current.isEmpty)
        ? null
        : current.replaceFirst(RegExp(r'^\.'), '');
    return normalizedCurrent == desired;
  }
}
