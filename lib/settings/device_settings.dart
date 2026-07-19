import 'settings_store.dart';

/// Per-device settings that were previously ad-hoc state, now declared in the
/// settings store's [SettingTier.device] tier so they share one backing and can
/// be reset together. They are still surfaced only as a "reset to defaults"
/// action — the user sets them by dragging, not by editing fields.

/// The desktop window's saved geometry (`x`, `y`, `width`, `height`,
/// `maximized`), or null when none is stored yet.
final Setting<Map<String, Object?>?> windowStateSetting =
    Setting<Map<String, Object?>?>(
      key: 'window.state',
      tier: SettingTier.device,
      defaultValue: null,
      encode: (value) => value,
      decode: (raw) =>
          raw is Map<String, dynamic> ? Map<String, Object?>.of(raw) : null,
    );

/// The engram-browser sidebar width in logical pixels, or null when the user
/// has never dragged the divider (callers apply their own default and clamp).
final Setting<double?> sidebarWidthSetting = Setting<double?>(
  key: 'ui.sidebarWidth',
  tier: SettingTier.device,
  defaultValue: null,
  encode: (value) => value,
  decode: (raw) => raw is num ? raw.toDouble() : null,
);

/// The id of the engram this device last had open, or null on a first run.
/// Per-device: which engram you were in is specific to this machine (the note
/// you left off on inside an engram is the per-engram tier — see the browser's
/// `lastOpenedNoteSetting`).
final Setting<String?> lastOpenedEngramSetting = Setting<String?>(
  key: 'engram.lastOpened',
  tier: SettingTier.device,
  defaultValue: null,
  encode: (value) => value,
  decode: (raw) => raw is String ? raw : null,
);
