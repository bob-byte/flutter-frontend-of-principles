import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/upgrader/principles_upgrader.dart';
import 'package:principles_app/core/upgrader/principles_upgrader_messages.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/l10n/app_localizations_en.dart';
import 'package:principles_app/l10n/app_localizations_uk.dart';
import 'package:upgrader/upgrader.dart';

void main() {
  group('PrinciplesUpgraderMessages', () {
    test('English matches MAUI update popup copy', () {
      final messages = PrinciplesUpgraderMessages(AppLocalizationsEn());
      expect(messages.message(UpgraderMessage.title), 'Update Available');
      expect(messages.message(UpgraderMessage.buttonTitleUpdate), 'Update');
      expect(messages.message(UpgraderMessage.buttonTitleLater), 'Close');
      expect(
        messages.message(UpgraderMessage.buttonTitleIgnore),
        "Don't remind me of it again",
      );
    });

    test('Ukrainian matches MAUI update popup copy', () {
      final messages = PrinciplesUpgraderMessages(AppLocalizationsUk());
      expect(messages.message(UpgraderMessage.title), 'Доступне оновлення');
      expect(messages.message(UpgraderMessage.buttonTitleUpdate), 'Оновити');
      expect(messages.message(UpgraderMessage.buttonTitleLater), 'Закрити');
      expect(
        messages.message(UpgraderMessage.buttonTitleIgnore),
        'Не нагадувати більше про це',
      );
    });
  });

  group('createPrinciplesUpgrader', () {
    test('uses UA store country for Ukrainian locale', () {
      final upgrader = createPrinciplesUpgrader(
        locale: const Locale('uk', 'UA'),
        l10n: AppLocalizationsUk(),
      );
      expect(upgrader.state.countryCodeOverride, 'ua');
      expect(upgrader.state.languageCodeOverride, 'uk');
      expect(upgrader.state.durationUntilAlertAgain, Duration.zero);
    });

    test('uses US store country for English locale', () {
      final upgrader = createPrinciplesUpgrader(
        locale: const Locale('en'),
        l10n: AppLocalizationsEn(),
      );
      expect(upgrader.state.countryCodeOverride, 'us');
      expect(upgrader.state.languageCodeOverride, 'en');
    });
  });

  testWidgets('AppLocalizations expose update strings', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(l10n.appUpdateAvailable, 'Update Available');
    expect(l10n.updateButton, 'Update');
  });
}
