import 'package:shared_preferences/shared_preferences.dart';

/// Device-local view state for the engram browser: the sidebar width and each
/// engram's collapsed-folder set.
///
/// These are **per-device application preferences, not engram content.** They
/// live in `shared_preferences` — never inside the engram's files — so they are
/// naturally excluded when cross-device engram sync is added later: syncing an
/// engram moves its notes, not this device's chosen sidebar width or which
/// folders it happens to have collapsed. Keep it that way; do not migrate this
/// state into the engram store.
///
/// Keys are namespaced under `ui.` to sit alongside the app's other local
/// preferences (the engram registry, last-opened, window geometry).
class BrowserPreferences {
  const BrowserPreferences(this._prefs);

  final SharedPreferencesAsync _prefs;

  /// One sidebar width for the whole app (not per-engram): switching engrams
  /// keeps the chrome stable, matching how file sidebars behave elsewhere.
  static const String _widthKey = 'ui.sidebar.width';

  /// Collapsed folders are per-engram — folder paths differ between engrams —
  /// so each engram id gets its own key.
  static String _collapsedKey(String engramId) =>
      'ui.fileTree.collapsed.$engramId';

  /// The saved sidebar width in logical pixels, or null if the user has never
  /// resized it (callers apply their own default and clamp to the viewport).
  Future<double?> sidebarWidth() => _prefs.getDouble(_widthKey);

  /// Records the sidebar [width] the user dragged to.
  Future<void> setSidebarWidth(double width) =>
      _prefs.setDouble(_widthKey, width);

  /// The set of collapsed folder paths for [engramId] (engram-relative, e.g.
  /// `notes/drafts`). Empty when nothing is stored — folders default to open.
  Future<Set<String>> collapsedFolders(String engramId) async =>
      (await _prefs.getStringList(_collapsedKey(engramId)))?.toSet() ??
      <String>{};

  /// Persists the collapsed folder [paths] for [engramId]. Stored sorted so the
  /// serialized value is stable regardless of collapse order.
  Future<void> setCollapsedFolders(String engramId, Set<String> paths) =>
      _prefs.setStringList(
        _collapsedKey(engramId),
        paths.toList()..sort(),
      );
}
