import 'package:flutter/widgets.dart';

import 'engram.dart';

/// The active-engram state [EngramScope] exposes to the widget tree: the single
/// open [engram] plus [switchTo] to change it.
@immutable
class EngramScopeData {
  const EngramScopeData({required this.engram, required this.switchTo});

  /// The one engram open right now — never a collection (Decision 2).
  final Engram engram;

  /// Switches the active engram, releasing the outgoing engram's store first.
  /// Switching to the already-active engram is a no-op.
  final Future<void> Function(Engram engram) switchTo;
}

/// Holds the single active engram and exposes it to descendants, the way
/// `AppSettings` exposes look-and-feel. Screens read
/// `EngramScope.of(context).engram`; the picker calls
/// `EngramScope.of(context).switchTo(next)`.
///
/// Switching swaps one value: engram-scoped subtrees rebuild while everything
/// *above* this widget (the `MaterialApp` root) is untouched, and the previous
/// engram's store is released (Decision 2). Because the active engram lives in
/// this widget's own [State], place [EngramScope] below the app root — as the
/// shell's `home`, not around the `MaterialApp` — so a switch never rebuilds the
/// root or tears down the navigator.
class EngramScope extends StatefulWidget {
  const EngramScope({
    super.key,
    required this.initialEngram,
    required this.child,
    this.onSwitched,
  });

  /// The engram open when the scope is first built (resolved at startup).
  final Engram initialEngram;

  /// Invoked after the active engram changes, e.g. to persist "last opened".
  /// Not called for a no-op switch to the already-active engram.
  final Future<void> Function(Engram engram)? onSwitched;

  final Widget child;

  /// The active-engram state, or throws if there is no [EngramScope] ancestor.
  static EngramScopeData of(BuildContext context) {
    final data = maybeOf(context);
    assert(data != null, 'No EngramScope found in the widget tree.');
    return data!;
  }

  /// The active-engram state, or null if there is no [EngramScope] ancestor.
  static EngramScopeData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_EngramScopeMarker>()
      ?.data;

  @override
  State<EngramScope> createState() => _EngramScopeState();
}

class _EngramScopeState extends State<EngramScope> {
  late Engram _engram = widget.initialEngram;

  Future<void> _switchTo(Engram next) async {
    if (next.id == _engram.id) return; // already open — nothing to swap/release
    final previous = _engram;
    // Swap first so the new (already-resolved) engram renders immediately, then
    // free the outgoing store. For v1's stateless stores release is a no-op;
    // this is where a Location-B security-scoped handle is freed in v2.
    setState(() => _engram = next);
    await previous.store.release();
    await widget.onSwitched?.call(next);
  }

  @override
  void dispose() {
    // Free the active store when the scope itself is torn down.
    _engram.store.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EngramScopeMarker(
        data: EngramScopeData(engram: _engram, switchTo: _switchTo),
        child: widget.child,
      );
}

class _EngramScopeMarker extends InheritedWidget {
  const _EngramScopeMarker({required this.data, required super.child});

  final EngramScopeData data;

  @override
  bool updateShouldNotify(_EngramScopeMarker oldWidget) =>
      data.engram.id != oldWidget.data.engram.id;
}
