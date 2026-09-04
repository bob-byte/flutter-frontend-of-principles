import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/widgets/app_alert_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(context: context, builder: (_) => dialog);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  String logoAssetOf(WidgetTester tester) {
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('appAlertLogo')),
        matching: find.byType(Image),
      ),
    );
    return (image.image as AssetImage).assetName;
  }

  test('theme logo assets match orange and blue marks', () {
    expect(TasksUiTheme.darkOrange.logoAsset, 'assets/images/orange_logo.png');
    expect(TasksUiTheme.lightOrange.logoAsset, 'assets/images/orange_logo.png');
    expect(TasksUiTheme.darkBlue.logoAsset, 'assets/images/blue_logo.png');
    expect(TasksUiTheme.lightBlue.logoAsset, 'assets/images/blue_logo.png');
  });

  testWidgets('confirm alert shows the themed app logo', (tester) async {
    await pumpDialog(
      tester,
      AppAlertDialog.confirm(
        title: 'Based on goal, mission and slogan',
        message: 'Load recommended habits?',
        cancelLabel: 'No',
        confirmLabel: 'Yes',
        onCancel: () {},
        onConfirm: () {},
      ),
    );

    expect(find.byKey(const Key('appAlertLogo')), findsOneWidget);
    expect(logoAssetOf(tester), 'assets/images/orange_logo.png');
    expect(find.text('Based on goal, mission and slogan'), findsOneWidget);
    expect(find.text('Load recommended habits?'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
  });

  testWidgets('message alert shows title, body, and dismiss action', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      AppAlertDialog.message(
        title: 'Error',
        message: 'Something went wrong.',
        buttonLabel: 'OK',
        onDismiss: () {},
      ),
    );

    expect(find.byKey(const Key('appAlertLogo')), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Something went wrong.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
