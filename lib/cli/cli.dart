import 'dart:io';
import 'package:args/args.dart';

import 'package:brainframe/prefs.dart';


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

  var user = ArgParser();
  user.addFlag('username', abbr:'u');
  parser.addCommand('user', user);


  var results = parser.parse(args);
  if (results['help']) {
    printHelp(parser);
  }
  return results;
}


void main(List<String> args) {
  var options = parse(args);
  prefs.username='Michael J. Pedersen';
  prefs.save();
  print(prefs.username);
}
