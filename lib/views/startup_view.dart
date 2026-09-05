import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/launch_data_loader.dart';
import '../core/theme/theme_controller.dart';
import '../viewmodels/startup_viewmodel.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/themed_lottie.dart';
import '../widgets/ui_theme_switcher.dart';
import 'app_benefits_view.dart';
import 'helper_view.dart';
import 'login_view.dart';
import 'signup_view.dart';

class StartupView extends StatefulWidget {
  const StartupView({super.key, this.showAuthenticationImmediately = false});

  static const routeName = '/';
  final bool showAuthenticationImmediately;

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    if (widget.showAuthenticationImmediately) {
      _isChecking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          context.read<StartupViewModel>().acknowledgeAppBenefitsShown();
        } on ProviderNotFoundException {
          // Widget tests may mount StartupView without the full graph.
        }
      });
      return;
    }
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
            Navigator.of(
              context,
            ).pushReplacementNamed(AppBenefitsView.routeName);
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

  void _resetLaunchDataForPostAuth() {
    try {
      context.read<StartupViewModel>().markSignedIn();
    } on ProviderNotFoundException {
      // Widget tests may mount StartupView without the full graph.
    }
    try {
      context.read<LaunchDataLoader>().reset();
    } on ProviderNotFoundException {
      // Widget tests may mount StartupView without LaunchDataLoader.
    }
  }

  Future<void> _handleGoogleAuth() async {
    final vm = context.read<StartupViewModel>();
    final success = await vm.continueWithGoogleAsync();
    if (!mounted) return;

    if (success) {
      _resetLaunchDataForPostAuth();
      Navigator.of(context).pushReplacementNamed(HelperView.routeName);
    }
  }

  Future<void> _handleAppleAuth() async {
    final vm = context.read<StartupViewModel>();
    final success = await vm.continueWithAppleAsync();
    if (!mounted) return;

    if (success) {
      _resetLaunchDataForPostAuth();
      Navigator.of(context).pushReplacementNamed(HelperView.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    if (_isChecking) {
      return Scaffold(
        backgroundColor: palette.pageBg,
        body: const AppLoadingIndicator(),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isApplePlatform =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: AppThemeSwitcher(),
              ),
            ),
            // Top Section (2.5* equivalent in XAML - taking remaining space)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ThemedLottieHalo(
                      child: ThemedLottie.fire(width: 200, height: 200),
                    ),
                    const SizedBox(height: 20),
                    // Title Text
                    Text(
                      l10n.startupTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
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
                    primary: palette.primary,
                    onPrimary: palette.onPrimary,
                    icon: SvgPicture.string(
                      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none">
  <!-- Right segment: Changed from #4285F4 to #FFFFFF -->
  <path fill="#FFFFFF" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <!-- Bottom segment: Green -->
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <!-- Left segment: Yellow -->
  <path fill="#FBBC05" d="M5.84 14.1c-.22-.66-.35-1.36-.35-2.1s.13-1.44.35-2.1V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.62z"/>
  <!-- Top segment: Red -->
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
</svg>''',
                      width: 24,
                      height: 24,
                    ),
                    isPrimary: true,
                    onPressed: _handleGoogleAuth,
                  ),
                  const SizedBox(height: 15),
                  if (isApplePlatform) ...[
                    // Apple Button
                    _AuthButton(
                      text: l10n.startupAppleBtn,
                      primary: palette.primary,
                      onPrimary: palette.onPrimary,
                      icon: Icon(
                        Icons.apple,
                        color: palette.onPrimary,
                        size: 28,
                      ),
                      isPrimary: true,
                      onPressed: _handleAppleAuth,
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Register Button
                  _AuthButton(
                    text: l10n.startupRegisterWithEmailBtn,
                    primary: palette.primary,
                    onPrimary: palette.onPrimary,
                    icon: Icon(
                      Icons.email_outlined,
                      color: palette.onPrimary,
                      size: 24,
                    ),
                    isPrimary: true,
                    onPressed: () {
                      Navigator.of(context).pushNamed(SignupView.routeName);
                    },
                  ),
                  const SizedBox(height: 15),

                  // Login Button
                  _AuthButton(
                    text: l10n.startupLoginBtn,
                    primary: palette.primary,
                    onPrimary: palette.onPrimary,
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
  final Color primary;
  final Color onPrimary;

  const _AuthButton({
    required this.text,
    this.icon,
    required this.isPrimary,
    required this.onPressed,
    required this.primary,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? primary : Colors.transparent;
    final textColor = isPrimary ? onPrimary : primary;
    final borderColor = primary;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return SizedBox(
      height: 44,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                elevation: 0,
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _buildContent(),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                padding: padding,
                side: BorderSide(color: borderColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
