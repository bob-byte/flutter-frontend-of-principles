import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/post_auth_navigation.dart';
import '../core/helpers/linked_text.dart';
import '../core/helpers/password_validation.dart';
import '../core/launch_data_loader.dart';
import '../core/theme/theme_controller.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import 'common/confirm_email_code_dialog.dart';
import 'common/ui_theme_switcher.dart';
import 'common/themed_lottie.dart';
import 'edit_profile_text_view.dart';

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

  bool _obscurePassword = true;
  int _selectedGender = 0; // 0: Male, 1: Female, 2: Other
  String _mission = '';
  String _slogan = '';

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    final validCode = await vm.generateSignupCode(
      email,
      language: Localizations.localeOf(context).languageCode,
      genericError: l10n.genericErrorOccurred,
      emailAlreadyExistsError: l10n.errorEmailAlreadyExists,
    );

    if (!mounted) return;
    if (validCode != null) {
      _showConfirmCodePopup(validCode);
    }
  }

  Future<void> _showConfirmCodePopup(int validCode) async {
    final confirmed = await showConfirmEmailCodeDialog(
      context: context,
      validCode: validCode,
    );
    if (!mounted || !confirmed) return;
    await _doRegister();
  }

  Future<void> _doRegister() async {
    final vm = context.read<SignupViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    final success = await vm.register(
      name: _nameController.text,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      gender: _selectedGender,
      mission: _mission.isEmpty ? null : _mission,
      slogan: _slogan.isEmpty ? null : _slogan,
      genericError: l10n.genericErrorOccurred,
      emailAlreadyExistsError: l10n.errorEmailAlreadyExists,
    );

    if (!mounted) return;
    if (success) {
      try {
        context.read<StartupViewModel>().markSignedIn();
      } catch (_) {}
      try {
        context.read<LaunchDataLoader>().reset();
      } catch (_) {}
      openPostAuthShell(navigator);
    }
  }

  Future<void> _editMission() async {
    final result = await EditMissionView.openDraft(
      context,
      initialText: _mission,
      gender: _selectedGender,
    );
    if (!mounted || result == null) return;
    setState(() => _mission = result);
  }

  Future<void> _editSlogan() async {
    final result = await EditSloganView.openDraft(
      context,
      initialText: _slogan,
      gender: _selectedGender,
    );
    if (!mounted || result == null) return;
    setState(() => _slogan = result);
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

                      _ProfileTextTile(
                        key: const Key('signupMissionTile'),
                        label: l10n.missionLabel,
                        value: _mission,
                        emptyLabel: l10n.optionalLabel,
                        icon: Icons.flag_outlined,
                        onTap: _editMission,
                      ),
                      const SizedBox(height: 12),
                      _ProfileTextTile(
                        key: const Key('signupSloganTile'),
                        label: l10n.sloganLabel,
                        value: _slogan,
                        emptyLabel: l10n.optionalLabel,
                        icon: Icons.assignment_outlined,
                        onTap: _editSlogan,
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
                            Uri.parse('https://principles.top/useragreement'),
                          ),
                          l10n.privacyPolicy: () => launchUrl(
                            Uri.parse('https://principles.top/privacypolicy'),
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

class _ProfileTextTile extends StatelessWidget {
  const _ProfileTextTile({
    super.key,
    required this.label,
    required this.value,
    required this.emptyLabel,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String emptyLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value.trim().isNotEmpty;
    return Material(
      color: scheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? value : emptyLabel,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: hasValue ? scheme.onSurface : Colors.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.45),
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
