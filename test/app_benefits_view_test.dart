import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/app_benefits_viewmodel.dart';
import 'package:principles_app/views/app_benefits_view.dart';
import 'package:principles_app/views/startup_view.dart';
import 'package:provider/provider.dart';

Widget _buildWidget({
  required Locale locale,
  Future<String?> Function()? tokenReader,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(
        create: (_) => AppBenefitsViewModel(
          AuthService(SecureStore()),
          tokenReader: tokenReader,
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppBenefitsView(),
    ),
  );
}

Future<void> _usePhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _ignoreOverflowErrors() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('A RenderFlex overflowed')) return;
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
}

Future<void> _tapThroughToAhead(WidgetTester tester) async {
  await _pumpThroughTransitions(tester);

  for (var i = 0; i < 4; i++) {
    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pump(const Duration(milliseconds: 1000));
}

Future<void> _pumpThroughTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  testWidgets('Prev button is hidden on first slide and visible on next', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget(locale: const Locale('en')));
    await _pumpThroughTransitions(tester);

    expect(find.byKey(const Key('appBenefitsPrevButton')), findsNothing);

    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await _pumpThroughTransitions(tester);
    expect(find.byKey(const Key('appBenefitsPrevButton')), findsOneWidget);
  });

  testWidgets(
    'Next button transforms to Ahead on last slide and resets when going back',
    (tester) async {
      await tester.pumpWidget(_buildWidget(locale: const Locale('en')));
      await _pumpThroughTransitions(tester);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Ahead'), findsOneWidget);
      final expandedWidth = tester
          .getSize(find.byKey(const Key('appBenefitsNextContainer')))
          .width;
      expect(expandedWidth, greaterThan(120));

      final prevRect = tester.getRect(
        find.byKey(const Key('appBenefitsPrevButton')),
      );
      final nextRect = tester.getRect(
        find.byKey(const Key('appBenefitsNextButton')),
      );
      expect(prevRect.overlaps(nextRect), isFalse);
      expect(
        find.byKey(const Key('appBenefitsPrevButton')).hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('appBenefitsPrevButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final collapsedWidth = tester
          .getSize(find.byKey(const Key('appBenefitsNextContainer')))
          .width;
      expect(collapsedWidth, lessThan(expandedWidth));
    },
  );

  testWidgets('Localized strings are rendered from arb', (tester) async {
    await tester.pumpWidget(_buildWidget(locale: const Locale('uk')));
    await _pumpThroughTransitions(tester);

    expect(find.text('ПОКРАЩ ВІДСТАЮЧІ СФЕРИ ЖИТТЯ'), findsOneWidget);
    expect(find.text('Вперед'), findsNothing);
  });

  testWidgets('Ahead routes to authentication startup', (tester) async {
    _ignoreOverflowErrors();
    await _usePhoneSurface(tester);
    await tester.pumpWidget(
      _buildWidget(locale: const Locale('en'), tokenReader: () async => null),
    );
    await _tapThroughToAhead(tester);

    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(AppBenefitsView), findsNothing);
    expect(find.byType(StartupView), findsOneWidget);
  });

  testWidgets('Ahead still leaves carousel when a leftover token exists', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await _usePhoneSurface(tester);
    await tester.pumpWidget(
      _buildWidget(
        locale: const Locale('en'),
        tokenReader: () async => 'stale-token',
      ),
    );
    await _tapThroughToAhead(tester);

    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(AppBenefitsView), findsNothing);
    expect(find.byType(StartupView), findsOneWidget);
  });
}
