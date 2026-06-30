import 'package:flutter/widgets.dart';

import 'app.dart';
import 'window/window_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the desktop window's size/position before the first frame.
  // No-op on web and mobile.
  await initWindowManager();
  runApp(const BrainFrameApp());
}
