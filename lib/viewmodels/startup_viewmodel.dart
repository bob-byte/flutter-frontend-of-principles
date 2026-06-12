import 'package:flutter/foundation.dart';

import '../core/sync/sync_service.dart';
import '../services/auth_service.dart';
import '../services/reminder_service.dart';

class StartupViewModel extends ChangeNotifier {
  StartupViewModel({
    required AuthService authService,
    required SyncService syncService,
    required ReminderService reminderService,
  })  : _authService = authService,
        _syncService = syncService,
        _reminderService = reminderService;

  final AuthService _authService;
  final SyncService _syncService;
  final ReminderService _reminderService;
  bool loading = false;
  String? errorMessage;

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

  Future<bool> continueWithGoogleAsync() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      final success = await _authService.googleAuthorize();
      if (success) {
        await _reminderService.tryToRecoverAllUserReminders();
        return true;
      }
      return false;
    } catch (e) {
      errorMessage = e.toString();
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
        await _reminderService.tryToRecoverAllUserReminders();
        return true;
      }
      return false;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
