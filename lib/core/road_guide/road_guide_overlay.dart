import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'road_guide_controller.dart';
import 'road_guide_steps.dart';

/// Dimmed spotlight overlay with Skip (first step) / Back / Next for the
/// post-login road guide.
///
/// Inserted as a [Positioned.fill] [OverlayEntry] so [GlassScaffold] / [GlassTabBar]
/// keep their original layout (no wrapping [Stack] or [OverlayPortal]).
class RoadGuideOverlay extends StatelessWidget {
  const RoadGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoadGuideController>(
      builder: (context, guide, _) {
        if (!guide.isActive) return const SizedBox.shrink();
        final step = guide.currentStep;
        if (step == null) return const SizedBox.shrink();
        return _RoadGuideOverlayBody(guide: guide, step: step);
      },
    );
  }
}

class _RoadGuideOverlayBody extends StatefulWidget {
  const _RoadGuideOverlayBody({required this.guide, required this.step});

  final RoadGuideController guide;
  final RoadGuideStep step;

  @override
  State<_RoadGuideOverlayBody> createState() => _RoadGuideOverlayBodyState();
}

class _RoadGuideOverlayBodyState extends State<_RoadGuideOverlayBody> {
  Rect? _target;
  int _measureGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _RoadGuideOverlayBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      _target = null;
    }
    // Remeasure on every guide rebuild — pushed routes finish laying out
    // after the step id already changed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final generation = ++_measureGeneration;
    final hole = _resolveHole(widget.step);
    if (hole != null) {
      final inflated = hole.inflate(8);
      if (_target != inflated) {
        setState(() => _target = inflated);
      }
      // Remasure after layout settles — covers both opening and closing
      // pushed routes (Edit Habit / Habit Detail) that shift tab targets.
      if (widget.step.targetKey != null || widget.step.opensPushedRoute) {
        for (final delayMs in [120, 320, 480]) {
          Future<void>.delayed(Duration(milliseconds: delayMs), () {
            if (!mounted || generation != _measureGeneration) return;
            final settled = _resolveHole(widget.step);
            if (settled == null) return;
            final next = settled.inflate(8);
            if (_target != next) {
              setState(() => _target = next);
            }
          });
        }
      }
      return;
    }
    if (_target != null) {
      setState(() => _target = null);
    }
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || generation != _measureGeneration) return;
      final retry = _resolveHole(widget.step);
      if (retry == null) return;
      setState(() => _target = retry.inflate(8));
    });
  }

  Rect? _resolveHole(RoadGuideStep step) {
    final tabIndex = step.tabIndex;
    if (tabIndex != null) {
      return RoadGuideKeys.tabHole(context, tabIndex);
    }
    final key = step.targetKey;
    if (key == null) return null;
    final targetBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.hasSize || !targetBox.attached) {
      return null;
    }
    // Paint is in overlay-local space; convert through this overlay box so
    // the hole tracks the button after route transitions.
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize || !overlayBox.attached) {
      return null;
    }
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & targetBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final scheme = Theme.of(context).colorScheme;
    final target = _target;
    final tooltipTop = _tooltipTop(
      mediaHeight: media.height,
      target: target,
      topSafe: padding.top,
      bottomSafe: padding.bottom,
    );

    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  hole: target,
                  overlayColor: Colors.black.withValues(alpha: 0.62),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: tooltipTop,
              child: _TooltipCard(
                title: widget.step.title(l10n),
                body: widget.step.body(l10n),
                stepLabel:
                    '${widget.guide.stepIndex + 1} / ${widget.guide.totalSteps}',
                skipLabel: widget.guide.isFirstStep
                    ? l10n.roadGuideSkip
                    : l10n.roadGuideBack,
                nextLabel: widget.guide.isLastStep
                    ? l10n.roadGuideDone
                    : l10n.roadGuideNext,
                onSkip: widget.guide.isFirstStep
                    ? () => widget.guide.skip()
                    : () => widget.guide.back(),
                secondaryKey: widget.guide.isFirstStep
                    ? const Key('roadGuideSkipButton')
                    : const Key('roadGuideBackButton'),
                onNext: () => widget.guide.next(),
                foreground: scheme.onSurface,
                background: scheme.surface,
                primary: scheme.primary,
                onPrimary: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _tooltipTop({
    required double mediaHeight,
    required Rect? target,
    required double topSafe,
    required double bottomSafe,
  }) {
    const cardHeightEstimate = 240.0;
    const gap = 16.0;
    final minTop = topSafe + 16;
    final maxTop = mediaHeight - bottomSafe - cardHeightEstimate - 16;
    final clampedFallback = mediaHeight * 0.28;
    double clampTop(double top) {
      if (maxTop < minTop) return minTop;
      return top.clamp(minTop, maxTop);
    }

    if (target == null) {
      return clampTop(clampedFallback);
    }
    final below = target.bottom + gap;
    final spaceBelow = mediaHeight - bottomSafe - below;
    if (spaceBelow >= cardHeightEstimate) {
      return clampTop(below);
    }
    final above = target.top - cardHeightEstimate - gap;
    if (above >= minTop) {
      return clampTop(above);
    }
    return clampTop(maxTop);
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
    required this.foreground,
    required this.background,
    required this.primary,
    required this.onPrimary,
    this.secondaryKey = const Key('roadGuideSkipButton'),
  });

  final String title;
  final String body;
  final String stepLabel;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final Color foreground;
  final Color background;
  final Color primary;
  final Color onPrimary;
  final Key secondaryKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
                Text(
                  stepLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground.withValues(alpha: 0.88),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  key: secondaryKey,
                  onPressed: onSkip,
                  child: Text(skipLabel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('roadGuideNextButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onPrimary,
                  ),
                  onPressed: onNext,
                  child: Text(nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.overlayColor});

  final Rect? hole;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final rrect = RRect.fromRectAndRadius(hole!, const Radius.circular(14));
      overlay.addRRect(rrect);
      overlay.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(overlay, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole || oldDelegate.overlayColor != overlayColor;
  }
}
