import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/post_auth_navigation.dart';
import '../core/config/principles_site.dart';
import '../core/helpers/linked_text.dart';
import '../core/helpers/password_validation.dart';
import '../core/launch_data_loader.dart';
import '../core/theme/theme_controller.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import 'common/confirm_email_code_dialog.dart';
import 'common/ui_theme_switcher.dart';
import 'common/themed_lottie.dart';

import 'package:url_launcher/url_launcher.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  static const routeName = '/signup';

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _missionController = TextEditingController();
  final _sloganController = TextEditingController();

  bool _obscurePassword = true;
  int _selectedGender = 0; // 0: Male, 1: Female, 2: Other

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _missionController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  Future<void> _onRegisterPressed() async {
    final vm = context.read<SignupViewModel>();
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericErrorOccurred)));
      return;
    }

    final email = _emailController.text.trim();
    final sent = await vm.generateSignupCode(
      email,
      language: Localizations.localeOf(context).languageCode,
      genericError: l10n.genericErrorOccurred,
      emailAlreadyExistsError: l10n.errorEmailAlreadyExists,
    );

    if (!mounted) return;
    if (sent) {
      await _showConfirmCodePopup();
    }
  }

  Future<void> _showConfirmCodePopup() async {
    final vm = context.read<SignupViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    final success = await showConfirmEmailCodeDialog(
      context: context,
      onSubmit: (code) async {
        final ok = await vm.register(
          name: _nameController.text,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          gender: _selectedGender,
          code: code,
          mission: _missionController.text.isEmpty
              ? null
              : _missionController.text,
          slogan: _sloganController.text.isEmpty
              ? null
              : _sloganController.text,
          genericError: l10n.genericErrorOccurred,
          emailAlreadyExistsError: l10n.errorEmailAlreadyExists,
          wrongCodeError: l10n.wrongCodeError,
        );
        if (ok) return null;
        return vm.error ?? l10n.genericErrorOccurred;
      },
    );

    if (!mounted || !success) return;
    try {
      context.read<StartupViewModel>().markSignedIn();
    } catch (_) {}
    try {
      context.read<LaunchDataLoader>().reset();
    } catch (_) {}
    openPostAuthShell(navigator);
  }

  void _showExplanationSnackBar(String message) {
    final palette = context.read<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: palette.onPrimary)),
        backgroundColor: palette.primary,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: l10n.okButton,
          textColor: palette.onPrimary,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<SignupViewModel>();
    final palette = context.watch<ThemeController>().palette;

    return Scaffold(
      backgroundColor: palette.pageBg,
      appBar: AppBar(
        title: Text(
          l10n.startupRegisterBtn,
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
        actions: const [AppThemeSwitcher()],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      const Center(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: ThemedLottie.fire(width: 120, height: 120),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name Field
                      _CustomTextField(
                        controller: _nameController,
                        hintText: l10n.nameLabel,
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return l10n.fieldRequired;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      _CustomTextField(
                        controller: _emailController,
                        hintText: l10n.emailLabel,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
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
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      _CustomTextField(
                        controller: _passwordController,
                        hintText: l10n.passwordLabel,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.fieldRequired;
                          }
                          if (!PasswordValidation.isValidNewPassword(value)) {
                            return l10n.newPasswordIsIncorrect;
                          }
                          return null;
                        },
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
                      const SizedBox(height: 24),

                      // Gender Selector
                      Row(
                        children: [
                          Expanded(
                            child: _GenderButton(
                              text: l10n.genderMale,
                              isSelected: _selectedGender == 0,
                              onTap: () => setState(() => _selectedGender = 0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GenderButton(
                              text: l10n.genderFemale,
                              isSelected: _selectedGender == 1,
                              onTap: () => setState(() => _selectedGender = 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GenderButton(
                              text: l10n.genderOther,
                              isSelected: _selectedGender == 2,
                              onTap: () => setState(() => _selectedGender = 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                        child: Text(
                          l10n.missionLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _CustomTextField(
                        controller: _missionController,
                        hintText: l10n.optionalLabel,
                        prefixIcon: Icons.flag_outlined,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: palette.textMuted,
                          ),
                          onPressed: () =>
                              _showExplanationSnackBar(l10n.missionExplanation),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                        child: Text(
                          l10n.sloganLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _CustomTextField(
                        controller: _sloganController,
                        hintText: l10n.optionalLabel,
                        prefixIcon: Icons.assignment_outlined,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: palette.textMuted,
                          ),
                          onPressed: () => _showExplanationSnackBar(
                            l10n.mainSloganExplanation,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.error != null) ...[
                      Text(
                        vm.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Register Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: vm.isBusy ? null : _onRegisterPressed,
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
                                l10n.startupRegisterBtn,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Disclaimer
                    RichText(
                      textAlign: TextAlign.center,
                      text: linkedTextSpan(
                        text: l10n.signupDisclaimer(
                          l10n.userAgreement,
                          l10n.privacyPolicy,
                        ),
                        links: {
                          l10n.userAgreement: () => launchUrl(
                            PrinciplesSite.userAgreement(
                              context.read<ThemeController>().uiTheme,
                            ),
                          ),
                          l10n.privacyPolicy: () => launchUrl(
                            PrinciplesSite.privacyPolicy(
                              context.read<ThemeController>().uiTheme,
                            ),
                          ),
                        },
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMuted,
                        ),
                        linkStyle: TextStyle(
                          fontSize: 11,
                          color: palette.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final int maxLines;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines > 1;

    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: obscureText
          ? TextCapitalization.none
          : textCapitalization,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      maxLines: isMultiline ? null : maxLines,
      expands: isMultiline,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(prefixIcon, color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.72),
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
      ),
    );

    if (!isMultiline) return field;

    return SizedBox(height: 96, child: field);
  }
}

class _GenderButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? scheme.primary : scheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
