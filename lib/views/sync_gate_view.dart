import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_controller.dart';
import '../widgets/themed_lottie.dart';

/// Full-screen gate while post-auth hydrate and reminder restore run.
///
/// Matches MAUI [SyncGateView]: fire Lottie + "Loading content...".
/// Shown after interactive sign-in, for full bootstrap (`since` null), or when
/// `since` is ≥ 20 days old — see `shouldShowSyncGate` / `kSyncGateStaleSince`.
/// Reminder restore explain uses [DialogService] / [AppAlertDialog] (MAUI
/// [ShowAlertAsync]), not inline copy on this gate.
class SyncGateView extends StatefulWidget {
  const SyncGateView({super.key});

  @override
  State<SyncGateView> createState() => _SyncGateViewState();
}

class _SyncGateViewState extends State<SyncGateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fireController;

  @override
  void initState() {
    super.initState();
    // Own the ticker so ThemeController rebuilds do not remount Lottie.asset
    // and stall the loop on frame 0.
    _fireController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _fireController.stop();
    _fireController.dispose();
    super.dispose();
  }

  void _onFireLoaded(LottieComposition composition) {
    if (!mounted) return;
    _fireController
      ..duration = composition.duration
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final fireAsset = ThemedLottie.themeOf(context).fireLottieAsset;

    // Force tickers on even if a parent route/overlay briefly disables them.
    return TickerMode(
      enabled: true,
      child: Scaffold(
        backgroundColor: palette.pageBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThemedLottieHalo(
                    size: 240,
                    child: Lottie.asset(
                      fireAsset,
                      controller: _fireController,
                      onLoaded: _onFireLoaded,
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.loadingContent,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
