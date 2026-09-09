import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../launch_data_loader.dart';
import '../road_guide/road_guide_controller.dart';
import 'sync_trigger.dart';

/// Foreground catch-up so a device that stays open still sees other devices.
const kForegroundSyncInterval = Duration(minutes: 3);

/// Ignore brief inactive blips (notification shade, window focus flicker).
const kResumeSyncAfter = Duration(seconds: 2);

/// Runs bootstrap sync when the signed-in shell is resumed or left open.
class SessionSyncBinder extends StatefulWidget {
  const SessionSyncBinder({
    super.key,
    required this.child,
    this.foregroundInterval = kForegroundSyncInterval,
    this.resumeAfter = kResumeSyncAfter,
  });

  final Widget child;
  final Duration foregroundInterval;
  final Duration resumeAfter;

  @override
  State<SessionSyncBinder> createState() => _SessionSyncBinderState();
}

class _SessionSyncBinderState extends State<SessionSyncBinder>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periodic = Timer.periodic(widget.foregroundInterval, (_) {
      unawaited(_sync(SyncTrigger.resume, skipIfRecent: true));
    });
  }

  @override
  void dispose() {
    _periodic?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final started = _backgroundedAt;
    _backgroundedAt = null;
    if (started == null) return;
    if (DateTime.now().difference(started) < widget.resumeAfter) return;
    // A notification-permission sheet pauses the app. A full remesh on
    // Allow races reminder recovery and freezes the UI.
    unawaited(_sync(SyncTrigger.resume, skipIfRecent: true));
  }

  Future<void> _sync(SyncTrigger trigger, {bool skipIfRecent = false}) async {
    if (!mounted) return;
    // Bootstrap merge during the post-sign-in road guide freezes the spotlight.
    try {
      if (context.read<RoadGuideController>().isActive) return;
    } on ProviderNotFoundException {
      // Widget tests may omit the guide.
    }
    await context.read<LaunchDataLoader>().syncAndHydrate(
      trigger,
      skipIfRecent: skipIfRecent,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
