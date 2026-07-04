import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engram.dart';
import 'markdown_reader.dart';

/// Opens the help engram as a floating read-only peek overlay (Decision 8).
///
/// The overlay reads from [helpEngram] but never becomes the active engram, so
/// dismissing it returns the user exactly where they were. This is the `?`
/// entry point; opening help as a full engram happens through the switcher.
Future<void> showHelpOverlay(BuildContext context, Engram helpEngram) {
  return showDialog<void>(
    context: context,
    builder: (context) => _HelpOverlay(helpEngram: helpEngram),
  );
}

class _HelpOverlay extends StatefulWidget {
  const _HelpOverlay({required this.helpEngram});

  final Engram helpEngram;

  @override
  State<_HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<_HelpOverlay> {
  static const String _entryFile = 'index.md';

  late final Future<List<String>> _paths = widget.helpEngram.store.list();
  String _path = _entryFile;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _paths,
                builder: (context, snapshot) {
                  final paths = snapshot.data ?? const <String>[];
                  return MarkdownReader(
                    store: widget.helpEngram.store,
                    path: _path,
                    availablePaths: paths.toSet(),
                    onNavigateToFile: (path) => setState(() => _path = path),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.help_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child:
                  Text(l10n.helpTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          // Let the user jump back to the help index from a sub-page.
          if (_path != _entryFile)
            TextButton(
              onPressed: () => setState(() => _path = _entryFile),
              child: Text(l10n.helpIndex),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.helpClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
