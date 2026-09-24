import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../sync/sync_run_result.dart';

class NetworkService extends ChangeNotifier {
  NetworkService({
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    bool? initialConnected,
    this.onConnectivityRestored,
    this.onAuthenticationFailure,
  }) : _checkConnectivity =
           checkConnectivity ??
           (connectivity ?? Connectivity()).checkConnectivity,
       _connectivityChanges =
           connectivityChanges ??
           (connectivity ?? Connectivity()).onConnectivityChanged,
       isConnected = initialConnected ?? false,
       _wasConnected = initialConnected ?? false;

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;

  bool isConnected;
  Future<SyncRunResult> Function()? onConnectivityRestored;
  Future<void> Function()? onAuthenticationFailure;

  bool _wasConnected;
  bool _sawFirstChange = false;
  bool _splashFinished = false;
  bool _postSplashUiReady = false;
  Completer<void>? _splashFinishedCompleter;
  Completer<void>? _postSplashUiReadyCompleter;
  Future<void>? _startFuture;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// True after [onSplashFinished] — update prompts may show.
  bool get isSplashFinished => _splashFinished;

  /// Completes when the epic_start clip ended (or immediately if already).
  ///
  /// The solid splash cover may still be up until [markPostSplashUiReady].
  Future<void> waitUntilSplashFinished() {
    if (_splashFinished) return Future<void>.value();
    return (_splashFinishedCompleter ??= Completer<void>()).future;
  }

  /// Completes when StartupView has navigated / shown its first real screen.
  Future<void> waitUntilPostSplashUiReady() {
    if (_postSplashUiReady) return Future<void>.value();
    return (_postSplashUiReadyCompleter ??= Completer<void>()).future;
  }

  /// True after [start] has begun (including while the first check is in flight).
  bool get hasStarted => _startFuture != null;

  /// Begins listening for connectivity. Safe to call more than once.
  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    return _startFuture = _startBody();
  }

  /// Waits for the first connectivity check when [start] was already invoked.
  ///
  /// Does not call [start] itself — unit tests may set [isConnected] without
  /// running a platform check.
  Future<void> ensureStarted() async {
    final pending = _startFuture;
    if (pending != null) await pending;
  }

  Future<void> _startBody() async {
    try {
      final results = await _checkConnectivity();
      isConnected = _hasInternet(results);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
    }
    _wasConnected = isConnected;
    notifyListeners();
    _subscription = _connectivityChanges.listen(_onChanged);
  }

  /// Call when the launch video has ended (hydrate may start; cover may remain).
  void onSplashFinished() {
    if (_splashFinished) return;
    _splashFinished = true;
    final waiting = _splashFinishedCompleter;
    _splashFinishedCompleter = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
    notifyListeners();
  }

  /// Call when the first post-splash screen is ready so the solid cover can lift.
  void markPostSplashUiReady() {
    if (_postSplashUiReady) return;
    _postSplashUiReady = true;
    final waiting = _postSplashUiReadyCompleter;
    _postSplashUiReadyCompleter = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  Future<void> _onChanged(List<ConnectivityResult> results) async {
    final nowConnected = _hasInternet(results);

    // iOS/Android emit the current (often `none`) status as soon as we
    // subscribe. Treat that as state sync, not a drop.
    if (!_sawFirstChange) {
      _sawFirstChange = true;
      if (nowConnected == isConnected) {
        _wasConnected = nowConnected;
        return;
      }
      isConnected = nowConnected;
      _wasConnected = nowConnected;
      notifyListeners();
      return;
    }

    final wasConnected = _wasConnected;
    if (nowConnected == wasConnected && nowConnected == isConnected) {
      return;
    }

    isConnected = nowConnected;
    notifyListeners();

    if (nowConnected && !wasConnected) {
      // Avoid SQLite/sync on the UI isolate while epic_start is playing.
      if (_splashFinished) {
        try {
          final result = await onConnectivityRestored?.call();
          if (result?.isAuthenticationFailure == true) {
            await onAuthenticationFailure?.call();
          }
        } catch (e) {
          debugPrint('Connectivity restored sync failed: $e');
        }
      }
    }

    _wasConnected = nowConnected;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    final splashWaiting = _splashFinishedCompleter;
    _splashFinishedCompleter = null;
    if (splashWaiting != null && !splashWaiting.isCompleted) {
      splashWaiting.complete();
    }
    final uiWaiting = _postSplashUiReadyCompleter;
    _postSplashUiReadyCompleter = null;
    if (uiWaiting != null && !uiWaiting.isCompleted) {
      uiWaiting.complete();
    }
    super.dispose();
  }

  static bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
