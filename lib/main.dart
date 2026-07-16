import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'app.dart';
import 'engram/engram.dart';
import 'engram/engram_repository.dart';
import 'engram/fs/fs_store.dart';
import 'startup_options.dart';
import 'window/window_state.dart';

Future<void> main(List<String> args) async {
  // Desktop forwards argv here; mobile and web start with an empty list.
  final options = StartupOptions.parse(args);

  WidgetsFlutterBinding.ensureInitialized();

  // --ignore-config: back every SharedPreferencesAsync in the app with an
  // ephemeral in-memory store, so no saved configuration (engram registry,
  // last-opened engram, window geometry, theme) is read or written. This must
  // run after ensureInitialized — which registers the real platform store — and
  // before the first SharedPreferencesAsync is constructed (initWindowManager
  // and the repository below).
  if (options.ignoreConfig) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  }

  // Restore the desktop window's size/position before the first frame.
  // No-op on web and mobile. With --ignore-config nothing is saved to restore,
  // so the window opens at its default geometry.
  await initWindowManager();

  // The engram registry lives in shared preferences; user engrams sit in the
  // app documents container by default. On web the container resolver throws,
  // and discovery degrades to the built-in tutorial and help engrams.
  final repository = EngramRepository(
    preferences: SharedPreferencesAsync(),
    containerPathResolver: applicationEngramContainerPath,
  );

  runApp(BrainFrameApp(
    repository: repository,
    resolveInitialEngram: _initialEngramResolver(options, repository),
  ));
}

/// The startup engram resolver. With `--engram <path>` it opens that folder
/// directly (creating a marker if it is not yet an engram); otherwise it returns
/// null so the app falls back to the repository's normal
/// last-opened-or-tutorial resolution.
Future<Engram> Function()? _initialEngramResolver(
  StartupOptions options,
  EngramRepository repository,
) {
  final path = options.engramPath;
  if (path == null) return null;
  return () => repository.openEngramAtPath(path);
}
