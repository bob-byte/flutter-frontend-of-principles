import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-install id sent as `X-Device-Id`, so the backend can skip the
/// silent sync push to the device that made the change.
abstract final class DeviceIdentity {
  static const prefsKey = 'device_install_id_v1';
  static const header = 'X-Device-Id';

  static Future<String>? _id;

  static Future<String> id() => _id ??= _load().catchError((Object e) {
    _id = null;
    throw e;
  });

  static Future<String> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final random = Random.secure();
    final created = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await prefs.setString(prefsKey, created);
    return created;
  }
}
