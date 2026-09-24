import 'package:flutter/material.dart';

/// Bottom-shell tabs that mount on first visit and stay alive afterward.
///
/// Tabs listed in [disposeWhenInactive] are removed from the tree whenever
/// they are not the selected index (e.g. Settings), so their [State] is
/// disposed and rebuilt on the next visit.
///
/// Inactive mounted tabs are wrapped in [TickerMode] so offstage animations
/// do not keep ticking.
class LazyShellTabStack extends StatefulWidget {
  const LazyShellTabStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.builder,
    this.initialMountedIndexes = const {},
    this.disposeWhenInactive = const {},
  }) : assert(itemCount > 0),
       assert(index >= 0 && index < itemCount);

  final int index;
  final int itemCount;

  /// Tabs already in the tree before the first user visit (e.g. default Tasks).
  final Set<int> initialMountedIndexes;

  /// Tabs that must not stay mounted after the user leaves them.
  final Set<int> disposeWhenInactive;

  /// Builds tab [index]. [isActive] is true only while that tab is selected.
  final Widget Function(BuildContext context, int index, bool isActive) builder;

  @override
  State<LazyShellTabStack> createState() => _LazyShellTabStackState();
}

class _LazyShellTabStackState extends State<LazyShellTabStack> {
  late final Set<int> _mounted = {...widget.initialMountedIndexes};

  @override
  void initState() {
    super.initState();
    _noteVisit(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyShellTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _noteVisit(widget.index);
    }
  }

  void _noteVisit(int index) {
    // Dispose-when-inactive tabs are never kept in [_mounted].
    if (widget.disposeWhenInactive.contains(index)) return;
    _mounted.add(index);
  }

  bool _shouldBuild(int i) {
    if (widget.disposeWhenInactive.contains(i)) {
      return widget.index == i;
    }
    return widget.index == i || _mounted.contains(i);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.itemCount; i++)
          _shouldBuild(i)
              ? TickerMode(
                  enabled: widget.index == i,
                  child: widget.builder(context, i, widget.index == i),
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}
