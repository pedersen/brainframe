import 'package:flutter/widgets.dart';

import 'settings_store.dart';

/// Exposes the app's shared [SettingsStore] to the widget tree — the single
/// seam every feature and (future) plugin uses to declare and persist a
/// preference.
///
/// The pattern:
///
/// ```dart
/// // Declare once (anywhere), picking the tier:
/// final myFlag = Setting.boolean(
///   key: 'myPlugin.flag', tier: SettingTier.engram, defaultValue: true);
///
/// // Read / write through the scoped store:
/// final on = await SettingsScope.of(context).read(myFlag);
/// await SettingsScope.of(context).write(myFlag, false);
/// ```
///
/// The store routes each setting to its tier — per-device (this machine) or
/// per-engram (stored in the active engram, so it travels with it) — the same
/// two tiers core uses. A plugin contributes its settings *UI* through the
/// registry (`settingsRegistry.registerCategory`) and its persisted *values*
/// through this store.
///
/// Placed above the `MaterialApp` (like `RepositoryScope`) so routes pushed onto
/// the navigator — the Settings screen included — can reach it. The store
/// instance is stable; the active-engram tier it resolves updates underneath as
/// the user switches engrams, so callers never re-fetch the store on a switch.
class SettingsScope extends InheritedWidget {
  const SettingsScope({super.key, required this.store, required super.child});

  final SettingsStore store;

  static SettingsStore of(BuildContext context) {
    final store = maybeOf(context);
    assert(store != null, 'No SettingsScope found in the widget tree.');
    return store!;
  }

  static SettingsStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.store;

  @override
  bool updateShouldNotify(SettingsScope oldWidget) => store != oldWidget.store;
}
