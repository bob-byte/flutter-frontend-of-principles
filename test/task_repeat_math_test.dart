import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/schedule/task_repeat_math.dart';
import 'package:principles_app/models/task_repeat_config.dart';

void main() {
  final start = DateTime(2026, 9, 4, 10, 0);

  test('daily advances by interval days', () {
    final next = nextOccurrenceStart(
      fromStart: start,
      repeat: const TaskRepeatConfig(
        preset: TaskRepeatPreset.daily,
        interval: 1,
      ),
    );
    expect(next, DateTime(2026, 9, 5, 10, 0));
  });

  test('weekly friday advances to next friday', () {
    final next = nextOccurrenceStart(
      fromStart: start, // Friday
      repeat: TaskRepeatConfig.weekly(start),
    );
    expect(next!.weekday, DateTime.friday);
    expect(next, DateTime(2026, 9, 11, 10, 0));
  });

  test('weekday skip weekend', () {
    final friday = DateTime(2026, 9, 4, 11, 30);
    final next = nextOccurrenceStart(
      fromStart: friday,
      repeat: TaskRepeatConfig.everyWeekday(),
    );
    expect(next, DateTime(2026, 9, 7, 11, 30));
  });

  test('monthly keeps day of month', () {
    final next = nextOccurrenceStart(
      fromStart: start,
      repeat: TaskRepeatConfig.monthly(),
    );
    expect(next, DateTime(2026, 10, 4, 10, 0));
  });

  test('completion anchor uses completedAt', () {
    final next = nextOccurrenceStart(
      fromStart: start,
      completedAt: DateTime(2026, 9, 6, 18, 0),
      repeat: const TaskRepeatConfig(
        preset: TaskRepeatPreset.daily,
        anchor: TaskRepeatAnchor.completion,
      ),
    );
    expect(next, DateTime(2026, 9, 7, 18, 0));
  });

  test('durationBetween returns span', () {
    expect(
      durationBetween(start, DateTime(2026, 9, 4, 12, 0)),
      const Duration(hours: 2),
    );
  });
}
