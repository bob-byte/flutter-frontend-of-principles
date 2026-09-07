import 'package:principles_app/l10n/app_localizations.dart';
import 'package:upgrader/upgrader.dart';

/// MAUI [UpdatePopup] copy wired into [UpgraderMessages].
class PrinciplesUpgraderMessages extends UpgraderMessages {
  PrinciplesUpgraderMessages(this.l10n) : super(code: _languageCodeFor(l10n));

  final AppLocalizations l10n;

  static String _languageCodeFor(AppLocalizations l10n) {
    final code = l10n.localeName;
    if (code.startsWith('uk')) return 'uk';
    return 'en';
  }

  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.title:
        return l10n.appUpdateAvailable;
      case UpgraderMessage.buttonTitleUpdate:
        return l10n.updateButton;
      case UpgraderMessage.buttonTitleLater:
        return l10n.appUpdateCloseButton;
      case UpgraderMessage.buttonTitleIgnore:
        return l10n.dontShowUpdateCheckBoxText;
      case UpgraderMessage.body:
      case UpgraderMessage.prompt:
      case UpgraderMessage.releaseNotes:
        return super.message(messageKey);
    }
  }
}
