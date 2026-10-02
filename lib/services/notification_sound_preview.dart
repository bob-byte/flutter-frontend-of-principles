import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/app_notification_sound.dart';

/// In-app preview for [AppNotificationSound] (Settings picker).
///
/// Uses a single reused player with an explicit iOS audio session so rapid
/// picks and leftover sessions (completion sound, splash, speech) do not
/// silently fail the way one-shot [AudioPlayer] + timeout dispose did.
class NotificationSoundPreview {
  NotificationSoundPreview();

  static final NotificationSoundPreview instance = NotificationSoundPreview();

  AudioPlayer? _player;
  Future<AudioPlayer>? _playerFuture;
  final Map<AppNotificationSound, Uint8List> _bytesBySound = {};
  int _playToken = 0;

  static bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  Future<void> play(AppNotificationSound sound) async {
    if (_inWidgetTest) return;
    final asset = sound.previewAssetPath;
    if (asset == null) return;

    final token = ++_playToken;
    try {
      final bytes = await _bytesFor(sound, asset);
      if (token != _playToken || bytes.isEmpty) return;

      final player = await _ensurePlayer();
      if (token != _playToken) return;

      await player.stop();
      if (token != _playToken) return;

      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (error, stackTrace) {
      debugPrint('Notification sound preview failed: $error\n$stackTrace');
    }
  }

  Future<Uint8List> _bytesFor(AppNotificationSound sound, String asset) async {
    final cached = _bytesBySound[sound];
    if (cached != null) return cached;
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _bytesBySound[sound] = bytes;
    return bytes;
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final inFlight = _playerFuture;
    if (inFlight != null) return inFlight;

    final creating = _createPlayer();
    _playerFuture = creating;
    try {
      final player = await creating;
      _player = player;
      return player;
    } finally {
      if (identical(_playerFuture, creating)) {
        _playerFuture = null;
      }
    }
  }

  Future<AudioPlayer> _createPlayer() async {
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await player.setPlayerMode(PlayerMode.lowLatency);
    }
    try {
      await player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
          ),
          iOS: AudioContextIOS(
            // Same category as completion feedback: audible when the hardware
            // switch is off, mixes with other app audio, reclaimable after speech.
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (_) {}
    return player;
  }

  Future<void> dispose() async {
    _playToken++;
    final player = _player;
    _player = null;
    _playerFuture = null;
    _bytesBySound.clear();
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
