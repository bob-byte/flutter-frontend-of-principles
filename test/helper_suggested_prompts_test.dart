import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/road_guide/main_shell_controller.dart';
import 'package:principles_app/core/road_guide/road_guide_controller.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/ai_chat_service.dart';
import 'package:principles_app/services/ai_conversation_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
import 'package:principles_app/views/helper_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp() {
  final apiClient = ApiClient(SecureStore());
  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => MainShellController()),
        Provider(create: (_) => UserService(forceLocalOnly: true)),
        ChangeNotifierProvider(
          create: (ctx) => RoadGuideController(
            userService: ctx.read<UserService>(),
            shell: ctx.read<MainShellController>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HelperViewModel(
            AiChatService(apiClient),
            AiConversationService(apiClient: apiClient),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GlassScaffold(
          body: HelperView(embedded: true, bottomBarClearance: 0),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = true;
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  testWidgets('empty helper chat shows selectable suggested prompts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.byKey(const Key('helperSuggestedPrompts')), findsOneWidget);
    expect(find.text(l10n.helperSuggestedPromptsTitle), findsOneWidget);
    expect(find.text(l10n.helperPromptPersonality), findsOneWidget);
    expect(find.text(l10n.helperPromptNextGoal), findsOneWidget);
    expect(find.text(l10n.helperPromptStickHabits), findsOneWidget);
    expect(find.text(l10n.helperPromptPlanToday), findsOneWidget);
  });
}
