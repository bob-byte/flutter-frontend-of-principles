import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/themed_lottie.dart';

/// Full-screen gate while post-auth hydrate and reminder restore run.
///
/// Matches MAUI [SyncGateView]: fire Lottie + "Loading content...".
/// Shown only for full bootstrap (`since` null) or when `since` is ≥ 20 days
/// old — see `requiresSyncGate` / `kSyncGateStaleSince`.
/// When [restore] is true, shows MAUI [RestoreReminders] /
/// [AfterLoginWhenUserAccountHaveReminders] inline (same copy as MAUI's alert)
/// so the flame keeps ticking — a modal [showDialog] would stop its ticker.
class SyncGateView extends StatefulWidget {
  const SyncGateView({super.key, this.restore = false, this.onRestoreAck});

  final bool restore;
  final VoidCallback? onRestoreAck;

  @override
  State<SyncGateView> createState() => _SyncGateViewState();
}

class _SyncGateViewState extends State<SyncGateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fireController;

  @override
  void initState() {
    super.initState();
    // Own the ticker so ThemeController / restore rebuilds do not remount
    // Lottie.asset and stall the loop on frame 0.
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
                    size: widget.restore ? 180 : 240,
                    child: Lottie.asset(
                      fireAsset,
                      controller: _fireController,
                      onLoaded: _onFireLoaded,
                      width: widget.restore ? 140 : 180,
                      height: widget.restore ? 140 : 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (!widget.restore) ...[
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
                  ] else ...[
                    const SizedBox(height: 8),
                    // MAUI ShowAlertAsync(RestoreReminders, AfterLogin…) —
                    // inline so Lottie keeps ticking.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLogo(size: 56),
                          const SizedBox(height: 12),
                          Text(
                            l10n.restoreReminders,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.afterLoginWhenUserAccountHaveReminders,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary.withValues(alpha: 0.9),
                              fontSize: 16,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: widget.onRestoreAck,
                            child: Text(
                              l10n.okButton,
                              style: TextStyle(
                                color: palette.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
