import 'package:flutter/material.dart';

import '../engram/engram_repository.dart';
import '../l10n/gen/app_localizations.dart';

/// Lists the registry-backed engrams that can be forgotten.
typedef ForgettableEngramsLoader = Future<List<RegisteredEngram>> Function();

/// Forgets the engram with the given id (registry-only, never touches disk).
typedef EngramForgetter = Future<void> Function(String id);

/// The Housekeeping settings pane: maintenance jobs on engrams.
///
/// For now its one job is **forgetting** a registry-backed engram — dropping it
/// from BrainFrame's list (and the switcher) without touching its files on disk.
/// This is how a user clears a dangling entry (a folder they deleted) or simply
/// stops managing a folder with BrainFrame. Only registry-backed engrams appear;
/// built-in and in-app engrams aren't forgettable (see [EngramRepository.forget]).
///
/// A custom [SettingsCategory] detail pane (like About), because it renders a
/// live list with actions rather than a fixed set of control rows. It depends on
/// two capabilities rather than the whole repository, so it stays trivially
/// testable (no filesystem in a widget test).
class HousekeepingPane extends StatefulWidget {
  const HousekeepingPane({super.key, required this.load, required this.forget});

  /// Wires the pane to a repository: `HousekeepingPane.forRepository(repo)`.
  HousekeepingPane.forRepository(EngramRepository repository, {Key? key})
    : this(
        key: key,
        load: repository.registeredEngrams,
        forget: repository.forget,
      );

  final ForgettableEngramsLoader load;
  final EngramForgetter forget;

  @override
  State<HousekeepingPane> createState() => _HousekeepingPaneState();
}

class _HousekeepingPaneState extends State<HousekeepingPane> {
  late Future<List<RegisteredEngram>> _engrams;

  @override
  void initState() {
    super.initState();
    _engrams = widget.load();
  }

  void _reload() {
    setState(() {
      _engrams = widget.load();
    });
  }

  Future<void> _forget(RegisteredEngram engram) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.housekeepingConfirmTitle(engram.displayName)),
        content: Text(l10n.housekeepingConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.housekeepingForget),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.forget(engram.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = constraints.maxWidth < 540 ? 18.0 : 32.0;
        return FutureBuilder<List<RegisteredEngram>>(
          future: _engrams,
          builder: (context, snapshot) {
            final engrams = snapshot.data;
            return ListView(
              padding: EdgeInsets.fromLTRB(hPad, 26, hPad, 44),
              children: [
                Text(
                  l10n.settingsHousekeepingName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01 * 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.housekeepingIntro,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (engrams == null)
                  const Center(child: CircularProgressIndicator.adaptive())
                else if (engrams.isEmpty)
                  _EmptyState(message: l10n.housekeepingEmpty)
                else
                  for (final engram in engrams)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EngramRow(
                        engram: engram,
                        onForget: () => _forget(engram),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EngramRow extends StatelessWidget {
  const _EngramRow({required this.engram, required this.onForget});

  final RegisteredEngram engram;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        engram.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!engram.available) ...[
                      const SizedBox(width: 8),
                      _MissingBadge(label: l10n.housekeepingMissing),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  engram.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            button: true,
            label: '${l10n.housekeepingForget} ${engram.displayName}',
            child: ExcludeSemantics(
              child: OutlinedButton(
                onPressed: onForget,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                ),
                child: Text(l10n.housekeepingForget),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingBadge extends StatelessWidget {
  const _MissingBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05 * 10,
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}
