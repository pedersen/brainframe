import 'dart:io';

import 'package:args/args.dart';

String cmdname() {
  var cmd = Platform.resolvedExecutable;
  return cmd.split(Platform.pathSeparator).last;
}


void printHelp(ArgParser parser, {bool doExit=true}) {
  const String about = 'the Brain Frame: A tool to help you manage all the '
      'information you try to keep in your brain.';

  print('\n$about\n\n${cmdname()} [options]\n${parser.usage}\n');

  if (doExit) {
    exit(0);
  }
}

ArgResults parse(List<String> args) {
  var parser = ArgParser();
  parser.addFlag('help', abbr:'h', negatable: false);
  var results = parser.parse(args);
  if (results['help']) {
    printHelp(parser);
  }
  return results;
}