import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/views/sync_gate_view.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeController(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('loading gate shows spinner and Loading content...', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SyncGateView()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading content...'), findsOneWidget);
    expect(find.text('Restore reminders'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('restore gate shows spinner and MAUI copy', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(SyncGateView(restore: true, onRestoreAck: () => tapped = true)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restore reminders'), findsOneWidget);
    expect(
      find.text(
        'Your account has motivating reminders. They can be restore on your device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Loading content...'), findsNothing);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text('OK'));
    expect(tapped, isTrue);
  });
}
