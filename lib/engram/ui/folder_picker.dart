import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Shows a dialog listing [folders] (engram-relative paths) plus, when
/// [includeRoot] is true, the engram root, and returns the destination the user
/// picks — `''` for the root — or null on cancel.
///
/// Select-then-confirm: tapping a row selects it, and a "Move" button confirms;
/// nothing moves on a single mis-tap. The caller pre-filters [folders] to valid
/// destinations (e.g. excluding a folder being moved and its descendants), so
/// this widget stays a generic chooser — the design earmarks it for reuse as the
/// Raspberry Pi / e-ink in-app directory browser.
Future<String?> showFolderPicker(
  BuildContext context, {
  required List<String> folders,
  bool includeRoot = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderPickerDialog(
      folders: folders,
      includeRoot: includeRoot,
    ),
  );
}

class _FolderPickerDialog extends StatefulWidget {
  const _FolderPickerDialog({required this.folders, required this.includeRoot});

  final List<String> folders;
  final bool includeRoot;

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = <_FolderEntry>[
      if (widget.includeRoot) _FolderEntry('', l10n.folderPickerRoot, 0),
      for (final folder in widget.folders)
        _FolderEntry(
          folder,
          folder.split('/').last,
          folder.split('/').length,
        ),
    ];

    return AlertDialog.adaptive(
      title: Text(l10n.moveTitle),
      content: SizedBox(
        width: 320,
        child: entries.isEmpty
            ? Text(l10n.folderPickerEmpty)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in entries)
                      ListTile(
                        dense: true,
                        selected: entry.path == _selected,
                        leading: Icon(entry.path == _selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                        title: Text(entry.label),
                        contentPadding:
                            EdgeInsets.only(left: 8.0 + entry.depth * 16, right: 8),
                        onTap: () => setState(() => _selected = entry.path),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(l10n.move),
        ),
      ],
    );
  }
}

/// One selectable row: its engram-relative [path] (`''` = root), display
/// [label], and indentation [depth].
class _FolderEntry {
  const _FolderEntry(this.path, this.label, this.depth);

  final String path;
  final String label;
  final int depth;
}
