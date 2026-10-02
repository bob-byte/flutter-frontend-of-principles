import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import 'app_alert_dialog.dart';

/// Themed confirmation dialog for email verification codes (signup / reset).
Future<bool> showConfirmEmailCodeDialog({
  required BuildContext context,
  required int validCode,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmEmailCodeDialog(validCode: validCode),
  );
  return result ?? false;
}

class _ConfirmEmailCodeDialog extends StatefulWidget {
  const _ConfirmEmailCodeDialog({required this.validCode});

  final int validCode;

  @override
  State<_ConfirmEmailCodeDialog> createState() =>
      _ConfirmEmailCodeDialogState();
}

class _ConfirmEmailCodeDialogState extends State<_ConfirmEmailCodeDialog> {
  final _codeController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _codeController.text = digits;
      _codeController.selection = TextSelection.collapsed(
        offset: _codeController.text.length,
      );
      _localError = null;
    });
  }

  void _confirm(AppLocalizations l10n) {
    final enteredCode = int.tryParse(
      _codeController.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (enteredCode == widget.validCode) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _localError = l10n.wrongCodeError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return AppAlertDialog(
      palette: palette,
      title: Text(
        l10n.confirmCodeTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.confirmCodeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: palette.textPrimary, letterSpacing: 2),
            cursorColor: palette.primary,
            decoration: InputDecoration(
              labelText: l10n.codeLabel,
              labelStyle: TextStyle(color: palette.textMuted),
              errorText: _localError,
              filled: true,
              fillColor: palette.softBg,
              suffixIcon: IconButton(
                tooltip: l10n.pasteCodeTooltip,
                onPressed: _pasteFromClipboard,
                icon: Icon(Icons.content_paste_rounded, color: palette.primary),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.primary),
              ),
            ),
            onSubmitted: (_) => _confirm(l10n),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: palette.textMuted),
          child: Text(l10n.cancelButton),
        ),
        ElevatedButton(
          onPressed: () => _confirm(l10n),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(l10n.confirmBtn),
        ),
      ],
    );
  }
}
