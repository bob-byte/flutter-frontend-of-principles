DateTime dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
