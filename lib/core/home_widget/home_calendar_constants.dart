/// Home-screen calendar widget contract (Android App Widget + iOS WidgetKit).
abstract final class HomeCalendarWidgetConfig {
  static const appGroupId = 'group.com.set.principles';
  static const snapshotKey = 'calendar_snapshot';

  static const urlScheme = 'principleswidget';
  static const urlHost = 'calendar';

  static const iosWidgetKind = 'CalendarWidget';
  static const androidMonthProvider =
      'com.set.principles.calendar.CalendarMonthWidgetProvider';
  static const androidWeekProvider =
      'com.set.principles.calendar.CalendarWeekWidgetProvider';
  static const androidTodayProvider =
      'com.set.principles.calendar.CalendarTodayWidgetProvider';

  /// Months before / after today included in the snapshot so arrows work offline.
  static const monthsBack = 2;
  static const monthsForward = 3;

  static const maxEventsPerMonthCell = 2;
  static const maxEventsPerWeekCell = 4;
  static const maxUpcoming = 4;
}

abstract final class HomeCalendarWidgetAction {
  static const create = 'create';
  static const day = 'day';
  static const today = 'today';
}

String homeCalendarArgbHex(int argb) {
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String homeCalendarDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? homeCalendarParseDateKey(String? raw) {
  if (raw == null || raw.length < 10) return null;
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(5, 7));
  final day = int.tryParse(raw.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

Uri homeCalendarWidgetUri({required String action, DateTime? date}) {
  return Uri(
    scheme: HomeCalendarWidgetConfig.urlScheme,
    host: HomeCalendarWidgetConfig.urlHost,
    queryParameters: {
      'action': action,
      if (date != null) 'date': homeCalendarDateKey(date),
      'homeWidget': 'true',
    },
  );
}

/// Monday-first month grid, always 6 weeks (42 days).
List<DateTime> homeCalendarMonthGrid(
  DateTime month, {
  int weekStartsOn = DateTime.monday,
}) {
  final first = DateTime(month.year, month.month, 1);
  final startOffset = (first.weekday - weekStartsOn + 7) % 7;
  final start = first.subtract(Duration(days: startOffset));
  return [for (var i = 0; i < 42; i++) start.add(Duration(days: i))];
}

List<DateTime> homeCalendarWeekDays(
  DateTime anchor, {
  int weekStartsOn = DateTime.monday,
}) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  final startOffset = (day.weekday - weekStartsOn + 7) % 7;
  final start = day.subtract(Duration(days: startOffset));
  return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
}
