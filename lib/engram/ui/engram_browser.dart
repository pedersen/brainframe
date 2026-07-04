import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../asset_engram_store.dart';
import '../built_in_engrams.dart';
import '../engram.dart';
import '../engram_repository.dart';
import '../engram_scope.dart';
import '../engram_store.dart';
import 'browser_preferences.dart';
import 'engram_switcher.dart';
import 'file_tree.dart';
import 'file_tree_node.dart';
import 'help_overlay.dart';
import 'markdown_reader.dart';

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
class EngramBrowser extends StatefulWidget {
  const EngramBrowser({
    super.key,
    required this.repository,
    this.preferences,
  });

  /// Supplies the engram switcher its list of engrams and create/adopt actions.
  final EngramRepository repository;

  /// Device-local view state (sidebar width, per-engram collapsed folders).
  /// Injectable for tests; defaults to the app's shared preferences store.
  final BrowserPreferences? preferences;

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
    final collapsed = await _prefs.collapsedFolders(engram.id);
    return _BrowserData(paths: paths, collapsed: collapsed);
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
        final collapsed = data?.collapsed ?? const <String>{};
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
            nodes: buildFileTree(paths),
            selectedPath: selected,
            onSelectFile: _selectFile,
            initialCollapsed: collapsed,
            onCollapsedChanged: (set) =>
                _prefs.setCollapsedFolders(engram.id, set),
          );
    final sidebar = _Sidebar(
      engram: engram,
      repository: widget.repository,
      tree: tree,
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
    return MarkdownReader(
      // The locale-bound store, so a built-in engram reads the localized page.
      store: _contentStore!,
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

/// The active engram's loaded browser state: its file list and the collapsed
/// folders restored from this device's saved preference.
class _BrowserData {
  const _BrowserData({required this.paths, required this.collapsed});

  final List<String> paths;
  final Set<String> collapsed;
}

/// The sidebar: the file [tree] above a footer that switches engrams.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.engram,
    required this.repository,
    required this.tree,
  });

  final Engram engram;
  final EngramRepository repository;
  final Widget tree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(child: tree),
            const Divider(height: 1),
            EngramSwitcher(repository: repository, current: engram),
          ],
        ),
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
