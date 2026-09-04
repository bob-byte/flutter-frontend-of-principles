import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/ai_chat_service.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
import 'package:principles_app/views/helper_view.dart';
import 'package:provider/provider.dart';

Widget _buildApp() {
  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(
          create: (_) =>
              HelperViewModel(AiChatService(ApiClient(SecureStore()))),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
            return GlassScaffold(
              resizeToAvoidBottomInset: true,
              extendBody: true,
              body: HelperView(
                embedded: true,
                bottomBarClearance: keyboardOpen ? 0 : 80,
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'embedded chat input drops tab-bar clearance when the keyboard is open',
    (tester) async {
      const dpr = 3.0;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = const Size(390, 844) * dpr;
      tester.view.padding = const FakeViewPadding(
        top: 47 * dpr,
        bottom: 34 * dpr,
      );
      tester.view.viewPadding = const FakeViewPadding(
        top: 47 * dpr,
        bottom: 34 * dpr,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final field = find.byType(GlassTextField);
      expect(field, findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * dpr);
      await tester.pump();

      final helperBottom = tester.getRect(find.byType(HelperView)).bottom;
      final fieldBottom = tester.getRect(field).bottom;
      expect(helperBottom - fieldBottom, lessThan(40));
    },
  );
}
