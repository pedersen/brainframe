import 'dart:io';

//import 'package:keep_screen_on/keep_screen_on.dart';

bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

String getHomeDir() {
  String? home = "";
  Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS || Platform.isLinux) {
    home = Platform.environment['HOME'];
  } else if (Platform.isWindows) {
    home = Platform.environment['UserProfile'];
  }
  return home ?? '';
}
