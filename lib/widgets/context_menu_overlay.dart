import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import 'app_alert_dialog.dart';

/// Long-press context menu with animated blur, scale, fade, and slide.
class ContextMenuOverlay extends StatefulWidget {
  const ContextMenuOverlay({
    super.key,
    required this.animation,
    required this.palette,
    required this.child,
    this.anchor,
    this.estimatedHeight = 252,
  });

  static const Duration transitionDuration = Duration(milliseconds: 280);
  static const Color destructiveColor = Color(0xFFE85D4C);

  final Animation<double> animation;
  final TasksUiPalette palette;
  final Widget child;
  final Rect? anchor;
  final double estimatedHeight;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(
      BuildContext dialogContext,
      Animation<double> animation,
    )
    builder,
  }) {
    Feedback.forLongPress(context);
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: transitionDuration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Animate blur by sigma inside the overlay — Opacity ancestors
        // prevent BackdropFilter from sampling the screen behind the menu.
        return child;
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext, animation);
      },
    );
  }

  @override
  State<ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<ContextMenuOverlay> {
  late final CurvedAnimation _ease;
  late final CurvedAnimation _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ease = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(begin: 0.86, end: 1.0).animate(_ease);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_ease);
  }

  @override
  void dispose() {
    _ease.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = math.min(280.0, constraints.maxWidth - 32);
        final padding = MediaQuery.paddingOf(context);
        final maxLeft = math.max(16.0, constraints.maxWidth - menuWidth - 16);
        final minTop = padding.top + 8;
        final maxTop = math.max(
          minTop,
          constraints.maxHeight - widget.estimatedHeight - padding.bottom - 16,
        );

        var left = 16.0;
        var top = (constraints.maxHeight - widget.estimatedHeight) / 2;
        if (widget.anchor != null) {
          left = widget.anchor!.left;
          top = widget.anchor!.top;
        }
        left = left.clamp(16.0, maxLeft);
        top = top.clamp(minTop, maxTop);

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: AnimatedBuilder(
                    animation: _ease,
                    builder: (context, child) {
                      final t = _ease.value;
                      return ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 24 * t,
                            sigmaY: 24 * t,
                          ),
                          child: ColoredBox(
                            color: palette.isDark
                                ? Colors.black.withValues(alpha: 0.28 * t)
                                : Colors.black.withValues(alpha: 0.16 * t),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ScaleTransition(
                      alignment: Alignment.topCenter,
                      scale: _scale,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ContextMenuHeader extends StatelessWidget {
  const ContextMenuHeader({
    super.key,
    required this.palette,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final TasksUiPalette palette;
  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      elevation: 8,
      shadowColor: palette.glassShadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContextMenuLeadingIcon extends StatelessWidget {
  const ContextMenuLeadingIcon({
    super.key,
    required this.icon,
    required this.palette,
  });

  final IconData icon;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: palette.isDark ? 0.28 : 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: palette.primary, size: 20),
    );
  }
}

class ContextMenuAction {
  const ContextMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.dividerBefore,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  /// When null, a divider is shown before destructive actions only.
  final bool? dividerBefore;

  bool get showsDividerBefore => dividerBefore ?? destructive;
}

class ContextMenuActionList extends StatelessWidget {
  const ContextMenuActionList({
    super.key,
    required this.palette,
    required this.actions,
  });

  final TasksUiPalette palette;
  final List<ContextMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      elevation: 8,
      shadowColor: palette.glassShadow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0 && actions[i].showsDividerBefore)
              Divider(height: 1, color: palette.cardBorder),
            _ContextMenuActionTile(
              action: actions[i],
              color: actions[i].destructive
                  ? ContextMenuOverlay.destructiveColor
                  : palette.textPrimary,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextMenuActionTile extends StatelessWidget {
  const _ContextMenuActionTile({required this.action, required this.color});

  final ContextMenuAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                action.label,
                style: TextStyle(fontSize: 17, color: color),
              ),
            ),
            Icon(action.icon, size: 22, color: color),
          ],
        ),
      ),
    );
  }
}

void showContextMenuConfirmDialog({
  required BuildContext context,
  required TasksUiPalette palette,
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) {
  showAppConfirmDialog(
    context: context,
    palette: palette,
    title: title,
    message: message,
    onConfirm: onConfirm,
  );
}
