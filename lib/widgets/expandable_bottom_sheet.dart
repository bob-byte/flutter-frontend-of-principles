import 'package:flutter/material.dart';

typedef ExpandableSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Default detents for expandable modal sheets.
abstract final class ExpandableSheetDefaults {
  static const double minChildSize = 0.34;
  static const double initialChildSize = 0.55;
  static const double maxChildSize = 0.94;
}

/// Modal bottom sheet that can be dragged between [minChildSize] and
/// [maxChildSize] (snap). Pass [scrollController] to the primary scrollable
/// so the grabber / list drag expands and collapses the sheet.
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
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          snap: true,
          snapSizes: resolvedSnaps,
          shouldCloseOnMinExtent: true,
          builder: builder,
        ),
      );
    },
  );
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

/// Standard grabber shown at the top of expandable sheets.
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
    return Padding(
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
  }
}
