import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/config/app_config.dart';
import '../core/sync/sync_service.dart';
import '../services/app_open_tracker_service.dart';
import '../services/auth_service.dart';
import '../services/dialog_service.dart';
import '../services/reminder_service.dart';

enum StartupNextRoute { helper, login, appBenefits }

class StartupViewModel extends ChangeNotifier {
  StartupViewModel({
    required AuthService authService,
    required SyncService syncService,
    required ReminderService reminderService,
    required DialogService dialogService,
    required AppOpenTrackerService appOpenTracker,
  }) : _authService = authService,
       _syncService = syncService,
       _reminderService = reminderService,
       _dialogService = dialogService,
       _appOpenTracker = appOpenTracker;

  final AuthService _authService;
  final SyncService _syncService;
  final ReminderService _reminderService;
  final DialogService _dialogService;
  final AppOpenTrackerService _appOpenTracker;
  bool loading = false;
  String? errorMessage;
  bool _hasShownAppBenefitsToGuest = false;
  Future<StartupNextRoute>? _initializeFuture;

  Future<StartupNextRoute> initialize() {
    return _initializeFuture ??= _initializeBody();
  }

  /// After the benefits carousel, the next start should be login — not a
  /// replay of the cached `appBenefits` initialize result.
  void acknowledgeAppBenefitsShown() {
    _hasShownAppBenefitsToGuest = true;
    _initializeFuture = Future.value(StartupNextRoute.login);
  }

  /// Clears the cached pre-auth initialize result after a successful sign-in
  /// so [LaunchDataLoader] hydrates goals/tasks/habits instead of bailing out.
  void markSignedIn() {
    _initializeFuture = Future.value(StartupNextRoute.helper);
  }

  Future<bool> hasAuthenticatedSession() => _authService.hasLocalSession();

  Future<StartupNextRoute> _initializeBody() async {
    loading = true;
    notifyListeners();
    try {
      await _appOpenTracker.trackAppOpen();
      if (AppConfig.useLocalData) {
        await _authService.ensureGuestSession();
        return StartupNextRoute.helper;
      }

      if (await _authService.hasLocalSession()) {
        return StartupNextRoute.helper;
      }
      if (!_hasShownAppBenefitsToGuest) {
        _hasShownAppBenefitsToGuest = true;
        return StartupNextRoute.appBenefits;
      }
      return StartupNextRoute.login;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> continueWithGoogleAsync() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.googleAuthorize();
      if (success) {
        markSignedIn();
        await _syncService.runSyncSafely();
        await _reminderService.tryToRecoverAllUserReminders();
        return true;
      }
      return false;
    } catch (e) {
      if (AuthService.isExternalAuthCanceled(e)) return false;
      errorMessage = e.toString();
      await _dialogService.showErrorAsync(
        _dialogService.l10n.somethingWentWrongWhenUserAuthsUsingExternalService,
      );
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> continueWithAppleAsync() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.appleAuthorize();
      if (success) {
        markSignedIn();
        await _syncService.runSyncSafely();
        await _reminderService.tryToRecoverAllUserReminders();
        return true;
      }
      return false;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (AuthService.isExternalAuthCanceled(e)) return false;
      await _handleAppleAuthException(e);
      return false;
    } catch (e) {
      if (AuthService.isExternalAuthCanceled(e)) return false;
      errorMessage = e.toString();
      await _handleAppleAuthException(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _handleAppleAuthException(Object ex) async {
    if (ex is SignInWithAppleAuthorizationException &&
        ex.code == AuthorizationErrorCode.canceled) {
      return;
    }

    final l10n = _dialogService.l10n;
    String errorMsg;

    if (ex is SignInWithAppleAuthorizationException &&
        ex.code == AuthorizationErrorCode.unknown) {
      // ASAuthorizationErrorUnknown (error 1000): often iCloud / Apple ID setup.
      errorMsg = l10n.appleAuthUnknownError;
    } else if (ex.toString().contains('AppleAuthUnavailableOnDevice')) {
      errorMsg = l10n.appleAuthUnavailableOnDevice;
    } else {
      errorMsg = l10n.somethingWentWrongWhenUserAuthsUsingExternalService;
    }

    errorMessage = errorMsg;
    await _dialogService.showErrorAsync(errorMsg);
  }
}
