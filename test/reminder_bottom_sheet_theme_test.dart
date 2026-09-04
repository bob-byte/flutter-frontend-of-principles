import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/views/widgets/reminder_bottom_sheet.dart';
import 'package:provider/provider.dart';

class _FixedThemeController extends ThemeController {
  _FixedThemeController(this.selectedTheme);

  final TasksUiTheme selectedTheme;

  @override
  TasksUiTheme get uiTheme => selectedTheme;

  @override
  TasksUiPalette get palette => TasksUiPalette.of(selectedTheme);

  @override
  ThemeData get theme => palette.toThemeData();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final uiTheme in TasksUiTheme.values) {
    testWidgets('reminder sheet follows ${uiTheme.name} theme', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FixedThemeController(uiTheme);
      final palette = TasksUiPalette.of(uiTheme);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeController>.value(
          value: controller,
          child: MaterialApp(
            theme: controller.theme,
            home: Scaffold(
              body: ReminderBottomSheet(habit: Habit(name: 'Read')),
            ),
          ),
        ),
      );
      await tester.pump();

      final surface = tester.widget<Material>(
        find.byKey(const Key('reminderSheetSurface')),
      );
      expect(surface.color, palette.cardBg, reason: uiTheme.name);

      final title = tester.widget<Text>(find.text('Нагадування'));
      expect(title.style?.color, palette.textPrimary, reason: uiTheme.name);

      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.style?.color, palette.textPrimary, reason: uiTheme.name);
        expect(field.cursorColor, palette.primary, reason: uiTheme.name);
      }

      final enabledSwitch = tester.widget<Switch>(
        find.byKey(const Key('reminderEnabledSwitch')),
      );
      expect(
        enabledSwitch.activeTrackColor,
        palette.primary,
        reason: uiTheme.name,
      );
      expect(
        enabledSwitch.activeThumbColor,
        palette.onPrimary,
        reason: uiTheme.name,
      );

      final firstDayFinder = find.byKey(const Key('reminderDay1'));
      expect(
        tester.widget<CircleAvatar>(firstDayFinder).backgroundColor,
        palette.primary.withValues(alpha: palette.isDark ? 0.12 : 0.10),
        reason: uiTheme.name,
      );
      await tester.tap(firstDayFinder);
      await tester.pump();
      expect(
        tester.widget<CircleAvatar>(firstDayFinder).backgroundColor,
        palette.primary,
        reason: uiTheme.name,
      );
      expect(
        tester.widget<Text>(find.text('Пн')).style?.color,
        palette.onPrimary,
        reason: uiTheme.name,
      );

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('reminderSaveButton')),
      );
      expect(
        saveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        palette.primary,
        reason: uiTheme.name,
      );
      expect(
        saveButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        palette.onPrimary,
        reason: uiTheme.name,
      );

      final cancelButton = tester.widget<TextButton>(
        find.byKey(const Key('reminderCancelButton')),
      );
      expect(
        cancelButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        palette.textPrimary,
        reason: uiTheme.name,
      );
    });
  }
}
