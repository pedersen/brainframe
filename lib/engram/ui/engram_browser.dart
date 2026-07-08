import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../asset_engram_store.dart';
import '../built_in_engrams.dart';
import '../engram.dart';
import '../engram_file_ops.dart';
import '../engram_repository.dart';
import '../engram_scope.dart';
import '../engram_store.dart';
import 'browser_preferences.dart';
import 'engram_switcher.dart';
import 'file_tree.dart';
import 'file_tree_node.dart';
import 'file_viewer.dart';
import 'help_overlay.dart';

/// Width below which the sidebar becomes an off-canvas drawer (phone). Above it
/// the sidebar and reader sit side-by-side with a draggable divider between.
const double _drawerBreakpoint = 720;

/// Sidebar width bounds and starting point for the draggable divider, in
/// logical pixels. The maximum is derived per-layout (leaving [_minReaderWidth]
/// for the reader); these are the fixed floor and default.
const double _minSidebarWidth = 180;
const double _defaultSidebarWidth = 260;
const double _minReaderWidth = 320;

/// Keyboard/assistive step when nudging the divider (arrow keys, screen-reader
/// increment/decrement).
const double _resizeStep = 24;

/// The read-only engram browser: a file-tree sidebar next to a Markdown reader.
///
/// It reads the active engram from [EngramScope], lists its files, and folds
/// them into a shallow tree. On a wide layout the sidebar and reader sit
/// side-by-side; on a phone the sidebar is a drawer opened from the app-bar
/// menu button, over a scrim. Selecting a file opens it in the reader (and, on
/// a phone, closes the drawer). This is the structure-only Step 8 UI — the
/// design handoff's bespoke styling is deferred.
/// A handle file-management actions use to ask the browser to re-list the
/// active engram after a mutation (new note/folder, rename, delete, move) and,
/// optionally, to select a path once the fresh listing loads.
///
/// The mutation itself happens through the store and `EngramFileOps`; this only
/// invalidates the browser's cached listing so the tree, the default selection,
/// and link resolution reflect the new state. Attach one via
/// [EngramBrowser.controller] — the standard controller idiom, like
/// `ScrollController`. Attaching the same instance to two browsers at once is a
/// usage error.
class EngramBrowserController {
  _EngramBrowserState? _state;

  void _attach(_EngramBrowserState state) {
    assert(_state == null, 'EngramBrowserController is already attached');
    _state = state;
  }

  void _detach(_EngramBrowserState state) {
    if (_state == state) _state = null;
  }

  /// Re-lists the active engram. When [selectPath] is given (typically a
  /// just-created note), it becomes the selection once the new listing loads;
  /// otherwise the current selection stands, falling back through the browser's
  /// default when the selected file no longer exists (e.g. after a delete).
  void refresh({String? selectPath}) =>
      _state?._refresh(selectPath: selectPath);
}

class EngramBrowser extends StatefulWidget {
  const EngramBrowser({
    super.key,
    required this.repository,
    this.preferences,
    this.controller,
  });

  /// Supplies the engram switcher its list of engrams and create/adopt actions.
  final EngramRepository repository;

  /// Device-local view state (sidebar width, per-engram collapsed folders).
  /// Injectable for tests; defaults to the app's shared preferences store.
  final BrowserPreferences? preferences;

  /// Optional seam for file-management actions to trigger a re-list after a
  /// store mutation. Null when nothing needs to invalidate the listing.
  final EngramBrowserController? controller;

  @override
  State<EngramBrowser> createState() => _EngramBrowserState();
}

class _EngramBrowserState extends State<EngramBrowser> {
  /// The file the user explicitly opened, if any. When it does not belong to
  /// the active engram (e.g. just after a switch), the effective selection
  /// falls back to a sensible default, so no reset is needed on switch.
  String? _selectedPath;
  bool _drawerOpen = false;

  late final BrowserPreferences _prefs =
      widget.preferences ?? BrowserPreferences(SharedPreferencesAsync());

  /// The active engram's file list plus its restored collapsed-folder set,
  /// loaded once per engram. Held in a field (not rebuilt in `build`) so
  /// selecting a file or dragging the divider never re-lists the store.
  Future<_BrowserData>? _data;
  String? _loadedEngramId;
  Locale? _loadedLocale;

