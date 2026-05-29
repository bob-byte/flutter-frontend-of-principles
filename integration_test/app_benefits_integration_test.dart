import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/app_benefits_viewmodel.dart';
import 'package:principles_app/views/app_benefits_view.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('not logged in Ahead sends user to startup root', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppBenefitsViewModel(
          AuthService(SecureStore()),
          tokenReader: () async => null,
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/': (_) => const Scaffold(body: Center(child: Text('StartupRoot'))),
            AppBenefitsView.routeName: (_) => const AppBenefitsView(),
          },
          initialRoute: AppBenefitsView.routeName,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('appBenefitsNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('StartupRoot'), findsOneWidget);
  });
}
