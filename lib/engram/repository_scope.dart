import 'package:flutter/widgets.dart';

import 'engram_repository.dart';

/// Exposes the app's [EngramRepository] to the widget tree, the way
/// `AppSettings` exposes look-and-feel.
///
/// Placed **above** the `MaterialApp` (not at `home`, where `EngramScope` sits),
/// so routes pushed onto the navigator — the Settings screen and its
/// Housekeeping pane — can reach the repository, which the active-engram
/// `EngramScope` cannot provide across a route boundary.
class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final EngramRepository repository;

  static EngramRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope found in the widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
