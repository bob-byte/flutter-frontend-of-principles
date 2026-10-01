import '../../services/auth_service.dart';
import '../../services/goal_service.dart';
import '../../services/push_sync_service.dart';
import '../../services/reminder_service.dart';
import '../../services/user_service.dart';
import '../storage/local_db.dart';
import '../storage/secure_store.dart';

class LocalDataCleaner {
  LocalDataCleaner({
    required this.localDb,
    required this.userService,
    required this.authService,
    required this.reminderService,
    required this.goalService,
    required this.secureStore,
    this.pushSyncService,
  });

  final LocalDb localDb;
  final UserService userService;
  final AuthService authService;
  final ReminderService reminderService;
  final GoalService goalService;
  final SecureStore secureStore;
  final PushSyncService? pushSyncService;

  Future<void> clearLocalData({bool logout = true}) async {
    if (logout) {
      // Needs the session token, so it runs before the token is dropped.
      await pushSyncService?.unregisterDevice().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
    await localDb.clearAllUserData();
    await userService.clearLocal();
    await reminderService.clearLocal();
    await goalService.clearLocal();
    if (logout) {
      await authService.logout();
    }
  }
}
