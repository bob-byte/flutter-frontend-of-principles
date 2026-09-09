import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/day_change_notifier.dart';
import 'package:principles_app/core/utils/date_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checkForDayChange notifies only when the calendar day advances', () {
    var now = DateTime(2026, 9, 8, 23, 50);
    final notifier = DayChangeNotifier(
      clock: () => now,
      observeLifecycle: false,
      scheduleTimer: false,
    );
    addTearDown(notifier.dispose);

    expect(notifier.today, DateTime(2026, 9, 8));

    var notifications = 0;
    notifier.addListener(() => notifications++);

    expect(notifier.checkForDayChange(), isFalse);
    expect(notifications, 0);

    now = DateTime(2026, 9, 9, 0, 1);
    expect(notifier.checkForDayChange(), isTrue);
    expect(notifier.today, DateTime(2026, 9, 9));
    expect(notifications, 1);

    expect(notifier.checkForDayChange(), isFalse);
    expect(notifications, 1);
  });

  test('didChangeAppLifecycleState resumed re-checks the day', () {
    var now = DateTime(2026, 9, 8, 10);
    final notifier = DayChangeNotifier(
      clock: () => now,
      observeLifecycle: false,
      scheduleTimer: false,
    );
    addTearDown(notifier.dispose);

    var notifications = 0;
    notifier.addListener(() => notifications++);

    now = DateTime(2026, 9, 9, 8);
    notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(notifier.today, DateTime(2026, 9, 9));
    expect(notifications, 1);
  });

  test('timeUntilMidnight matches local next midnight', () {
    final noon = DateTime(2026, 9, 8, 12);
    expect(timeUntilMidnight(noon), const Duration(hours: 12));
  });
}
