/// Conditional-export seam for pre-Flutter terminal output, mirroring
/// [window_state.dart](window/window_state.dart) and
/// [fs_store.dart](engram/fs/fs_store.dart): the real `dart:io` implementation
/// on native platforms, a no-op stub on web (which has no stdout and receives
/// no command-line arguments, so `--help` never reaches it).
library;

export 'cli_output_stub.dart' if (dart.library.io) 'cli_output_io.dart';
