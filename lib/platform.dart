import 'dart:io';

import 'package:keep_screen_on/keep_screen_on.dart';

bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
