import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/widgets/habit_context_menu.dart';
import 'package:principles_app/widgets/habit_task_tile.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('long-pressing a habit tile opens the habit context menu', (
    tester,
  ) async {
    final habit = Habit(id: 1, name: 'Train');
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            HabitProgressViewModel(HabitService(AuthService(SecureStore()))),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final vm = context.read<HabitProgressViewModel>();
              return Scaffold(
                body: HabitTaskTile(
                  key: const Key('habitTaskTile-1'),
                  habit: habit,
                  palette: palette,
                  isCompleted: false,
                  onTap: () {},
                  onToggle: () {},
                  onLongPress: (anchor) {
                    showHabitContextMenu(
                      context: context,
                      habit: habit,
                      vm: vm,
                      palette: palette,
                      anchor: anchor,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('habitTaskTile-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('habitContextMenu')), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Details')).dy,
      greaterThan(tester.getTopLeft(find.text('Edit')).dy),
    );
  });
}
