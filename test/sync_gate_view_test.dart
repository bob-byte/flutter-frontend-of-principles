import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
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
  testWidgets('loading gate shows fire Lottie and Loading content...', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SyncGateView()));

    expect(find.byType(Lottie), findsOneWidget);
    expect(find.text('Loading content...'), findsOneWidget);
    expect(find.text('Restore reminders'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });
}
