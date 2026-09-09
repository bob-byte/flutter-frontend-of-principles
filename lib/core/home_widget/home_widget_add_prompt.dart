import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../../widgets/app_alert_dialog.dart';
import '../helpers/open_notification_settings.dart';
import 'home_calendar_constants.dart';

/// Opens how-to instructions, and on supported Android launchers offers pin.
Future<void> showAddHomeCalendarWidgetPrompt(BuildContext context) async {
  if (kIsWeb) return;
  final l10n = AppLocalizations.of(context)!;
  final canPin =
      defaultTargetPlatform == TargetPlatform.android &&
      (await HomeWidget.isRequestPinWidgetSupported() ?? false);
  if (!context.mounted) return;

  final message = defaultTargetPlatform == TargetPlatform.iOS
      ? l10n.calendarWidgetHowToIos
      : l10n.calendarWidgetHowToAndroid;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AppAlertDialog(
        title: Text(
          l10n.calendarWidgetSettingsTitle,
          textAlign: TextAlign.center,
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (canPin)
            TextButton(
              key: const Key('calendarWidgetPinButton'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _requestPinMonthCalendarWidget();
              },
              child: Text(
                l10n.calendarWidgetAddToHome,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          TextButton(
            key: const Key('calendarWidgetHowToOkButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.okButton, style: const TextStyle(fontSize: 16)),
          ),
        ],
      );
    },
  );
}

/// Pins with a filled static preview; falls back to the plugin pin API.
Future<void> _requestPinMonthCalendarWidget() async {
  try {
    final pinned = await notificationSettingsChannel.invokeMethod<bool>(
      'requestPinCalendarWidget',
    );
    if (pinned == true) return;
  } on MissingPluginException {
    // Tests / unsupported embeds — try plugin path below.
  } catch (e) {
    debugPrint('Native pin calendar widget failed: $e');
  }
  try {
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: HomeCalendarWidgetConfig.androidMonthProvider,
    );
  } on MissingPluginException {
    // Tests / unsupported embeds.
  } catch (e) {
    debugPrint('Pin calendar widget failed: $e');
  }
}

/// True when Settings should show the home-screen calendar entry.
bool showHomeCalendarWidgetSettingsEntry() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
