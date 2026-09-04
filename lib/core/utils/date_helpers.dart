DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime tomorrowDate({DateTime? now}) =>
    dateOnly(now ?? DateTime.now()).add(const Duration(days: 1));

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
