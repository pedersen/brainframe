import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'file_tree_node.dart';

/// The read-only file browser: a shallow folder tree over an engram's files.
///
/// Folders expand/collapse in place (all open by default, so a small engram
/// shows everything); files are selectable and report taps via [onSelectFile].
/// The currently open file ([selectedPath]) is highlighted. Indentation and a
/// leading disclosure triangle / file glyph convey structure without relying on
/// the design handoff's bespoke styling (Step 8 is structure-only).
///
/// The list scrolls both ways so long file names stay reachable. To stay fast
/// on large engrams (thousands of files) the vertical axis is a lazy
/// [ListView.builder] — only visible rows are built. A lazy list needs a fixed
/// cross-axis width, so the widest row is measured once with a [TextPainter]
/// (memoized), rather than laying every row out via `IntrinsicWidth`.
class FileTree extends StatefulWidget {
  const FileTree({
    super.key,
    required this.nodes,
    required this.selectedPath,
    required this.onSelectFile,
    this.initialCollapsed = const <String>{},
    this.onCollapsedChanged,
  });

  /// The roots of the tree (see [buildFileTree]).
  final List<FileTreeNode> nodes;

  /// The engram-relative path of the open file, or null if none is open.
  final String? selectedPath;

  final void Function(String path) onSelectFile;

  /// Folder paths (engram-relative) that start collapsed, restored from a saved
  /// per-engram preference. Read once to seed state; give the tree a [Key] tied
  /// to the engram so switching engrams re-seeds from that engram's saved set.
  final Set<String> initialCollapsed;

  /// Called with the full collapsed set whenever the user expands or collapses
  /// a folder, so the host can persist it. The tree owns the live state; this
  /// is a notification, not a controlling input.
  final void Function(Set<String> collapsed)? onCollapsedChanged;

  @override
  State<FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends State<FileTree> {
  // Folders collapsed by their full path. Absent means expanded (default open).
  // Seeded from the saved preference; see [FileTree.initialCollapsed].
  late final Set<String> _collapsed = {...widget.initialCollapsed};

  // Bumped whenever the collapsed set changes, so the memoized content-width
  // measurement below knows the visible row set has changed.
  int _collapsedVersion = 0;

  // One controller per axis, each shared by a Scrollbar and its scroll view.
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // Memoized widest-row measurement (see [_contentWidth]). Invalidated when the
  // node set, the collapsed set, or the text scale changes — not on scroll,
  // resize, or selection, which is what keeps large engrams responsive.
  double? _cachedWidth;
  List<FileTreeNode>? _cachedNodes;
  int? _cachedCollapsedVersion;
  double? _cachedScaleProbe;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).engramEmpty,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // The flat list of currently-visible rows. Cheap to rebuild each layout
    // (one object per visible node); the expensive width measurement over it is
    // memoized separately.
    final rows = _visibleRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            math.max(_contentWidth(context, rows), constraints.maxWidth);

