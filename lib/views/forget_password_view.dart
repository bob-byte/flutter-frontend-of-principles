import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/post_auth_navigation.dart';
import '../core/helpers/password_validation.dart';
import '../core/launch_data_loader.dart';
import '../core/theme/theme_controller.dart';
import '../viewmodels/forget_password_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import 'common/app_alert_dialog.dart';
import 'common/confirm_email_code_dialog.dart';

class ForgetPasswordArgs {
  final String? initialEmail;
  final bool emailReadOnly;

  const ForgetPasswordArgs({this.initialEmail, this.emailReadOnly = false});

  static ForgetPasswordArgs fromRouteArguments(Object? arguments) {
    if (arguments is ForgetPasswordArgs) return arguments;
    if (arguments is String) {
      return ForgetPasswordArgs(initialEmail: arguments);
    }
    return const ForgetPasswordArgs();
  }
}

class ForgetPasswordView extends StatefulWidget {
  final String? initialEmail;
  final bool emailReadOnly;

  const ForgetPasswordView({
    super.key,
    this.initialEmail,
    this.emailReadOnly = false,
  });

  static const routeName = '/forget-password';

  @override
  State<ForgetPasswordView> createState() => _ForgetPasswordViewState();
}

class _ForgetPasswordViewState extends State<ForgetPasswordView> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSendCode() async {
    final vm = context.read<ForgetPasswordViewModel>();
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text;
    final newPassword = _passwordController.text;

    final validCode = await vm.generateCode(
      email,
      language: Localizations.localeOf(context).languageCode,
      genericError: l10n.genericErrorOccurred,
      emailNotRegisteredError: l10n.emailNotRegisteredError,
      mailServerError: l10n.mailServerError,
    );

    if (!mounted) return;
    if (validCode != null) {
      _showConfirmCodePopup(validCode, email, newPassword);
    }
  }

  Future<void> _showConfirmCodePopup(
    int validCode,
    String email,
    String newPassword,
  ) async {
    final confirmed = await showConfirmEmailCodeDialog(
      context: context,
      validCode: validCode,
    );
    if (!mounted || !confirmed) return;
    await _doChangePassword(email, newPassword);
  }

  Future<void> _doChangePassword(String email, String newPassword) async {
    final vm = context.read<ForgetPasswordViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    final success = await vm.changePassword(
      email,
      newPassword,
      genericError: l10n.genericErrorOccurred,
    );

    if (!mounted) return;
    if (success) {
      await showDialog(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(l10n.passwordChangedSuccess, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      try {
        context.read<StartupViewModel>().markSignedIn();
      } catch (_) {}
      try {
        context.read<LaunchDataLoader>().reset();
      } catch (_) {}
      openPostAuthShell(navigator);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<ForgetPasswordViewModel>();
    final palette = context.watch<ThemeController>().palette;

    return Scaffold(
      backgroundColor: palette.pageBg,
      appBar: AppBar(
        title: Text(
          l10n.forgotPasswordTitle,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: palette.pageBg,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.primary),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  l10n.forgotPasswordSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: palette.textPrimary),
                ),
                const SizedBox(height: 32),

                // Email Field — read-only when changing password while signed in
                TextFormField(
                  controller: _emailController,
                  readOnly: widget.emailReadOnly,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return l10n.fieldRequired;
                    if (!RegExp(
                      r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$',
                    ).hasMatch(value)) {
                      return l10n.invalidEmailFormat;
                    }
                    return null;
                  },
                  decoration: _inputDecoration(
                    l10n.emailLabel,
                    Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.fieldRequired;
                    }
                    if (!PasswordValidation.isValidNewPassword(value)) {
                      return l10n.newPasswordIsIncorrect;
                    }
                    return null;
                  },
                  decoration:
                      _inputDecoration(
                        l10n.newPasswordLabel,
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          color: Colors.grey,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 32),

                if (vm.error != null) ...[
                  Text(
                    vm.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Send Code Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: vm.isBusy ? null : _onSendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: vm.isBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            l10n.sendCodeBtn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, IconData prefixIcon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(prefixIcon, color: Colors.grey),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }
}
