import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/views/widgets/frequency_dialog.dart';
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
    testWidgets('frequency dialog follows ${uiTheme.name} theme', (
      tester,
    ) async {
      final controller = _FixedThemeController(uiTheme);
      final palette = TasksUiPalette.of(uiTheme);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeController>.value(
          value: controller,
          child: MaterialApp(
            theme: controller.theme,
            home: const Scaffold(
              body: FrequencyDialogWidget(
                initialConfig: FrequencyConfig(type: FrequencyType.daily),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        palette.cardBg,
        reason: uiTheme.name,
      );

      for (final radio in tester.widgetList<Radio<FrequencyType>>(
        find.byType(Radio<FrequencyType>),
      )) {
        expect(radio.activeColor, palette.primary, reason: uiTheme.name);
      }

      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.style?.color, palette.textPrimary, reason: uiTheme.name);
        expect(field.cursorColor, palette.primary, reason: uiTheme.name);
      }

      final dropdown = tester.widget<DropdownButton<PeriodType>>(
        find.byKey(const Key('frequencyPeriodDropdown')),
      );
      expect(dropdown.dropdownColor, palette.cardBg, reason: uiTheme.name);
      expect(dropdown.style?.color, palette.textPrimary, reason: uiTheme.name);

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('frequencySaveButton')),
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
    });
  }
}
