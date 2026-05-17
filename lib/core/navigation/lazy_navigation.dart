import 'package:flutter/material.dart';

/// Drop-in replacement for [IndexedStack] that builds each child lazily —
/// only when it is first navigated to — then keeps it alive indefinitely.
///
/// Streams and heavy init work inside each tab only start on first visit.
/// Once built, a tab is never torn down (equivalent to IndexedStack behaviour
/// for visited tabs).
///
/// Usage:
/// ```dart
/// LazyIndexedStack(
///   index: _currentIndex,
///   children: enabledItems.map((e) => e.page).toList(),
/// )
/// ```
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.children.length != _activated.length) {
      // Tabs list changed (e.g. remote feature flag toggled); reset.
      _activated
        ..clear()
        ..addAll(List.generate(
          widget.children.length,
          (i) => i == widget.index,
        ));
      return;
    }
    if (!_activated[widget.index]) {
      setState(() => _activated[widget.index] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _activated[i] ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
