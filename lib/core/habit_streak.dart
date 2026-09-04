import '../models/habit_record.dart';
import '../models/progress_value.dart';
import 'utils/date_helpers.dart';

/// MAUI [UserHabitsToStreakConverter].
///
/// Groups each habit's progress by day (including UNKNOWN placeholders for
/// the last [kNumberOfDaysInProgress] days, matching
/// [ServiceOfHabit.InitializeHabitProgresses]). Days on or before
/// [lastMissedAppOpen] are ignored. A day whose values are all UNKNOWN or NO
/// resets the counter; otherwise the count of YES_MANUAL marks is added.
int calculateUserHabitsStreak({
  required Iterable<int> habitIds,
  required List<HabitRecord> records,
  DateTime? lastMissedAppOpen,
  DateTime? now,
}) {
  final ids = habitIds.toSet();
  if (ids.isEmpty) return 0;

  final lastMissed = lastMissedAppOpen == null
      ? null
      : dateOnly(lastMissedAppOpen);
  final progressesByDate = <DateTime, List<int>>{};
  final habitIdsByDate = <DateTime, Set<int>>{};

  for (final record in records) {
    if (!ids.contains(record.habitId)) continue;
    final date = dateOnly(record.date);
    if (!_isAfterLastMissed(date, lastMissed)) continue;
    progressesByDate.putIfAbsent(date, () => []).add(record.value);
    habitIdsByDate.putIfAbsent(date, () => {}).add(record.habitId);
  }

  final today = dateOnly(now ?? DateTime.now());
  for (var offset = 0; offset < kNumberOfDaysInProgress; offset++) {
    final date = today.subtract(Duration(days: offset));
    if (!_isAfterLastMissed(date, lastMissed)) continue;
    final present = habitIdsByDate[date] ?? const <int>{};
    for (final id in ids) {
      if (present.contains(id)) continue;
      progressesByDate.putIfAbsent(date, () => []).add(kProgressUnknown);
    }
  }

  var streak = 0;
  final sortedDates = progressesByDate.keys.toList()..sort();

  for (final date in sortedDates) {
    final values = progressesByDate[date];
    if (values == null || values.isEmpty) continue;

    if (values.every((v) => v == kProgressUnknown || v == kProgressNo)) {
      streak = 0;
    } else {
      streak += values.where((v) => v == kProgressYesManual).length;
    }
  }

  return streak;
}

bool _isAfterLastMissed(DateTime date, DateTime? lastMissed) {
  if (lastMissed == null) return true;
  return date.isAfter(lastMissed);
}
