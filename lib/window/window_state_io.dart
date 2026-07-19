import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../settings/device_settings.dart';
import '../settings/settings_store.dart';

const Size _defaultSize = Size(1280, 800);
const Size _minimumSize = Size(640, 480);

/// The device-tier settings store used for window geometry (there is no
/// per-engram window state, so the engram tier is null).
SettingsStore _deviceStore(SharedPreferencesAsync prefs) => SettingsStore(
  device: DeviceSettingsBackend(prefs),
  engram: () => const NullSettingsBackend(),
);

/// True from a "reset to defaults" until the user next resizes or moves the
/// window. While set, geometry is not persisted — otherwise the save-on-close
/// (or a stray event) would immediately rewrite the geometry the user just
/// cleared, silently undoing the reset.
bool _persistenceSuspended = false;

/// Suspends persisting window geometry until the next deliberate resize/move.
/// Called by the settings "reset window & layout" action so the reset sticks.
/// No-op where there is no OS window (see the stub).
void suspendWindowStatePersistence() {
  _persistenceSuspended = true;
}

bool get _isDesktop =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Restores the saved desktop window geometry (or applies sensible defaults)
/// and begins persisting future size, position, and maximized changes.
///
/// No-op on mobile — only desktop platforms have an OS window to manage.
/// Assumes `WidgetsFlutterBinding.ensureInitialized()` has already run.
///
/// Note on position: under Wayland the compositor owns window placement and
/// silently ignores client requests to move a window, so position is neither
/// meaningfully restorable nor savable there. Size and maximized state work on
/// all desktops; position additionally works on X11, macOS, and Windows.
Future<void> initWindowManager() async {
  if (!_isDesktop) return;

  await windowManager.ensureInitialized();
  final store = _deviceStore(SharedPreferencesAsync());
  final saved = await _readSaved(store);

  final options = WindowOptions(
    size: saved?.size ?? _defaultSize,
    minimumSize: _minimumSize,
    center: saved == null,
    title: 'BrainFrame',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    // Size comes from WindowOptions; restore position separately (a no-op on
    // Wayland). Skip it when maximized — maximize() drives the geometry.
    if (saved?.position != null && !(saved!.isMaximized)) {
      await windowManager.setPosition(saved.position!);
    }
    await windowManager.show();
    await windowManager.focus();
    if (saved?.isMaximized ?? false) {
      await windowManager.maximize();
    }
  });

  // Persist on close as well as on change, so the final geometry is never lost.
  await windowManager.setPreventClose(true);
  windowManager.addListener(_WindowStatePersister(store));
}

/// Persists window geometry whenever it changes.
///
/// Linux (GTK) emits only the present-tense `resize`/`move` events, while
/// macOS and Windows emit the past-tense `resized`/`moved` variants. We listen
/// for both and debounce, since the present-tense events fire continuously
/// during a drag.
class _WindowStatePersister extends WindowListener {
  _WindowStatePersister(this._store);

  final SettingsStore _store;
  Timer? _debounce;

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _save);
  }

  /// A deliberate user resize/move re-enables persistence after a reset — the
  /// user is choosing a new geometry, which should be remembered again.
  void _onGeometryChanged() {
    _persistenceSuspended = false;
    _scheduleSave();
  }

  Future<void> _save() async {
    if (_persistenceSuspended) return;
    final isMaximized = await windowManager.isMaximized();

    if (isMaximized) {
      // Keep the previously stored "normal" geometry so that un-maximizing on
      // next launch restores a sensible size rather than the full-screen one.
      final previous = await _readSaved(_store);
      await _write(
        position: previous?.position,
        size: previous?.size ?? _defaultSize,
        isMaximized: true,
      );
      return;
    }

    await _write(
      position: await windowManager.getPosition(),
      size: await windowManager.getSize(),
      isMaximized: false,
    );
  }

  Future<void> _write({
    required Offset? position,
    required Size size,
    required bool isMaximized,
  }) async {
    await _store.write(windowStateSetting, {
      if (position != null) 'x': position.dx,
      if (position != null) 'y': position.dy,
      'width': size.width,
      'height': size.height,
      'maximized': isMaximized,
    });
  }

  // Present-tense (Linux) and past-tense (macOS/Windows) geometry events.
  @override
  void onWindowResize() => _onGeometryChanged();

  @override
  void onWindowResized() => _onGeometryChanged();

  @override
  void onWindowMove() => _onGeometryChanged();

  @override
  void onWindowMoved() => _onGeometryChanged();

  @override
  void onWindowMaximize() => _onGeometryChanged();

  @override
  void onWindowUnmaximize() => _onGeometryChanged();

  @override
  Future<void> onWindowClose() async {
    _debounce?.cancel();
    try {
      await _save();
    } finally {
      // We intercepted the close (setPreventClose); always actually close,
      // even if the final save failed.
      await windowManager.destroy();
    }
  }
}

class _SavedWindowState {
  const _SavedWindowState({
    required this.position,
    required this.size,
    required this.isMaximized,
  });

  /// Null when no position was stored (e.g. saved under Wayland).
  final Offset? position;
  final Size size;
  final bool isMaximized;
}

Future<_SavedWindowState?> _readSaved(SettingsStore store) async {
  final map = await store.read(windowStateSetting);
  if (map == null) return null;
  try {
    final x = map['x'] as num?;
    final y = map['y'] as num?;
    return _SavedWindowState(
      position: (x != null && y != null)
          ? Offset(x.toDouble(), y.toDouble())
          : null,
      size: Size(
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      ),
      isMaximized: map['maximized'] as bool? ?? false,
    );
  } catch (_) {
    // Corrupt or outdated state — fall back to defaults.
    return null;
  }
}
