import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/app_benefits_viewmodel.dart';
import 'package:principles_app/views/app_benefits_view.dart';
import 'package:provider/provider.dart';

Widget _buildWidget({
  required Locale locale,
  Future<String?> Function()? tokenReader,
}) {
  return ChangeNotifierProvider(
    create: (_) => AppBenefitsViewModel(
      AuthService(SecureStore()),
      tokenReader: tokenReader,
    ),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/': (_) => const Scaffold(body: Text('Startup root')),
      },
      home: const AppBenefitsView(),
    ),
  );
}

void main() {
  testWidgets('Prev button is hidden on first slide and visible on next', (tester) async {
    await tester.pumpWidget(_buildWidget(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appBenefitsPrevButton')), findsNothing);

    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appBenefitsPrevButton')), findsOneWidget);
  });

  testWidgets('Next button transforms to Ahead on last slide and resets when going back', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget(locale: const Locale('en')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ahead'), findsOneWidget);
    final expandedWidth = tester.getSize(find.byKey(const Key('appBenefitsNextContainer'))).width;
    expect(expandedWidth, greaterThan(120));

    await tester.tap(find.byKey(const Key('appBenefitsPrevButton')));
    await tester.pumpAndSettle();

    expect(find.text('>'), findsOneWidget);
    final collapsedWidth = tester.getSize(find.byKey(const Key('appBenefitsNextContainer'))).width;
    expect(collapsedWidth, lessThan(expandedWidth));
  });

  testWidgets('Localized strings are rendered from arb', (tester) async {
    await tester.pumpWidget(_buildWidget(locale: const Locale('uk')));
    await tester.pumpAndSettle();

    expect(find.text('ПОКРАЩ ВІДСТАЮЧІ СФЕРИ ЖИТТЯ'), findsOneWidget);
    expect(find.text('Вперед'), findsNothing);
  });
}
