import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

import 'task_theme_palette.dart';

/// Switches the home-screen / window icon to match orange vs blue UI themes.
///
/// Orange (light and dark) uses the primary launcher icon. Blue uses the
/// `AppIconBlue` / `icon_1` alternate on mobile, and a second desktop icon
/// while the app is running (Windows taskbar / macOS Dock).
///
/// On Android the alias swap is queued and applied when the app is backgrounded
/// (Samsung One UI often ignores the plugin's kill-task hook and kicks the user
/// home if aliases flip while foregrounded).
class AppIconController {
  static const iosBlueIcon = 'AppIconBlue';
  static const _iconChannel = MethodChannel('com.set.principles/app_icon');

  static bool _lifecycleHooked = false;

  static Future<void> apply(TasksUiTheme theme) async {
    if (kIsWeb) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await _iconChannel.invokeMethod<void>(
          'setIcon',
          theme.isOrange ? 'orange' : 'blue',
        );
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        _ensureAndroidLifecycleHook();
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

  /// Flips activity-aliases for a previously [apply]ed Android theme.
  /// Safe no-op when nothing is pending or when not on Android.
  static Future<void> applyPendingAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _iconChannel.invokeMethod<void>('applyPendingIcon');
    } catch (_) {
      // Best-effort; next background / launch will retry via native prefs.
    }
  }

  static void _ensureAndroidLifecycleHook() {
    if (_lifecycleHooked) return;
    _lifecycleHooked = true;
    WidgetsBinding.instance.addObserver(_AppIconLifecycleObserver());
  }

  static bool _sameIcon(String? current, String? desired) {
    final normalizedCurrent = (current == null || current.isEmpty)
        ? null
        : current.replaceFirst(RegExp(r'^\.'), '');
    return normalizedCurrent == desired;
  }
}

class _AppIconLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(AppIconController.applyPendingAndroid());
    }
  }
}
