import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Asset played when the user marks a goal, task, subtask, or habit complete.
const kCompleteSoundAsset = 'assets/sounds/complete.wav';

/// How long Active-list rows stay visible after completion (matches the burst).
const kCompletionCelebrationDuration = Duration(milliseconds: 520);

/// Sound + haptic for a completion. Overlay burst lives in [CompletionCelebrate].
class CompletionFeedback {
  CompletionFeedback();

  static final CompletionFeedback instance = CompletionFeedback();

  static const _poolSize = 2;

  final List<AudioPlayer> _players = [];
  Uint8List? _bytes;
  int _next = 0;
  Future<void>? _loadingFuture;
  Future<void>? _playersFuture;

  static bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  /// Widget tests skip audio so [pumpAndSettle] and CI stay quiet.
  bool get skipAudio => _inWidgetTest;

  Future<void> preload() async {
    if (skipAudio) return;
    if (_bytes != null) {
      await _ensurePlayers();
      return;
    }
    final inFlight = _loadingFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loading = _loadBytesAndPlayers();
    _loadingFuture = loading;
    try {
      await loading;
    } finally {
      if (identical(_loadingFuture, loading)) {
        _loadingFuture = null;
      }
    }
  }

  Future<void> _loadBytesAndPlayers() async {
    try {
      final data = await rootBundle.load(kCompleteSoundAsset);
      _bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await _ensurePlayers();
    } catch (error, stackTrace) {
      debugPrint('Completion sound preload failed: $error\n$stackTrace');
    }
  }

  Future<void> play() async {
    if (skipAudio) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    try {
      await preload();
      final bytes = _bytes;
      if (bytes == null || bytes.isEmpty) return;
      await _ensurePlayers();
      if (_players.isEmpty) return;
      final player = _players[_next % _players.length];
      _next++;
      await player.stop();
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (error) {
      debugPrint('Completion sound failed: $error');
    }
  }

  Future<void> _ensurePlayers() async {
    if (_players.isNotEmpty) return;
    final inFlight = _playersFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final creating = _createPlayers();
    _playersFuture = creating;
    try {
      await creating;
    } finally {
      if (identical(_playersFuture, creating)) {
        _playersFuture = null;
      }
    }
  }

  Future<void> _createPlayers() async {
    if (_players.isNotEmpty) return;
    for (var i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.9);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await player.setPlayerMode(PlayerMode.lowLatency);
      }
      try {
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      } catch (_) {}
      _players.add(player);
    }
  }

  Future<void> dispose() async {
    final players = List<AudioPlayer>.from(_players);
    _players.clear();
    _bytes = null;
    _loadingFuture = null;
    _playersFuture = null;
    for (final player in players) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }
}