        // Both scrollbars sit outside the horizontal scroll view so they stay
        // pinned to the sidebar edges instead of sliding away when the content
        // is panned. The vertical ListView's notifications reach the outer
        // vertical Scrollbar one viewport deep (past the horizontal scroll
        // view), hence the depth == 1 predicate; the horizontal Scrollbar wraps
        // its scroll view directly and takes the default depth == 0.
        return Scrollbar(
          controller: _verticalController,
          notificationPredicate: (notification) => notification.depth == 1,
          child: Scrollbar(
            controller: _horizontalController,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: ListView.builder(
                  controller: _verticalController,
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => _buildRow(rows[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Flattens the tree into the currently-visible rows, honoring collapse
  /// state. Folders that are collapsed contribute a row but not their children.
  List<_Row> _visibleRows() {
    final rows = <_Row>[];
    void walk(FileTreeNode node, int depth, String parentPath) {
      final fullPath =
          parentPath.isEmpty ? node.name : '$parentPath/${node.name}';
      if (!node.isFolder) {
        rows.add(_Row(node: node, depth: depth, fullPath: fullPath));
        return;
      }
      final expanded = !_collapsed.contains(fullPath);
      rows.add(_Row(node: node, depth: depth, fullPath: fullPath));
      if (expanded) {
        for (final child in node.children) {
          walk(child, depth + 1, fullPath);
        }
      }
    }

    for (final node in widget.nodes) {
      walk(node, 0, '');
    }
    return rows;
  }

  Widget _buildRow(_Row row) {
    final node = row.node;
    if (!node.isFolder) {
      return _FileRow(
        node: node,
        depth: row.depth,
        selected: node.path == widget.selectedPath,
        onTap: () => widget.onSelectFile(node.path!),
      );
    }
    final expanded = !_collapsed.contains(row.fullPath);
    return _FolderRow(
      node: node,
      depth: row.depth,
      expanded: expanded,
      onTap: () => _toggleFolder(row.fullPath, expanded),
    );
  }

  void _toggleFolder(String fullPath, bool expanded) {
    setState(() {
      if (expanded) {
        _collapsed.add(fullPath);
      } else {
        _collapsed.remove(fullPath);
      }
      _collapsedVersion++;
    });
    // Notify after the mutation so the host persists the new set. A fresh copy
    // keeps the caller from aliasing our mutable state.
    widget.onCollapsedChanged?.call(Set<String>.of(_collapsed));
  }

  /// The width the row column needs so the longest name is fully visible.
  ///
  /// Measured once per (node set, collapse state, text scale) with a single
  /// reused [TextPainter], then memoized. Names are measured in the heaviest
  /// weight a row can use (folders and the selected file are semibold), so the
  /// result is never an under-estimate that would clip a name.
  double _contentWidth(BuildContext context, List<_Row> rows) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleProbe = textScaler.scale(100);
    if (_cachedWidth != null &&
        identical(_cachedNodes, widget.nodes) &&
        _cachedCollapsedVersion == _collapsedVersion &&
        _cachedScaleProbe == scaleProbe) {
      return _cachedWidth!;
    }

    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    );
    var maxWidth = 0.0;
    for (final row in rows) {
      painter.text = TextSpan(text: row.node.name, style: style);
      painter.layout();
      final left = row.node.isFolder
          ? _folderTextLeft(row.depth)
          : _fileTextLeft(row.depth);
      final width = left + painter.width + _kRowRightPadding + _kWidthSlack;
      if (width > maxWidth) maxWidth = width;
    }
    painter.dispose();

    _cachedWidth = maxWidth;
    _cachedNodes = widget.nodes;
    _cachedCollapsedVersion = _collapsedVersion;
    _cachedScaleProbe = scaleProbe;
    return maxWidth;
  }
}

/// A visible row in the flattened tree: a [node] at an indentation [depth],
/// keyed by its [fullPath] (used to toggle folder collapse state).
class _Row {
  const _Row({required this.node, required this.depth, required this.fullPath});

  final FileTreeNode node;
  final int depth;
  final String fullPath;
}

/// Shared left inset per depth level, plus a base inset.
double _indent(int depth) => 12 + depth * 14;

// Row metrics, shared between the row widgets and the width measurement so the
// two can't drift. An Icon's box is square, so its size doubles as its width.
const double _kFolderIconWidth = 18;
const double _kFolderIconGap = 4;
const double _kFileIconWidth = 15;
const double _kFileIconGap = 6;
// Files sit one disclosure-slot further in than the folder label above them.
const double _kFileExtraIndent = 22;
const double _kRowRightPadding = 12;
// A little breathing room past the measured name, and a hedge against subpixel
// rounding so the last glyph never clips at the right edge.
const double _kWidthSlack = 4;

/// Left inset of a folder row's text: indent + disclosure icon + gap.
double _folderTextLeft(int depth) =>
    _indent(depth) + _kFolderIconWidth + _kFolderIconGap;

/// Left inset of a file row's text: indent + disclosure slot + glyph + gap.
double _fileTextLeft(int depth) =>
    _indent(depth) + _kFileExtraIndent + _kFileIconWidth + _kFileIconGap;

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
      label: AppLocalizations.of(context).fileTreeFolder(node.name),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Meet the 48px minimum interactive/tap-target size.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(
              left: _indent(depth),
              right: _kRowRightPadding,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: _kFolderIconWidth,
                ),
                const SizedBox(width: _kFolderIconGap),
                // No Expanded/ellipsis: the row sizes to the full name and the
                // horizontal scroll view reaches anything past the sidebar edge.
                Text(
                  node.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
      label: AppLocalizations.of(context).fileTreeFile(node.name),
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
              left: _indent(depth) + _kFileExtraIndent,
              right: _kRowRightPadding,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: _kFileIconWidth,
                  color: selected ? theme.colorScheme.primary : theme.hintColor,
                ),
                const SizedBox(width: _kFileIconGap),
                // No Expanded/ellipsis: the row sizes to the full name and the
                // horizontal scroll view reaches anything past the sidebar edge.
                Text(
                  node.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? theme.colorScheme.primary : null,
                    fontWeight: selected ? FontWeight.w600 : null,
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
