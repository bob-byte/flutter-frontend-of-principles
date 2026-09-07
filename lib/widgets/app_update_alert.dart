import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../core/network/network_service.dart';
import '../core/upgrader/principles_upgrader.dart';

/// Store update prompt (package `upgrader`), deferred until the splash ends.
///
/// Skipped in debug (MAUI [IsDebug]), on web, and under widget tests.
class AppUpdateAlert extends StatefulWidget {
  const AppUpdateAlert({super.key, required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<AppUpdateAlert> createState() => _AppUpdateAlertState();
}

class _AppUpdateAlertState extends State<AppUpdateAlert> {
  Upgrader? _upgrader;
  String? _messagesLanguage;

  bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  bool get _enabled => !kIsWeb && !kDebugMode && !_inWidgetTest;

  Upgrader _upgraderFor(Locale locale, AppLocalizations l10n) {
    final language = locale.languageCode == 'uk' ? 'uk' : 'en';
    if (_upgrader != null && _messagesLanguage == language) {
      return _upgrader!;
    }
    _upgrader?.dispose();
    _messagesLanguage = language;
    return _upgrader = createPrinciplesUpgrader(locale: locale, l10n: l10n);
  }

  @override
  void dispose() {
    _upgrader?.dispose();
    _upgrader = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    return Consumer<NetworkService>(
      builder: (context, network, _) {
        if (!network.isSplashFinished) return widget.child;

        final l10n = AppLocalizations.of(context);
        if (l10n == null) return widget.child;

        final locale = Localizations.localeOf(context);
        return UpgradeAlert(
          upgrader: _upgraderFor(locale, l10n),
          navigatorKey: widget.navigatorKey,
          showPrompt: false,
          showIgnore: true,
          showLater: true,
          showReleaseNotes: true,
          child: widget.child,
        );
      },
    );
  }
}