  /// The active engram's store bound to the current locale — used for every
  /// content read so a built-in engram serves the localized page (falling back
  /// to English per file). A no-op for filesystem engrams.
  EngramStore? _contentStore;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(EngramBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  /// Re-issues the active engram's listing after a mutation, optionally moving
  /// the selection to [selectPath]. Invoked through [EngramBrowserController];
  /// only called once the engram has loaded, so [_contentStore] is set.
  void _refresh({String? selectPath}) {
    final engram = EngramScope.of(context).engram;
    setState(() {
      if (selectPath != null) _selectedPath = selectPath;
      _data = _load(engram, _contentStore!);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Both EngramScope and Localizations are inherited dependencies, so this
    // fires on first build, on every engram switch, and on a locale change —
    // exactly when the content store and its listing should be (re)issued.
    final engram = EngramScope.of(context).engram;
    final locale = Localizations.localeOf(context);
    if (engram.id != _loadedEngramId || locale != _loadedLocale) {
      _loadedEngramId = engram.id;
      _loadedLocale = locale;
      _contentStore = contentForLocale(engram.store, locale);
      _data = _load(engram, _contentStore!);
    }
  }

  Future<_BrowserData> _load(Engram engram, EngramStore store) async {
    final paths = await store.list();
    final directories = await store.listDirectories();
    final collapsed = await _prefs.collapsedFolders(engram.id);
    return _BrowserData(
      paths: paths,
      directories: directories,
      collapsed: collapsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final engram = EngramScope.of(context).engram;
    final isNarrow = MediaQuery.sizeOf(context).width < _drawerBreakpoint;

    return FutureBuilder<_BrowserData>(
      key: ValueKey(engram.id),
      future: _data,
      builder: (context, snapshot) {
        final loading = !snapshot.hasData && !snapshot.hasError;
        final data = snapshot.data;
        // Hide dotfiles and dot-directories (.git, .obsidian, the .brainframe
        // marker) from the browser, so the tree, the default selection, and
        // link resolution all see the same visible set.
        final paths = [
          for (final path in data?.paths ?? const <String>[])
            if (!isHiddenEngramPath(path)) path,
        ];
        // Empty folders the user created — no file reveals them, so the tree
        // needs them explicitly. Same hidden-path filter as files.
        final directories = [
          for (final path in data?.directories ?? const <String>[])
            if (!isHiddenEngramPath(path)) path,
        ];
        final collapsed = data?.collapsed ?? const <String>{};
        final selected = _effectiveSelection(paths);
        final title = selected != null
            ? _fileName(selected)
            : localizedEngramName(engram, AppLocalizations.of(context));

        return AppScaffold(
          title: title,
          leading: isNarrow
              ? _MenuButton(onPressed: () => setState(() => _drawerOpen = true))
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: AppLocalizations.of(context).helpTitle,
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
            directories: directories,
            collapsed: collapsed,
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
    required List<String> directories,
    required Set<String> collapsed,
    required String? selected,
  }) {
    final l10n = AppLocalizations.of(context);
    // Build the FileTree only once its saved collapsed set is loaded, so its
    // state seeds from that set rather than from an empty default during load.
    // (Keyed by engram id so switching engrams re-seeds from the new set.)
    final Widget tree = loading
        ? const SizedBox.shrink()
        : FileTree(
            key: ValueKey(engram.id),
            nodes: buildFileTree(paths, directoryPaths: directories),
            selectedPath: selected,
            onSelectFile: _selectFile,
            initialCollapsed: collapsed,
            onCollapsedChanged: (set) =>
                _prefs.setCollapsedFolders(engram.id, set),
            onRowAction: engram.readOnly ? null : _handleRowAction,
          );
    final sidebar = _Sidebar(
      engram: engram,
      repository: widget.repository,
      tree: tree,
      onNewNote: engram.readOnly ? null : _newNote,
      onNewFolder: engram.readOnly ? null : _newFolder,
    );
    final reader = _reader(
      l10n: l10n,
      engram: engram,
      loading: loading,
      hasError: hasError,
      paths: paths,
      selected: selected,
    );

    if (!isNarrow) {
      // Side-by-side with a draggable divider that remembers its width.
      return _ResizableSplitView(
        preferences: _prefs,
        sidebar: sidebar,
        reader: reader,
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
    required AppLocalizations l10n,
    required Engram engram,
    required bool loading,
    required bool hasError,
    required List<String> paths,
    required String? selected,
  }) {
    if (loading) {
      return Center(
        child: Semantics(
          label: l10n.browserLoading,
          child: const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    if (hasError) {
      return Center(child: Text(l10n.browserUnreadable));
    }
    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            paths.isEmpty ? l10n.engramEmpty : l10n.browserSelectFile,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return buildFileViewer(
      // The locale-bound store, so a built-in engram reads the localized page.
      store: _contentStore!,
      path: selected,
      availablePaths: paths.toSet(),
      onNavigateToFile: _selectFile,
      // Built-in engrams are read-only; a writable engram gets the editor.
      readOnly: engram.readOnly,
    );
  }

  void _selectFile(String path) => setState(() {
        _selectedPath = path;
        _drawerOpen = false;
      });

  /// Prompts for a name and creates a new Markdown note inside [parent] (the
  /// engram root when empty), seeded with an H1 derived from the name, then
  /// selects it (opening it in Edit) and closes the drawer. A collision with an
  /// existing note in that folder is avoided with the same "Name", "Name 2"
  /// numbering the store uses for folders.
  Future<void> _newNote({String parent = ''}) async {
    final store = _contentStore;
    if (store == null) return;
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameInputDialog(
        title: l10n.newNote,
        label: l10n.newNoteNameLabel,
        submitLabel: l10n.create,
      ),
    );
    if (name == null || !mounted) return; // cancelled

    final existingStems = <String>{
      for (final path in await store.list())
        if (_parentOf(path) == parent &&
            _lastSegment(path).toLowerCase().endsWith('.md'))
          _stemOf(_lastSegment(path), '.md'),
    };
    final stem = EngramFileOps.freeName(_sanitizeName(name), existingStems);
    final notePath = parent.isEmpty ? '$stem.md' : '$parent/$stem.md';
    await store.writeString(notePath, '# ${_noteTitle(stem)}\n');
    if (!mounted) return;
    setState(() => _drawerOpen = false);
    _refresh(selectPath: notePath);
  }

  /// Prompts for a name and creates a new empty folder inside [parent] (the
  /// engram root when empty), visible in the tree via
  /// [EngramStore.listDirectories], avoiding a collision with an existing folder
  /// in that parent using the same "Name", "Name 2" numbering.
  Future<void> _newFolder({String parent = ''}) async {
    final store = _contentStore;
    if (store == null) return;
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameInputDialog(
        title: l10n.newFolder,
        label: l10n.newFolderNameLabel,
        submitLabel: l10n.create,
      ),
    );
    if (name == null || !mounted) return; // cancelled

    final existing = <String>{
      for (final directory in await store.listDirectories())
        if (_parentOf(directory) == parent) _lastSegment(directory),
    };
    final folder = EngramFileOps.freeName(_sanitizeName(name), existing);
    final folderPath = parent.isEmpty ? folder : '$parent/$folder';
    await store.createDirectory(folderPath);
    if (!mounted) return;
    setState(() => _drawerOpen = false);
    _refresh();
  }

  /// Dispatches a row's "⋯" menu action.
  Future<void> _handleRowAction(
    FileTreeNode node,
    String fullPath,
    FileTreeRowAction action,
  ) async {
    switch (action) {
      case FileTreeRowAction.rename:
        await _renameEntry(node, fullPath);
      case FileTreeRowAction.delete:
        await _deleteEntry(node, fullPath);
      case FileTreeRowAction.newNoteHere:
        await _newNote(parent: fullPath);
      case FileTreeRowAction.newFolderHere:
        await _newFolder(parent: fullPath);
    }
  }

  /// Deletes the file or folder at [fullPath] after a confirmation. A file goes
  /// through `store.delete`; a folder (and everything in it) through
  /// `EngramFileOps.deleteFolder`. The listing is refreshed; if the open file
  /// was the target (or lived inside a deleted folder) it is no longer in the
  /// list, so `_effectiveSelection` falls back on its own.
  Future<void> _deleteEntry(FileTreeNode node, String fullPath) async {
    final store = _contentStore;
    if (store == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(node.isFolder
            ? l10n.deleteFolderConfirm(node.name)
            : l10n.deleteFileConfirm(node.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (node.isFolder) {
      await EngramFileOps(store).deleteFolder(fullPath);
    } else {
      await store.delete(fullPath);
    }
    if (!mounted) return;
    _refresh();
  }

  /// Renames the file or folder at [fullPath]: prompts for a new name (a file
  /// keeps its extension), avoids colliding with a same-kind sibling, moves it
  /// through the store / `EngramFileOps`, and keeps the open file selected under
  /// its new path.
  Future<void> _renameEntry(FileTreeNode node, String fullPath) async {
    final store = _contentStore;
    if (store == null) return;
    final l10n = AppLocalizations.of(context);
    final isFolder = node.isFolder;
    final extension = isFolder ? '' : _extensionOf(node.name);
    final currentStem =
        node.name.substring(0, node.name.length - extension.length);

    final input = await showDialog<String>(
      context: context,
      builder: (_) => _NameInputDialog(
        title: l10n.rename,
        label: l10n.renameNameLabel,
        submitLabel: l10n.rename,
        initialValue: currentStem,
      ),
    );
    if (input == null || !mounted) return;

    final parent = _parentOf(fullPath);
    final desiredStem = _sanitizeName(input);

    if (isFolder) {
      final siblings = <String>{
        for (final directory in await store.listDirectories())
          if (directory != fullPath && _parentOf(directory) == parent)
            _lastSegment(directory),
      };
      final newName = EngramFileOps.freeName(desiredStem, siblings);
      if (newName == node.name) return; // unchanged
      final newPath = parent.isEmpty ? newName : '$parent/$newName';
      await EngramFileOps(store).renameFolder(fullPath, newName);
      if (!mounted) return;
      _refresh(selectPath: _selectionAfterFolderMove(fullPath, newPath));
    } else {
      final siblingStems = <String>{
        for (final path in await store.list())
          if (path != fullPath &&
              _parentOf(path) == parent &&
              _extensionOf(_lastSegment(path)) == extension)
            _stemOf(_lastSegment(path), extension),
      };
      final newStem = EngramFileOps.freeName(desiredStem, siblingStems);
      final newName = '$newStem$extension';
      if (newName == node.name) return; // unchanged
      final newPath = parent.isEmpty ? newName : '$parent/$newName';
      await store.move(fullPath, newPath);
      if (!mounted) return;
      _refresh(selectPath: _selectedPath == fullPath ? newPath : null);
    }
  }

  /// The selection to restore after renaming a folder from [oldFolder] to
  /// [newFolder]: the open file's remapped path if it lived inside, else null
  /// (leave the current selection untouched).
  String? _selectionAfterFolderMove(String oldFolder, String newFolder) {
    final selected = _selectedPath;
    final prefix = '$oldFolder/';
    if (selected != null && selected.startsWith(prefix)) {
      return '$newFolder/${selected.substring(prefix.length)}';
    }
    return null;
  }

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

/// The engram-relative parent folder of [path] (`''` for a top-level entry).
String _parentOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash == -1 ? '' : path.substring(0, slash);
}

String _lastSegment(String path) => path.split('/').last;

/// The file extension of [name] *including* the leading dot (`.md`), or `''`
/// when it has none or is a dotfile.
String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot);
}

/// [name] with its [extension] (as returned by [_extensionOf]) removed.
String _stemOf(String name, String extension) =>
    name.substring(0, name.length - extension.length);

/// A filesystem-safe name from a user-entered [name], shared by new notes and
/// new folders: path separators become dashes, runs of whitespace collapse, and
/// a blank name falls back to "Untitled". The note flow adds the `.md`
/// extension. (Windows also forbids `:*?"<>|` and reserved device names —
/// tightening this to be Windows-safe is a tracked follow-up.)
String _sanitizeName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'Untitled' : cleaned;
}

/// The H1 title seeded into a new note, derived from its filename [stem]:
/// dashes/underscores become spaces and each word is capitalized, so
/// `the-beginning-of-infinity` reads as `The Beginning Of Infinity`.
String _noteTitle(String stem) {
  final words = stem
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// A name-prompt dialog with the given [title] and field [label], shared by the
/// new-note, new-folder, and rename actions. [initialValue] pre-fills the field
/// (with the text pre-selected, for rename); [submitLabel] names the confirm
/// button. Pops its text on submit (the button or the keyboard action), or null
/// on Cancel.
class _NameInputDialog extends StatefulWidget {
  const _NameInputDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String submitLabel;
  final String initialValue;

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );

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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// The active engram's loaded browser state: its file list, its directory list
/// (including empty folders), and the collapsed folders restored from this
/// device's saved preference.
class _BrowserData {
  const _BrowserData({
    required this.paths,
    required this.directories,
    required this.collapsed,
  });

  final List<String> paths;
  final List<String> directories;
  final Set<String> collapsed;
}

/// The sidebar: an optional action header, the file [tree], and a footer that
/// switches engrams.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.engram,
    required this.repository,
    required this.tree,
    this.onNewNote,
    this.onNewFolder,
  });

  final Engram engram;
  final EngramRepository repository;
  final Widget tree;

  /// Creates a new note / folder; null for a read-only engram, which shows no
  /// header. Both are null or both are set together.
  final VoidCallback? onNewNote;
  final VoidCallback? onNewFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            if (onNewNote != null && onNewFolder != null)
              _SidebarHeader(
                onNewNote: onNewNote!,
                onNewFolder: onNewFolder!,
              ),
            Expanded(child: tree),
            const Divider(height: 1),
            EngramSwitcher(repository: repository, current: engram),
          ],
        ),
      ),
    );
  }
}

/// The sidebar's file-management action header (writable engrams only).
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onNewNote, required this.onNewFolder});

  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
            onPressed: onNewFolder,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: l10n.newNote,
            onPressed: onNewNote,
          ),
        ],
      ),
    );
  }
}

