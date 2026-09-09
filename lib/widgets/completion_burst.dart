import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/completion_feedback.dart';

const kCompletionBurstDuration = kCompletionCelebrationDuration;

/// Plays the chime and draws the check + burst at [origin] (or this widget).
///
/// Call this on tap **before** the row can leave the Active list, so the
/// check stays in the circle the user just pressed.
void playCompletionCelebration(
  BuildContext context, {
  Color? color,
  Color? onColor,
  Gradient? fillGradient,
  Offset? origin,
  double radius = 46,
  double checkSize = 26,
}) {
  CompletionFeedback.instance.play();
  if (!context.mounted) return;
  final resolved = color ?? Theme.of(context).colorScheme.primary;
  CompletionBurst.show(
    context,
    color: resolved,
    onColor: onColor ?? Colors.white,
    fillGradient: fillGradient,
    origin: origin,
    radius: radius,
    checkSize: checkSize,
  );
}

/// Pins the burst overlay to [child] so it stays on the checkbox if the row
/// moves (or when window chrome makes global overlay coords unreliable).
class CompletionBurstTarget extends StatefulWidget {
  const CompletionBurstTarget({super.key, required this.child});

  final Widget child;

  static LayerLink? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_CompletionBurstTargetState>()?.link;
  }

  @override
  State<CompletionBurstTarget> createState() => _CompletionBurstTargetState();
}

class _CompletionBurstTargetState extends State<CompletionBurstTarget> {
  final link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: link, child: widget.child);
  }
}

Offset? _originInOverlay({
  required BuildContext context,
  required OverlayState overlay,
  Offset? globalOrigin,
}) {
  final overlayBox = overlay.context.findRenderObject();
  if (overlayBox is! RenderBox || !overlayBox.hasSize) {
    return globalOrigin;
  }

  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    return box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayBox,
    );
  }
  if (globalOrigin != null) {
    return overlayBox.globalToLocal(globalOrigin);
  }
  return null;
}

/// Overlay check + starburst, positioned in the overlay's local space.
class CompletionBurst {
  CompletionBurst._();

  static bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  static void show(
    BuildContext context, {
    required Color color,
    Color onColor = Colors.white,
    Gradient? fillGradient,
    Offset? origin,
    double radius = 46,
    double checkSize = 26,
  }) {
    if (_inWidgetTest) return;
    // Nearest overlay (same space as the checkbox), not the root — a
    // CompositedTransformFollower in the root overlay painted at the
    // status bar instead of the tick.
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final localOrigin = _originInOverlay(
      context: context,
      overlay: overlay,
      globalOrigin: origin,
    );
    if (localOrigin == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: _BurstLayer(
            center: localOrigin,
            color: color,
            onColor: onColor,
            fillGradient: fillGradient,
            radius: radius,
            checkSize: checkSize,
            onDone: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

/// Scales [child] when [isCompleted] rises. Sound/check overlay is on tap.
class CompletionCelebrate extends StatefulWidget {
  const CompletionCelebrate({
    super.key,
    required this.isCompleted,
    required this.color,
    required this.child,
    this.burstRadius = 40,
  });

  final bool isCompleted;
  final Color color;
  final Widget child;
  final double burstRadius;

  @override
  State<CompletionCelebrate> createState() => _CompletionCelebrateState();
}

class _CompletionCelebrateState extends State<CompletionCelebrate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kCompletionBurstDuration,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.22,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.22,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant CompletionCelebrate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted && !oldWidget.isCompleted) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: widget.child,
    );
  }
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({
    required this.center,
    required this.color,
    required this.onColor,
    required this.fillGradient,
    required this.radius,
    required this.checkSize,
    required this.onDone,
  });

