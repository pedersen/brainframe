import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';

import 'package:brainframe/platform.dart';
import 'package:brainframe/cli/cli.dart';
import 'package:brainframe/widgets/apphome.dart';

void main(List<String> args) {
  var options = parse(args);

  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop()) {
    setWindowTitle("Brain Frame");
  }

  runApp(const BrainFrameApp());
}