/// A [sidebar] and [reader] side-by-side, separated by a divider the user can
/// drag to resize the sidebar. The chosen width is restored on launch and saved
/// (once, when the drag ends) to device-local preferences. Width is clamped so
/// neither pane starves; the drag handle is keyboard- and screen-reader
/// operable.
///
/// The width lives in this widget's own state, so dragging repaints only the
/// split — not the browser above it, which holds the engram's file list.
class _ResizableSplitView extends StatefulWidget {
  const _ResizableSplitView({
    required this.preferences,
    required this.sidebar,
    required this.reader,
  });

  final BrowserPreferences preferences;
  final Widget sidebar;
  final Widget reader;

  @override
  State<_ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<_ResizableSplitView> {
  // Null until the saved width loads (or if none was ever saved); the default
  // applies meanwhile. Always re-clamped to the live viewport in [build].
  double? _width;

  @override
  void initState() {
    super.initState();
    widget.preferences.sidebarWidth().then((saved) {
      if (mounted && saved != null) setState(() => _width = saved);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave room for the reader; never let the sidebar exceed that.
        final maxWidth =
            math.max(_minSidebarWidth, constraints.maxWidth - _minReaderWidth);
        final width =
            (_width ?? _defaultSidebarWidth).clamp(_minSidebarWidth, maxWidth);
        return Row(
          // Stretch so the reader fills the full pane height. Without it, Row's
          // default center alignment gives loose vertical constraints, the
          // reader's scroll view shrink-wraps to its content, and the Row then
          // centers that short block vertically.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: width, child: widget.sidebar),
            _ResizeHandle(
              width: width,
              minWidth: _minSidebarWidth,
              maxWidth: maxWidth,
              onResize: (next) => setState(() => _width = next),
              onResizeEnd: _persist,
            ),
            Expanded(child: widget.reader),
          ],
        );
      },
    );
  }

