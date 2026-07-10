import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/sync/sync_service.dart';
import '../services/auth_service.dart';

enum StartupNextRoute { helper, login, appBenefits }

class StartupViewModel extends ChangeNotifier {
  StartupViewModel({
    required AuthService authService,
    required SyncService syncService,
  })  : _authService = authService,
        _syncService = syncService;

  final AuthService _authService;
  final SyncService _syncService;
  bool loading = false;
  bool _hasShownAppBenefitsToGuest = false;

  Future<StartupNextRoute> initialize() async {
    loading = true;
    notifyListeners();
    try {
      if (AppConfig.useLocalData) {
        await _authService.ensureGuestSession();
        return StartupNextRoute.helper;
      }

      await _syncService.runSync();
      final token = await _authService.getToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      if (isLoggedIn) {
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
}