  final Offset center;
  final Color color;
  final Color onColor;
  final Gradient? fillGradient;
  final double radius;
  final double checkSize;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kCompletionBurstDuration,
    )..forward();
    _controller.addListener(_maybeFinish);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  bool _finished = false;

  void _maybeFinish() {
    if (_controller.value >= 0.92) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final checkT = Interval(
          0.08,
          0.42,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final fillT = Interval(0, 0.18, curve: Curves.easeOutBack).transform(t);
        // Overlay check fades as soon as the in-row tick is visible so the
        // last frames are particles, not a frozen duplicate circle.
        final checkFade =
            1 - Interval(0.38, 0.62, curve: Curves.easeIn).transform(t);
        final fade =
            1 - Interval(0.48, 0.90, curve: Curves.easeIn).transform(t);
        return Stack(
          children: [
            Positioned(
              left: widget.center.dx - widget.radius,
              top: widget.center.dy - widget.radius,
              width: size,
              height: size,
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: CompletionBurstPainter(
                        progress: t,
                        color: widget.color,
                      ),
                    ),
                    Opacity(
                      opacity: checkFade.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.72 + 0.28 * fillT,
                        child: Container(
                          width: widget.checkSize,
                          height: widget.checkSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: widget.fillGradient,
                            color: widget.fillGradient == null
                                ? widget.color
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: CompletionCheckStrokePainter(
                              progress: checkT,
                              color: widget.onColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Draws a check stroke from 0 to 1 — used in the overlay circle.
class CompletionCheckStrokePainter extends CustomPainter {
  CompletionCheckStrokePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.70)
      ..lineTo(size.width * 0.78, size.height * 0.30);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(
      0,
      metric.length * progress.clamp(0.0, 1.0),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width * 0.13).clamp(2.0, 3.6)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CompletionCheckStrokePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Starburst + ring used by the overlay (and tests).
class CompletionBurstPainter extends CustomPainter {
  CompletionBurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _particleCount = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.48;
    final highlight = Color.lerp(color, Colors.white, 0.42) ?? color;
    const gold = Color(0xFFFBBF24);

    final ringT = (progress / 0.5).clamp(0.0, 1.0);
    final ringEase = Curves.easeOutCubic.transform(ringT);
    final ringR = maxR * (0.28 + 0.82 * ringEase);
    final ringAlpha = (1 - Curves.easeIn.transform(ringT)) * 0.7;
    if (ringAlpha > 0.02) {
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * (1 - ringT * 0.55)
          ..color = highlight.withValues(alpha: ringAlpha),
      );
      canvas.drawCircle(
        center,
        ringR * 0.55,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.28 * (1 - ringT)),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: ringR * 0.55)),
      );
    }

    for (var i = 0; i < _particleCount; i++) {
      final stagger = i * 0.028;
      final local = ((progress - stagger) / 0.88).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dist =
          maxR *
          (0.55 + (i.isEven ? 0.45 : 0.22)) *
          Curves.easeOutCubic.transform(local);
      final fade = 1 - Curves.easeInQuad.transform(local);
      final angle = (i / _particleCount) * math.pi * 2 + 0.22;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final particleColor = switch (i % 3) {
        0 => color,
        1 => highlight,
        _ => gold,
      }.withValues(alpha: fade);
      final particleR = (3.1 + (i % 3)) * (1 - local * 0.25);
      _drawParticle(canvas, pos, particleR, particleColor, i % 3);
    }
  }

  void _drawParticle(
    Canvas canvas,
    Offset pos,
    double r,
    Color color,
    int kind,
  ) {
    final paint = Paint()..color = color;
    if (kind == 0) {
      canvas.drawCircle(pos, r, paint);
      return;
    }
    if (kind == 1) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = (i / 4) * math.pi * 2 - math.pi / 2;
        final outer = Offset(math.cos(a), math.sin(a)) * r * 1.7;
        final mid =
            Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)) *
            r *
            0.45;
        if (i == 0) {
          path.moveTo(pos.dx + outer.dx, pos.dy + outer.dy);
        } else {
          path.lineTo(pos.dx + outer.dx, pos.dy + outer.dy);
        }
        path.lineTo(pos.dx + mid.dx, pos.dy + mid.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
      return;
    }
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.5),
        const Radius.circular(1.2),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CompletionBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
