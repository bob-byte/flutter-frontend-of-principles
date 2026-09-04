import 'dart:async';

import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../core/helpers/open_notification_settings.dart';
import '../widgets/app_alert_dialog.dart';

enum DialogType { frequencyConfig, addEditGoal }

enum BottomSheetType { goalSelection, archive }

class DialogResponse {
  final bool confirmed;
  final dynamic data;

  DialogResponse({this.confirmed = false, this.data});
}

class SheetResponse {
  final bool confirmed;
  final dynamic data;

  SheetResponse({this.confirmed = false, this.data});
}

/// Flutter counterpart of MAUI [DialogService]: shows alerts via the root navigator
/// and hosts custom habit/goal dialogs and sheets.
class DialogService {
  static final DialogService _instance = DialogService._internal();
  factory DialogService() => _instance;
  DialogService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool isPopupOpen = false;
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  final Map<DialogType, Widget Function(BuildContext, dynamic)>
  _dialogBuilders = {};
  final Map<BottomSheetType, Widget Function(BuildContext, dynamic)>
  _sheetBuilders = {};

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

  void registerDialogBuilder(
    DialogType type,
    Widget Function(BuildContext, dynamic) builder,
  ) {
    _dialogBuilders[type] = builder;
  }

  void registerSheetBuilder(
    BottomSheetType type,
    Widget Function(BuildContext, dynamic) builder,
  ) {
    _sheetBuilders[type] = builder;
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
        builder: (dialogContext) => AppAlertDialog.message(
          title: title,
          message: msg,
          buttonLabel: buttonLabel,
          onDismiss: () => Navigator.of(dialogContext).pop(),
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
        builder: (dialogContext) => AppAlertDialog.confirm(
          title: title,
          message: msg,
          cancelLabel: cancel,
          confirmLabel: accept,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onConfirm: () => Navigator.of(dialogContext).pop(true),
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

  /// After notification permission is denied, asks whether to open OS settings.
  Future<void> promptOpenNotificationSettings() async {
    try {
      final open = await showConfirmAsync(
        title: l10n.notificationsDisabledTitle,
        msg: l10n.notificationsDisabledMessage,
      );
      if (!open) return;
      await openNotificationSettings();
    } on StateError {
      // Navigator or localizations are not attached (tests / early startup).
    }
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

  Future<DialogResponse?> showCustomDialog({
    required DialogType variant,
    dynamic data,
    bool barrierDismissible = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    final builder = _dialogBuilders[variant];
    if (builder == null) {
      throw Exception('Dialog builder for variant $variant is not registered.');
    }

    isPopupOpen = true;
    try {
      return await showDialog<DialogResponse>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (ctx) => builder(ctx, data),
      );
    } finally {
      isPopupOpen = false;
    }
  }

  void completeDialog(DialogResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.canPop(context)) {
      Navigator.pop(context, response);
    }
  }

  Future<SheetResponse?> showCustomSheet({
    required BottomSheetType variant,
    dynamic data,
    bool isScrollControlled = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    final builder = _sheetBuilders[variant];
    if (builder == null) {
      throw Exception('Sheet builder for variant $variant is not registered.');
    }

    return await showModalBottomSheet<SheetResponse>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => builder(ctx, data),
    );
  }

  void completeSheet(SheetResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.canPop(context)) {
      Navigator.pop(context, response);
    }
  }

  /// Shows a short toast above dialogs and sheets.
  void showToast(String message) {
    hideToast();
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => _AppToast(message: message),
    );
    _toastEntry = entry;
    overlay.insert(entry);
    _toastTimer = Timer(const Duration(seconds: 2), hideToast);
  }

  void hideToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    _toastEntry?.remove();
    _toastEntry = null;
  }
}

class _AppToast extends StatelessWidget {
  const _AppToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Material(
              key: const Key('appToast'),
              elevation: 6,
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
