/// Restores and persists the desktop window's size, position, and maximized
/// state.
///
/// `window_manager` depends on `dart:io` and only supports desktop, so we
/// select the real implementation on `dart:io` platforms and a no-op stub on
/// web via a conditional export. The real implementation itself no-ops on
/// mobile, where there is no OS window to manage.
library;

export 'window_state_stub.dart'
    if (dart.library.io) 'window_state_io.dart';
