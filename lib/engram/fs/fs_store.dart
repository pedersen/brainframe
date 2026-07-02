/// Conditional-export seam for the filesystem engram store, mirroring
/// [lib/window/window_state.dart](../../window/window_state.dart): the real
/// `dart:io` implementation on native platforms, a throwing stub on web.
///
/// Callers import only this file and get `createFileSystemEngram`,
/// `openFileSystemEngram`, and `applicationEngramContainerPath` — plus the
/// platform-agnostic [EngramLocation] value type — resolved to the right
/// implementation for the build.
library;

export 'engram_location.dart';
export 'fs_store_stub.dart' if (dart.library.io) 'fs_store_io.dart';
