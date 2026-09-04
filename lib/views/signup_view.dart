import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/helpers/linked_text.dart';
import '../core/theme/theme_controller.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../widgets/ui_theme_switcher.dart';
import '../widgets/themed_lottie.dart';
import 'helper_view.dart';

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

  void _doRegister() async {
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

    final navigator = Navigator.of(context);
    final success = await vm.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      gender: _selectedGender,
      mission: _missionController.text.isEmpty ? null : _missionController.text,
      slogan: _sloganController.text.isEmpty ? null : _sloganController.text,
      genericError: l10n.genericErrorOccurred,
      emailAlreadyExistsError: l10n.errorEmailAlreadyExists,
    );

    if (!mounted) return;
    if (success) {
      navigator.pushReplacementNamed(HelperView.routeName);
    }
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
                          if (value == null || value.isEmpty)
                            return l10n.fieldRequired;
                          if (value.length < 6) return l10n.passwordMinLength;
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

                      // Mission
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: palette.textMuted,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Вона буде використана для створення більш доцільних для вас рекомендованих звичок. Місія - це життєва мета, яка постійно підтримує високий рівень мотивації й допомагає зробити найкращий вибір у різноманітних ситуаціях. Наприклад, місія може звучати так: “Я створюю ІТ-додатки, щоб робити світ кращим”.',
                                  style: TextStyle(color: palette.onPrimary),
                                ),
                                backgroundColor: palette.primary,
                                duration: const Duration(seconds: 10),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: palette.onPrimary,
                                  onPressed: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Slogan
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: palette.textMuted,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Основне гасло буде використано для формування кращих рекомендованих звичок. Воно допомагає визначити, як діяти, коли вам чогось не хочеться або виникають певні випробування чи спокуси. Приклад основного гасла: стосунки з Богом та сильний характер визначають якість життя.',
                                  style: TextStyle(color: palette.onPrimary),
                                ),
                                backgroundColor: palette.primary,
                                duration: const Duration(seconds: 10),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: palette.onPrimary,
                                  onPressed: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                  },
                                ),
                              ),
                            );
                          },
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
                        onPressed: vm.isBusy ? null : _doRegister,
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

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
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
