import 'package:flutter/material.dart';

import 'file_tree_node.dart';

/// The read-only file browser: a shallow folder tree over an engram's files.
///
/// Folders expand/collapse in place (all open by default, so a small engram
/// shows everything); files are selectable and report taps via [onSelectFile].
/// The currently open file ([selectedPath]) is highlighted. Indentation and a
/// leading disclosure triangle / file glyph convey structure without relying on
/// the design handoff's bespoke styling (Step 8 is structure-only).
class FileTree extends StatefulWidget {
  const FileTree({
    super.key,
    required this.nodes,
    required this.selectedPath,
    required this.onSelectFile,
  });

  /// The roots of the tree (see [buildFileTree]).
  final List<FileTreeNode> nodes;

  /// The engram-relative path of the open file, or null if none is open.
  final String? selectedPath;

  final void Function(String path) onSelectFile;

  @override
  State<FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends State<FileTree> {
  // Folders collapsed by their full path. Absent means expanded (default open).
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This engram has no files yet.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      primary: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final node in widget.nodes) ..._rowsFor(node, 0, ''),
      ],
    );
  }

  /// Flattens [node] (and its visible descendants) into indented rows.
  List<Widget> _rowsFor(FileTreeNode node, int depth, String parentPath) {
    final fullPath =
        parentPath.isEmpty ? node.name : '$parentPath/${node.name}';

    if (!node.isFolder) {
      return [_FileRow(
        node: node,
        depth: depth,
        selected: node.path == widget.selectedPath,
        onTap: () => widget.onSelectFile(node.path!),
      )];
    }

    final expanded = !_collapsed.contains(fullPath);
    return [
      _FolderRow(
        node: node,
        depth: depth,
        expanded: expanded,
        onTap: () => setState(() {
          if (expanded) {
            _collapsed.add(fullPath);
          } else {
            _collapsed.remove(fullPath);
          }
        }),
      ),
      if (expanded)
        for (final child in node.children)
          ..._rowsFor(child, depth + 1, fullPath),
    ];
  }
}

/// Shared left inset per depth level, plus a base inset.
double _indent(int depth) => 12 + depth * 14;

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onTap,
  });

  final FileTreeNode node;
  final int depth;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: 'Folder ${node.name}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Meet the 48px minimum interactive/tap-target size.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(left: _indent(depth), right: 12),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.node,
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  final FileTreeNode node;
  final int depth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'File ${node.name}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Meet the 48px minimum interactive/tap-target size.
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : null,
            padding: EdgeInsets.only(
              // Line files up under the folder label, past the disclosure slot.
              left: _indent(depth) + 22,
              right: 12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: selected ? theme.colorScheme.primary : theme.hintColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? theme.colorScheme.primary : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
