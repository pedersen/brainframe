import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const String _prefsKey = 'window_state';
const Size _defaultSize = Size(1280, 800);
const Size _minimumSize = Size(640, 480);

bool get _isDesktop =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Restores the saved desktop window bounds (or applies sensible defaults) and
/// begins persisting future size, position, and maximized changes.
///
/// No-op on mobile — only desktop platforms have an OS window to manage.
/// Assumes `WidgetsFlutterBinding.ensureInitialized()` has already run.
Future<void> initWindowManager() async {
  if (!_isDesktop) return;

  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = _readSaved(prefs);

  final options = WindowOptions(
    size: saved?.size ?? _defaultSize,
    minimumSize: _minimumSize,
    center: saved == null,
    title: 'BrainFrame',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    if (saved != null) {
      await windowManager.setBounds(
        Rect.fromLTWH(
          saved.offset.dx,
          saved.offset.dy,
          saved.size.width,
          saved.size.height,
        ),
      );
    }
    await windowManager.show();
    await windowManager.focus();
    if (saved?.isMaximized ?? false) {
      await windowManager.maximize();
    }
  });

  windowManager.addListener(_WindowStatePersister(prefs));
}

/// Persists window geometry whenever it changes.
class _WindowStatePersister extends WindowListener {
  _WindowStatePersister(this._prefs);

  final SharedPreferences _prefs;

  Future<void> _save() async {
    final isMaximized = await windowManager.isMaximized();

    // While maximized, keep the previously stored "normal" bounds so that
    // un-maximizing on next launch restores a sensible size rather than the
    // full-screen rectangle.
    late final Rect bounds;
    if (isMaximized) {
      final previous = _readSaved(_prefs);
      bounds = previous != null
          ? Rect.fromLTWH(
              previous.offset.dx,
              previous.offset.dy,
              previous.size.width,
              previous.size.height,
            )
          : await windowManager.getBounds();
    } else {
      bounds = await windowManager.getBounds();
    }

    await _prefs.setString(
      _prefsKey,
      jsonEncode({
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
        'maximized': isMaximized,
      }),
    );
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMoved() => _save();

  @override
  void onWindowMaximize() => _save();

  @override
  void onWindowUnmaximize() => _save();

  @override
  void onWindowClose() => _save();
}

class _SavedWindowState {
  const _SavedWindowState({
    required this.offset,
    required this.size,
    required this.isMaximized,
  });

  final Offset offset;
  final Size size;
  final bool isMaximized;
}

_SavedWindowState? _readSaved(SharedPreferences prefs) {
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _SavedWindowState(
      offset: Offset(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
      ),
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
