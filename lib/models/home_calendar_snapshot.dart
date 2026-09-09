import '../core/home_widget/home_calendar_constants.dart';

class HomeCalendarThemeSnapshot {
  const HomeCalendarThemeSnapshot({
    required this.isDark,
    required this.background,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.divider,
    required this.sunday,
    required this.todayFill,
    required this.todayText,
  });

  final bool isDark;
  final String background;
  final String text;
  final String textMuted;
  final String primary;
  final String onPrimary;
  final String divider;
  final String sunday;
  final String todayFill;
  final String todayText;

  Map<String, dynamic> toJson() => {
    'isDark': isDark,
    'background': background,
    'text': text,
    'textMuted': textMuted,
    'primary': primary,
    'onPrimary': onPrimary,
    'divider': divider,
    'sunday': sunday,
    'todayFill': todayFill,
    'todayText': todayText,
  };

  factory HomeCalendarThemeSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeCalendarThemeSnapshot(
      isDark: json['isDark'] == true,
      background: json['background'] as String? ?? '#FF121212',
      text: json['text'] as String? ?? '#FFFFFFFF',
      textMuted: json['textMuted'] as String? ?? '#80FFFFFF',
      primary: json['primary'] as String? ?? '#FFFF6B00',
      onPrimary: json['onPrimary'] as String? ?? '#FF180C06',
      divider: json['divider'] as String? ?? '#FF222222',
      sunday: json['sunday'] as String? ?? '#FFFF6B00',
      todayFill: json['todayFill'] as String? ?? '#FFFFFFFF',
      todayText: json['todayText'] as String? ?? '#FF180C06',
    );
  }
}

class HomeCalendarLabels {
  const HomeCalendarLabels({
    required this.today,
    required this.add,
    required this.empty,
    required this.monthNames,
    required this.monthNamesShort,
    required this.weekdays,
  });

  final String today;
  final String add;
  final String empty;
  final List<String> monthNames;
  final List<String> monthNamesShort;
  final List<String> weekdays;

  Map<String, dynamic> toJson() => {
    'today': today,
    'add': add,
    'empty': empty,
    'monthNames': monthNames,
    'monthNamesShort': monthNamesShort,
    'weekdays': weekdays,
  };

  factory HomeCalendarLabels.fromJson(Map<String, dynamic> json) {
    return HomeCalendarLabels(
      today: json['today'] as String? ?? 'Today',
      add: json['add'] as String? ?? 'Add',
      empty: json['empty'] as String? ?? 'No tasks or habits',
      monthNames: _stringList(json['monthNames'], _enMonths),
      monthNamesShort: _stringList(json['monthNamesShort'], _enMonthsShort),
      weekdays: _stringList(json['weekdays'], _enWeekdays),
    );
  }
}

class HomeCalendarItem {
  const HomeCalendarItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.timed,
    required this.color,
    required this.done,
  });

  final String id;
  final String kind;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool timed;
  final String color;
  final bool done;

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return !d.isBefore(a) && !d.isAfter(b);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'start': homeCalendarDateKey(start),
    'end': homeCalendarDateKey(end),
    'allDay': allDay,
    'timed': timed,
    'color': color,
    'done': done,
  };

  factory HomeCalendarItem.fromJson(Map<String, dynamic> json) {
    final start =
        homeCalendarParseDateKey(json['start'] as String?) ?? DateTime(1970);
    final end = homeCalendarParseDateKey(json['end'] as String?) ?? start;
    return HomeCalendarItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'task',
      title: json['title'] as String? ?? '',
      start: start,
      end: end.isBefore(start) ? start : end,
      allDay: json['allDay'] == true,
      timed: json['timed'] == true,
      color: json['color'] as String? ?? '#FF007BFF',
      done: json['done'] == true,
    );
  }
}

class HomeCalendarSnapshot {
  const HomeCalendarSnapshot({
    required this.locale,
    required this.today,
    required this.weekStartsOn,
    required this.theme,
    required this.labels,
    required this.items,
  });

  final String locale;
  final DateTime today;
  final int weekStartsOn;
  final HomeCalendarThemeSnapshot theme;
  final HomeCalendarLabels labels;
  final List<HomeCalendarItem> items;

  List<HomeCalendarItem> itemsOn(DateTime day) {
    final matches = items.where((item) => item.occursOn(day)).toList();
    matches.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return matches;
  }

  List<HomeCalendarItem> upcoming({
    int limit = HomeCalendarWidgetConfig.maxUpcoming,
  }) {
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 7));
    final seen = <String>{};
    final result = <HomeCalendarItem>[];
    var cursor = start;
    while (!cursor.isAfter(end) && result.length < limit) {
      for (final item in itemsOn(cursor)) {
        if (item.done) continue;
        if (!seen.add(item.id)) continue;
        result.add(item);
        if (result.length >= limit) break;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'locale': locale,
    'today': homeCalendarDateKey(today),
    'weekStartsOn': weekStartsOn,
    'theme': theme.toJson(),
    'labels': labels.toJson(),
    'items': [for (final item in items) item.toJson()],
  };

  factory HomeCalendarSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return HomeCalendarSnapshot(
      locale: json['locale'] as String? ?? 'uk',
      today:
          homeCalendarParseDateKey(json['today'] as String?) ?? DateTime(1970),
      weekStartsOn: json['weekStartsOn'] as int? ?? DateTime.monday,
      theme: HomeCalendarThemeSnapshot.fromJson(
        Map<String, dynamic>.from(json['theme'] as Map? ?? const {}),
      ),
      labels: HomeCalendarLabels.fromJson(
        Map<String, dynamic>.from(json['labels'] as Map? ?? const {}),
      ),
      items: [
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map)
              HomeCalendarItem.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

List<String> _stringList(Object? raw, List<String> fallback) {
  if (raw is! List || raw.length < fallback.length) return fallback;
  return [for (final item in raw) item.toString()];
}

const _enMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _enMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _enWeekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
