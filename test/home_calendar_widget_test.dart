import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:principles_app/core/home_widget/home_calendar_builder.dart';
import 'package:principles_app/core/home_widget/home_calendar_constants.dart';
import 'package:principles_app/core/home_widget/home_widget_link.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/progress_value.dart';
import 'package:principles_app/models/task.dart';

void main() {
  final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('uk');
  });

  test('month grid is Monday-first and always 42 days', () {
    final days = homeCalendarMonthGrid(DateTime(2026, 9, 1));
    expect(days, hasLength(42));
    expect(days.first, DateTime(2026, 8, 31));
    expect(days.first.weekday, DateTime.monday);
    expect(days[8], DateTime(2026, 9, 8));
    expect(days.last, DateTime(2026, 10, 11));
  });

  test('week days start on Monday containing the anchor', () {
    final days = homeCalendarWeekDays(DateTime(2026, 9, 8));
    expect(days, hasLength(7));
    expect(days.first, DateTime(2026, 9, 7));
    expect(days.last, DateTime(2026, 9, 13));
  });

  test('parses widget deep links', () {
    final create = parseHomeWidgetLaunchUri(
      homeCalendarWidgetUri(
        action: HomeCalendarWidgetAction.create,
        date: DateTime(2026, 9, 8),
      ),
    );
    expect(create?.openCreate, isTrue);
    expect(create?.day, DateTime(2026, 9, 8));

    final day = parseHomeWidgetLaunchUri(
      homeCalendarWidgetUri(
        action: HomeCalendarWidgetAction.day,
        date: DateTime(2026, 9, 10),
      ),
    );
    expect(day?.day, DateTime(2026, 9, 10));
    expect(day?.openCreate, isFalse);

    final today = parseHomeWidgetLaunchUri(
      homeCalendarWidgetUri(action: HomeCalendarWidgetAction.today),
    );
    expect(today?.openToday, isTrue);
  });

  test('snapshot includes scheduled tasks and due habits', () {
    final snapshot = buildHomeCalendarSnapshot(
      tasks: [
        Task(
          id: '1',
          title: 'Bring keys',
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 8, 9, 30),
          theme: 'Home',
        ),
        Task(
          id: '2',
          title: 'All-day trip',
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 12),
          allDay: true,
          isDone: true,
        ),
        Task(id: '3', title: 'Inbox only', createdAt: DateTime(2026, 9, 1)),
      ],
      themeColors: {'Home': 0xFF007BFF},
      habits: [
        Habit(
          id: 7,
          name: 'Morning run',
          frequency: const FrequencyConfig(type: FrequencyType.daily),
        ),
      ],
      records: [
        HabitRecord(
          habitId: 7,
          date: DateTime(2026, 9, 8),
          status: HabitStatus.completed,
        ),
      ],
      palette: palette,
      locale: const Locale('en'),
      now: DateTime(2026, 9, 8),
    );

    expect(snapshot.today, DateTime(2026, 9, 8));
    expect(snapshot.labels.weekdays, hasLength(7));
    expect(snapshot.labels.today, 'Today');

    final onEighth = snapshot.itemsOn(DateTime(2026, 9, 8));
    expect(
      onEighth.map((i) => i.title),
      containsAll(['Bring keys', 'Morning run']),
    );
    expect(onEighth.firstWhere((i) => i.title == 'Bring keys').timed, isTrue);
    expect(onEighth.firstWhere((i) => i.title == 'Morning run').done, isTrue);

    final tripDays = [
      for (final day in [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 12),
      ])
        snapshot.itemsOn(day).any((i) => i.title == 'All-day trip'),
    ];
    expect(tripDays, [true, true, true]);
    expect(snapshot.items.any((i) => i.title == 'Inbox only'), isFalse);
  });

  test('upcoming prefers incomplete items from today onward', () {
    final snapshot = buildHomeCalendarSnapshot(
      tasks: [
        Task(
          id: 'done',
          title: 'Done today',
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 8),
          isDone: true,
        ),
        Task(
          id: 'later',
          title: 'Tomorrow call',
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 9, 11),
        ),
      ],
      themeColors: const {},
      habits: const [],
      records: const [],
      palette: palette,
      locale: const Locale('uk'),
      now: DateTime(2026, 9, 8),
    );

    expect(snapshot.labels.today, 'Сьогодні');
    expect(snapshot.upcoming().map((i) => i.title), ['Tomorrow call']);
  });
}
