import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:provider/provider.dart';

DioException _dio(int status) {
  final options = RequestOptions(path: '/sync/bootstrap');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isServerTechnicalWork matches MAUI 404 and 503', () {
    expect(isServerTechnicalWork(_dio(404)), isTrue);
    expect(isServerTechnicalWork(_dio(503)), isTrue);
    expect(
      isServerTechnicalWork(
        const ServerTechnicalWorkException(statusCode: 404),
      ),
      isTrue,
    );
    expect(isServerTechnicalWork(_dio(500)), isFalse);
    expect(isServerTechnicalWork(StateError('boom')), isFalse);
    expect(isServerTechnicalWork(null), isFalse);
  });

  test('run retries 404 then succeeds', () async {
    var attempts = 0;
    var prompts = 0;
    final retry = ServerRequiredRetry(
      prompt: () async {
        prompts += 1;
        return true;
      },
    );

    final value = await retry.run(() async {
      attempts += 1;
      if (attempts == 1) throw _dio(404);
      return 'ok';
    });

    expect(value, 'ok');
    expect(attempts, 2);
    expect(prompts, 1);
  });

  test('run returns null when the user cancels', () async {
    final retry = ServerRequiredRetry(prompt: () async => false);
    final value = await retry.run(() async => throw _dio(503));
    expect(value, isNull);
  });

  test('run rethrows errors that are not 404/503', () async {
    final retry = ServerRequiredRetry(prompt: () async => true);
    expect(
      () => retry.run(() async => throw StateError('boom')),
      throwsStateError,
    );
  });

  testWidgets('offerRetry shows MAUI technical-work copy', (tester) async {
    final dialogs = DialogService();
    dialogs.isPopupOpen = false;
    addTearDown(() {
      dialogs.isPopupOpen = false;
      dialogs.hideToast();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          navigatorKey: dialogs.navigatorKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    final future = ServerRequiredRetry(dialogs: dialogs).offerRetry();
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(
      find.text(
        'Technical work on our server is in progress. Please try again later.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);
  });
}
