import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/locale/locale_controller.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/local_data_cleaner.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/settings_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsViewModel vm;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      UserService.prefsKey: jsonEncode(
        User(
          name: 'Ada',
          email: 'ada@example.com',
          mainSlogan: 'Keep going',
          mission: 'Build tools',
          gender: 0,
        ).toJson(),
      ),
    });
    final secureStore = SecureStore();
    final authService = AuthService(secureStore);
    final userService = UserService(forceLocalOnly: true);
    vm = SettingsViewModel(
      settingsService: SettingsService(secureStore),
      localeController: LocaleController(),
      userService: userService,
      localDataCleaner: LocalDataCleaner(
        localDb: LocalDb(),
        userService: userService,
        authService: authService,
        reminderService: ReminderService(forceLocalOnly: true),
        goalService: GoalService(authService),
        secureStore: secureStore,
      ),
    );
  });

  test('loadProfile reads cached name, email, slogan, mission and gender', () async {
    await vm.loadProfile();

    expect(vm.userName, 'Ada');
    expect(vm.email, 'ada@example.com');
    expect(vm.mainSlogan, 'Keep going');
    expect(vm.mission, 'Build tools');
    expect(vm.gender, 0);
  });

  test('saveUserName rejects a blank name', () async {
    await vm.loadProfile();
    expect(await vm.saveUserName('   '), isFalse);
    expect(vm.userName, 'Ada');
  });

  test('saves name, slogan, mission and gender locally', () async {
    await vm.loadProfile();

    expect(await vm.saveUserName('Grace'), isTrue);
    expect(vm.userName, 'Grace');

    expect(await vm.saveMainSlogan('Ship it'), isTrue);
    expect(vm.mainSlogan, 'Ship it');

    expect(await vm.saveMission('Help people'), isTrue);
    expect(vm.mission, 'Help people');

    expect(await vm.saveGender(1), isTrue);
    expect(vm.gender, 1);
  });

  test('saveGender rejects an invalid value', () async {
    await vm.loadProfile();
    expect(await vm.saveGender(9), isFalse);
    expect(vm.gender, 0);
  });

  test('deleteAccount clears the cached profile', () async {
    await vm.loadProfile();
    expect(await vm.deleteAccount(), isTrue);
    expect(vm.userName, isEmpty);
    expect(vm.email, isEmpty);
  });

  test('logout clears local profile storage and in-memory user', () async {
    await vm.loadProfile();
    expect(vm.userName, 'Ada');

    await vm.logout();

    expect(vm.userName, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(UserService.prefsKey), isNull);
  });
}
