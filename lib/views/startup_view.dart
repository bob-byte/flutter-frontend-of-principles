import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/startup_viewmodel.dart';
import 'app_benefits_view.dart';
import 'helper_view.dart';
import 'login_view.dart';
import 'signup_view.dart';

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  static const routeName = '/';

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<StartupViewModel>();
      try {
        final nextRoute = await vm.initialize();
        if (!mounted) return;
        switch (nextRoute) {
          case StartupNextRoute.helper:
            Navigator.of(context).pushReplacementNamed(HelperView.routeName);
            break;
          case StartupNextRoute.appBenefits:
            Navigator.of(context).pushReplacementNamed(AppBenefitsView.routeName);
            break;
          case StartupNextRoute.login:
            setState(() {
              _isChecking = false;
            });
            break;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isChecking = false; // Show the view even if initialization fails
        });
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.genericErrorOccurred),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleAuth() async {
    final vm = context.read<StartupViewModel>();
    final success = await vm.continueWithGoogleAsync();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(HelperView.routeName);
    } else if (vm.errorMessage != null) {
      _showErrorDialog(vm.errorMessage!);
    } else {
      _showErrorDialog(AppLocalizations.of(context)!.startupErrorGeneric);
    }
  }

  Future<void> _handleAppleAuth() async {
    final vm = context.read<StartupViewModel>();
    final success = await vm.continueWithAppleAsync();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(HelperView.routeName);
    } else if (vm.errorMessage != null) {
      // Prompt said: "Не показувати помилку, якщо скасування відбулося самим користувачем."
      // Since we don't have the exact error string for cancellation, we will just show it for now
      // unless it contains 'canceled' or 'cancelled'.
      final msg = vm.errorMessage!.toLowerCase();
      if (!msg.contains('cancel')) {
        _showErrorDialog(vm.errorMessage!);
      }
    } else {
      _showErrorDialog(AppLocalizations.of(context)!.startupErrorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (2.5* equivalent in XAML - taking remaining space)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animation with RadialGradient background
                    Container(
                      width: 320,
                      height: 320,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xEEFFFFFF),
                            Color(0x523D7FFF),
                            Color(0xB63D7FFF),
                            Color(0x623D7FFF),
                            Color(0x12E3F9FF),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                      child: Lottie.asset(
                        'assets/lottie/blue_fire_loading.json',
                        width: 200,
                        height: 200,
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title Text
                    Text(
                      l10n.startupTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // Bottom Section (Auto equivalent in XAML)
            Padding(
              padding: const EdgeInsets.only(left: 30, right: 30, bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Google Button
                  _AuthButton(
                    text: l10n.startupGoogleBtn,
                    icon: SvgPicture.string(
                      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/><path fill="none" d="M0 0h48v48H0z"/></svg>''',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    isPrimary: true,
                    onPressed: _handleGoogleAuth,
                  ),
                  const SizedBox(height: 15),
                  
                  // Apple Button
                  _AuthButton(
                    text: l10n.startupAppleBtn,
                    icon: const Icon(Icons.apple, color: Colors.white, size: 28),
                    isPrimary: true,
                    onPressed: _handleAppleAuth,
                  ),
                  const SizedBox(height: 15),
                  
                  // Register Button
                  _AuthButton(
                    text: l10n.startupRegisterBtn,
                    icon: const Icon(Icons.email_outlined, color: Colors.white, size: 24),
                    isPrimary: true,
                    onPressed: () {
                      Navigator.of(context).pushNamed(SignupView.routeName);
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  // Login Button
                  _AuthButton(
                    text: l10n.startupLoginBtn,
                    isPrimary: false,
                    onPressed: () {
                      Navigator.of(context).pushNamed(LoginView.routeName);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String text;
  final Widget? icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.text,
    this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? const Color(0xFF3B82F6) : Colors.transparent;
    final textColor = isPrimary ? Colors.white : const Color(0xFF3B82F6);
    final borderColor = const Color(0xFF3B82F6);

    return SizedBox(
      height: 50, // Fixed height per requirements
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25), // Radius ~25
                ),
              ),
              child: _buildContent(),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor, width: 2), // border thickness 2
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25), // Radius ~25
                ),
              ),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
