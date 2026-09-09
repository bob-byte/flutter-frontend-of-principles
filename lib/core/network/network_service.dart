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

  bool _started = false;
  bool _wasConnected;
  bool _sawFirstChange = false;
  bool _splashFinished = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// True after [onSplashFinished] — update prompts may show.
  bool get isSplashFinished => _splashFinished;

  Future<void> start() async {
    if (_started) return;
    _started = true;
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

  /// Call when the launch video overlay is gone.
  void onSplashFinished() {
    if (_splashFinished) return;
    _splashFinished = true;
    notifyListeners();
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
      try {
        final result = await onConnectivityRestored?.call();
        if (result?.isAuthenticationFailure == true) {
          await onAuthenticationFailure?.call();
        }
      } catch (e) {
        debugPrint('Connectivity restored sync failed: $e');
      }
    }

    _wasConnected = nowConnected;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
