import 'package:flutter/material.dart';

import '../engram/engram.dart';
import '../window/window_state.dart';
import 'device_settings.dart';
import 'settings_store.dart';

/// A per-engram theme choice. [followDefault] defers to the device-wide default
/// ([defaultThemeSetting]); the rest force a specific mode for this engram only.
enum EngramThemeChoice { followDefault, system, light, dark }

/// The device-wide default theme — used everywhere unless the active engram
/// overrides it, and the only theme read-only/built-in engrams can show.
final Setting<ThemeMode> defaultThemeSetting = Setting.enumerated<ThemeMode>(
  key: 'theme.default',
  tier: SettingTier.device,
  defaultValue: ThemeMode.system,
  values: ThemeMode.values,
);

/// The active engram's optional theme override (per-engram tier — travels with
/// the engram). Defaults to [EngramThemeChoice.followDefault].
final Setting<EngramThemeChoice> engramThemeSetting =
    Setting.enumerated<EngramThemeChoice>(
      key: 'theme.override',
      tier: SettingTier.engram,
      defaultValue: EngramThemeChoice.followDefault,
      values: EngramThemeChoice.values,
    );

/// Mutable, persisted look-and-feel state that backs [AppSettings] and drives
/// the app's theme.
///
/// Theme resolves from two tiers: a **device-wide default** and an optional
/// **per-engram override**. Because the theme is applied at the app root (above
/// `EngramScope`) but the override lives with the active engram (below it), the
/// root reports the active engram here via [setActiveEngram] on startup and on
/// every switch; this controller reloads the override and recomputes the
/// effective [themeMode], notifying listeners so the root rebuilds.
///
/// Read-only/built-in engrams cannot store an override, so [setActiveEngram]
/// binds them to a [NullSettingsBackend]: they always show the device default,
/// and [canOverridePerEngram] is false so the UI disables their override.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    SettingsBackend device = const NullSettingsBackend(),
  }) {
    _store = SettingsStore(device: device, engram: () => _engramBackend);
  }

  late final SettingsStore _store;

  /// The app's shared settings store, exposed to the tree via `SettingsScope`
  /// so any feature or plugin can declare and persist its own [Setting]s through
  /// the same two tiers. Its per-engram tier tracks the active engram (see
  /// [setActiveEngram]).
  SettingsStore get store => _store;

  SettingsBackend _engramBackend = const NullSettingsBackend();
  ThemeMode _defaultTheme = ThemeMode.system;
  EngramThemeChoice _engramChoice = EngramThemeChoice.followDefault;
  bool _engramWritable = false;

  /// The effective theme mode after resolving the active engram's override
  /// against the device default.
  ThemeMode get themeMode => switch (_engramChoice) {
    EngramThemeChoice.followDefault => _defaultTheme,
    EngramThemeChoice.system => ThemeMode.system,
    EngramThemeChoice.light => ThemeMode.light,
    EngramThemeChoice.dark => ThemeMode.dark,
  };

  /// The device-wide default theme (the [SettingTier.device] value).
  ThemeMode get defaultTheme => _defaultTheme;

  /// The active engram's override choice.
  EngramThemeChoice get engramThemeChoice => _engramChoice;

  /// Whether the active engram can store a per-engram override (false for
  /// read-only/built-in engrams).
  bool get canOverridePerEngram => _engramWritable;

  /// Builds a controller with the device default restored from [device].
  static Future<AppSettingsController> load(SettingsBackend device) async {
    final controller = AppSettingsController(device: device);
    controller._defaultTheme = await controller._store.read(
      defaultThemeSetting,
    );
    return controller;
  }

  /// Reports the newly-active [engram] (on startup and every switch): rebinds
  /// the per-engram tier and reloads its theme override.
  Future<void> setActiveEngram(Engram engram) async {
    _engramWritable = !engram.readOnly;
    _engramBackend = engram.readOnly
        ? const NullSettingsBackend()
        : EngramSettingsBackend(engram.store);
    _engramChoice = await _store.read(engramThemeSetting);
    notifyListeners();
  }

  /// Sets the device-wide default theme and persists it.
  Future<void> setDefaultTheme(ThemeMode mode) async {
    if (mode == _defaultTheme) return;
    _defaultTheme = mode;
    notifyListeners();
    await _store.write(defaultThemeSetting, mode);
  }

  /// Sets the active engram's theme override and persists it in that engram.
  /// A no-op when the engram can't store one ([canOverridePerEngram] false).
  Future<void> setEngramThemeChoice(EngramThemeChoice choice) async {
    if (!_engramWritable || choice == _engramChoice) return;
    _engramChoice = choice;
    notifyListeners();
    await _store.write(engramThemeSetting, choice);
  }

  /// Clears the per-device window geometry and sidebar width, so the window and
  /// layout return to their defaults on next launch. The user sets these by
  /// dragging, so this is the only control offered for them.
  Future<void> resetWindowAndLayout() async {
    // Stop persisting the current geometry, or the save-on-exit would rewrite
    // what we're about to clear and undo the reset.
    suspendWindowStatePersistence();
    await _store.write(windowStateSetting, null);
    await _store.write(sidebarWidthSetting, null);
  }
}
