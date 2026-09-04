import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/dialog_service.dart';
import '../sync/sync_run_result.dart';

class NetworkService extends ChangeNotifier {
  NetworkService({
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    bool? initialConnected,
    this.onConnectivityRestored,
    this.onAuthenticationFailure,
    this.onOfflineToast,
    Duration? offlineConfirmDelay,
  }) : _checkConnectivity =
           checkConnectivity ??
           (connectivity ?? Connectivity()).checkConnectivity,
       _connectivityChanges =
           connectivityChanges ??
           (connectivity ?? Connectivity()).onConnectivityChanged,
       isConnected = initialConnected ?? true,
       _wasConnected = initialConnected ?? true,
       _offlineConfirmDelay =
           offlineConfirmDelay ?? const Duration(seconds: 2);

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Duration _offlineConfirmDelay;

  bool isConnected;
  Future<SyncRunResult> Function()? onConnectivityRestored;
  Future<void> Function()? onAuthenticationFailure;

  /// Test hook. When null, a SnackBar is shown via [DialogService].
  void Function()? onOfflineToast;

  bool _started = false;
  bool _wasConnected;
  bool _sawFirstChange = false;
  bool _splashFinished = false;
  Timer? _offlineDebounce;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

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

  /// Call when the launch video overlay is gone so an offline notice can be
  /// seen. Startup often emits a brief [ConnectivityResult.none] that is not
  /// a real outage.
  void onSplashFinished() {
    if (_splashFinished) return;
    _splashFinished = true;
    _offlineDebounce?.cancel();
    _offlineDebounce = null;
    if (!isConnected) {
      _showOfflineToast();
    }
  }

  Future<void> _onChanged(List<ConnectivityResult> results) async {
    final nowConnected = _hasInternet(results);

    // iOS/Android emit the current (often `none`) status as soon as we
    // subscribe. Treat that as state sync, not a drop the user should see.
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

    if (nowConnected) {
      _offlineDebounce?.cancel();
      _offlineDebounce = null;
      if (!wasConnected) {
        try {
          final result = await onConnectivityRestored?.call();
          if (result?.isAuthenticationFailure == true) {
            await onAuthenticationFailure?.call();
          }
        } catch (e) {
          debugPrint('Connectivity restored sync failed: $e');
        }
      }
    } else if (wasConnected) {
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(_offlineConfirmDelay, () {
        if (!isConnected) {
          _emitOfflineToast();
        }
      });
    }

    _wasConnected = nowConnected;
  }

  void _emitOfflineToast() {
    if (!_splashFinished) return;
    _showOfflineToast();
  }

  void _showOfflineToast() {
    if (onOfflineToast != null) {
      onOfflineToast!();
      return;
    }
    try {
      final context = DialogService().navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = l10n?.noInternetConnection ?? 'No internet connection';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Offline toast failed: $e');
    }
  }

  @override
  void dispose() {
    _offlineDebounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  static bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
