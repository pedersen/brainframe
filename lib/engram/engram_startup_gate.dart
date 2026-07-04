import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'engram.dart';
import 'engram_scope.dart';

/// Resolves the engram to open at startup, then installs an [EngramScope] over
/// [child] with that engram active.
///
/// While the engram resolves it shows an adaptive progress indicator. The
/// resolution ([resolveInitialEngram], normally `EngramRepository.openInitialEngram`)
/// is designed never to fail — discovery degrades to the always-present
/// built-ins — so a failure is treated as a rare edge and surfaced as a plain
/// message rather than blocking the app.
///
/// Place this as the app shell's `home`, below the `MaterialApp`, so the scope
/// it installs — and every later engram switch — sits under the app root rather
/// than around it (see [EngramScope]).
class EngramStartupGate extends StatefulWidget {
  const EngramStartupGate({
    super.key,
    required this.resolveInitialEngram,
    required this.child,
    this.onSwitched,
  });

  /// Resolves the engram to open first. Run once, when the gate is inserted.
  final Future<Engram> Function() resolveInitialEngram;

  /// Forwarded to [EngramScope.onSwitched] to persist the active engram after a
  /// switch (normally `(e) => repository.setLastOpened(e.id)`).
  final Future<void> Function(Engram engram)? onSwitched;

  /// The app content shown once an engram is active.
  final Widget child;

  @override
  State<EngramStartupGate> createState() => _EngramStartupGateState();
}

class _EngramStartupGateState extends State<EngramStartupGate> {
  // Held in a field, not created in build, so a rebuild never re-runs startup.
  late final Future<Engram> _initial = widget.resolveInitialEngram();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Engram>(
      future: _initial,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return EngramScope(
            initialEngram: snapshot.data!,
            onSwitched: widget.onSwitched,
            child: widget.child,
          );
        }
        if (snapshot.hasError) {
          return _StartupMessage(AppLocalizations.of(context).startupOpenError);
        }
        return const _StartupMessage.loading();
      },
    );
  }
}

/// The gate's pre-engram states: a centered spinner while resolving, or a short
/// message if resolution failed. Non-interactive, so no `Semantics` actions are
/// needed; the loading spinner carries a label for screen readers.
class _StartupMessage extends StatelessWidget {
  const _StartupMessage(String this.message) : _loading = false;
  const _StartupMessage.loading()
      : message = null,
        _loading = true;

  final String? message;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _loading
          ? Semantics(
              label: AppLocalizations.of(context).startupOpening,
              child: const CircularProgressIndicator.adaptive(),
            )
          : Text(message!, textAlign: TextAlign.center),
    );
  }
}
