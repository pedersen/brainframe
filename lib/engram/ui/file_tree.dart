import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'file_tree_node.dart';

/// An action a user can invoke on a file-tree row via its "⋯" menu. The menu is
/// the stable seam: how it is *triggered* (a pinned column here) is decoupled
/// from the actions, so the trigger can change later without touching the
/// action wiring above.
enum FileTreeRowAction { rename }

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
    this.onRowAction,
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

  /// Invoked when a row's "⋯" menu action is chosen, with the row's [node], its
  /// engram-relative [fullPath], and the [action]. Null for a read-only engram,
  /// which shows no action column at all.
  final void Function(
    FileTreeNode node,
    String fullPath,
    FileTreeRowAction action,
  )? onRowAction;

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

  // Drives the pinned action column so it scrolls in lockstep with the tree.
  // The column never scrolls on its own (NeverScrollableScrollPhysics); this
  // one-way mirror keeps the "⋯" buttons aligned to their rows. Both lists use
  // the same itemExtent, so mirroring the offset aligns row-for-row exactly.
  final ScrollController _actionController = ScrollController();

  // Memoized widest-row measurement (see [_contentWidth]). Invalidated when the
  // node set, the collapsed set, or the text scale changes — not on scroll,
  // resize, or selection, which is what keeps large engrams responsive.
  double? _cachedWidth;
  List<FileTreeNode>? _cachedNodes;
  int? _cachedCollapsedVersion;
  double? _cachedScaleProbe;

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_mirrorScrollToActionColumn);
  }

  void _mirrorScrollToActionColumn() {
    if (!_actionController.hasClients) return;
    final target = _verticalController.offset
        .clamp(0.0, _actionController.position.maxScrollExtent);
    if (_actionController.offset != target) _actionController.jumpTo(target);
  }

  @override
  void dispose() {
    _verticalController.removeListener(_mirrorScrollToActionColumn);
    _verticalController.dispose();
    _horizontalController.dispose();
    _actionController.dispose();
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
    final rowExtent = _rowExtent(context);
    final tree = _treeView(rows, rowExtent);

    // Read-only engram: no action column, so the tree is exactly as before.
    if (widget.onRowAction == null) return tree;

    // Writable engram: pin an always-visible "⋯" action column beside the
    // horizontally-scrolling tree, so a long file name can never push the row
    // actions off-screen.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tree),
        _ActionColumn(
          rows: rows,
          rowExtent: rowExtent,
          controller: _actionController,
          onRowAction: widget.onRowAction!,
        ),
      ],
    );
  }

  Widget _treeView(List<_Row> rows, double rowExtent) {
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
                  // Fixed row height: aligns the action column row-for-row and
                  // lets the lazy list skip per-row measurement.
                  itemExtent: rowExtent,
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

  /// The uniform per-row height for both the tree and the action column: a
  /// single-line row scaled by the text scale, never below the 48px tap target.
  double _rowExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    return math.max(48.0, scaler.scale(fontSize) * 1.4 + 16);
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

/// The pinned column of "⋯" row-action buttons, one per visible row, mirroring
/// the tree's vertical scroll so each button stays aligned with its row.
class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.rows,
    required this.rowExtent,
    required this.controller,
    required this.onRowAction,
  });

  final List<_Row> rows;
  final double rowExtent;
  final ScrollController controller;
  final void Function(FileTreeNode, String, FileTreeRowAction) onRowAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: ListView.builder(
        controller: controller,
        primary: false,
        // Driven by the tree's scroll (see _mirrorScrollToActionColumn); never
        // scrolls on its own, so it can't drift out of alignment.
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: rowExtent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _RowActionButton(
            node: row.node,
            fullPath: row.fullPath,
            onRowAction: onRowAction,
          );
        },
      ),
    );
  }
}

/// One row's "⋯" menu button. The menu is the stable seam; the chosen action is
/// dispatched to [onRowAction] above the tree, independent of this trigger.
class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.node,
    required this.fullPath,
    required this.onRowAction,
  });

  final FileTreeNode node;
  final String fullPath;
  final void Function(FileTreeNode, String, FileTreeRowAction) onRowAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<FileTreeRowAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.rowActionsTooltip(node.name),
      onSelected: (action) => onRowAction(node, fullPath, action),
      itemBuilder: (context) => <PopupMenuEntry<FileTreeRowAction>>[
        PopupMenuItem<FileTreeRowAction>(
          value: FileTreeRowAction.rename,
          child: Text(l10n.rename),
        ),
      ],
    );
  }
}
