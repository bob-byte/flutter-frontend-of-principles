import 'package:flutter/material.dart';

/// Matches [MainShell] [GlassTabBar.bottom] `barHeight` (the visible pill).
const kMainShellTabPillHeight = 58.0;

/// [GlassTabBar.bottom] default `verticalPadding` (applied above and below).
const kMainShellTabBarVerticalPadding = 20.0;

/// [GlassTabBar] preferred height: pill + top/bottom vertical padding.
const kMainShellTabBarPreferredHeight =
    kMainShellTabPillHeight + kMainShellTabBarVerticalPadding * 2;

/// Gap between embedded content and the top of the shell tab pill.
const kMainShellEmbeddedContentGap = 8.0;

/// Bottom inset so embedded tab content clears the floating shell tab pill.
///
/// [GlassScaffold] uses `extendBody`, so the body draws under the bar. Clear
/// just above the visible pill — not the full preferred height, which includes
/// the tab bar's top padding and left a large empty gap (same as Tasks).
///
/// On Android the bar is wrapped in [SafeArea]; the body is not, so include
/// [MediaQueryData.viewPadding] bottom. On iOS the bar already straddles the
/// home indicator via its own vertical padding.
double mainShellEmbeddedBottomClearance(BuildContext context) {
  final androidInset = Theme.of(context).platform == TargetPlatform.android
      ? MediaQuery.viewPaddingOf(context).bottom
      : 0.0;
  return androidInset +
      kMainShellTabBarVerticalPadding +
      kMainShellTabPillHeight +
      kMainShellEmbeddedContentGap;
}
