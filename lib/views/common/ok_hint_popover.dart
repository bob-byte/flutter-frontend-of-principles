import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../../core/road_guide/road_guide_controller.dart';

/// Primary-colored coachmark with message + OK (same look as Add Habit AI hint).
class OkHintPopover extends StatelessWidget {
  const OkHintPopover({
    super.key,
    required this.controller,
    required this.message,
    required this.okLabel,
    required this.child,
    this.direction = TooltipDirection.up,
    this.showOnTap = true,
    this.contentWidth = 280,
  });

  final SuperTooltipController controller;
  final String message;
  final String okLabel;
  final Widget child;
  final TooltipDirection direction;
  final bool showOnTap;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SuperTooltip(
      controller: controller,
      style: TooltipStyle(backgroundColor: scheme.primary, hasShadow: false),
      positionConfig: PositionConfiguration(preferredDirection: direction),
      interactionConfig: InteractionConfiguration(showOnTap: showOnTap),
      content: SizedBox(
        width: contentWidth,
        child: Material(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 13),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: () => controller.hideTooltip(),
                child: Text(
                  okLabel,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Shows [controller] once per device via SharedPreferences [prefsKey].
///
/// Skips while the road guide is active. Returns whether the tooltip was shown.
Future<bool> showOkHintOnce({
  required BuildContext context,
  required SuperTooltipController controller,
  required String prefsKey,
  bool skip = false,
}) async {
  if (skip) return false;
  try {
    if (context.read<RoadGuideController>().isActive) return false;
  } on ProviderNotFoundException {
    // Widget tests may mount without the road guide.
  }

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(prefsKey) ?? false) return false;

  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return false;
  final animation = ModalRoute.of(context)?.animation;
  if (animation != null && animation.status != AnimationStatus.completed) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  if (!context.mounted) return false;

  // Autofocused fields (e.g. empty goal name) raise the IME over the coachmark.
  final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
  FocusManager.instance.primaryFocus?.unfocus();
  if (hadFocus) {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!context.mounted) return false;
  }

  await prefs.setBool(prefsKey, true);
  await controller.showTooltip();
  return true;
}