  void _persist() {
    if (_width != null) widget.preferences.setSidebarWidth(_width!);
  }
}

/// The draggable divider between the sidebar and reader.
///
/// A thin visual line inside a wider transparent hit strip (easier to grab than
/// a 1px target), showing a horizontal-resize cursor. It is fully accessible:
/// exposed to screen readers as a slider with increment/decrement actions, and
/// operable from a physical keyboard with the arrow keys once focused. All
/// nudges and drags feed [onResize]; [onResizeEnd] fires when the interaction
/// settles, so the host persists once rather than on every pixel.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    required this.onResizeEnd,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onResize;
  final VoidCallback onResizeEnd;

  double _clamp(double value) => value.clamp(minWidth, maxWidth);

  void _nudge(double delta) {
    onResize(_clamp(width + delta));
    onResizeEnd();
  }

  String _label(AppLocalizations l10n, double value) =>
      l10n.resizeHandleWidth(value.round());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      slider: true,
      label: l10n.resizeHandleLabel,
      // A slider with increase/decrease actions must declare all three values.
      value: _label(l10n, width),
      increasedValue: _label(l10n, _clamp(width + _resizeStep)),
      decreasedValue: _label(l10n, _clamp(width - _resizeStep)),
      // Screen-reader increase/decrease adjust the sidebar width.
      onIncrease: () => _nudge(_resizeStep),
      onDecrease: () => _nudge(-_resizeStep),
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          _NudgeIntent: CallbackAction<_NudgeIntent>(
            onInvoke: (intent) {
              _nudge(intent.delta);
              return null;
            },
          ),
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              _NudgeIntent(-_resizeStep),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              _NudgeIntent(_resizeStep),
        },
        mouseCursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              onResize(_clamp(width + details.delta.dx)),
          onHorizontalDragEnd: (_) => onResizeEnd(),
          child: SizedBox(
            width: 12,
            child: Center(
              child: ColoredBox(
                color: theme.dividerColor,
                child: const SizedBox(width: 1, height: double.infinity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intent for a keyboard/assistive nudge of the divider by [delta] pixels.
class _NudgeIntent extends Intent {
  const _NudgeIntent(this.delta);

  final double delta;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: onPressed,
      tooltip: AppLocalizations.of(context).menuOpenBrowser,
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
              label: AppLocalizations.of(context).drawerCloseBrowser,
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
