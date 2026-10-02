import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable local notification sound.
///
/// Custom files must live in native bundles (`android/.../res/raw`,
/// `ios/Runner`, `macos/Runner`) — Flutter assets only drive Settings preview.
enum AppNotificationSound {
  /// Branded Principles tone (default).
  principles,

  /// OS default notification sound.
  system,

  /// Soft two-note chime.
  chime,

  /// Quiet single tone.
  soft,

  /// Insistent dual-tone alarm beep.
  alarm;

  static const prefsKey = 'notification_sound_v1';

  static const AppNotificationSound defaultSound =
      AppNotificationSound.principles;

  static const List<AppNotificationSound> selectable = [
    AppNotificationSound.principles,
    AppNotificationSound.system,
    AppNotificationSound.chime,
    AppNotificationSound.soft,
    AppNotificationSound.alarm,
  ];

  static AppNotificationSound fromId(String? id) {
    for (final sound in AppNotificationSound.values) {
      if (sound.id == id) return sound;
    }
    return defaultSound;
  }

  static Future<AppNotificationSound> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Background isolates and Settings writes share this key.
    await prefs.reload();
    return fromId(prefs.getString(prefsKey));
  }

  String get id => name;

  /// Android `res/raw` name without extension, or null for the system sound.
  String? get androidRawName => switch (this) {
    AppNotificationSound.principles => 'principles_reminder',
    AppNotificationSound.system => null,
    AppNotificationSound.chime => 'notification_chime',
    AppNotificationSound.soft => 'notification_soft',
    AppNotificationSound.alarm => 'notification_alarm',
  };

  /// Darwin bundle filename including extension, or null for the system sound.
  String? get darwinFileName => switch (this) {
    AppNotificationSound.principles => 'principles_reminder.wav',
    AppNotificationSound.system => null,
    AppNotificationSound.chime => 'notification_chime.wav',
    AppNotificationSound.soft => 'notification_soft.wav',
    AppNotificationSound.alarm => 'notification_alarm.wav',
  };

  /// Flutter asset for in-app preview (system has none).
  String? get previewAssetPath => switch (this) {
    AppNotificationSound.principles => 'assets/sounds/principles_reminder.wav',
    AppNotificationSound.system => null,
    AppNotificationSound.chime => 'assets/sounds/notification_chime.wav',
    AppNotificationSound.soft => 'assets/sounds/notification_soft.wav',
    AppNotificationSound.alarm => 'assets/sounds/notification_alarm.wav',
  };

  /// Suffix appended to Android channel ids so a new sound creates a new channel.
  /// Bump [channelRevision] when replacing bundled sound files in place.
  static const channelRevision = 'v3';

  String get androidChannelSuffix => '_${id}_$channelRevision';
}
