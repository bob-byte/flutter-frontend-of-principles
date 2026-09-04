import '../../services/auth_service.dart';
import '../../services/goal_service.dart';
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
  });

  final LocalDb localDb;
  final UserService userService;
  final AuthService authService;
  final ReminderService reminderService;
  final GoalService goalService;
  final SecureStore secureStore;

  Future<void> clearLocalData({bool logout = true}) async {
    await localDb.clearAllUserData();
    await userService.clearLocal();
    await reminderService.clearLocal();
    await goalService.clearLocal();
    if (logout) {
      await authService.logout();
    }
  }
}
