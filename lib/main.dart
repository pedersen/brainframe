import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'engram/engram_repository.dart';
import 'engram/fs/fs_store.dart';
import 'window/window_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the desktop window's size/position before the first frame.
  // No-op on web and mobile.
  await initWindowManager();

  // The engram registry lives in shared preferences; user engrams sit in the
  // app documents container by default. On web the container resolver throws,
  // and discovery degrades to the built-in tutorial and help engrams.
  final repository = EngramRepository(
    preferences: SharedPreferencesAsync(),
    containerPathResolver: applicationEngramContainerPath,
  );

  runApp(BrainFrameApp(repository: repository));
}
