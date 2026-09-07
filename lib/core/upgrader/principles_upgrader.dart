import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:upgrader/upgrader.dart';

import 'principles_upgrader_messages.dart';

/// Builds the shared [Upgrader] used by [UpgradeAlert] (Play + App Store).
///
/// Matches MAUI update UX:
/// - Ignore ≈ “Don't remind me of it again” for the offered store version
/// - Later ≈ Close (shown again on next check / resume)
/// - Update opens the store listing
Upgrader createPrinciplesUpgrader({
  required Locale locale,
  required AppLocalizations l10n,
}) {
  final isUk = locale.languageCode == 'uk';
  return Upgrader(
    // MAUI re-checks on resume; Close without ignore should show again soon.
    checkOnResume: true,
    durationUntilAlertAgain: Duration.zero,
    countryCode: isUk ? 'ua' : 'us',
    languageCode: isUk ? 'uk' : 'en',
    messages: PrinciplesUpgraderMessages(l10n),
  );
}
