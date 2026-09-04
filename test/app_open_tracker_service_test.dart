import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/services/app_open_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 3);
  final yesterday = DateTime(2026, 9, 2);
  final twoDaysAgo = DateTime(2026, 9, 1);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first open does not record a missed day', () async {
    final tracker = AppOpenTrackerService();
    await tracker.trackAppOpen(now: today);

    expect(await tracker.getLastOpenDate(), today);
    expect(await tracker.getLastMissedDate(), isNull);
  });

  test('opening the next day keeps last missed empty', () async {
    SharedPreferences.setMockInitialValues({
      AppOpenTrackerService.lastOpenKey: '2026-09-02',
    });
    final tracker = AppOpenTrackerService();
    await tracker.trackAppOpen(now: today);

    expect(await tracker.getLastOpenDate(), today);
    expect(await tracker.getLastMissedDate(), isNull);
  });

  test('skipping a day stores yesterday as last missed', () async {
    SharedPreferences.setMockInitialValues({
      AppOpenTrackerService.lastOpenKey: '2026-09-01',
    });
    final tracker = AppOpenTrackerService();
    await tracker.trackAppOpen(now: today);

    expect(await tracker.getLastOpenDate(), today);
    expect(await tracker.getLastMissedDate(), yesterday);
  });

  test('same-day reopen does not change last missed', () async {
    SharedPreferences.setMockInitialValues({
      AppOpenTrackerService.lastOpenKey: '2026-09-03',
      AppOpenTrackerService.lastMissedKey: '2026-09-01',
    });
    final tracker = AppOpenTrackerService();
    await tracker.trackAppOpen(now: today);

    expect(await tracker.getLastOpenDate(), today);
    expect(await tracker.getLastMissedDate(), twoDaysAgo);
  });
}
