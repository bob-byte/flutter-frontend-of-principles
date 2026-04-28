import 'package:flutter/foundation.dart';

import '../core/sync/sync_service.dart';
import '../services/auth_service.dart';

class StartupViewModel extends ChangeNotifier {
  StartupViewModel({
    required AuthService authService,
    required SyncService syncService,
  })  : _authService = authService,
        _syncService = syncService;

  final AuthService _authService;
  final SyncService _syncService;
  bool loading = false;

  Future<bool> initialize() async {
    loading = true;
    notifyListeners();
    try {
      await _syncService.runSync();
      final token = await _authService.getToken();
      return token != null && token.isNotEmpty;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
