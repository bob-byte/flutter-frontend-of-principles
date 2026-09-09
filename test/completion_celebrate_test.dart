import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/l10n/task_strings.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/completion_feedback.dart';
import 'package:principles_app/widgets/completion_burst.dart';
import 'package:principles_app/widgets/completion_check.dart';
import 'package:principles_app/widgets/task_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completion feedback skips audio under the widget test binding', () {
    expect(CompletionFeedback.instance.skipAudio, isTrue);
  });

  test('completion feedback play is a no-op in tests', () async {
    await CompletionFeedback.instance.play();
  });

  test('burst painter repaints when progress or color changes', () {
    const color = Color(0xFFFF8A00);
    final painter = CompletionBurstPainter(progress: 0.4, color: color);
    expect(
      painter.shouldRepaint(
        CompletionBurstPainter(progress: 0.5, color: color),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        CompletionBurstPainter(progress: 0.4, color: Colors.blue),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        CompletionBurstPainter(progress: 0.4, color: color),
      ),
      isFalse,
    );
  });

  test('check stroke painter repaints when progress changes', () {
    const color = Colors.white;
    final painter = CompletionCheckStrokePainter(progress: 0.4, color: color);
    expect(
      painter.shouldRepaint(
        CompletionCheckStrokePainter(progress: 0.9, color: color),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        CompletionCheckStrokePainter(progress: 0.4, color: color),
      ),
      isFalse,
    );
  });

  testWidgets('celebrate scales only after incomplete becomes complete', (
    tester,
  ) async {
    Future<void> pumpDone(bool done) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompletionCelebrate(
                isCompleted: done,
                color: Colors.orange,
                child: const SizedBox(width: 26, height: 26),
              ),
            ),
          ),
        ),
      );
    }

    await pumpDone(true);
    await tester.pump();
    expect(_scaleOf(tester), closeTo(1, 0.01));

    await pumpDone(false);
    await tester.pump();
    await pumpDone(true);
    await tester.pump(const Duration(milliseconds: 90));
    expect(_scaleOf(tester), greaterThan(1.05));
  });

  testWidgets('completion check shows a checkmark when done', (tester) async {
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CompletionCheck(isDone: true, palette: palette)),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('task tile still exposes the subtask toggle', (tester) async {
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);
    final toggled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskTile(
            task: Task(
              id: '1',
              title: 'Shop',
              createdAt: DateTime(2026, 1, 1),
              subtasks: const [],
            ),
            palette: palette,
            themeColor: palette.primary,
            strings: TaskStrings.en,
            onTap: () {},
            onToggle: () {},
            onToggleSubtask: toggled.add,
          ),
        ),
      ),
    );
    expect(find.byType(CompletionCheck), findsOneWidget);
  });

  testWidgets('held completion keeps title active and overdue chrome', (
    tester,
  ) async {
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskTile(
            task: Task(
              id: '1',
              title: 'Overdue shop',
              isDone: true,
              createdAt: DateTime(2026, 1, 1),
              dueDate: yesterday,
            ),
            palette: palette,
            themeColor: palette.primary,
            strings: TaskStrings.en,
            keepActiveAppearance: true,
            onTap: () {},
            onToggle: () {},
            onMoveToToday: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Overdue shop'));
    expect(title.style?.decoration, isNot(TextDecoration.lineThrough));
    expect(title.style?.color, palette.textPrimary);
    expect(find.textContaining('Overdue ·'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}

double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byType(CompletionCelebrate),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.getMaxScaleOnAxis();
}
