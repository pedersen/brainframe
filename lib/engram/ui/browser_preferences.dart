import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/device_settings.dart';
import '../../settings/settings_store.dart';

/// Device-local view state for the engram browser: the sidebar width and each
/// engram's collapsed-folder set.
///
/// These are **per-device application preferences, not engram content.** They
/// live on the device (`shared_preferences`) — never inside the engram's
/// files — so they are naturally excluded when cross-device engram sync is
/// added later: syncing an engram moves its notes, not this device's chosen
/// sidebar width or which folders it happens to have collapsed. The sidebar
/// width is a declared per-device [Setting] ([sidebarWidthSetting]) so it shares
/// the settings store's backing and its "reset to defaults"; the per-engram
/// collapsed-folder sets stay as their own `ui.`-namespaced keys.
class BrowserPreferences {
  BrowserPreferences(this._prefs);

  final SharedPreferencesAsync _prefs;

  /// The device tier of the settings store, over the same `shared_preferences`
  /// — used for the sidebar width so it resets with the rest of the layout.
  late final SettingsStore _deviceStore = SettingsStore(
    device: DeviceSettingsBackend(_prefs),
    engram: () => const NullSettingsBackend(),
  );

  /// Collapsed folders are per-engram — folder paths differ between engrams —
  /// so each engram id gets its own key.
  static String _collapsedKey(String engramId) =>
      'ui.fileTree.collapsed.$engramId';

  /// The saved sidebar width in logical pixels, or null if the user has never
  /// resized it (callers apply their own default and clamp to the viewport).
  Future<double?> sidebarWidth() => _deviceStore.read(sidebarWidthSetting);

  /// Records the sidebar [width] the user dragged to.
  Future<void> setSidebarWidth(double width) =>
      _deviceStore.write(sidebarWidthSetting, width);

  /// The set of collapsed folder paths for [engramId] (engram-relative, e.g.
  /// `notes/drafts`). Empty when nothing is stored — folders default to open.
  Future<Set<String>> collapsedFolders(String engramId) async =>
      (await _prefs.getStringList(_collapsedKey(engramId)))?.toSet() ??
      <String>{};

  /// Persists the collapsed folder [paths] for [engramId]. Stored sorted so the
  /// serialized value is stable regardless of collapse order.
  Future<void> setCollapsedFolders(String engramId, Set<String> paths) =>
      _prefs.setStringList(_collapsedKey(engramId), paths.toList()..sort());
}
