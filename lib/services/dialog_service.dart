import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';

/// Flutter counterpart of MAUI [DialogService]: shows alerts via the root navigator.
class DialogService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool isPopupOpen = false;

  BuildContext get _context {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw StateError('DialogService navigator is not attached.');
    }
    return context;
  }

  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(_context);
    if (localizations == null) {
      throw StateError('AppLocalizations are not available on the navigator.');
    }
    return localizations;
  }

  Future<void> showAlertAsync({
    required String msg,
    required String title,
    required String buttonLabel,
  }) async {
    isPopupOpen = true;
    try {
      final context = _context;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(buttonLabel),
            ),
          ],
        ),
      );
    } finally {
      isPopupOpen = false;
    }
  }

  Future<void> showErrorAsync(String msg) {
    return showAlertAsync(
      msg: msg,
      title: l10n.errorTitle,
      buttonLabel: l10n.okButton,
    );
  }

  Future<bool> showAlertWithTwoBtnsAsync({
    required String msg,
    required String title,
    required String accept,
    required String cancel,
  }) async {
    isPopupOpen = true;
    try {
      final context = _context;
      if (!context.mounted) return false;
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(accept),
            ),
          ],
        ),
      );
      return result ?? false;
    } finally {
      isPopupOpen = false;
    }
  }

  Future<bool> showConfirmAsync({required String msg, required String title}) {
    return showAlertWithTwoBtnsAsync(
      msg: msg,
      title: title,
      accept: l10n.yesButton,
      cancel: l10n.noButton,
    );
  }

  Future<T?> showPopupAsync<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    isPopupOpen = true;
    try {
      final context = _context;
      if (!context.mounted) return null;
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    } finally {
      isPopupOpen = false;
    }
  }

  Future<void> closePopupAsync([Object? result]) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
    isPopupOpen = false;
  }
}
