import 'package:flutter/material.dart';

import '../../core/input/keyboard.dart';

typedef ExpandableSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Default detents for expandable modal sheets.
abstract final class ExpandableSheetDefaults {
  static const double minChildSize = 0.34;
  static const double initialChildSize = 0.55;
  static const double maxChildSize = 0.94;
}

/// Provides the [DraggableScrollableController] so [BottomSheetDragHandle]
/// can expand / collapse the sheet when the grabber sits outside a scrollable.
class ExpandableSheetScope extends InheritedWidget {
  const ExpandableSheetScope({
    super.key,
    required this.controller,
    required this.minChildSize,
    required this.maxChildSize,
    required this.snapSizes,
    required super.child,
  });

  final DraggableScrollableController controller;
  final double minChildSize;
  final double maxChildSize;
  final List<double> snapSizes;

  static ExpandableSheetScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ExpandableSheetScope>();
  }

  @override
  bool updateShouldNotify(ExpandableSheetScope oldWidget) {
    return controller != oldWidget.controller ||
        minChildSize != oldWidget.minChildSize ||
        maxChildSize != oldWidget.maxChildSize ||
        snapSizes != oldWidget.snapSizes;
  }
}

/// Modal bottom sheet that can be dragged between [minChildSize] and
/// [maxChildSize] (snap). Pass [scrollController] to the primary scrollable
/// so list drag expands and collapses the sheet. The grabber also swipes.
Future<T?> showExpandableModalBottomSheet<T>({
  required BuildContext context,
  required ExpandableSheetBuilder builder,
  double initialChildSize = ExpandableSheetDefaults.initialChildSize,
  double minChildSize = ExpandableSheetDefaults.minChildSize,
  double maxChildSize = ExpandableSheetDefaults.maxChildSize,
  List<double>? snapSizes,
  Color? backgroundColor,
  bool useRootNavigator = false,
}) {
  assert(minChildSize > 0 && minChildSize <= initialChildSize);
  assert(initialChildSize <= maxChildSize && maxChildSize <= 1);

  hideSoftKeyboard();

  final resolvedSnaps = _resolveSnapSizes(
    minChildSize: minChildSize,
    initialChildSize: initialChildSize,
    maxChildSize: maxChildSize,
    snapSizes: snapSizes,
  );

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: backgroundColor ?? Colors.transparent,
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) {
      return _ExpandableSheetHost(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snapSizes: resolvedSnaps,
        builder: builder,
      );
    },
  );
}

class _ExpandableSheetHost extends StatefulWidget {
  const _ExpandableSheetHost({
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.snapSizes,
    required this.builder,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;
  final ExpandableSheetBuilder builder;

  @override
  State<_ExpandableSheetHost> createState() => _ExpandableSheetHostState();
}

class _ExpandableSheetHostState extends State<_ExpandableSheetHost> {
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final snaps =
        widget.snapSizes ??
        <double>[widget.initialChildSize, widget.maxChildSize];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ExpandableSheetScope(
        controller: _sheetController,
        minChildSize: widget.minChildSize,
        maxChildSize: widget.maxChildSize,
        snapSizes: snaps,
        child: DraggableScrollableSheet(
          controller: _sheetController,
          expand: false,
          initialChildSize: widget.initialChildSize,
          minChildSize: widget.minChildSize,
          maxChildSize: widget.maxChildSize,
          snap: true,
          snapSizes: widget.snapSizes,
          shouldCloseOnMinExtent: true,
          builder: widget.builder,
        ),
      ),
    );
  }
}

/// Wraps an existing [DraggableScrollableSheet] subtree (e.g. archive / goals)
/// so [BottomSheetDragHandle] can swipe-expand when the grabber is outside
/// the primary scrollable.
class ExpandableSheetFrame extends StatefulWidget {
  const ExpandableSheetFrame({
    super.key,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.builder,
    this.snapSizes,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;
  final Widget Function(BuildContext context, ScrollController scrollController)
  builder;

  @override
  State<ExpandableSheetFrame> createState() => _ExpandableSheetFrameState();
}

class _ExpandableSheetFrameState extends State<ExpandableSheetFrame> {
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snaps =
        widget.snapSizes ??
        _resolveSnapSizes(
          minChildSize: widget.minChildSize,
          initialChildSize: widget.initialChildSize,
          maxChildSize: widget.maxChildSize,
          snapSizes: null,
        ) ??
        <double>[widget.maxChildSize];

    return ExpandableSheetScope(
      controller: _sheetController,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      snapSizes: snaps,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        initialChildSize: widget.initialChildSize,
        minChildSize: widget.minChildSize,
        maxChildSize: widget.maxChildSize,
        snap: true,
        snapSizes: snaps,
        shouldCloseOnMinExtent: true,
        builder: widget.builder,
      ),
    );
  }
}

List<double>? _resolveSnapSizes({
  required double minChildSize,
  required double initialChildSize,
  required double maxChildSize,
  List<double>? snapSizes,
}) {
  if (snapSizes != null) return snapSizes;

  final sizes = <double>{};
  if (initialChildSize > minChildSize + 0.02 &&
      initialChildSize < maxChildSize - 0.02) {
    sizes.add(initialChildSize);
  }
  if (maxChildSize > minChildSize + 0.02) {
    sizes.add(maxChildSize);
  }
  if (sizes.isEmpty) return null;
  return sizes.toList()..sort();
}

/// Grabber at the top of expandable sheets. Swipe up to expand, down to
/// collapse (and dismiss past the minimum when the sheet allows it).
class BottomSheetDragHandle extends StatelessWidget {
  const BottomSheetDragHandle({
    super.key,
    required this.color,
    this.width = 36,
    this.height = 4,
    this.topPadding = 10,
    this.bottomPadding = 0,
  });

  final Color color;
  final double width;
  final double height;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scope = ExpandableSheetScope.maybeOf(context);
    final handle = Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );

    if (scope == null) return handle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final controller = scope.controller;
        if (!controller.isAttached) return;
        final screenHeight = MediaQuery.sizeOf(context).height;
        if (screenHeight <= 0) return;
        final next = (controller.size - details.delta.dy / screenHeight).clamp(
          scope.minChildSize,
          scope.maxChildSize,
        );
        controller.jumpTo(next);
      },
      onVerticalDragEnd: (details) {
        final controller = scope.controller;
        if (!controller.isAttached) return;
        final velocity = details.primaryVelocity ?? 0;
        final target = _snapTarget(
          current: controller.size,
          velocity: velocity,
          minChildSize: scope.minChildSize,
          maxChildSize: scope.maxChildSize,
          snapSizes: scope.snapSizes,
        );
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        // Dragging firmly past the floor dismisses the modal sheet.
        if (velocity > 900 && controller.size <= scope.minChildSize + 0.02) {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          }
        }
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 28,
          minWidth: double.infinity,
        ),
        child: handle,
      ),
    );
  }
}

double _snapTarget({
  required double current,
  required double velocity,
  required double minChildSize,
  required double maxChildSize,
  required List<double> snapSizes,
}) {
  final candidates = <double>{minChildSize, ...snapSizes, maxChildSize}.toList()
    ..sort();

  // Negative primaryVelocity = finger moved up = expand.
  if (velocity < -400) {
    for (final size in candidates) {
      if (size > current + 0.01) return size;
    }
    return maxChildSize;
  }
  if (velocity > 400) {
    for (final size in candidates.reversed) {
      if (size < current - 0.01) return size;
    }
    return minChildSize;
  }

  return candidates.reduce(
    (a, b) => (a - current).abs() <= (b - current).abs() ? a : b,
  );
}
