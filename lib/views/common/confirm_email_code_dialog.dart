import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import 'app_alert_dialog.dart';

/// Collects a 6-digit email verification code and runs [onSubmit].
///
/// [onSubmit] should call the backend (signup / password change). Return `null`
/// on success, or an error message to keep the dialog open. Validation of the
/// code value is server-side (hashed); the dialog only checks 6-digit shape.
///
/// Returns `true` when [onSubmit] succeeds, or `false` if the user cancels.
Future<bool> showConfirmEmailCodeDialog({
  required BuildContext context,
  required Future<String?> Function(int code) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmEmailCodeDialog(onSubmit: onSubmit),
  );
  return result ?? false;
}

class _ConfirmEmailCodeDialog extends StatefulWidget {
  const _ConfirmEmailCodeDialog({required this.onSubmit});

  final Future<String?> Function(int code) onSubmit;

  @override
  State<_ConfirmEmailCodeDialog> createState() =>
      _ConfirmEmailCodeDialogState();
}

class _ConfirmEmailCodeDialogState extends State<_ConfirmEmailCodeDialog> {
  final _codeController = TextEditingController();
  String? _localError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    if (_isSubmitting) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _codeController.text = digits.length > 6
          ? digits.substring(0, 6)
          : digits;
      _codeController.selection = TextSelection.collapsed(
        offset: _codeController.text.length,
      );
      _localError = null;
    });
  }

  Future<void> _confirm(AppLocalizations l10n) async {
    if (_isSubmitting) return;
    final enteredCode = int.tryParse(
      _codeController.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (enteredCode == null || enteredCode < 100000 || enteredCode > 999999) {
      setState(() => _localError = l10n.wrongCodeError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });
    try {
      final error = await widget.onSubmit(enteredCode);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _localError = error;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localError = l10n.genericErrorOccurred;
        _isSubmitting = false;
      });
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
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: palette.textPrimary, letterSpacing: 2),
            cursorColor: palette.primary,
            decoration: InputDecoration(
              labelText: l10n.codeLabel,
              labelStyle: TextStyle(color: palette.textMuted),
              errorText: _localError,
              counterText: '',
              filled: true,
              fillColor: palette.softBg,
              suffixIcon: _isSubmitting
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: l10n.pasteCodeTooltip,
                      onPressed: _pasteFromClipboard,
                      icon: Icon(
                        Icons.content_paste_rounded,
                        color: palette.primary,
                      ),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: palette.textMuted),
          child: Text(l10n.cancelButton),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _confirm(l10n),
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
