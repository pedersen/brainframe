import 'dart:io';
import 'package:yaml/yaml.dart';

import 'package:brainframe/platform.dart';

const rcFile = '.brainframerc';
const usernamekey = 'username';

class BrainFramePreferences {
  final Map<String, String> _prefs = {};
  final prefsFilename = '${getHomeDir()}${Platform.pathSeparator}$rcFile';

  // manage config file
  void load() {
    var configFile = File(prefsFilename);
    var yamlString = configFile.readAsStringSync();
    _prefs.addAll(loadYaml(yamlString));
  }

  void save() {
    var configFile = File(prefsFilename);
    configFile.writeAsStringSync(_prefs.toString());
  }

  // field: username
  String get username {
      return _prefs[usernamekey] ?? "Unknown";
  }

  set username(String? user) {
    if (user != null) {
      _prefs[usernamekey] = user;
    } else {
      if (_prefs.containsKey(usernamekey)) {
        _prefs.remove(usernamekey);
      }
    }
  }
}

BrainFramePreferences prefs = BrainFramePreferences();
