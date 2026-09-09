DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime tomorrowDate({DateTime? now}) =>
    dateOnly(now ?? DateTime.now()).add(const Duration(days: 1));

/// Duration until local midnight after [now] (MAUI [TimeUntilMidnight]).
Duration timeUntilMidnight([DateTime? now]) {
  final n = now ?? DateTime.now();
  final midnight = dateOnly(n).add(const Duration(days: 1));
  return midnight.difference(n);
}

/// Next whole hour on or after [now] (e.g. 19:24 → 20:00; 19:00 → 19:00).
DateTime nearestNextHour([DateTime? now]) {
  final n = now ?? DateTime.now();
  final truncated = DateTime(n.year, n.month, n.day, n.hour);
  if (!n.isAfter(truncated)) return truncated;
  return truncated.add(const Duration(hours: 1));
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String formatTaskDate(DateTime date) {
  final d = dateOnly(date);
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';
}
