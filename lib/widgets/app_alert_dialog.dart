import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import 'app_logo.dart';

TasksUiPalette appAlertPaletteOf(
  BuildContext context, [
  TasksUiPalette? override,
]) {
  if (override != null) return override;
  try {
    return Provider.of<ThemeController>(context).palette;
  } on ProviderNotFoundException {
    return TasksUiPalette.of(TasksUiTheme.darkOrange);
  }
}

/// Branded [AlertDialog] with the current theme's app icon.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.actionsAlignment,
    this.contentPadding,
    this.insetPadding,
    this.scrollable = false,
    this.iconSize = 72,
    this.showLogo = true,
    this.palette,
  });

  factory AppAlertDialog.message({
    Key? key,
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onDismiss,
    TasksUiPalette? palette,
  }) {
    return AppAlertDialog(
      key: key,
      palette: palette,
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(buttonLabel, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  factory AppAlertDialog.confirm({
    Key? key,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    TasksUiPalette? palette,
  }) {
    return AppAlertDialog(
      key: key,
      palette: palette,
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(cancelLabel, style: const TextStyle(fontSize: 16)),
        ),
        const _ConfirmActionDivider(),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            confirmLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final MainAxisAlignment? actionsAlignment;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsets? insetPadding;
  final bool scrollable;
  final double iconSize;
  final bool showLogo;
  final TasksUiPalette? palette;

  @override
  Widget build(BuildContext context) {
    final resolvedPalette = appAlertPaletteOf(context, palette);

    return Theme(
      data: resolvedPalette.toThemeData(),
      child: AlertDialog(
        backgroundColor: resolvedPalette.cardBg,
        surfaceTintColor: Colors.transparent,
        title: showLogo
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLogo(key: const Key('appAlertLogo'), size: iconSize),
                  if (title != null) ...[
                    const SizedBox(height: 12),
                    DefaultTextStyle.merge(
                      textAlign: TextAlign.center,
                      child: title!,
                    ),
                  ],
                ],
              )
            : title,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: content,
        contentPadding:
            contentPadding ?? const EdgeInsets.fromLTRB(24, 12, 24, 8),
        insetPadding:
            insetPadding ??
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        scrollable: scrollable,
        actions: actions,
        actionsAlignment: actionsAlignment ?? MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: resolvedPalette.primary.withValues(
              alpha: resolvedPalette.isDark ? 0.35 : 0.22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmActionDivider extends StatelessWidget {
  const _ConfirmActionDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: VerticalDivider(color: Theme.of(context).colorScheme.outline),
    );
  }
}

Future<void> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onConfirm,
  TasksUiPalette? palette,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppAlertDialog.confirm(
      palette: palette,
      title: title,
      message: message,
      cancelLabel: l10n.noButton,
      confirmLabel: l10n.yesButton,
      onCancel: () => Navigator.pop(ctx),
      onConfirm: () {
        Navigator.pop(ctx);
        onConfirm();
      },
    ),
  );
}
