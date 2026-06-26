import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/signup_viewmodel.dart';
import 'helper_view.dart';

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
    
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericErrorOccurred)),
      );
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.startupRegisterBtn,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3B82F6)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Lottie.asset(
                    'assets/lottie/blue_fire_loading.json',
                    repeat: true,
                    animate: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Name Field
              _CustomTextField(
                controller: _nameController,
                hintText: l10n.nameLabel,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              // Email Field
              _CustomTextField(
                controller: _emailController,
                hintText: l10n.emailLabel,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password Field
              _CustomTextField(
                controller: _passwordController,
                hintText: l10n.passwordLabel,
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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
                  Expanded(child: _GenderButton(text: l10n.genderMale, isSelected: _selectedGender == 0, onTap: () => setState(() => _selectedGender = 0))),
                  const SizedBox(width: 8),
                  Expanded(child: _GenderButton(text: l10n.genderFemale, isSelected: _selectedGender == 1, onTap: () => setState(() => _selectedGender = 1))),
                  const SizedBox(width: 8),
                  Expanded(child: _GenderButton(text: l10n.genderOther, isSelected: _selectedGender == 2, onTap: () => setState(() => _selectedGender = 2))),
                ],
              ),
              const SizedBox(height: 24),

              // Mission
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                child: Text(l10n.missionLabel, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              _CustomTextField(
                controller: _missionController,
                hintText: l10n.optionalLabel,
                prefixIcon: Icons.flag_outlined,
                suffixIcon: const Icon(Icons.info_outline, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Slogan
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                child: Text(l10n.sloganLabel, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              _CustomTextField(
                controller: _sloganController,
                hintText: l10n.optionalLabel,
                prefixIcon: Icons.assignment_outlined,
                suffixIcon: const Icon(Icons.info_outline, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              if (vm.error != null) ...[
                Text(vm.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],

              // Register Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: vm.isBusy ? null : _doRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: vm.isBusy
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(l10n.startupRegisterBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // Disclaimer
              Text(
                l10n.signupDisclaimer,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 24),
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

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(prefixIcon, color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF5F6F8),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
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
