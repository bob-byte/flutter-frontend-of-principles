import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = UserService(forceLocalOnly: true);
  });

  test('saveLocalUser and loadLocalUser round-trip', () async {
    await service.saveLocalUser(
      User(
        name: 'Ada',
        email: 'ada@example.com',
        mainSlogan: 'Keep going',
        mission: 'Build',
        lastModified: DateTime.utc(2026, 1, 2),
      ),
    );

    final loaded = await service.loadLocalUser();
    expect(loaded?.name, 'Ada');
    expect(loaded?.email, 'ada@example.com');
    expect(loaded?.mainSlogan, 'Keep going');
    expect(loaded?.mission, 'Build');
    expect(loaded?.lastModified, DateTime.utc(2026, 1, 2));
  });

  test('clearLocal removes cached profile', () async {
    await service.saveLocalUser(User(name: 'Ada'));
    await service.clearLocal();
    expect(await service.loadLocalUser(), isNull);
  });
}
