import 'dart:io';
import 'package:yaml/yaml.dart';

import 'package:brainframe/platform.dart';

const rcFile = '.brainframerc';
const usernamekey = 'username';
final prefsFilename = '${getHomeDir()}${Platform.pathSeparator}$rcFile';

extension ConfigMap<K, V> on Map<K, V> {
  void load() {
    var configFile = File(prefsFilename);
    var yamlString = configFile.readAsStringSync();
    addAll(loadYaml(yamlString));
  }

  void save() {
    var configFile = File(prefsFilename);
    configFile.writeAsStringSync(toString());
  }
}


var prefs = <String, String>{};

void gotoit() {
  prefs.load();
}