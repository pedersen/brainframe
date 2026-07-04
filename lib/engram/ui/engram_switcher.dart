import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../built_in_engrams.dart';
import '../desktop_folder_adoption.dart';
import '../engram.dart';
import '../engram_repository.dart';
import '../engram_scope.dart';

/// The sidebar-footer engram switcher (Decision 8's "travel there" entry point).
///
/// Shows the current engram and, on tap, a sheet listing the available engrams
/// (built-ins and user engrams), the reconnectable ones as disabled rows, and
/// the app-level actions `New engram` and — on desktop — `Open folder…`. It
/// captures the [EngramScope] before opening the sheet, because the sheet is
/// pushed above the app content and no longer has the scope as an ancestor.
///
/// On web there is no user-engram filesystem (the store throws), so `New engram`
/// is hidden and only the built-in tutorial and help are switchable.
class EngramSwitcher extends StatelessWidget {
  const EngramSwitcher({
    super.key,
    required this.repository,
    required this.current,
    this.allowCreateEngram = !kIsWeb,
  });

  final EngramRepository repository;
  final Engram current;

  /// Whether creating a new engram is offered. False on web, where the
  /// filesystem store is unsupported. Injectable so both branches are testable.
  final bool allowCreateEngram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = localizedEngramName(current, l10n);
    return Semantics(
      button: true,
      label: l10n.switcherCurrentEngram(name),
      child: InkWell(
        onTap: () => _openSwitcher(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.book_outlined, size: 18, color: theme.hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (current.readOnly) ...[
                  Semantics(
                    label: l10n.switcherReadOnly,
                    child: Icon(Icons.lock_outline,
                        size: 15, color: theme.hintColor),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.unfold_more, size: 18, color: theme.hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSwitcher(BuildContext context) async {
    // Capture the scope before the async gap — the sheet's context won't have
    // it as an ancestor.
    final scope = EngramScope.of(context);
    final discovery = await repository.discover();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _SwitcherSheet(
        discovery: discovery,
        currentId: current.id,
        onSelect: (engram) {
          Navigator.of(sheetContext).pop();
          scope.switchTo(engram);
        },
        onNewEngram: allowCreateEngram
            ? () async {
                Navigator.of(sheetContext).pop();
                await _createEngram(context, scope);
              }
            : null,
        onOpenFolder: isDesktopFolderAdoptionSupported
            ? () async {
                Navigator.of(sheetContext).pop();
                final engram = await pickAndAdoptFolder(repository);
                if (engram != null) await scope.switchTo(engram);
              }
            : null,
      ),
    );
  }

  Future<void> _createEngram(BuildContext context, EngramScopeData scope) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewEngramDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    final engram = await repository.create(name.trim());
    await scope.switchTo(engram);
  }
}

class _SwitcherSheet extends StatelessWidget {
  const _SwitcherSheet({
    required this.discovery,
    required this.currentId,
    required this.onSelect,
    required this.onNewEngram,
    required this.onOpenFolder,
  });

  final EngramDiscovery discovery;
  final String currentId;
  final void Function(Engram engram) onSelect;
  final VoidCallback? onNewEngram;
  final VoidCallback? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(l10n.switcherHeading),
          ),
          for (final engram in discovery.available)
            ListTile(
              leading: Icon(
                engram.readOnly ? Icons.menu_book_outlined : Icons.book_outlined,
              ),
              title: Text(localizedEngramName(engram, l10n)),
              trailing: engram.id == currentId ? const Icon(Icons.check) : null,
              selected: engram.id == currentId,
              onTap: () => onSelect(engram),
            ),
          for (final unavailable in discovery.unavailable)
            ListTile(
              enabled: false,
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(unavailable.displayName),
              subtitle: Text(l10n.switcherUnavailable),
            ),
          if (onNewEngram != null || onOpenFolder != null) const Divider(),
          if (onNewEngram != null)
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.switcherNewEngram),
              onTap: onNewEngram,
            ),
          if (onOpenFolder != null)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.switcherOpenFolder),
              onTap: onOpenFolder,
            ),
        ],
      ),
    );
  }
}

class _NewEngramDialog extends StatefulWidget {
  const _NewEngramDialog();

  @override
  State<_NewEngramDialog> createState() => _NewEngramDialogState();
}

class _NewEngramDialogState extends State<_NewEngramDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog.adaptive(
      title: Text(l10n.switcherNewEngram),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.newEngramNameLabel),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.create)),
      ],
    );
  }
}
