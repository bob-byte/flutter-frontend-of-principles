import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/launch_data_loader.dart';
import '../core/logging/app_log.dart';
import '../core/network/network_service.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';

/// Fraction of the 16:9 frame that must stay visible.
///
/// `PRINCIPLES` occupies ~43% of the frame width. 0.52 leaves side margin
/// without going back to the old left/right crop.
const kSplashVisibleWidthFraction = 0.52;

/// Ignore end-of-stream events that fire as soon as the player attaches.
const kSplashEndDetectionGrace = Duration(milliseconds: 250);

/// Real background time before a resume may skip the remaining clip.
const kSplashResumeSkipMinAway = Duration(milliseconds: 400);

/// The clip must have been on screen this long before resume-skip is allowed.
const kSplashResumeSkipMinPlayed = Duration(milliseconds: 400);

/// Zoom applied on top of [BoxFit.contain] so the logo fills a phone screen
/// without clipping the wordmark. Landscape 16:9 stays at 1.0.
double splashVideoZoom({required Size viewport, required Size video}) {
  if (viewport.width <= 0 ||
      viewport.height <= 0 ||
      video.width <= 0 ||
      video.height <= 0) {
    return 1;
  }
  final contain = math.min(
    viewport.width / video.width,
    viewport.height / video.height,
  );
  final cropped = math.min(
    viewport.width / (video.width * kSplashVisibleWidthFraction),
    viewport.height / video.height,
  );
  if (contain <= 0) return 1;
  return (cropped / contain).clamp(1.0, 2.5);
}

/// Whether a lifecycle resume should dismiss the remaining splash.
///
/// Cold start, debugger attach, and themed-icon apply emit a short
/// paused→resumed burst. Those must not skip epic_start.
bool shouldFinishSplashOnResume({
  required bool videoVisible,
  required DateTime now,
  required DateTime? playedAt,
  required DateTime? backgroundedAt,
}) {
  if (!videoVisible || playedAt == null || backgroundedAt == null) {
    return false;
  }
  return now.difference(backgroundedAt) >= kSplashResumeSkipMinAway &&
      now.difference(playedAt) >= kSplashResumeSkipMinPlayed;
}

/// Full-screen themed splash overlay.
///
/// Cold start: the clip plays all the way through, then briefly holds the
/// last frame before revealing the app.
/// Resume: if the user actually left the app while the clip was playing,
/// the remaining animation is skipped.
class VideoSplashOverlay extends StatefulWidget {
  const VideoSplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<VideoSplashOverlay> createState() => _VideoSplashOverlayState();
}

class _VideoSplashOverlayState extends State<VideoSplashOverlay>
    with WidgetsBindingObserver {
  static const _endSlop = Duration(milliseconds: 50);
  static const _holdAfterEnd = Duration(milliseconds: 300);
  static const _maxFallback = Duration(seconds: 8);
  static const _audioChannel = MethodChannel('com.set.principles/splash_audio');

  bool get _useNativeSplashAudio =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  VideoPlayerController? _controller;
  AudioPlayer? _audio;
  Timer? _completionFallback;
  Color _background = Colors.black;
  DateTime? _playedAt;
  DateTime? _backgroundedAt;
  bool _showSplash = true;
  bool _initialized = false;
  bool _holdingEnd = false;
  bool _finishing = false;

  bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_inWidgetTest) {
      _showSplash = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _notifySplashFinished(),
      );
      return;
    }
    try {
      _background = context.read<ThemeController>().uiTheme.splashBackground;
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    unawaited(context.read<LaunchDataLoader>().ensureLoaded());

    final theme = context.read<ThemeController>();
    await theme.restore();
    if (!mounted || _finishing || !_showSplash) return;

    final uiTheme = theme.uiTheme;
    if (mounted) {
      setState(() => _background = uiTheme.splashBackground);
    }

    try {
      // Silent H.264 only. Muxed AAC in the same file makes iOS AVPlayer
      // fail with OSStatus -12746; the soundtrack is played separately.
      final controller = VideoPlayerController.asset(
        uiTheme.splashVideoAsset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      final duration = controller.value.duration;
      final fallback = duration > Duration.zero
          ? duration + _holdAfterEnd + const Duration(milliseconds: 400)
          : _maxFallback;
      _completionFallback = Timer(
        fallback > _maxFallback ? _maxFallback : fallback,
        _finish,
      );
      // Mount the player before play() so the first frames are visible.
      setState(() => _initialized = true);
      await _playSplashAudio();
      if (!mounted || _finishing) return;
      await controller.play();
      if (!mounted) return;
      _playedAt = DateTime.now();
      controller.addListener(_onVideoUpdate);
    } catch (error, stackTrace) {
      AppLog.error('epic_start failed to play', error, stackTrace);
      _finish();
    }
  }

  Future<void> _playSplashAudio() async {
    try {
      final data = await rootBundle.load(TasksUiTheme.splashAudioAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (_useNativeSplashAudio) {
        await _audioChannel.invokeMethod<void>('play', bytes);
        return;
      }
      if (kIsWeb) return;
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      final audio = AudioPlayer();
      _audio = audio;
      await audio.setReleaseMode(ReleaseMode.stop);
      await audio.setVolume(1);
      await audio.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (error, stackTrace) {
      AppLog.error('epic_start audio failed', error, stackTrace);
    }
  }

  Future<void> _stopSplashAudio() async {
    if (_useNativeSplashAudio) {
      try {
        await _audioChannel.invokeMethod<void>('stop');
      } catch (_) {}
      return;
    }
    final audio = _audio;
    _audio = null;
    if (audio == null) return;
    try {
      await audio.stop();
    } catch (_) {}
    await audio.dispose();
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final playedAt = _playedAt;
    if (playedAt == null) return;
    if (DateTime.now().difference(playedAt) < kSplashEndDetectionGrace) {
      return;
    }
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;
    if (controller.value.position + _endSlop >= duration) {
      _holdLastFrameThenFinish();
    }
  }

  void _holdLastFrameThenFinish() {
    if (_holdingEnd || _finishing || !_showSplash) return;
    _holdingEnd = true;
    _controller?.removeListener(_onVideoUpdate);
    _controller?.pause();
    unawaited(_stopSplashAudio());
    _completionFallback?.cancel();
    _completionFallback = Timer(_holdAfterEnd, _finish);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized || !_showSplash || _finishing) return;

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (shouldFinishSplashOnResume(
      videoVisible: true,
      now: DateTime.now(),
      playedAt: _playedAt,
      backgroundedAt: _backgroundedAt,
    )) {
      _finish();
    }
    _backgroundedAt = null;
  }

  void _finish() {
    if (_finishing || !_showSplash) return;
    _finishing = true;
    _completionFallback?.cancel();
    _completionFallback = null;
    _controller?.removeListener(_onVideoUpdate);
    unawaited(_stopSplashAudio());
    if (mounted) {
      setState(() => _showSplash = false);
      _notifySplashFinished();
    } else {
      _showSplash = false;
    }
  }

  void _notifySplashFinished() {
    if (!mounted) return;
    context.read<NetworkService>().onSplashFinished();
    unawaited(context.read<ThemeController>().applyAppIcon());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completionFallback?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onVideoUpdate);
    controller?.dispose();
    unawaited(_stopSplashAudio());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showSplash)
          Positioned.fill(
            child: ColoredBox(
              color: _background,
              child: _initialized && controller != null
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final zoom = splashVideoZoom(
                          viewport: constraints.biggest,
                          video: controller.value.size,
                        );
                        return ClipRect(
                          child: Center(
                            child: Transform.scale(
                              scale: zoom,
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}
