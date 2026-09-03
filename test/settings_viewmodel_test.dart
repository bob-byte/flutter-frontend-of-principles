import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/locale/locale_controller.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/settings_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      UserService.prefsKey: jsonEncode(
        User(
          name: 'Ada',
          email: 'ada@example.com',
          mainSlogan: 'Keep going',
          mission: 'Build tools',
        ).toJson(),
      ),
    });
    vm = SettingsViewModel(
      settingsService: SettingsService(SecureStore()),
      localeController: LocaleController(),
      userService: UserService(forceLocalOnly: true),
    );
  });

  test('loadProfile reads cached name, email, slogan and mission', () async {
    await vm.loadProfile();

    expect(vm.userName, 'Ada');
    expect(vm.email, 'ada@example.com');
    expect(vm.mainSlogan, 'Keep going');
    expect(vm.mission, 'Build tools');
  });

  test('saveUserName rejects a blank name', () async {
    await vm.loadProfile();
    expect(await vm.saveUserName('   '), isFalse);
    expect(vm.userName, 'Ada');
  });

  test('saves name, slogan and mission locally', () async {
    await vm.loadProfile();

    expect(await vm.saveUserName('Grace'), isTrue);
    expect(vm.userName, 'Grace');

    expect(await vm.saveMainSlogan('Ship it'), isTrue);
    expect(vm.mainSlogan, 'Ship it');

    expect(await vm.saveMission('Help people'), isTrue);
    expect(vm.mission, 'Help people');
  });

  test('deleteAccount clears the cached profile', () async {
    await vm.loadProfile();
    expect(await vm.deleteAccount(), isTrue);
    expect(vm.userName, isEmpty);
    expect(vm.email, isEmpty);
  });
}
