import 'package:flutter/material.dart';

import '../../widgets/app_scaffold.dart';
import '../built_in_engrams.dart';
import '../engram.dart';
import '../engram_repository.dart';
import '../engram_scope.dart';
import 'engram_switcher.dart';
import 'file_tree.dart';
import 'file_tree_node.dart';
import 'help_overlay.dart';
import 'markdown_reader.dart';

/// Width below which the sidebar becomes an off-canvas drawer (phone).
const double _drawerBreakpoint = 720;

/// The read-only engram browser: a file-tree sidebar next to a Markdown reader.
///
/// It reads the active engram from [EngramScope], lists its files, and folds
/// them into a shallow tree. On a wide layout the sidebar and reader sit
/// side-by-side; on a phone the sidebar is a drawer opened from the app-bar
/// menu button, over a scrim. Selecting a file opens it in the reader (and, on
/// a phone, closes the drawer). This is the structure-only Step 8 UI — the
/// design handoff's bespoke styling is deferred.
class EngramBrowser extends StatefulWidget {
  const EngramBrowser({super.key, required this.repository});

  /// Supplies the engram switcher its list of engrams and create/adopt actions.
  final EngramRepository repository;

  @override
  State<EngramBrowser> createState() => _EngramBrowserState();
}

class _EngramBrowserState extends State<EngramBrowser> {
  /// The file the user explicitly opened, if any. When it does not belong to
  /// the active engram (e.g. just after a switch), the effective selection
  /// falls back to a sensible default, so no reset is needed on switch.
  String? _selectedPath;
  bool _drawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final engram = EngramScope.of(context).engram;
    final isNarrow = MediaQuery.sizeOf(context).width < _drawerBreakpoint;

    return FutureBuilder<List<String>>(
      key: ValueKey(engram.id),
      future: engram.store.list(),
      builder: (context, snapshot) {
        final loading = !snapshot.hasData && !snapshot.hasError;
        // Hide dotfiles and dot-directories (.git, .obsidian, the .brainframe
        // marker) from the browser, so the tree, the default selection, and
        // link resolution all see the same visible set.
        final paths = [
          for (final path in snapshot.data ?? const <String>[])
            if (!isHiddenEngramPath(path)) path,
        ];
        final selected = _effectiveSelection(paths);
        final title = selected != null ? _fileName(selected) : engram.displayName;

        return AppScaffold(
          title: title,
          leading: isNarrow
              ? _MenuButton(onPressed: () => setState(() => _drawerOpen = true))
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: () => showHelpOverlay(context, builtInHelpEngram()),
            ),
          ],
          body: _body(
            context,
            engram: engram,
            isNarrow: isNarrow,
            loading: loading,
            hasError: snapshot.hasError,
            paths: paths,
            selected: selected,
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context, {
    required Engram engram,
    required bool isNarrow,
    required bool loading,
    required bool hasError,
    required List<String> paths,
    required String? selected,
  }) {
    final sidebar = _Sidebar(
      engram: engram,
      repository: widget.repository,
      nodes: buildFileTree(paths),
      selectedPath: selected,
      onSelectFile: _selectFile,
    );
    final reader = _reader(
      engram: engram,
      loading: loading,
      hasError: hasError,
      paths: paths,
      selected: selected,
    );

    if (!isNarrow) {
      final wide = MediaQuery.sizeOf(context).width >= 1080;
      return Row(
        children: [
          SizedBox(width: wide ? 260 : 210, child: sidebar),
          const VerticalDivider(width: 1),
          Expanded(child: reader),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: reader),
        _SlideDrawer(
          open: _drawerOpen,
          width: 288,
          onClose: () => setState(() => _drawerOpen = false),
          child: sidebar,
        ),
      ],
    );
  }

  Widget _reader({
    required Engram engram,
    required bool loading,
    required bool hasError,
    required List<String> paths,
    required String? selected,
  }) {
    if (loading) {
      return Center(
        child: Semantics(
          label: 'Loading engram',
          child: const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    if (hasError) {
      return const Center(child: Text('Could not read this engram.'));
    }
    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            paths.isEmpty
                ? 'This engram has no files yet.'
                : 'Select a file to read it.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return MarkdownReader(
      store: engram.store,
      path: selected,
      availablePaths: paths.toSet(),
      onNavigateToFile: _selectFile,
    );
  }

  void _selectFile(String path) => setState(() {
        _selectedPath = path;
        _drawerOpen = false;
      });

  /// The file to show: the user's selection when it belongs to [paths],
  /// otherwise a sensible default (a welcome/index file, else the first).
  String? _effectiveSelection(List<String> paths) {
    if (_selectedPath != null && paths.contains(_selectedPath)) {
      return _selectedPath;
    }
    if (paths.isEmpty) return null;
    for (final preferred in const ['welcome.md', 'index.md', 'README.md']) {
      if (paths.contains(preferred)) return preferred;
    }
    return (paths.toList()..sort()).first;
  }
}

String _fileName(String path) => path.split('/').last;

/// The sidebar: the file tree above a footer that names the current engram.
/// The footer becomes the engram switcher in the next step; for now it is a
/// static label carrying the engram's name and read-only state.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.engram,
    required this.repository,
    required this.nodes,
    required this.selectedPath,
    required this.onSelectFile,
  });

  final Engram engram;
  final EngramRepository repository;
  final List<FileTreeNode> nodes;
  final String? selectedPath;
  final void Function(String path) onSelectFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(
              child: FileTree(
                nodes: nodes,
                selectedPath: selectedPath,
                onSelectFile: onSelectFile,
              ),
            ),
            const Divider(height: 1),
            EngramSwitcher(repository: repository, current: engram),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: onPressed,
      tooltip: 'Open file browser',
    );
  }
}

/// A left-anchored off-canvas panel with a tap-to-close scrim. Slide and fade
/// respect Reduce Motion (`MediaQuery.disableAnimations`) — instantaneous on
/// the e-ink target and for users who ask for reduced motion.
class _SlideDrawer extends StatelessWidget {
  const _SlideDrawer({
    required this.open,
    required this.width,
    required this.onClose,
    required this.child,
  });

  final bool open;
  final double width;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 270);
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: duration,
            child: Semantics(
              label: 'Close file browser',
              button: true,
              child: GestureDetector(
                onTap: onClose,
                child: const ColoredBox(
                  color: Color(0x80000000),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            curve: Curves.ease,
            left: open ? 0 : -width,
            top: 0,
            bottom: 0,
            width: width,
            child: Material(elevation: 16, child: child),
          ),
        ],
      ),
    );
  }
}
